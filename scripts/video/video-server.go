package main

import (
	"bytes"
	"context"
	"crypto/md5"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"os/exec"
	"os/signal"
	"path/filepath"
	"regexp"
	"runtime"
	"sort"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"unsafe"

	"golang.org/x/sync/singleflight"
	"golang.org/x/sys/unix"
)

// ── Config ────────────────────────────────────────────────────────────────────

var (
	homeDir = mustHomeDir()
	videoRoots = map[string]string{
		"anime": filepath.Join(homeDir, "Videos", "アニメ"),
		"drama": filepath.Join(homeDir, "Videos", "ドラマ"),
	}
	cacheDir      = filepath.Join(homeDir, ".local", "share", "quickshell-video", "covers")
	durationCache = filepath.Join(homeDir, ".local", "share", "quickshell-video", "durations.json")
	overridesFile = filepath.Join(homeDir, ".config", "quickshell", "modules", "video-overrides.json")
	watchLaterDir = filepath.Join(homeDir, ".local", "share", "mpv", "watch_later")
	// Set TMDB_API_KEY env var to override; falls back to built-in key
	tmdbAPIKey = envOr("TMDB_API_KEY", "5e08cb97ea8502aa86592271cbf400d5")
	videoExts  = map[string]bool{
		".mkv": true, ".mp4": true, ".avi": true, ".webm": true, ".m4v": true,
	}
)

func mustHomeDir() string {
	h, err := os.UserHomeDir()
	if err != nil {
		panic(err)
	}
	return h
}

func envOr(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func unsafePointer(b *byte) unsafe.Pointer {
	return unsafe.Pointer(b)
}

// ── Duration cache ────────────────────────────────────────────────────────────
// Persisted to disk so durations survive server restarts.
// Key: "size:mtime_unix" — auto-invalidates if the file is ever replaced.

// durationEntry stores either a real duration (>0) or a failure sentinel (-1).
// Failed entries are retried after durFailureRetryAfter.
type durationEntry struct {
	Duration    float64   `json:"d"`
	FailedAt    time.Time `json:"failed_at,omitempty"`
}

const (
	durFailureSentinel    = -1.0
	durFailureRetryAfter  = 7 * 24 * time.Hour // retry failed probes after 1 week
)

var (
	durCacheMu    sync.RWMutex
	durCacheMem   = make(map[string]durationEntry, 512)
	durCacheDirty atomic.Bool
)

// durKey builds a cache key that invalidates automatically when the file changes.
func durKey(path string) string {
	fi, err := os.Stat(path)
	if err != nil {
		return path
	}
	return fmt.Sprintf("%d:%d", fi.Size(), fi.ModTime().Unix())
}

func loadDurationCache() {
	data, err := os.ReadFile(durationCache)
	if err != nil {
		return
	}
	var m map[string]durationEntry
	if err := json.Unmarshal(data, &m); err != nil {
		return
	}
	durCacheMu.Lock()
	for k, v := range m {
		durCacheMem[k] = v
	}
	durCacheMu.Unlock()
	log.Printf("[duration-cache] loaded %d entries", len(m))
}

func saveDurationCache() {
	if !durCacheDirty.Swap(false) {
		return
	}
	durCacheMu.RLock()
	m := make(map[string]durationEntry, len(durCacheMem))
	for k, v := range durCacheMem {
		m[k] = v
	}
	durCacheMu.RUnlock()

	data, err := json.Marshal(m)
	if err != nil {
		return
	}
	// Atomic write via temp file — no corrupt cache on crash
	tmp := durationCache + ".tmp"
	if err := os.WriteFile(tmp, data, 0644); err != nil {
		return
	}
	os.Rename(tmp, durationCache)
}

// startDurationCacheFlusher flushes dirty cache to disk every 30s and on shutdown.
func startDurationCacheFlusher(ctx context.Context) {
	go func() {
		t := time.NewTicker(30 * time.Second)
		defer t.Stop()
		for {
			select {
			case <-t.C:
				saveDurationCache()
			case <-ctx.Done():
				saveDurationCache()
				return
			}
		}
	}()
}

// sweepDurationCache removes entries whose keys are no longer present in the
// live library. Called once on startup after the initial scan, and weekly
// via a background ticker. Prevents durations.json growing forever.
func sweepDurationCache(livePaths []string) {
	// Build set of live keys
	liveKeys := make(map[string]struct{}, len(livePaths))
	for _, p := range livePaths {
		liveKeys[durKey(p)] = struct{}{}
	}

	durCacheMu.Lock()
	evicted := 0
	for k := range durCacheMem {
		if _, ok := liveKeys[k]; !ok {
			delete(durCacheMem, k)
			evicted++
		}
	}
	durCacheMu.Unlock()

	if evicted > 0 {
		durCacheDirty.Store(true)
		log.Printf("[duration-cache] swept %d stale entries", evicted)
	}
}

// collectAllVideoPaths returns every video file path currently in the library
// roots, used by sweepDurationCache.
func collectAllVideoPaths() []string {
	var paths []string
	for _, root := range videoRoots {
		entries, err := os.ReadDir(root)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}
			files, err := os.ReadDir(filepath.Join(root, entry.Name()))
			if err != nil {
				continue
			}
			for _, f := range files {
				if !f.IsDir() && videoExts[strings.ToLower(filepath.Ext(f.Name()))] {
					paths = append(paths, filepath.Join(root, entry.Name(), f.Name()))
				}
			}
		}
	}
	return paths
}

