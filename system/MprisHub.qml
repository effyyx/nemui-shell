pragma Singleton
import Quickshell
import Quickshell.Services.Mpris
import QtQuick

// Single point of truth for the active MPRIS player.
// Prefers mpdris2 / MPD; falls back to the first available player.
Singleton {
    id: root

    function isUsable(p) {
        return p && p.canControl && p.playbackState !== MprisPlaybackState.Stopped
    }

    property MprisPlayer player: {
        var players = Mpris.players.values
        for (var i = 0; i < players.length; i++) {
            var p = players[i]
            if ((p.desktopEntry === "mpdris2" || p.identity === "Music Player Daemon") && p.canControl)
                return p
        }
        for (var j = 0; j < players.length; j++) {
            if (root.isUsable(players[j])) return players[j]
        }
        return null
    }

    readonly property string title:     player ? player.trackTitle  ?? "" : ""
    readonly property string artist:    player ? player.trackArtist ?? "" : ""
    readonly property bool   isPlaying: player !== null && player.isPlaying
    readonly property bool   hasTrack:  player !== null && player.playbackState !== MprisPlaybackState.Stopped
}
