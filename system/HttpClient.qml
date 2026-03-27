pragma Singleton
import Quickshell
import QtQuick

// Thin XHR helpers shared by MangaPanel and VideoPanel.
// Usage:
//   HttpClient.get("http://…/path", function(data, err) { … })
//   HttpClient.post("http://…/path", { key: "val" }, function(ok) { … })
Singleton {
    function get(url, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState !== 4) return
            if (xhr.status === 200) {
                try { callback(JSON.parse(xhr.responseText), null) }
                catch(e) { callback(null, "parse error: " + e.toString()) }
            } else {
                callback(null, "HTTP " + xhr.status)
            }
        }
        xhr.open("GET", url)
        xhr.send()
    }

    function post(url, data, callback) {
        var xhr = new XMLHttpRequest()
        xhr.onreadystatechange = function() {
            if (xhr.readyState === 4 && callback)
                callback(xhr.status === 200)
        }
        xhr.open("POST", url)
        xhr.setRequestHeader("Content-Type", "application/json")
        xhr.send(JSON.stringify(data))
    }
}