// startWeeklyCacheSweep runs sweepDurationCache once a week in the background.
func startWeeklyCacheSweep(ctx context.Context) {
	go func() {
		t := time.NewTicker(7 * 24 * time.Hour)
		defer t.Stop()
		for {
			select {
			case <-t.C:
				sweepDurationCache(collectAllVideoPaths())
			case <-ctx.Done():
				return
			}
		}
	}()
}

// ── inotify filesystem watcher ────────────────────────────────────────────────
// Watches videoRoots for new/deleted files and invalidates the library cache
// immediately so new episodes appear without pressing refresh.

func startFSWatcher(ctx context.Context) {
	fd, err := unix.InotifyInit1(unix.IN_CLOEXEC | unix.IN_NONBLOCK)
	if err != nil {
		log.Printf("[fswatcher] inotify init failed: %v — auto-refresh disabled", err)
		return
	}

	// Watch each root dir and every series subdir (two levels deep)
	watched := make(map[int]string)
	addWatch := func(path string) {
		wd, err := unix.InotifyAddWatch(fd, path,
			unix.IN_CREATE|unix.IN_DELETE|unix.IN_MOVED_FROM|unix.IN_MOVED_TO|unix.IN_CLOSE_WRITE)
		if err == nil {
			watched[wd] = path
		}
	}

	for _, root := range videoRoots {
		addWatch(root)
		entries, err := os.ReadDir(root)
		if err != nil {
			continue
		}
		for _, e := range entries {
			if e.IsDir() {
				addWatch(filepath.Join(root, e.Name()))
			}
		}
	}

	log.Printf("[fswatcher] watching %d directories", len(watched))

	go func() {
		defer unix.Close(fd)
		buf := make([]byte, 4096)
		// Debounce — don't rescan on every single event when copying a batch of files
		var debounce *time.Timer
		const debounceDelay = 3 * time.Second

		for {
			select {
			case <-ctx.Done():
				return
			default:
			}

			n, err := unix.Read(fd, buf)
			if err != nil {
				if err == unix.EAGAIN {
					time.Sleep(500 * time.Millisecond)
					continue
				}
				log.Printf("[fswatcher] read error: %v", err)
				return
			}

			// Parse events — if any involve a video file or dir, debounce a rescan
			offset := 0
			triggered := false
			for offset+unix.SizeofInotifyEvent <= n {
				event := (*unix.InotifyEvent)(unsafePointer(&buf[offset]))
				nameLen := int(event.Len)
				var name string
				if nameLen > 0 && offset+unix.SizeofInotifyEvent+nameLen <= n {
					nameBytes := buf[offset+unix.SizeofInotifyEvent : offset+unix.SizeofInotifyEvent+nameLen]
					name = strings.TrimRight(string(nameBytes), "\x00")
				}
				ext := strings.ToLower(filepath.Ext(name))
				// Trigger on video files OR new directories (new series folder)
				if videoExts[ext] || (event.Mask&unix.IN_CREATE != 0 && event.Mask&unix.IN_ISDIR != 0) {
					// Watch new subdirectory so files added inside it are caught
					if event.Mask&unix.IN_ISDIR != 0 && event.Mask&unix.IN_CREATE != 0 {
						if dir, ok := watched[int(event.Wd)]; ok {
							newDir := filepath.Join(dir, name)
							addWatch(newDir)
						}
					}
					triggered = true
				}
				offset += unix.SizeofInotifyEvent + nameLen
			}

			if triggered {
				if debounce != nil {
					debounce.Reset(debounceDelay)
				} else {
					debounce = time.AfterFunc(debounceDelay, func() {
						log.Println("[fswatcher] change detected — invalidating library cache")
						libraryMu.Lock()
						libraryCache = nil
						libraryLastScan = time.Time{}
						libraryMu.Unlock()
						debounce = nil
					})
				}
			}
		}
	}()
}

