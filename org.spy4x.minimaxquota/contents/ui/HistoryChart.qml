import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Bar chart for a single quota window. Shows usage % over time with
// downsampled bars (maxBars cap) preserving min/max envelope per bucket.
//
// Inputs:
//   points    — array of { ts: int (ms), p: int (0..100, REMAINING) }
//   title     — header text (e.g. "5-HOUR WINDOW — LAST 7 DAYS")
//   maxBars   — display cap (default 200)
//
// Bars are drawn from the bottom up; bar height = (100 - p) * chartHeight / 100.
// Color matches the rest of the widget: cyan < 70 used, orange < 90, red >= 90.
Item {
  id: chart

  property var points: []
  property string title: ""
  property int maxBars: 200
  property real plotHeight: 130

  // ---------- derived ----------
  readonly property var dsPoints: downsample()
  readonly property bool hasData: dsPoints.length > 0
  readonly property int currentP: hasData ? dsPoints[dsPoints.length - 1].p : -1
  readonly property real currentUsed: currentP >= 0
    ? Math.max(0, Math.min(100, 100 - currentP))
    : -1
  readonly property real avgUsed: {
    if (!hasData) return -1
    let sum = 0
    for (let i = 0; i < dsPoints.length; i++) sum += (100 - dsPoints[i].p)
    return sum / dsPoints.length
  }
  readonly property real maxUsed: {
    if (!hasData) return -1
    let maxV = -Infinity
    for (let i = 0; i < dsPoints.length; i++) {
      const used = 100 - dsPoints[i].p
      if (used > maxV) maxV = used
    }
    return maxV
  }
  readonly property real minUsed: {
    if (!hasData) return -1
    let minV = Infinity
    for (let i = 0; i < dsPoints.length; i++) {
      const used = 100 - dsPoints[i].p
      if (used < minV) minV = used
    }
    return minV
  }
  readonly property int firstTs: hasData ? dsPoints[0].ts : 0
  readonly property int lastTs: hasData ? dsPoints[dsPoints.length - 1].ts : 0
  readonly property int spanMs: lastTs - firstTs

  // ---------- helpers ----------
  function downsample() {
    if (points.length === 0) return []
    if (points.length <= maxBars) return points
    const bucket = points.length / maxBars
    const out = []
    for (let i = 0; i < maxBars; i++) {
      const start = Math.floor(i * bucket)
      const end = Math.min(points.length, Math.floor((i + 1) * bucket))
      if (start >= end) continue
      let minV = 100, maxV = 0, sumP = 0, sumTs = 0, n = 0
      for (let j = start; j < end; j++) {
        if (points[j].p < minV) minV = points[j].p
        if (points[j].p > maxV) maxV = points[j].p
        sumP += points[j].p
        sumTs += points[j].ts
        n++
      }
      out.push({
        ts: n > 0 ? Math.floor(sumTs / n) : 0,
        p: n > 0 ? Math.floor(sumP / n) : 0,
        minP: minV,
        maxP: maxV
      })
    }
    return out
  }

  function barColor(used) {
    if (used < 70) return "#3df0e0"
    if (used < 90) return "#ffa726"
    return "#ff5252"
  }

  function fmtDate(ts) {
    if (!ts) return ""
    const d = new Date(ts)
    // Show MM-dd for compactness; for > 30d spans, show MM-dd too (year omitted).
    return Qt.formatDateTime(d, "MM-dd")
  }

  function fmtDateLong(ts) {
    if (!ts) return ""
    return Qt.formatDateTime(new Date(ts), spanMs > 86400000 * 2 ? "MM-dd" : "HH:mm")
  }

  // ---------- layout ----------
  implicitHeight: 230

  Rectangle {
    anchors.fill: parent
    color: "#161d2f"
    border.color: "#252b3d"
    border.width: 1
    radius: 12
  }

  ColumnLayout {
    anchors.fill: parent
    anchors.margins: 14
    spacing: 10

    // Title + summary stats row
    RowLayout {
      Layout.fillWidth: true
      spacing: 14

      Label {
        text: chart.title
        color: "#e8edf5"
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 2
      }
      Item { Layout.fillWidth: true }
      // "now" — colored by current usage
      ColumnLayout {
        spacing: 0
        Label {
          text: "now"
          color: "#8a93a8"
          font.pixelSize: 9
          font.letterSpacing: 1
        }
        Label {
          visible: chart.hasData
          text: chart.currentP >= 0 ? chart.currentP + "%" : "—"
          color: chart.barColor(chart.currentUsed)
          font.pixelSize: 14
          font.bold: true
          font.family: "monospace"
        }
        Label {
          visible: !chart.hasData
          text: "—"
          color: "#8a93a8"
          font.pixelSize: 14
          font.family: "monospace"
        }
      }
      // "avg" — average usage over the window
      ColumnLayout {
        spacing: 0
        Label {
          text: "avg"
          color: "#8a93a8"
          font.pixelSize: 9
          font.letterSpacing: 1
        }
        Label {
          visible: chart.hasData
          text: Math.round(chart.avgUsed) + "%"
          color: "#e8edf5"
          font.pixelSize: 14
          font.bold: true
          font.family: "monospace"
        }
        Label {
          visible: !chart.hasData
          text: "—"
          color: "#8a93a8"
          font.pixelSize: 14
          font.family: "monospace"
        }
      }
      // "peak" — maximum usage reached
      ColumnLayout {
        spacing: 0
        Label {
          text: "peak"
          color: "#8a93a8"
          font.pixelSize: 9
          font.letterSpacing: 1
        }
        Label {
          visible: chart.hasData
          text: Math.round(chart.maxUsed) + "%"
          color: chart.barColor(chart.maxUsed)
          font.pixelSize: 14
          font.bold: true
          font.family: "monospace"
        }
        Label {
          visible: !chart.hasData
          text: "—"
          color: "#8a93a8"
          font.pixelSize: 14
          font.family: "monospace"
        }
      }
    }

    // Plot area or empty-state message
    Item {
      Layout.fillWidth: true
      Layout.preferredHeight: chart.plotHeight

      // Empty-state message (centered)
      Label {
        anchors.centerIn: parent
        visible: !chart.hasData
        text: chart.points.length === 0
          ? "Collecting data — check back after a few hours"
          : "Loading..."
        color: "#8a93a8"
        font.pixelSize: 12
      }

      // Plot — only visible when we have data
      Item {
        anchors.fill: parent
        visible: chart.hasData

        // Horizontal gridlines (5 levels: 0, 25, 50, 75, 100)
        Repeater {
          model: 5
          delegate: Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: 36  // space for Y-axis labels
            y: index * (parent.height / 4)
            height: 1
            color: "#252b3d"
            opacity: 0.55
          }
        }

        // Y-axis labels (0, 25, 50, 75, 100)
        Repeater {
          model: [ 100, 75, 50, 25, 0 ]
          delegate: Label {
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            anchors.verticalCenterOffset: -((100 - modelData) / 100 * (parent.height - 16) - (parent.height - 16) / 2)
            width: 30
            text: modelData
            color: "#8a93a8"
            opacity: 0.65
            font.pixelSize: 9
            horizontalAlignment: Text.AlignRight
          }
        }

        // Bars
        Repeater {
          model: chart.dsPoints
          delegate: Rectangle {
            readonly property real used: 100 - modelData.p
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            x: index * ((parent.width - 36) / chart.dsPoints.length)
            width: Math.max(1, ((parent.width - 36) / chart.dsPoints.length) - 1)
            height: (parent.height - 16) * Math.max(0, Math.min(100, used)) / 100
            color: chart.barColor(used)
            opacity: 0.85
            radius: 1.5
          }
        }

        // X-axis labels: first / middle / last
        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.rightMargin: 36
          anchors.bottom: parent.bottom
          height: 14
          Label {
            width: parent.width / 3
            text: chart.fmtDate(chart.firstTs)
            color: "#8a93a8"
            opacity: 0.7
            font.pixelSize: 9
          }
          Label {
            width: parent.width / 3
            text: chart.fmtDate(Math.floor((chart.firstTs + chart.lastTs) / 2))
            color: "#8a93a8"
            opacity: 0.7
            font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
          }
          Label {
            width: parent.width / 3
            text: chart.fmtDate(chart.lastTs)
            color: "#8a93a8"
            opacity: 0.7
            font.pixelSize: 9
            horizontalAlignment: Text.AlignRight
          }
        }
      }
    }

    // Footer line: sample count and bar count
    Label {
      Layout.fillWidth: true
      visible: chart.hasData
      text: chart.points.length + " samples · " + chart.dsPoints.length + " bars"
      color: "#8a93a8"
      font.pixelSize: 10
      horizontalAlignment: Text.AlignHCenter
    }
  }
}