import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Bar chart for a single quota window. Shows usage % over time with
// downsampled bars (maxBars cap) preserving min/max envelope per bucket.
//
// Inputs:
//   points    — array of { ts: int (ms), p: int (0..100, REMAINING) }
//   title     — header text
//   maxBars   — display cap (default 200)
//
// Bars are positioned BY TIMESTAMP, not by index, so sparse data shows
// gaps where the time gaps are. Bar width is capped at 8px so dense
// data still leaves a 1px gap between bars. A hover tooltip surfaces
// the timestamp + value of the nearest bar.
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
      const u = 100 - dsPoints[i].p
      if (u > maxV) maxV = u
    }
    return maxV
  }
  readonly property int firstTs: hasData ? dsPoints[0].ts : 0
  readonly property int lastTs: hasData ? dsPoints[dsPoints.length - 1].ts : 0
  readonly property int spanMs: lastTs - firstTs
  // Index of the bar currently hovered (-1 = none). Set by the plot's
  // MouseArea; consumed by the tooltip + bar highlight.
  property int hoveredIndex: -1
  readonly property var hoveredPoint:
    hoveredIndex >= 0 && hoveredIndex < dsPoints.length
      ? dsPoints[hoveredIndex]
      : null

  // ---------- layout constants ----------
  readonly property int axisMargin: 44   // right margin for Y-axis labels
  readonly property real plotInnerWidth: Math.max(0, plot.width - axisMargin)
  // Bar width: max(2, min(8, slot - 1)) — sparse data → narrow bars with
  // gaps, dense data → bars fill the slot with a 1px gutter.
  readonly property real barWidth: {
    if (!hasData || dsPoints.length === 0 || plotInnerWidth <= 0) return 0
    const slot = plotInnerWidth / dsPoints.length
    return Math.max(2, Math.min(8, slot - 1))
  }

  // X position of a bar centered on its timestamp. Edge bars clamp to the
  // chart bounds so they're always visible.
  function barX(ts) {
    if (!hasData) return 0
    if (dsPoints.length === 1) return Math.max(0, (plotInnerWidth - barWidth) / 2)
    if (spanMs <= 0) return 0
    const ratio = (ts - firstTs) / spanMs
    const center = ratio * plotInnerWidth
    return Math.max(0, Math.min(plotInnerWidth - barWidth, center - barWidth / 2))
  }

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

  // X-axis label formatter: short spans (≤48h) show time, long spans show date.
  function fmtAxisDate(ts) {
    if (!ts) return ""
    const d = new Date(ts)
    if (spanMs <= 172800000) return Qt.formatDateTime(d, "MMM dd, HH:mm")
    return Qt.formatDateTime(d, "MMM dd")
  }

  // Tooltip formatter — slightly longer so users can disambiguate samples.
  function fmtTipDate(ts) {
    if (!ts) return ""
    const d = new Date(ts)
    if (spanMs <= 172800000) return Qt.formatDateTime(d, "MMM dd HH:mm")
    return Qt.formatDateTime(d, "MMM dd yyyy")
  }

  // ---------- visual root ----------
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

    // Title + now/avg/peak stats row
    RowLayout {
      Layout.fillWidth: true
      spacing: 16

      Label {
        text: chart.title
        color: "#e8edf5"
        font.pixelSize: 11
        font.bold: true
        font.letterSpacing: 2
      }

      Item { Layout.fillWidth: true }

      // "now"
      ColumnLayout {
        spacing: 0
        Label { text: "now"; color: "#8a93a8"; font.pixelSize: 9; font.letterSpacing: 1; horizontalAlignment: Text.AlignRight }
        Label {
          visible: chart.hasData
          text: chart.currentP >= 0 ? Math.round(chart.currentUsed) + "%" : "—"
          color: chart.barColor(chart.currentUsed)
          font.pixelSize: 14; font.bold: true; font.family: "monospace"
          horizontalAlignment: Text.AlignRight
        }
        Label {
          visible: !chart.hasData
          text: "—"; color: "#8a93a8"; font.pixelSize: 14; font.family: "monospace"
          horizontalAlignment: Text.AlignRight
        }
      }
      // "avg" — always white
      ColumnLayout {
        spacing: 0
        Label { text: "avg"; color: "#8a93a8"; font.pixelSize: 9; font.letterSpacing: 1; horizontalAlignment: Text.AlignRight }
        Label {
          visible: chart.hasData
          text: Math.round(chart.avgUsed) + "%"
          color: "#e8edf5"
          font.pixelSize: 14; font.bold: true; font.family: "monospace"
          horizontalAlignment: Text.AlignRight
        }
        Label {
          visible: !chart.hasData
          text: "—"; color: "#8a93a8"; font.pixelSize: 14; font.family: "monospace"
          horizontalAlignment: Text.AlignRight
        }
      }
      // "peak" — colored by peak level
      ColumnLayout {
        spacing: 0
        Label { text: "peak"; color: "#8a93a8"; font.pixelSize: 9; font.letterSpacing: 1; horizontalAlignment: Text.AlignRight }
        Label {
          visible: chart.hasData
          text: Math.round(chart.maxUsed) + "%"
          color: chart.barColor(chart.maxUsed)
          font.pixelSize: 14; font.bold: true; font.family: "monospace"
          horizontalAlignment: Text.AlignRight
        }
        Label {
          visible: !chart.hasData
          text: "—"; color: "#8a93a8"; font.pixelSize: 14; font.family: "monospace"
          horizontalAlignment: Text.AlignRight
        }
      }
    }

    // Plot area
    Item {
      id: plot
      Layout.fillWidth: true
      Layout.fillHeight: true
      Layout.minimumHeight: chart.plotHeight

      // Empty state
      Label {
        anchors.centerIn: parent
        visible: !chart.hasData
        text: chart.points.length === 0
          ? "Collecting data — check back after a few hours"
          : "Loading..."
        color: "#8a93a8"
        font.pixelSize: 12
      }

      // Plot content (only when has data)
      Item {
        anchors.fill: parent
        visible: chart.hasData

        // Hover handler — finds the nearest bar by timestamp and writes
        // its index to chart.hoveredIndex. Tooltip + bar highlight read it.
        MouseArea {
          id: hoverArea
          anchors.fill: parent
          hoverEnabled: true
          z: 50   // above bars, below tooltip
          onPositionChanged: {
            if (!chart.hasData || chart.dsPoints.length === 0) {
              chart.hoveredIndex = -1
              return
            }
            if (chart.dsPoints.length === 1) {
              chart.hoveredIndex = 0
              return
            }
            const ratio = Math.max(0, Math.min(1, mouseX / chart.plotInnerWidth))
            const targetTs = chart.firstTs + ratio * chart.spanMs
            let bestI = 0
            let bestD = Math.abs(chart.dsPoints[0].ts - targetTs)
            for (let i = 1; i < chart.dsPoints.length; i++) {
              const d = Math.abs(chart.dsPoints[i].ts - targetTs)
              if (d < bestD) { bestD = d; bestI = i }
            }
            chart.hoveredIndex = bestI
          }
          onExited: chart.hoveredIndex = -1
        }

        // Gridlines (5 horizontal levels)
        Repeater {
          model: 5
          delegate: Rectangle {
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.rightMargin: chart.axisMargin
            y: index * (parent.height / 4)
            height: 1
            color: "#252b3d"
            opacity: 0.55
          }
        }

        // Y-axis labels (100, 75, 50, 25, 0)
        Repeater {
          model: [ 100, 75, 50, 25, 0 ]
          delegate: Label {
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.topMargin: (100 - modelData) / 100 * (parent.height - 16) - height / 2
            width: 38
            height: 12
            verticalAlignment: Text.AlignVCenter
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
            readonly property bool isHovered: chart.hoveredIndex === index
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 16
            x: chart.barX(modelData.ts)
            width: chart.barWidth
            height: (parent.height - 16) * Math.max(0, Math.min(100, used)) / 100
            color: chart.barColor(used)
            opacity: isHovered ? 1 : 0.85
            radius: 1.5
          }
        }

        // Tooltip — pinned above the hovered bar, clamped inside the plot.
        Rectangle {
          id: tooltip
          visible: chart.hoveredIndex >= 0 && chart.hasData
          z: 100
          radius: 4
          color: "#0a0f1c"
          border.color: "#3df0e0"
          border.width: 1
          width: tipText.implicitWidth + 12
          height: tipText.implicitHeight + 8
          x: {
            if (chart.hoveredIndex < 0 || !chart.hasData) return 0
            const center = chart.barX(chart.dsPoints[chart.hoveredIndex].ts) + chart.barWidth / 2
            return Math.max(4, Math.min(parent.width - width - 4, center - width / 2))
          }
          y: 4
          Label {
            id: tipText
            anchors.centerIn: parent
            color: "#e8edf5"
            font.pixelSize: 10
            font.family: "monospace"
            text: chart.hoveredPoint
              ? chart.fmtTipDate(chart.hoveredPoint.ts)
                + "  ·  "
                + (100 - chart.hoveredPoint.p) + "%"
              : ""
          }
        }

        // X-axis labels: first / middle / last
        Row {
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.rightMargin: chart.axisMargin
          anchors.bottom: parent.bottom
          height: 14
          Label {
            width: parent.width / 3
            text: chart.fmtAxisDate(chart.firstTs)
            color: "#8a93a8"; opacity: 0.7; font.pixelSize: 9
          }
          Label {
            width: parent.width / 3
            text: chart.fmtAxisDate(Math.floor((chart.firstTs + chart.lastTs) / 2))
            color: "#8a93a8"; opacity: 0.7; font.pixelSize: 9
            horizontalAlignment: Text.AlignHCenter
          }
          Label {
            width: parent.width / 3
            text: chart.fmtAxisDate(chart.lastTs)
            color: "#8a93a8"; opacity: 0.7; font.pixelSize: 9
            horizontalAlignment: Text.AlignRight
          }
        }
      }
    }

    // Legend: color thresholds (usage %)
    Row {
      Layout.alignment: Qt.AlignLeft
      spacing: 14
      Row {
        spacing: 6
        Rectangle { width: 10; height: 10; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: "#3df0e0" }
        Label { text: "0–69% used"; color: "#8a93a8"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
      }
      Row {
        spacing: 6
        Rectangle { width: 10; height: 10; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: "#ffa726" }
        Label { text: "70–89% used"; color: "#8a93a8"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
      }
      Row {
        spacing: 6
        Rectangle { width: 10; height: 10; radius: 2; anchors.verticalCenter: parent.verticalCenter; color: "#ff5252" }
        Label { text: "90%+ used"; color: "#8a93a8"; font.pixelSize: 10; anchors.verticalCenter: parent.verticalCenter }
      }
    }
  }
}