// ── Constants & globals ───────────────────────────────────────────────────────

const (
	coverWarmupWorkers = 3
	libraryCacheTTL    = 5 * time.Minute
)

var (
	maxScanWorkers = getRecommendedScanWorkers()
	coverGroup     singleflight.Group
	refreshing     atomic.Bool
)

// ── In-memory cover path cache ────────────────────────────────────────────────

var (
	coverMemCacheMu sync.RWMutex
	coverMemCache   = make(map[string]string, 256)
)

func getCoverFromMemCache(cat, name string) (string, bool) {
	coverMemCacheMu.RLock()
	defer coverMemCacheMu.RUnlock()
	v, ok := coverMemCache[cat+":"+name]
	return v, ok
}

func setCoverInMemCache(cat, name, path string) {
	coverMemCacheMu.Lock()
	defer coverMemCacheMu.Unlock()
	coverMemCache[cat+":"+name] = path
}

func evictCoverFromMemCache(cat, name string) {
	coverMemCacheMu.Lock()
	defer coverMemCacheMu.Unlock()
	delete(coverMemCache, cat+":"+name)
}

// ── Library cache ─────────────────────────────────────────────────────────────

var (
	libraryMu       sync.Mutex
	libraryCache    []Series
	libraryLastScan time.Time
)

func getLibrary() []Series {
	libraryMu.Lock()
	defer libraryMu.Unlock()
	if libraryCache != nil && time.Since(libraryLastScan) < libraryCacheTTL {
		return libraryCache
	}
	libraryCache = scanLibrary()
	libraryLastScan = time.Now()
	return libraryCache
}

// ── Worker count ──────────────────────────────────────────────────────────────

func getRecommendedScanWorkers() int {
	cpus := runtime.NumCPU()
	return max(4, min(cpus, 10))
}

// ── Types ─────────────────────────────────────────────────────────────────────

type Episode struct {
	Filename       string  `json:"filename"`
	Path           string  `json:"path"`
	Position       float64 `json:"position"`
	Watched        bool    `json:"watched"`
	ProgressExists bool    `json:"progress_exists"`
}

type Series struct {
	ID           string    `json:"id"`
	Name         string    `json:"name"`
	Category     string    `json:"category"`
	Cover        string    `json:"cover"`
	Episodes     []Episode `json:"episodes"`
	EpisodeCount int       `json:"episode_count"`
	WatchedCount int       `json:"watched_count"`
}

type Progress struct {
	Position float64 `json:"position"`
	Watched  bool    `json:"watched"`
	Exists   bool    `json:"exists"`
}

// ── Episode sorting ───────────────────────────────────────────────────────────

var (
	reAnimeEp = regexp.MustCompile(`-\s*(\d+)`)
	reDramaEp = regexp.MustCompile(`(?i)[Ss](\d+)[Ee](\d+)`)
)

type episodeSort struct {
	episodes []Episode
	category string
}

func (e episodeSort) Len() int      { return len(e.episodes) }
func (e episodeSort) Swap(i, j int) { e.episodes[i], e.episodes[j] = e.episodes[j], e.episodes[i] }
func (e episodeSort) Less(i, j int) bool {
	ai := episodeKey(e.episodes[i].Filename, e.category)
	aj := episodeKey(e.episodes[j].Filename, e.category)
	if ai[0] != aj[0] {
		return ai[0] < aj[0]
	}
	if ai[1] != aj[1] {
		return ai[1] < aj[1]
	}
	return e.episodes[i].Filename < e.episodes[j].Filename
}

func episodeKey(filename, category string) [2]int {
	stem := strings.TrimSuffix(filename, filepath.Ext(filename))
	if category == "anime" {
		if m := reAnimeEp.FindStringSubmatch(stem); m != nil {
			n, _ := strconv.Atoi(m[1])
			return [2]int{0, n}
		}
	} else if category == "drama" {
		if m := reDramaEp.FindStringSubmatch(stem); m != nil {
			s, _ := strconv.Atoi(m[1])
			e, _ := strconv.Atoi(m[2])
			return [2]int{s, e}
		}
	}
	return [2]int{0, 0}
}

