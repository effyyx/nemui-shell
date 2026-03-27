package main

import (
	"bytes"
	"crypto/sha256"
	"encoding/hex"
	"encoding/json"
	"fmt"
	"image/png"
	"io"
	"log"
	"math/rand"
	"net/http"
	"net/url"
	"os"
	"path/filepath"
	"regexp"
	"strings"
	"sync"
	"time"

	"golang.org/x/image/webp"
	"golang.org/x/sync/singleflight"
)

const (
	PORT    = 5175
	BASE    = "https://rawkuma.net"
	DATADIR = ".local/share/quickshell-manga"
)

// ── Outbound rate limiter ──────────────────────────────────────────────────
// Max 4 concurrent outbound HTTP requests to rawkuma at a time.
var fetchSem = make(chan struct{}, 4)

func acquireFetch() { fetchSem <- struct{}{} }
func releaseFetch() { <-fetchSem }

// jitter adds a small random delay to spread out burst requests.
func jitter() {
	time.Sleep(time.Duration(rand.Intn(300)) * time.Millisecond)
}

// ── HTTP Client ────────────────────────────────────────────────────────────
var client = &http.Client{
	Timeout: 20 * time.Second,
}

var headers = map[string]string{
	"User-Agent":      "Mozilla/5.0 (X11; Linux x86_64; rv:128.0) Gecko/20100101 Firefox/128.0",
	"Accept":          "text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8",
	"Accept-Language": "ja,en;q=0.5",
	"Accept-Encoding": "identity",
	"Connection":      "keep-alive",
}

