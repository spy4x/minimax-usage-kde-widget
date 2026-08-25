import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtCore
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import "."

PlasmoidItem {
  id: root

  // Default size on first add. metadata.json X-Plasma-DefaultSize is read
  // by Plasma 6 but PlasmoidItem also needs these implicit dimensions
  // so the widget renders correctly when previewed in the Add Widgets
  // dialog (which uses QML rendering at constrained size).
  implicitWidth: 960
  implicitHeight: 630

  // ---------- state ----------
  property var intervalData: ({ remainingPercent: null, resetMs: null, totalCount: 0, usedCount: 0 })
  property var weeklyData: ({ remainingPercent: null, resetMs: null, totalCount: 0, usedCount: 0 })
  property string lastError: ""
  property bool loading: false
  // Wall-clock time (ms) when the last successful fetch landed.
  property real fetchedAt: 0
  // Tick counter — bound by a 1-second timer so any UI reading liveResetMs
  // re-evaluates and the countdowns decrement without a network call.
  property int tickCount: 0
  // Header clock string, refreshed every second.
  property string clockText: Qt.formatDateTime(new Date(), "HH:mm:ss")
  // View mode: 0 = current quota (rings), 1 = stats (history charts).
  property int viewMode: 0

  HistoryStore { id: historyStore }

  // ---------- helpers ----------
  function cfgEndpoint() {
    return plasmoid.configuration.endpoint || "https://www.minimax.io/v1/token_plan/remains"
  }

  // Adjusted reset ms: subtract elapsed time since the fetch.
  readonly property real _now: Date.now() + tickCount * 0  // touch tickCount for re-bind

  function liveResetMs(originalMs) {
    if (originalMs === null || originalMs === undefined) return null
    if (fetchedAt === 0) return originalMs
    return Math.max(0, originalMs - (Date.now() - fetchedAt))
  }

  function usedFromRemaining(remainingPercent) {
    if (remainingPercent === null || remainingPercent === undefined || isNaN(remainingPercent)) return 0
    return Math.max(0, Math.min(100, 100 - remainingPercent))
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
    fetchedAt = Date.now()
    // Expose to plasmoid so the compact rep can read.
    plasmoid.intervalData = intervalData
    plasmoid.weeklyData = weeklyData
    // Append to history unless explicitly disabled.
    if (plasmoid.configuration.historyEnabled !== false) {
      historyStore.append(intervalData.remainingPercent, weeklyData.remainingPercent)
    }
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

  // ---------- timers ----------
  Timer {
    id: refreshTimer
    interval: Math.max(60, (plasmoid.configuration.refreshIntervalSec || 300)) * 1000
    repeat: true
    running: (plasmoid.configuration.apiKey || "").length > 0
    triggeredOnStart: true
    onTriggered: root.fetch()
  }
  Timer {
    id: tickTimer
    interval: 1000
    repeat: true
    running: true
    triggeredOnStart: true
    onTriggered: {
      root.tickCount++
      root.clockText = Qt.formatDateTime(new Date(), "HH:mm:ss")
    }
  }
  // History flush: writes pending samples to disk every 30s and at unload.
  Timer {
    id: flushTimer
    interval: 30000
    repeat: true
    running: true
    triggeredOnStart: false
    onTriggered: historyStore.flush(
      plasmoid.configuration.intervalRetentionDays || 7,
      plasmoid.configuration.weeklyRetentionDays || 90
    )
  }

  Connections {
    target: plasmoid.configuration
    function onApiKeyChanged() { refreshTimer.restart() }
    function onRefreshIntervalSecChanged() { refreshTimer.interval = Math.max(60, plasmoid.configuration.refreshIntervalSec || 300) * 1000 }
    function onIntervalRetentionDaysChanged() { historyStore.flush(
      plasmoid.configuration.intervalRetentionDays || 7,
      plasmoid.configuration.weeklyRetentionDays || 90
    ) }
    function onWeeklyRetentionDaysChanged() { historyStore.flush(
      plasmoid.configuration.intervalRetentionDays || 7,
      plasmoid.configuration.weeklyRetentionDays || 90
    ) }
    function onHistoryClearRequestedChanged() {
      if (plasmoid.configuration.historyClearRequested === true) {
        historyStore.clearAll(
          plasmoid.configuration.intervalRetentionDays || 7,
          plasmoid.configuration.weeklyRetentionDays || 90
        )
        plasmoid.configuration.historyClearRequested = false
      }
    }
  }

  Component.onCompleted: {
    historyStore.load()
    Qt.callLater(fetch)
  }
  Component.onDestruction: historyStore.flush(
    plasmoid.configuration.intervalRetentionDays || 7,
    plasmoid.configuration.weeklyRetentionDays || 90
  )

  // ---------- UI ----------
  Rectangle {
    anchors.fill: parent
    color: "#0e1424"
    radius: 12
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 18
    spacing: 14

    // Header
    RowLayout {
      Layout.fillWidth: true
      spacing: 10

      Rectangle {
        width: 8
        height: 8
        radius: 4
        color: "#5cb85c"
      }
      Label {
        text: "TOKEN PLAN"
        color: "#e8edf5"
        font.pixelSize: 13
        font.bold: true
        font.letterSpacing: 2
      }
      Item { Layout.fillWidth: true }
      // Quota / Stats tab toggle
      Rectangle {
        Layout.preferredWidth: 130
        Layout.preferredHeight: 28
        radius: 6
        color: "#0a0f1c"
        border.color: "#252b3d"
        border.width: 1

        Row {
          anchors.fill: parent
          anchors.margins: 2
          spacing: 0

          Rectangle {
            width: parent.width / 2
            height: parent.height
            radius: 4
            color: root.viewMode === 0 ? "#252b3d" : "transparent"
            Label {
              anchors.centerIn: parent
              text: "Quota"
              color: root.viewMode === 0 ? "#e8edf5" : "#8a93a8"
              font.pixelSize: 11
              font.bold: root.viewMode === 0
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.viewMode = 0
            }
          }
          Rectangle {
            width: parent.width / 2
            height: parent.height
            radius: 4
            color: root.viewMode === 1 ? "#252b3d" : "transparent"
            Label {
              anchors.centerIn: parent
              text: "Stats"
              color: root.viewMode === 1 ? "#e8edf5" : "#8a93a8"
              font.pixelSize: 11
              font.bold: root.viewMode === 1
            }
            MouseArea {
              anchors.fill: parent
              cursorShape: Qt.PointingHandCursor
              onClicked: root.viewMode = 1
            }
          }
        }
      }
      Label {
        text: root.clockText
        color: "#8a93a8"
        font.pixelSize: 13
        font.family: "monospace"
      }
      Button {
        text: "↻ Refresh"
        font.pixelSize: 11
        padding: 6
        onClicked: root.fetch()
        visible: (plasmoid.configuration.apiKey || "").length > 0
      }
    }

    // Empty-state hint
    Rectangle {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: (plasmoid.configuration.apiKey || "").length === 0
      color: "#161d2f"
      border.color: "#252b3d"
      border.width: 1
      radius: 12
      Label {
        anchors.centerIn: parent
        text: "Right-click widget → Configure MiniMax Quota → paste your API key"
        color: "#e8edf5"
        font.pixelSize: 13
      }
    }

    // Error banner
    Rectangle {
      Layout.fillWidth: true
      visible: root.lastError.length > 0 && (plasmoid.configuration.apiKey || "").length > 0
      color: "#161d2f"
      border.color: "#ff5252"
      border.width: 1
      radius: 8
      implicitHeight: errLabel.implicitHeight + 16
      Label {
        id: errLabel
        anchors.fill: parent
        anchors.margins: 8
        text: root.lastError
        color: "#ff8a80"
        font.pixelSize: 11
        wrapMode: Text.Wrap
        verticalAlignment: Text.AlignVCenter
      }
    }

    // Two cards: orientation picked from config (horizontal default,
    // vertical for narrow panels). Loader swaps between two Components
    // since QML Layouts can't switch row<->column direction at runtime.
    Loader {
      Layout.fillWidth: true
      Layout.fillHeight: true
      visible: (plasmoid.configuration.apiKey || "").length > 0
      sourceComponent: root.viewMode === 1
        ? statsContent
        : ((plasmoid.configuration.orientation || "horizontal") === "vertical"
            ? verticalCards : horizontalCards)
    }
    Component {
      id: horizontalCards
      RowLayout {
        spacing: 14
        QuotaCard {
          id: intervalCard
          Layout.fillWidth: true
          Layout.fillHeight: true
          label: "5-HOUR WINDOW"
          remainingPercent: root.intervalData.remainingPercent
          resetMs: root.liveResetMs(root.intervalData.resetMs)
          windowTotalMs: 5 * 60 * 60 * 1000
          formatFn: root.formatDuration
        }
        QuotaCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          label: "WEEKLY"
          remainingPercent: root.weeklyData.remainingPercent
          resetMs: root.liveResetMs(root.weeklyData.resetMs)
          windowTotalMs: 7 * 24 * 60 * 60 * 1000
          formatFn: root.formatDuration
        }
      }
    }
    Component {
      id: verticalCards
      ColumnLayout {
        spacing: 14
        QuotaCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          label: "5-HOUR WINDOW"
          remainingPercent: root.intervalData.remainingPercent
          resetMs: root.liveResetMs(root.intervalData.resetMs)
          windowTotalMs: 5 * 60 * 60 * 1000
          formatFn: root.formatDuration
        }
        QuotaCard {
          Layout.fillWidth: true
          Layout.fillHeight: true
          label: "WEEKLY"
          remainingPercent: root.weeklyData.remainingPercent
          resetMs: root.liveResetMs(root.weeklyData.resetMs)
          windowTotalMs: 7 * 24 * 60 * 60 * 1000
          formatFn: root.formatDuration
        }
      }
    }
    Component {
      id: statsContent
      StatsView {
        intervalPoints: historyStore.interval
        weeklyPoints: historyStore.weekly
      }
    }

    // Footer
    RowLayout {
      Layout.fillWidth: true
      spacing: 8
      Label {
        text: "Polling " + Math.max(60, (plasmoid.configuration.refreshIntervalSec || 300))
              + "s · live ticking"
        color: "#8a93a8"
        font.pixelSize: 11
      }
      Item { Layout.fillWidth: true }
      Rectangle {
        width: 8
        height: 8
        radius: 4
        color: root.loading ? "#ffa726" : "#5cb85c"
      }
      Label {
        text: root.loading ? "Loading" : "Live"
        color: "#8a93a8"
        font.pixelSize: 11
      }
    }
  }
}