// ── Name cleaning ─────────────────────────────────────────────────────────────

var (
	reLeadingGroup   = regexp.MustCompile(`^\[.*?\]\s*`)
	reTrailingYear1  = regexp.MustCompile(`\s*\(\d{4}\)\s*$`)
	reTrailingYear2  = regexp.MustCompile(`\s+\d{4}\s*$`)
	reTrailingTag    = regexp.MustCompile(`\s*\[.*?\]\s*$`)
	reTrailingSeason = regexp.MustCompile(`(?i)\s+(S\d+|Season\s*\d+|\d+(?:st|nd|rd|th)\s*Season)$`)
	reSplitTitle     = regexp.MustCompile(`[:\-–—]`)
)

func cleanSeriesName(name string) string {
	name = reLeadingGroup.ReplaceAllString(name, "")
	name = reTrailingYear1.ReplaceAllString(name, "")
	name = reTrailingYear2.ReplaceAllString(name, "")
	name = reTrailingTag.ReplaceAllString(name, "")
	name = reTrailingSeason.ReplaceAllString(name, "")
	return strings.TrimSpace(name)
}

func sanitize(name string) string {
	re := regexp.MustCompile(`[^\w\-.]`)
	return re.ReplaceAllString(name, "_")
}

// ── AniList ───────────────────────────────────────────────────────────────────

func anilistQuery(search string) ([]byte, error) {
	query := `query($search:String){Media(search:$search,type:ANIME){coverImage{large}}}`
	payload, _ := json.Marshal(map[string]interface{}{
		"query":     query,
		"variables": map[string]string{"search": search},
	})

	req, _ := http.NewRequest("POST", "https://graphql.anilist.co", bytes.NewReader(payload))
	req.Header.Set("Content-Type", "application/json")
	req.Header.Set("Accept", "application/json")
	req.Header.Set("User-Agent", "Mozilla/5.0 (X11; Linux x86_64; rv:120.0) Gecko/20100101 Firefox/120.0")

	resp, err := http.DefaultClient.Do(req)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("AniList HTTP %d", resp.StatusCode)
	}

	var result struct {
		Data struct {
			Media struct {
				CoverImage struct {
					Large string `json:"large"`
				} `json:"coverImage"`
			} `json:"Media"`
		} `json:"data"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	imgURL := result.Data.Media.CoverImage.Large
	if imgURL == "" {
		return nil, fmt.Errorf("no cover URL")
	}
	return downloadURL(imgURL)
}

func fetchAnilistCover(seriesName string) ([]byte, error) {
	cleaned := cleanSeriesName(seriesName)
	parts := reSplitTitle.Split(cleaned, 2)
	short := strings.TrimSpace(parts[0])

	candidates := []string{seriesName}
	if cleaned != seriesName {
		candidates = append(candidates, cleaned)
	}
	if short != "" && short != cleaned {
		candidates = append(candidates, short)
	}

	for _, attempt := range candidates {
		for retry := 0; retry < 3; retry++ {
			data, err := anilistQuery(attempt)
			if err == nil && len(data) > 0 {
				log.Printf("[AniList] '%s' matched via '%s'", seriesName, attempt)
				return data, nil
			}
			if retry == 2 {
				log.Printf("[AniList] '%s' failed: %v", attempt, err)
			}
		}
	}
	return nil, fmt.Errorf("all candidates failed")
}

// ── TMDB ──────────────────────────────────────────────────────────────────────

func tmdbSearch(name, mediaType string) ([]byte, error) {
	u := fmt.Sprintf("https://api.themoviedb.org/3/search/%s?api_key=%s&query=%s&language=en-US&page=1",
		mediaType, tmdbAPIKey, url.QueryEscape(name))
	resp, err := http.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()

	var result struct {
		Results []struct {
			PosterPath string `json:"poster_path"`
		} `json:"results"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		return nil, err
	}
	if len(result.Results) == 0 || result.Results[0].PosterPath == "" {
		return nil, fmt.Errorf("no results")
	}
	imgURL := fmt.Sprintf("https://image.tmdb.org/t/p/w500%s", result.Results[0].PosterPath)
	return downloadURL(imgURL)
}

func fetchTMDBCover(seriesName string) ([]byte, error) {
	data, err := tmdbSearch(seriesName, "tv")
	if err == nil {
		return data, nil
	}
	return tmdbSearch(seriesName, "movie")
}

// ── Override covers ───────────────────────────────────────────────────────────