func fetch(rawURL string) (string, error) {
	acquireFetch()
	defer releaseFetch()
	jitter()
	req, err := http.NewRequest("GET", rawURL, nil)
	if err != nil {
		return "", err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := client.Do(req)
	if err != nil {
		return "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	return string(body), err
}

func fetchBytes(rawURL string) ([]byte, string, error) {
	acquireFetch()
	defer releaseFetch()
	jitter()
	req, err := http.NewRequest("GET", rawURL, nil)
	if err != nil {
		return nil, "", err
	}
	for k, v := range headers {
		req.Header.Set(k, v)
	}
	resp, err := client.Do(req)
	if err != nil {
		return nil, "", err
	}
	defer resp.Body.Close()
	body, err := io.ReadAll(resp.Body)
	ct := resp.Header.Get("Content-Type")
	if ct == "" {
		ct = "image/jpeg"
	}
	return body, ct, err
}

// ── In-memory cache with failure caching ──────────────────────────────────
type cacheEntry struct {
	data     interface{}
	expires  time.Time
	failedAt time.Time // non-zero = failure entry
}

const failRetryAfter = 30 * time.Second

var (
	cache   = map[string]cacheEntry{}
	cacheMu sync.Mutex
)

func cached(key string, ttl time.Duration, fn func() (interface{}, error)) (interface{}, error) {
	cacheMu.Lock()
	entry, ok := cache[key]
	cacheMu.Unlock()

	if ok {
		// Success hit
		if entry.failedAt.IsZero() && time.Now().Before(entry.expires) {
			return entry.data, nil
		}
		// Failure hit — don't retry yet
		if !entry.failedAt.IsZero() && time.Since(entry.failedAt) < failRetryAfter {
			return nil, fmt.Errorf("cached failure, retry after %s",
				entry.failedAt.Add(failRetryAfter).Format(time.Kitchen))
		}
	}

	val, err := fn()
	cacheMu.Lock()
	if err != nil {
		cache[key] = cacheEntry{failedAt: time.Now()}
	} else {
		cache[key] = cacheEntry{data: val, expires: time.Now().Add(ttl)}
	}
	cacheMu.Unlock()
	return val, err
}

// ── Singleflight ───────────────────────────────────────────────────────────
var fetchGroup singleflight.Group

// ── WebP → PNG conversion ──────────────────────────────────────────────────
func maybeConvertWebP(body []byte, ct string) ([]byte, string) {
	if !strings.Contains(ct, "webp") {
		return body, ct
	}
	img, err := webp.Decode(bytes.NewReader(body))
	if err != nil {
		return body, ct
	}
	var buf bytes.Buffer
	if err := png.Encode(&buf, img); err != nil {
		return body, ct
	}
	return buf.Bytes(), "image/png"
}

// ── Disk image cache (L2) ──────────────────────────────────────────────────
// Images stored as DATADIR/imgcache/<sha256>.img + <sha256>.ct
// Survives server restarts — once fetched, never re-fetched.

func imgCacheDir() string {
	return filepath.Join(homeDir(), DATADIR, "imgcache")
}

func imgCacheKey(u string) string {
	h := sha256.Sum256([]byte(u))
	return hex.EncodeToString(h[:])
}

func diskImgGet(u string) ([]byte, string, bool) {
	key := imgCacheKey(u)
	dir := imgCacheDir()
	ctBytes, err := os.ReadFile(filepath.Join(dir, key+".ct"))
	if err != nil {
		return nil, "", false
	}
	body, err := os.ReadFile(filepath.Join(dir, key+".img"))
	if err != nil {
		return nil, "", false
	}
	return body, string(ctBytes), true
}

func diskImgPut(u string, body []byte, ct string) {
	key := imgCacheKey(u)
	dir := imgCacheDir()
	os.MkdirAll(dir, 0755)
	os.WriteFile(filepath.Join(dir, key+".img"), body, 0644)
	os.WriteFile(filepath.Join(dir, key+".ct"), []byte(ct), 0644)
}

// ── In-memory image cache (L1) ─────────────────────────────────────────────
type imgEntry struct {
	body []byte
	ct   string
}

var (
	imgMemCache   = map[string]imgEntry{}
	imgMemCacheMu sync.Mutex
	imgMemMax     = 200
)

func imgMemGet(u string) (imgEntry, bool) {
	imgMemCacheMu.Lock()
	defer imgMemCacheMu.Unlock()
	e, ok := imgMemCache[u]
	return e, ok
}

func imgMemPut(u string, e imgEntry) {
	imgMemCacheMu.Lock()
	defer imgMemCacheMu.Unlock()
	if len(imgMemCache) >= imgMemMax {
		for k := range imgMemCache {
			delete(imgMemCache, k)
			break
		}
	}
	imgMemCache[u] = e
}

// getImage: L1 mem → L2 disk → fetch (singleflight-deduped)
func getImage(imgURL string) ([]byte, string, error) {
	// L1: memory
	if e, ok := imgMemGet(imgURL); ok {
		return e.body, e.ct, nil
	}
	// L2: disk
	if body, ct, ok := diskImgGet(imgURL); ok {
		imgMemPut(imgURL, imgEntry{body, ct})
		return body, ct, nil
	}
	// Fetch — only one goroutine fetches per URL, others wait and share the result
	type result struct {
		body []byte
		ct   string
	}
	v, err, _ := fetchGroup.Do("img:"+imgURL, func() (interface{}, error) {
		body, ct, err := fetchBytes(imgURL)
		if err != nil {
			return nil, err
		}
		body, ct = maybeConvertWebP(body, ct)
		diskImgPut(imgURL, body, ct)
		imgMemPut(imgURL, imgEntry{body, ct})
		return result{body, ct}, nil
	})
	if err != nil {
		return nil, "", err
	}
	r := v.(result)
	return r.body, r.ct, nil
}

// ── Data types ─────────────────────────────────────────────────────────────
type MangaItem struct {
	ID      string `json:"id"`
	Title   string `json:"title"`
	Image   string `json:"image"`
	Chapter string `json:"chapter"`
	URL     string `json:"url"`
}

type Chapter struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	URL   string `json:"url"`
	Date  string `json:"date"`
}

type SeriesInfo struct {
	ID       string    `json:"id"`
	Title    string    `json:"title"`
	Image    string    `json:"image"`
	RawImage string    `json:"rawImage"`
	Status   string    `json:"status"`
	Type     string    `json:"type"`
	Synopsis string    `json:"synopsis"`
	Chapters []Chapter `json:"chapters"`
}

type PageItem struct {
	Page int    `json:"page"`
	Img  string `json:"img"`
}

type PagesResult struct {
	Pages   []PageItem `json:"pages"`
	NextURL string     `json:"nextUrl"`
	Total   int        `json:"total"`
}

type Favorite struct {
	ID    string `json:"id"`
	Title string `json:"title"`
	Image string `json:"image"`
	URL   string `json:"url"`
}

// ── Progress ───────────────────────────────────────────────────────────────
type ProgressStore map[string][]string

var progressMu sync.Mutex

func progressFile() string {
	return filepath.Join(homeDir(), DATADIR, "progress.json")
}

func loadProgress() (ProgressStore, error) {
	progressMu.Lock()
	defer progressMu.Unlock()
	data, err := os.ReadFile(progressFile())
	if os.IsNotExist(err) {
		return ProgressStore{}, nil
	}
	if err != nil {
		return nil, err
	}
	var ps ProgressStore
	if err := json.Unmarshal(data, &ps); err != nil {
		return ProgressStore{}, nil
	}
	return ps, nil
}

func saveProgress(ps ProgressStore) error {
	progressMu.Lock()
	defer progressMu.Unlock()
	os.MkdirAll(filepath.Dir(progressFile()), 0755)
	data, _ := json.MarshalIndent(ps, "", "  ")
	return os.WriteFile(progressFile(), data, 0644)
}

func getProgress(mangaID string) ([]string, error) {
	ps, err := loadProgress()
	if err != nil {
		return nil, err
	}
	chapters := ps[mangaID]
	if chapters == nil {
		chapters = []string{}
	}
	return chapters, nil
}

func setProgress(mangaID, chapterID string) error {
	ps, err := loadProgress()
	if err != nil {
		return err
	}
	for _, c := range ps[mangaID] {
		if c == chapterID {
			return nil
		}
	}
	ps[mangaID] = append(ps[mangaID], chapterID)
	return saveProgress(ps)
}

// ── Helpers ────────────────────────────────────────────────────────────────
var reHTML = regexp.MustCompile(`<[^>]+>`)

func cleanHTML(s string) string {
	return strings.TrimSpace(reHTML.ReplaceAllString(s, ""))
}

func proxyURL(imgURL string) string {
	return fmt.Sprintf("http://127.0.0.1:%d/image?url=%s", PORT, url.QueryEscape(imgURL))
}

func homeDir() string {
	h, _ := os.UserHomeDir()
	return h
}

func favFile() string {
	return filepath.Join(homeDir(), DATADIR, "favorites.json")
}

// ── Regexps ────────────────────────────────────────────────────────────────
var (
	// Step 1: extract each <a href=".../manga/SLUG/"> block (everything up to </a>)
	reAnchorBlock = regexp.MustCompile(
		`<a[^>]+href="https://rawkuma\.net/manga/([^/"]+)/?"[^>]*>([\s\S]{0,800}?)</a>`)
	// Step 2: extract image and alt/title from within a block
	reBlockImg   = regexp.MustCompile(
		`<img\s+src="(https://rawkuma\.net/wp-content/uploads/[^"]+\.(?:jpg|jpeg|png|webp))"[^>]*alt="([^"]+)"`)
	reChapter    = regexp.MustCompile(`Chapter[:\s]*([\d.]+)`)
	reOgTitle    = regexp.MustCompile(`og:title"[^>]+content="([^"]+)"`)
	reOgImage    = regexp.MustCompile(`og:image"[^>]+content="([^"]+)"`)
	reStatus     = regexp.MustCompile(`(?:Status|ステータス)[^<]*</[^>]+>\s*<[^>]+>([^<]+)<`)
	reType       = regexp.MustCompile(`(?:Type|タイプ)[^<]*</[^>]+>\s*<[^>]+>([^<]+)<`)
	reParagraph  = regexp.MustCompile(`<p[^>]*>([\s\S]{50,800}?)</p>`)
	reChapterURL = regexp.MustCompile(`href="(https://rawkuma\.net/manga/[^/]+/chapter-([^/"]+)[^"]*)"`)
	rePageImg    = regexp.MustCompile(`src="(https://[^"]+\.(?:jpg|jpeg|png|webp)[^"]*)"`)
	reNextChap   = regexp.MustCompile(`href="(https://rawkuma\.net/manga/[^"]+/chapter-[^"]+)"[^>]*>[^<]*[Nn]ext`)
)

// ── Parsing ────────────────────────────────────────────────────────────────
func parseListingPage(html string) []MangaItem {
	results := []MangaItem{}
	seen := map[string]bool{}

	// Step 1: find each <a href=".../manga/SLUG/"> block
	blocks := reAnchorBlock.FindAllStringSubmatch(html, -1)
	for _, block := range blocks {
		slug  := block[1]
		inner := block[2]

		if seen[slug] || slug == "" {
			continue
		}
		skip := false
		for _, x := range []string{"feed", "chapter", "auth", "library", "bookmark", "history", "premium", "leaderboard"} {
			if strings.Contains(slug, x) {
				skip = true
				break
			}
		}
		if skip {
			continue
		}

		// Step 2: find image and title within this block
		imgMatch := reBlockImg.FindStringSubmatch(inner)
		if imgMatch == nil {
			continue
		}
		img   := imgMatch[1]
		title := imgMatch[2]

		tl := strings.ToLower(title)
		for _, x := range []string{"rawkuma", "logo", "manga.svg", "icon"} {
			if strings.Contains(tl, x) {
				skip = true
				break
			}
		}
		if skip || len(title) < 2 {
			continue
		}

		ch := ""
		if m := reChapter.FindStringSubmatch(inner); m != nil {
			ch = m[1]
		}

		seen[slug] = true
		results = append(results, MangaItem{
			ID:      slug,
			Title:   title,
			Image:   proxyURL(img),
			Chapter: ch,
			URL:     BASE + "/manga/" + slug + "/",
		})
		if len(results) >= 30 {
			break
		}
	}
	return results
}

// ── Endpoints ──────────────────────────────────────────────────────────────
func hot() (interface{}, error) {
	return cached("hot", 10*time.Minute, func() (interface{}, error) {
		html, err := fetch(BASE + "/manga/?order=popular")
		if err != nil {
			return nil, err
		}
		return parseListingPage(html), nil
	})
}

func latest(page int) (interface{}, error) {
	key := fmt.Sprintf("latest:%d", page)
	return cached(key, 3*time.Minute, func() (interface{}, error) {
		html, err := fetch(fmt.Sprintf("%s/latest-update/?the_page=%d", BASE, page))
		if err != nil {
			return nil, err
		}
		return parseListingPage(html), nil
	})
}

func search(query string) (interface{}, error) {
	key := "search:" + query
	return cached(key, 15*time.Minute, func() (interface{}, error) {
		html, err := fetch(BASE + "/library/?search_term=" + url.QueryEscape(query))
		if err != nil {
			return nil, err
		}
		return parseListingPage(html), nil
	})
}

func info(slug string) (interface{}, error) {
	return cached("info:"+slug, 30*time.Minute, func() (interface{}, error) {
		v, err, _ := fetchGroup.Do("info:"+slug, func() (interface{}, error) {
			html, err := fetch(BASE + "/manga/" + slug + "/")
			if err != nil {
				return nil, err
			}

			title := slug
			if m := reOgTitle.FindStringSubmatch(html); m != nil {
				title = strings.TrimSuffix(strings.TrimSpace(cleanHTML(m[1])), " - Rawkuma")
			}

			rawImg := ""
			if m := reOgImage.FindStringSubmatch(html); m != nil {
				rawImg = m[1]
			}

			status := ""
			if m := reStatus.FindStringSubmatch(html); m != nil {
				status = strings.TrimSpace(m[1])
			}

			tp := ""
			if m := reType.FindStringSubmatch(html); m != nil {
				tp = strings.TrimSpace(m[1])
			}

			synopsis := ""
			for _, m := range reParagraph.FindAllStringSubmatch(html, -1) {
				c := cleanHTML(m[1])
				if len(c) > 50 && !strings.Contains(c, "function") &&
					!strings.Contains(c, "Login") && !strings.Contains(c, "{") {
					if len(c) > 600 {
						c = c[:600]
					}
					synopsis = c
					break
				}
			}

			chapters := []Chapter{}
			seen := map[string]bool{}
			for _, m := range reChapterURL.FindAllStringSubmatch(html, -1) {
				chURL := m[1]
				chID  := m[2]
				if seen[chID] {
					continue
				}
				seen[chID] = true
				num := regexp.MustCompile(`[^0-9.]`).ReplaceAllString(strings.Split(chID, ".")[0], "")
				chapters = append(chapters, Chapter{
					ID:    chID,
					Title: "Chapter " + num,
					URL:   chURL,
					Date:  "",
				})
			}
			for i, j := 0, len(chapters)-1; i < j; i, j = i+1, j-1 {
				chapters[i], chapters[j] = chapters[j], chapters[i]
			}

			return SeriesInfo{
				ID:       slug,
				Title:    title,
				Image:    proxyURL(rawImg),
				RawImage: rawImg,
				Status:   status,
				Type:     tp,
				Synopsis: synopsis,
				Chapters: chapters,
			}, nil
		})
		return v, err
	})
}

func pages(chapterURL string) (interface{}, error) {
	return cached("pages:"+chapterURL, time.Hour, func() (interface{}, error) {
		v, err, _ := fetchGroup.Do("pages:"+chapterURL, func() (interface{}, error) {
			html, err := fetch(chapterURL)
			if err != nil {
				return nil, err
			}

			seen := map[string]bool{}
			var imgs []string
			for _, m := range rePageImg.FindAllStringSubmatch(html, -1) {
				u := m[1]
				if seen[u] {
					continue
				}
				if strings.Contains(u, "wp-content/uploads") && !strings.Contains(u, "chapter") {
					continue
				}
				seen[u] = true
				imgs = append(imgs, u)
			}

			nextURL := ""
			if m := reNextChap.FindStringSubmatch(html); m != nil {
				nextURL = m[1]
			}

			pageItems := make([]PageItem, len(imgs))
			for i, img := range imgs {
				pageItems[i] = PageItem{Page: i + 1, Img: proxyURL(img)}
			}

			return PagesResult{Pages: pageItems, NextURL: nextURL, Total: len(imgs)}, nil
		})
		return v, err
	})
}

// ── Favorites ──────────────────────────────────────────────────────────────
var favMu sync.Mutex

func loadFavs() ([]Favorite, error) {
	data, err := os.ReadFile(favFile())
	if os.IsNotExist(err) {
		return []Favorite{}, nil
	}
	if err != nil {
		return nil, err
	}
	var favs []Favorite
	json.Unmarshal(data, &favs)
	return favs, nil
}

func saveFavs(favs []Favorite) error {
	os.MkdirAll(filepath.Dir(favFile()), 0755)
	data, _ := json.MarshalIndent(favs, "", "  ")
	return os.WriteFile(favFile(), data, 0644)
}

func addFav(id, title, image, u string) error {
	favMu.Lock()
	defer favMu.Unlock()
	favs, err := loadFavs()
	if err != nil {
		return err
	}
	for _, f := range favs {
		if f.ID == id {
			return nil
		}
	}
	favs = append(favs, Favorite{ID: id, Title: title, Image: image, URL: u})
	return saveFavs(favs)
}

func removeFav(id string) error {
	favMu.Lock()
	defer favMu.Unlock()
	favs, err := loadFavs()
	if err != nil {
		return err
	}
	filtered := favs[:0]
	for _, f := range favs {
		if f.ID != id {
			filtered = append(filtered, f)
		}
	}
	return saveFavs(filtered)
}

func getFavs() ([]Favorite, error) {
	favMu.Lock()
	defer favMu.Unlock()
	return loadFavs()
}

// ── HTTP Handlers ──────────────────────────────────────────────────────────
func withCORS(w http.ResponseWriter) {
	w.Header().Set("Access-Control-Allow-Origin", "*")
	w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
	w.Header().Set("Access-Control-Allow-Headers", "Content-Type")
}

func writeJSON(w http.ResponseWriter, data interface{}) {
	withCORS(w)
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	json.NewEncoder(w).Encode(data)
}

func writeError(w http.ResponseWriter, msg string, code int) {
	withCORS(w)
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(map[string]string{"error": msg})
}

func handler(w http.ResponseWriter, r *http.Request) {
	if r.Method == "OPTIONS" {
		withCORS(w)
		w.WriteHeader(204)
		return
	}

	path := r.URL.Path
	q    := r.URL.Query()

	switch path {
	case "/hot":
		data, err := hot()
		if err != nil { writeError(w, err.Error(), 500); return }
		writeJSON(w, data)

	case "/latest":
		page := 1
		fmt.Sscanf(q.Get("page"), "%d", &page)
		if page < 1 { page = 1 }
		data, err := latest(page)
		if err != nil { writeError(w, err.Error(), 500); return }
		writeJSON(w, data)

	case "/search":
		sq := q.Get("q")
		if sq == "" { writeError(w, "missing q", 400); return }
		data, err := search(sq)
		if err != nil { writeError(w, err.Error(), 500); return }
		writeJSON(w, data)

	case "/info":
		slug := q.Get("id")
		if slug == "" { writeError(w, "missing id", 400); return }
		data, err := info(slug)
		if err != nil { writeError(w, err.Error(), 500); return }
		writeJSON(w, data)

	case "/pages":
		cu, _ := url.QueryUnescape(q.Get("url"))
		if cu == "" { writeError(w, "missing url", 400); return }
		data, err := pages(cu)
		if err != nil { writeError(w, err.Error(), 500); return }
		writeJSON(w, data)

	case "/image":
		imgURL, _ := url.QueryUnescape(q.Get("url"))
		if imgURL == "" { writeError(w, "missing url", 400); return }
		body, ct, err := getImage(imgURL)
		if err != nil { writeError(w, err.Error(), 500); return }
		withCORS(w)
		w.Header().Set("Content-Type", ct)
		w.Header().Set("Cache-Control", "public, max-age=604800") // 1 week
		w.Write(body)

	case "/favorites":
		favs, err := getFavs()
		if err != nil { writeError(w, err.Error(), 500); return }
		writeJSON(w, favs)

	case "/favorites/add":
		var body struct {
			ID    string `json:"id"`
			Title string `json:"title"`
			Image string `json:"image"`
			URL   string `json:"url"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		if body.ID == "" { writeError(w, "missing id", 400); return }
		if err := addFav(body.ID, body.Title, body.Image, body.URL); err != nil {
			writeError(w, err.Error(), 500); return
		}
		writeJSON(w, map[string]bool{"ok": true})

	case "/favorites/remove":
		var body struct{ ID string `json:"id"` }
		json.NewDecoder(r.Body).Decode(&body)
		if body.ID == "" { writeError(w, "missing id", 400); return }
		if err := removeFav(body.ID); err != nil {
			writeError(w, err.Error(), 500); return
		}
		writeJSON(w, map[string]bool{"ok": true})

	case "/progress":
		mangaID := q.Get("id")
		if mangaID == "" { writeError(w, "missing id", 400); return }
		chapters, err := getProgress(mangaID)
		if err != nil { writeError(w, err.Error(), 500); return }
		writeJSON(w, chapters)

	case "/progress/set":
		var body struct {
			MangaID   string `json:"manga_id"`
			ChapterID string `json:"chapter_id"`
		}
		json.NewDecoder(r.Body).Decode(&body)
		if body.MangaID == "" || body.ChapterID == "" {
			writeError(w, "missing manga_id or chapter_id", 400); return
		}
		if err := setProgress(body.MangaID, body.ChapterID); err != nil {
			writeError(w, err.Error(), 500); return
		}
		writeJSON(w, map[string]bool{"ok": true})

	case "/health":
		writeJSON(w, map[string]bool{"ok": true})

	default:
		writeError(w, "not found", 404)
	}
}

// evictOldImages deletes cached image files older than maxAge.
// Runs once at startup so it never impacts request latency.
func evictOldImages(maxAge time.Duration) {
	dir := imgCacheDir()
	entries, err := os.ReadDir(dir)
	if err != nil {
		return
	}
	cutoff := time.Now().Add(-maxAge)
	evicted := 0
	for _, e := range entries {
		if e.IsDir() {
			continue
		}
		info, err := e.Info()
		if err != nil {
			continue
		}
		if info.ModTime().Before(cutoff) {
			os.Remove(filepath.Join(dir, e.Name()))
			evicted++
		}
	}
	if evicted > 0 {
		log.Printf("[manga-server] Evicted %d stale image cache files (older than %v)", evicted, maxAge)
	}
}

func main() {
	os.MkdirAll(filepath.Join(homeDir(), DATADIR), 0755)
	os.MkdirAll(imgCacheDir(), 0755)
	go evictOldImages(30 * 24 * time.Hour) // evict images older than 30 days, async
	addr := fmt.Sprintf("127.0.0.1:%d", PORT)
	log.Printf("[manga-server] Listening on http://%s", addr)
	log.Printf("[manga-server] Image cache: %s", imgCacheDir())
	http.HandleFunc("/", handler)
	log.Fatal(http.ListenAndServe(addr, nil))
}
