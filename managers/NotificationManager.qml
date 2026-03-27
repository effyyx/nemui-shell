pragma Singleton
import Quickshell
import Quickshell.Services.Notifications
import QtQuick

Singleton {
    id: root

    property int  maxHistory:    50
    property int  popupDuration: 3000
    property int  unreadCount:   0
    property list<NotifObject> list: []
    property var  popupList: list.filter(function(n) { return n.popup })

    // ── public API ────────────────────────────────────────────────────────
    function clearUnread()  { unreadCount = 0 }

    function clearHistory() {
        var kept = []
        for (var i = 0; i < list.length; i++)
            if (list[i].popup) kept.push(list[i])
        list = kept
    }

    function dismiss(id) {
        for (var i = 0; i < list.length; i++) {
            if (list[i].notificationId === id) {
                list[i].popup = false
                break
            }
        }
        _triggerChange()
    }

    // ── internals ─────────────────────────────────────────────────────────
    property var _timers: ({})

    function _triggerChange() { list = list.slice(0) }

    function _scheduleOrRestartDismiss(id) {
        if (root._timers[id]) {
            root._timers[id].stop()
            root._timers[id].destroy()
        }
        var t = Qt.createQmlObject(
            'import QtQuick; Timer { interval: ' + root.popupDuration + '; repeat: false; running: true }',
            root
        )
        var capturedId = id
        t.triggered.connect(function() {
            root.dismiss(capturedId)
            delete root._timers[capturedId]
            t.destroy()
        })
        root._timers[id] = t
    }

    // ── notification object ───────────────────────────────────────────────
    component NotifObject: QtObject {
        required property int notificationId
        property Notification notification: null
        property bool   popup:   false
        property double time:    0
        property string appName: ""
        property string summary: ""
        property string body:    ""
        property string image:   ""

        // Watch live for mpDris2 which reuses the same notification ID
        property string _liveImage:   notification ? notification.image   : ""
        property string _liveSummary: notification ? notification.summary : ""

        on_LiveImageChanged: {
            if (_liveImage === "") return
            image = _liveImage
            if (!popup) { popup = true; root._triggerChange(); root.unreadCount++ }
            root._scheduleOrRestartDismiss(notificationId)
        }

        on_LiveSummaryChanged: {
            if (_liveSummary === "" || _liveSummary === summary) return
            summary = _liveSummary
            if (notification) body = notification.body || ""
            if (!popup) { popup = true; root._triggerChange(); root.unreadCount++ }
            root._scheduleOrRestartDismiss(notificationId)
        }
    }

    Component { id: notifComponent; NotifObject {} }

    NotificationServer {
        id: server
        keepOnReload:       false
        actionsSupported:   true
        bodySupported:      true
        bodyImagesSupported: true
        imageSupported:     true

        onNotification: function(notif) {
            notif.tracked = true

            // Find existing by ID
            var existing = null
            for (var i = 0; i < root.list.length; i++) {
                if (root.list[i].notificationId === notif.id) { existing = root.list[i]; break }
            }

            if (existing) {
                existing.time     = Date.now()
                existing.appName  = notif.appName  || existing.appName
                existing.summary  = notif.summary  || existing.summary
                existing.body     = notif.body     || existing.body
                existing.image    = notif.image    || existing.image
                existing.notification = notif
                existing.popup    = true
                root._triggerChange()
                root.unreadCount++
                root._scheduleOrRestartDismiss(notif.id)
            } else {
                var obj = notifComponent.createObject(root, {
                    notificationId: notif.id,
                    notification:   notif,
                    appName:  notif.appName  || "",
                    summary:  notif.summary  || "",
                    body:     notif.body     || "",
                    image:    notif.image    || "",
                    popup:    true,
                    time:     Date.now()
                })
                root.list = [obj, ...root.list]
                if (root.list.length > root.maxHistory)
                    root.list = root.list.slice(0, root.maxHistory)
                root.unreadCount++
                root._scheduleOrRestartDismiss(notif.id)
            }
        }
    }
}