func fetchOverrideCover(val string) ([]byte, error) {
	if strings.HasPrefix(val, "tmdb:") {
		parts := strings.SplitN(val, ":", 3)
		if len(parts) != 3 {
			return nil, fmt.Errorf("bad override format")
		}
		mediaType, id := parts[1], parts[2]
		u := fmt.Sprintf("https://api.themoviedb.org/3/%s/%s?api_key=%s", mediaType, id, tmdbAPIKey)
		resp, err := http.Get(u)
		if err != nil {
			return nil, err
		}
		defer resp.Body.Close()
		var result struct {
			PosterPath string `json:"poster_path"`
		}
		if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
			return nil, err
		}
		if result.PosterPath == "" {
			return nil, fmt.Errorf("no poster")
		}
		return downloadURL(fmt.Sprintf("https://image.tmdb.org/t/p/w500%s", result.PosterPath))
	}
	return downloadURL(val)
}

func loadOverrides() map[string]string {
	data, err := os.ReadFile(overridesFile)
	if err != nil {
		return nil
	}
	var overrides map[string]string
	json.Unmarshal(data, &overrides)
	return overrides
}

// ── Cover cache ───────────────────────────────────────────────────────────────

func coverCachePath(category, series string) string {
	return filepath.Join(cacheDir, fmt.Sprintf("%s_%s.jpg", category, sanitize(series)))
}

func fetchAndCacheCover(category, name string) (string, error) {
	path := coverCachePath(category, name)
	overrides := loadOverrides()
	key := category + ":" + name

	var data []byte
	var err error

	if val, ok := overrides[key]; ok {
		data, err = fetchOverrideCover(val)
		if err == nil {
			log.Printf("[cover] override OK: %s", name)
		}
	} else if category == "anime" {
		data, err = fetchAnilistCover(name)
		if err == nil {
			log.Printf("[cover] AniList OK: %s", name)
		} else {
			log.Printf("[cover] AniList failed: %s — %v", name, err)
		}
	} else {
		data, err = fetchTMDBCover(name)
		if err == nil {
			log.Printf("[cover] TMDB OK: %s", name)
		} else {
			log.Printf("[cover] TMDB failed: %s — %v", name, err)
		}
	}

	if err != nil || len(data) == 0 {
		return "", fmt.Errorf("no cover data for %s", name)
	}
	if err := os.WriteFile(path, data, 0644); err != nil {
		return "", err
	}
	return path, nil
}

func getCachedCoverURL(category, name string) string {
	path := coverCachePath(category, name)
	if _, err := os.Stat(path); err == nil {
		return "file://" + path
	}
	return ""
}

// ── MPV progress ──────────────────────────────────────────────────────────────

func mpvHash(path string) string {
	return strings.ToUpper(fmt.Sprintf("%x", md5.Sum([]byte(path))))
}

func getDuration(videoPath string) float64 {
	key := durKey(videoPath)

	// Check in-memory cache first
	durCacheMu.RLock()
	entry, ok := durCacheMem[key]
	durCacheMu.RUnlock()

	if ok {
		// Cached failure — only retry after durFailureRetryAfter
		if entry.Duration == durFailureSentinel {
			if time.Since(entry.FailedAt) < durFailureRetryAfter {
				return 0
			}
			// Retry window elapsed — fall through to ffprobe
		} else {
			return entry.Duration
		}
	}

	// Cache miss or retry — call ffprobe
	out, err := exec.Command("ffprobe", "-v", "quiet", "-print_format", "json",
		"-show_format", videoPath).Output()
	if err != nil {
		// Cache the failure so we don't retry on every scan
		durCacheMu.Lock()
		durCacheMem[key] = durationEntry{Duration: durFailureSentinel, FailedAt: time.Now()}
		durCacheMu.Unlock()
		durCacheDirty.Store(true)
		log.Printf("[ffprobe] failed for %s: %v (will retry in %s)", videoPath, err, durFailureRetryAfter)
		return 0
	}
	var result struct {
		Format struct {
			Duration string `json:"duration"`
		} `json:"format"`
	}
	if err := json.Unmarshal(out, &result); err != nil {
		durCacheMu.Lock()
		durCacheMem[key] = durationEntry{Duration: durFailureSentinel, FailedAt: time.Now()}
		durCacheMu.Unlock()
		durCacheDirty.Store(true)
		return 0
	}
	d, _ := strconv.ParseFloat(result.Format.Duration, 64)
	if d > 0 {
		durCacheMu.Lock()
		durCacheMem[key] = durationEntry{Duration: d}
		durCacheMu.Unlock()
		durCacheDirty.Store(true)
	} else {
		durCacheMu.Lock()
		durCacheMem[key] = durationEntry{Duration: durFailureSentinel, FailedAt: time.Now()}
		durCacheMu.Unlock()
		durCacheDirty.Store(true)
	}
	return d
}

