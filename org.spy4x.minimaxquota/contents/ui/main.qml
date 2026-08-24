import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "."

PlasmoidItem {
  id: root

  // Persisted state held on the plasmoid so the compact representation can
  // read it without re-fetching.
  property var intervalData: ({ remainingPercent: null, resetMs: null, totalCount: 0, usedCount: 0 })
  property var weeklyData: ({ remainingPercent: null, resetMs: null, totalCount: 0, usedCount: 0 })
  property string lastError: ""
  property string lastUpdate: ""
  property bool loading: false

  Component.onCompleted: Qt.callLater(fetch)

  Timer {
    id: refreshTimer
    interval: Math.max(15, (plasmoid.configuration.refreshIntervalSec || 60)) * 1000
    repeat: true
    running: (plasmoid.configuration.apiKey || "").length > 0
    triggeredOnStart: true
    onTriggered: root.fetch()
  }

  Connections {
    target: plasmoid.configuration
    function onApiKeyChanged() { refreshTimer.restart() }
    function onRefreshIntervalSecChanged() { refreshTimer.interval = Math.max(15, plasmoid.configuration.refreshIntervalSec || 60) * 1000 }
  }

  function cfgEndpoint() {
    return plasmoid.configuration.endpoint || "https://www.minimax.io/v1/token_plan/remains"
  }

  function fetch() {
    const apiKey = plasmoid.configuration.apiKey || ""
    if (apiKey.length === 0) {
      lastError = "API key not set. Configure via widget settings."
      loading = false
      return
    }
    loading = true
    const xhr = new XMLHttpRequest()
    xhr.open("GET", cfgEndpoint())
    xhr.setRequestHeader("Authorization", "Bearer " + apiKey)
    xhr.setRequestHeader("Content-Type", "application/json")
    xhr.timeout = 10000
    xhr.onreadystatechange = function() {
      if (xhr.readyState !== XMLHttpRequest.DONE) return
      loading = false
      if (xhr.status >= 200 && xhr.status < 300) {
        root.parseResponse(xhr.responseText)
      } else {
        lastError = "HTTP " + xhr.status + " (" + xhr.statusText + ")"
      }
    }
    try {
      xhr.send()
    } catch (e) {
      loading = false
      lastError = "Network error: " + e
    }
  }

  function parseResponse(text) {
    let doc
    try {
      doc = JSON.parse(text)
    } catch (e) {
      lastError = "Parse error: " + e
      return
    }
    if (doc.base_resp && doc.base_resp.status_code !== 0) {
      lastError = "API error: " + (doc.base_resp.status_msg || "unknown")
      return
    }
    const models = doc.model_remains || []
    let general = null
    for (let i = 0; i < models.length; i++) {
      if (models[i].model_name === "general") {
        general = models[i]
        break
      }
    }
    if (!general) {
      lastError = "No 'general' model entry in API response"
      return
    }
    intervalData = {
      remainingPercent: general.current_interval_remaining_percent,
      resetMs: general.remains_time,
      totalCount: general.current_interval_total_count,
      usedCount: general.current_interval_usage_count
    }
    weeklyData = {
      remainingPercent: general.current_weekly_remaining_percent,
      resetMs: general.weekly_remains_time,
      totalCount: general.current_weekly_total_count,
      usedCount: general.current_weekly_usage_count
    }
    lastError = ""
    lastUpdate = Qt.formatDateTime(new Date(), "yyyy-MM-dd HH:mm:ss")
    // Expose to plasmoid so the compact rep can read
    plasmoid.intervalData = intervalData
    plasmoid.weeklyData = weeklyData
  }

  function formatDuration(ms) {
    if (ms === null || ms === undefined || isNaN(ms) || ms < 0) return "—"
    const totalSec = Math.floor(ms / 1000)
    const days = Math.floor(totalSec / 86400)
    const hours = Math.floor((totalSec % 86400) / 3600)
    const minutes = Math.floor((totalSec % 3600) / 60)
    if (days > 0) return days + "d " + hours + "h"
    if (hours > 0) return hours + " hr " + minutes + " min"
    return minutes + " min"
  }

  function usedFromRemaining(remainingPercent) {
    if (remainingPercent === null || remainingPercent === undefined || isNaN(remainingPercent)) return 0
    return Math.max(0, Math.min(100, 100 - remainingPercent))
  }

  function barColor(usedPercent) {
    if (usedPercent < 70) return "#5cb85c"
    if (usedPercent < 90) return "#f0ad4e"
    return "#d9534f"
  }

  Rectangle {
    anchors.fill: parent
    color: PlasmaCore.Theme.backgroundColor
    border.color: PlasmaCore.Theme.separatorColor
    border.width: 1
    radius: 8
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 16
    spacing: 12

    RowLayout {
      Layout.fillWidth: true
      spacing: 8

      Label {
        text: "MiniMax Token Plan"
        font.bold: true
        font.pixelSize: 16
        color: PlasmaCore.Theme.textColor
      }
      Item { Layout.fillWidth: true }
      BusyIndicator {
        running: root.loading
        visible: root.loading
        implicitWidth: 16
        implicitHeight: 16
      }
      Label {
        text: root.lastUpdate ? "updated " + root.lastUpdate : "not yet fetched"
        font.pixelSize: 10
        color: PlasmaCore.Theme.subTextColor
      }
      Button {
        text: "Refresh"
        font.pixelSize: 10
        onClicked: root.fetch()
        visible: (plasmoid.configuration.apiKey || "").length > 0
      }
    }

    Rectangle {
      Layout.fillWidth: true
      visible: (plasmoid.configuration.apiKey || "").length === 0
      color: PlasmaCore.Theme.linkColor
      opacity: 0.18
      radius: 6
      implicitHeight: 44
      Label {
        anchors.centerIn: parent
        text: "Right-click widget → Configure MiniMax Quota → paste your API key"
        color: PlasmaCore.Theme.textColor
        font.pixelSize: 12
      }
    }

    Label {
      Layout.fillWidth: true
      text: root.lastError
      visible: root.lastError.length > 0
      color: "#d9534f"
      font.pixelSize: 11
      wrapMode: Text.Wrap
    }

    QuotaBar {
      Layout.fillWidth: true
      label: "5h limit"
      resetText: "Resets in " + root.formatDuration(root.intervalData.resetMs)
      remainingPercent: root.intervalData.remainingPercent
      formatFn: root.formatDuration
      usedFn: root.usedFromRemaining
      colorFn: root.barColor
    }

    QuotaBar {
      Layout.fillWidth: true
      label: "Weekly limit"
      resetText: "Resets in " + root.formatDuration(root.weeklyData.resetMs)
      remainingPercent: root.weeklyData.remainingPercent
      formatFn: root.formatDuration
      usedFn: root.usedFromRemaining
      colorFn: root.barColor
    }

    Item { Layout.fillHeight: true }

    Label {
      Layout.fillWidth: true
      horizontalAlignment: Text.AlignHCenter
      font.pixelSize: 9
      color: PlasmaCore.Theme.subTextColor
      text: "Polling every " + Math.max(15, (plasmoid.configuration.refreshIntervalSec || 60)) + "s — click Refresh for instant update"
    }
  }
}