func getProgress(videoPath string) Progress {
	h := mpvHash(videoPath)
	wlFile := filepath.Join(watchLaterDir, h)

	data, err := os.ReadFile(wlFile)
	if err != nil {
		// No watch_later file — skip ffprobe entirely
		return Progress{}
	}

	var position float64
	for _, line := range strings.Split(string(data), "\n") {
		if strings.HasPrefix(line, "start=") {
			position, _ = strconv.ParseFloat(strings.TrimPrefix(line, "start="), 64)
			break
		}
	}

	// Only call ffprobe when we actually have a progress file
	duration := getDuration(videoPath)
	var watched bool
	if duration > 0 {
		watched = position >= duration*0.90
	} else {
		watched = position > 1200
	}

	return Progress{Position: position, Watched: watched, Exists: true}
}

// ── Bulk progress ─────────────────────────────────────────────────────────────

// handleProgressBulk accepts {"paths":[...]} and returns a map of path→Progress.
// Replaces N individual /progress XHR calls with a single round-trip.
func handleProgressBulk(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Paths []string `json:"paths"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || len(body.Paths) == 0 {
		http.Error(w, "bad request", 400)
		return
	}

	result := make(map[string]Progress, len(body.Paths))
	var mu sync.Mutex
	var wg sync.WaitGroup
	sem := make(chan struct{}, maxScanWorkers)

	for _, p := range body.Paths {
		wg.Add(1)
		sem <- struct{}{}
		go func(path string) {
			defer wg.Done()
			defer func() { <-sem }()
			prog := getProgress(path)
			mu.Lock()
			result[path] = prog
			mu.Unlock()
		}(p)
	}
	wg.Wait()
	writeJSON(w, result)
}

// ── Mark watched ──────────────────────────────────────────────────────────────

// handleMarkWatched writes or removes a synthetic mpv watch_later entry so an
// episode can be toggled watched/unwatched without actually playing it.
func handleMarkWatched(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Path    string `json:"path"`
		Watched bool   `json:"watched"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Path == "" {
		http.Error(w, "bad request", 400)
		return
	}

	h := mpvHash(body.Path)
	wlFile := filepath.Join(watchLaterDir, h)

	if !body.Watched {
		// Unmark — remove the watch_later file
		os.Remove(wlFile)
		writeJSON(w, map[string]bool{"ok": true})
		return
	}

	// Mark as watched — write a position past the 90% threshold
	duration := getDuration(body.Path)
	var position float64
	if duration > 0 {
		position = duration * 0.95
	} else {
		position = 1300 // safely past the 1200s heuristic
	}

	os.MkdirAll(watchLaterDir, 0755)
	content := fmt.Sprintf("# mpv watch_later\nstart=%.6f\n", position)
	if err := os.WriteFile(wlFile, []byte(content), 0644); err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	writeJSON(w, map[string]bool{"ok": true})
}

// ── Library scan ─────────────────────────────────────────────────────────────

func scanLibrary() []Series {
	var (
		mu     sync.Mutex
		result []Series
		wg     sync.WaitGroup
		sem    = make(chan struct{}, maxScanWorkers)
	)

	for category, root := range videoRoots {
		entries, err := os.ReadDir(root)
		if err != nil {
			continue
		}
		for _, entry := range entries {
			if !entry.IsDir() {
				continue
			}
			wg.Add(1)
			sem <- struct{}{}
			go func(category, root string, entry os.DirEntry) {
				defer wg.Done()
				defer func() { <-sem }()

				seriesName := entry.Name()
				seriesPath := filepath.Join(root, seriesName)

				files, err := os.ReadDir(seriesPath)
				if err != nil {
					return
				}

				var episodes []Episode
				for _, f := range files {
					if f.IsDir() {
						continue
					}
					ext := strings.ToLower(filepath.Ext(f.Name()))
					if !videoExts[ext] {
						continue
					}
					fullPath := filepath.Join(seriesPath, f.Name())
					prog := getProgress(fullPath)
					episodes = append(episodes, Episode{
						Filename:       f.Name(),
						Path:           fullPath,
						Position:       prog.Position,
						Watched:        prog.Watched,
						ProgressExists: prog.Exists,
					})
				}
				if len(episodes) == 0 {
					return
				}

				sort.Sort(episodeSort{episodes: episodes, category: category})

				coverURL := getCachedCoverURL(category, seriesName)
				watchedCount := 0
				for _, ep := range episodes {
					if ep.Watched {
						watchedCount++
					}
				}

				mu.Lock()
				result = append(result, Series{
					ID:           category + ":" + seriesName,
					Name:         seriesName,
					Category:     category,
					Cover:        coverURL,
					Episodes:     episodes,
					EpisodeCount: len(episodes),
					WatchedCount: watchedCount,
				})
				mu.Unlock()
			}(category, root, entry)
		}
	}

	wg.Wait()

	sort.Slice(result, func(i, j int) bool {
		if result[i].Category != result[j].Category {
			return result[i].Category < result[j].Category
		}
		return result[i].Name < result[j].Name
	})

	return result
}

// ── Warmup covers ─────────────────────────────────────────────────────────────

func warmupCovers(series []Series) {
	var wg sync.WaitGroup
	sem := make(chan struct{}, coverWarmupWorkers)

	toFetch := 0
	for _, s := range series {
		if getCachedCoverURL(s.Category, s.Name) == "" {
			toFetch++
		}
	}
	log.Printf("[warmup] fetching covers for %d/%d series", toFetch, len(series))
	start := time.Now()

	for _, s := range series {
		if getCachedCoverURL(s.Category, s.Name) != "" {
			continue
		}
		wg.Add(1)
		sem <- struct{}{}
		go func(cat, name string) {
			defer wg.Done()
			defer func() { <-sem }()
			time.Sleep(time.Duration(rand.Intn(601)) * time.Millisecond)
			fetchAndCacheCover(cat, name)
		}(s.Category, s.Name)
	}

	wg.Wait()
	log.Printf("[warmup] done in %s", time.Since(start).Round(time.Millisecond))
}

// ── HTTP helpers ──────────────────────────────────────────────────────────────

func downloadURL(u string) ([]byte, error) {
	resp, err := http.Get(u)
	if err != nil {
		return nil, err
	}
	defer resp.Body.Close()
	if resp.StatusCode != 200 {
		return nil, fmt.Errorf("HTTP %d", resp.StatusCode)
	}
	return io.ReadAll(resp.Body)
}

func writeJSON(w http.ResponseWriter, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.Header().Set("Access-Control-Allow-Origin", "*")
	json.NewEncoder(w).Encode(v)
}

func withCORS(h http.HandlerFunc) http.HandlerFunc {
	return func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		h(w, r)
	}
}

// ── Handlers ──────────────────────────────────────────────────────────────────

func handleLibrary(w http.ResponseWriter, r *http.Request) {
	writeJSON(w, getLibrary())
}

func handleProgress(w http.ResponseWriter, r *http.Request) {
	path := r.URL.Query().Get("path")
	writeJSON(w, getProgress(path))
}

func handleCover(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	parts := strings.SplitN(id, ":", 2)
	if len(parts) != 2 {
		http.NotFound(w, r)
		return
	}
	cat, name := parts[0], parts[1]

	// 1. In-memory cache — no syscall
	if cachedPath, ok := getCoverFromMemCache(cat, name); ok {
		serveCoverWithCacheHeaders(w, r, cachedPath)
		return
	}

	// 2. Disk cache
	path := coverCachePath(cat, name)
	if _, err := os.Stat(path); err == nil {
		setCoverInMemCache(cat, name, path)
		serveCoverWithCacheHeaders(w, r, path)
		return
	}

	// 3. Fetch — singleflight collapses concurrent requests
	_, err, _ := coverGroup.Do(cat+":"+name, func() (interface{}, error) {
		return fetchAndCacheCover(cat, name)
	})
	if err != nil {
		http.NotFound(w, r)
		return
	}
	setCoverInMemCache(cat, name, path)
	serveCoverWithCacheHeaders(w, r, path)
}

func serveCoverWithCacheHeaders(w http.ResponseWriter, r *http.Request, path string) {
	f, err := os.Open(path)
	if err != nil {
		http.NotFound(w, r)
		return
	}
	defer f.Close()

	fi, err := f.Stat()
	if err != nil {
		http.NotFound(w, r)
		return
	}

	etag := fmt.Sprintf(`"%d-%d"`, fi.Size(), fi.ModTime().Unix())
	w.Header().Set("ETag", etag)
	w.Header().Set("Cache-Control", "public, max-age=86400, immutable")
	w.Header().Set("Content-Type", "image/jpeg")

	if match := r.Header.Get("If-None-Match"); match == etag {
		w.WriteHeader(http.StatusNotModified)
		return
	}

	http.ServeContent(w, r, fi.Name(), fi.ModTime(), f)
}

func handleRefreshCover(w http.ResponseWriter, r *http.Request) {
	id := r.URL.Query().Get("id")
	parts := strings.SplitN(id, ":", 2)
	if len(parts) != 2 {
		http.Error(w, "bad id", 400)
		return
	}
	cat, name := parts[0], parts[1]
	cached := coverCachePath(cat, name)
	os.Remove(cached)
	evictCoverFromMemCache(cat, name)
	path, err := fetchAndCacheCover(cat, name)
	if err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	setCoverInMemCache(cat, name, path)
	writeJSON(w, map[string]string{"cover": "file://" + path})
}

func handleRefreshLibrary(w http.ResponseWriter, r *http.Request) {
	if !refreshing.CompareAndSwap(false, true) {
		writeJSON(w, map[string]string{
			"status":  "already_running",
			"message": "Library scan already in progress",
		})
		return
	}

	libraryMu.Lock()
	libraryCache = nil
	libraryLastScan = time.Time{}
	libraryMu.Unlock()

	go func() {
		defer refreshing.Store(false)
		getLibrary()
	}()

	writeJSON(w, map[string]string{
		"status":  "refresh triggered",
		"message": "Library scan started in background",
	})
}

func handlePlay(w http.ResponseWriter, r *http.Request) {
	var body struct {
		Path string `json:"path"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil || body.Path == "" {
		http.Error(w, "bad request", 400)
		return
	}
	if _, err := os.Stat(body.Path); err != nil {
		http.Error(w, "file not found", 400)
		return
	}
	cmd := exec.Command("setsid", "mpv", "--fullscreen", body.Path)
	cmd.SysProcAttr = &syscall.SysProcAttr{Setsid: true}
	if err := cmd.Start(); err != nil {
		http.Error(w, err.Error(), 500)
		return
	}
	cmd.Process.Release()
	writeJSON(w, map[string]bool{"ok": true})
}

// ── Main ──────────────────────────────────────────────────────────────────────

func main() {
	ctx, stop := signal.NotifyContext(context.Background(), syscall.SIGINT, syscall.SIGTERM)
	defer stop()

	os.MkdirAll(cacheDir, 0755)

	// Load persisted duration cache so ffprobe is skipped for known files
	loadDurationCache()
	startDurationCacheFlusher(ctx)

	// Watch filesystem for new/deleted episodes — invalidates library cache automatically
	startFSWatcher(ctx)

	// Warm up library + covers on start so first panel open is instant.
	// After warmup, sweep stale duration cache entries.
	go func() {
		lib := getLibrary()
		warmupCovers(lib)
		sweepDurationCache(collectAllVideoPaths())
		startWeeklyCacheSweep(ctx)
	}()

	mux := http.NewServeMux()
	mux.HandleFunc("/library",          withCORS(handleLibrary))
	mux.HandleFunc("/progress",         withCORS(handleProgress))
	mux.HandleFunc("/progress_bulk",    withCORS(handleProgressBulk))
	mux.HandleFunc("/cover",            withCORS(handleCover))
	mux.HandleFunc("/refresh_cover",    withCORS(handleRefreshCover))
	mux.HandleFunc("/play",             withCORS(handlePlay))
	mux.HandleFunc("/refresh_library",  withCORS(handleRefreshLibrary))
	mux.HandleFunc("/mark_watched",     withCORS(handleMarkWatched))

	srv := &http.Server{
		Addr:         "127.0.0.1:5176",
		Handler:      mux,
		ReadTimeout:  10 * time.Second,
		WriteTimeout: 30 * time.Second,
		IdleTimeout:  60 * time.Second,
	}

	go func() {
		log.Printf("[video-server] listening on http://127.0.0.1:5176 (scan workers: %d, cache TTL: %s)",
			maxScanWorkers, libraryCacheTTL)
		if err := srv.ListenAndServe(); err != nil && err != http.ErrServerClosed {
			log.Fatalf("[video-server] fatal: %v", err)
		}
	}()

	<-ctx.Done()
	log.Println("[video-server] shutting down...")
	shutCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()
	if err := srv.Shutdown(shutCtx); err != nil {
		log.Printf("[video-server] shutdown error: %v", err)
	}
	log.Println("[video-server] stopped")
}
