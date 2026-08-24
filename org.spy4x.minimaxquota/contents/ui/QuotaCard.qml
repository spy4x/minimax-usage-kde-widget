import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import QtQuick.Shapes
import org.kde.plasma.core as PlasmaCore

Rectangle {
  id: cardRoot

  property string label: ""
  // var (not real) so null is preserved — QML coerces null to 0 on real,
  // which would render a fully-filled ring for "no data".
  property var remainingPercent: null
  // The reset duration returned by the API, in ms. Live value is computed
  // in main.qml by subtracting elapsed time since fetch.
  property var resetMs: null
  // Total window duration, in ms. Defaults to 5h; override for weekly.
  property real windowTotalMs: 5 * 60 * 60 * 1000
  property var formatFn: function(ms) { return "—" }

  readonly property bool hasData: remainingPercent !== null && remainingPercent !== undefined
  readonly property real usedPercent: hasData
    ? Math.max(0, Math.min(100, 100 - remainingPercent))
    : -1
  // Outer ring: percent of the window still remaining. e.g. 3h left of 5h = 60%.
  readonly property real timeRemainingPercent: {
    if (!hasData || resetMs === null || resetMs === undefined) return -1
    return Math.max(0, Math.min(100, (resetMs / windowTotalMs) * 100))
  }

  // Inner ring color tied to time-until-reset: cyan when plenty,
  // orange < 1h, red < 30m. Outer ring stays a muted slate so the
  // two rings are visually distinguishable.
  readonly property color innerColor: {
    if (!hasData || resetMs === null || resetMs === undefined) return "#252b3d"
    if (resetMs < 30 * 60 * 1000) return "#ff5252"
    if (resetMs < 60 * 60 * 1000) return "#ffa726"
    return "#3df0e0"
  }

  color: "#161d2f"
  border.color: "#252b3d"
  border.width: 1
  radius: 12

  Item {
    id: ringArea
    anchors.fill: parent
    anchors.margins: 18

    readonly property real ringSize: Math.min(width, height) * 0.88

    Shape {
      id: ringShape
      width: ringArea.ringSize
      height: ringArea.ringSize
      anchors.centerIn: parent

      // Outer track — time remaining ring background
      ShapePath {
        strokeColor: "#1f2940"
        strokeWidth: 5
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: ringShape.width / 2
          centerY: ringShape.height / 2
          radiusX: Math.min(ringShape.width, ringShape.height) / 2 - 3
          radiusY: radiusX
          startAngle: -90
          sweepAngle: 360
        }
      }
      // Outer arc — time remaining in window
      ShapePath {
        strokeColor: "#5a8db0"
        strokeWidth: 5
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: ringShape.width / 2
          centerY: ringShape.height / 2
          radiusX: Math.min(ringShape.width, ringShape.height) / 2 - 3
          radiusY: radiusX
          startAngle: -90
          sweepAngle: cardRoot.timeRemainingPercent >= 0 ? 360 * cardRoot.timeRemainingPercent / 100 : 0
        }
      }

      // Inner track — quota used ring background
      ShapePath {
        strokeColor: "#252b3d"
        strokeWidth: 7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: ringShape.width / 2
          centerY: ringShape.height / 2
          radiusX: Math.min(ringShape.width, ringShape.height) / 2 - 18
          radiusY: radiusX
          startAngle: -90
          sweepAngle: 360
        }
      }
      // Inner arc — quota used
      ShapePath {
        strokeColor: cardRoot.innerColor
        strokeWidth: 7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: ringShape.width / 2
          centerY: ringShape.height / 2
          radiusX: Math.min(ringShape.width, ringShape.height) / 2 - 18
          radiusY: radiusX
          startAngle: -90
          sweepAngle: cardRoot.hasData ? 360 * cardRoot.usedPercent / 100 : 0
        }
      }
    }

    // Center text overlay (in the inner ring's hole)
    ColumnLayout {
      anchors.centerIn: ringShape
      spacing: 4

      Label {
        text: cardRoot.hasData ? cardRoot.formatFn(cardRoot.resetMs) : "—"
        color: cardRoot.innerColor
        font.pixelSize: 26
        font.bold: true
        font.family: "monospace"
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }
      Label {
        text: cardRoot.label
        color: "#8a93a8"
        font.pixelSize: 9
        font.letterSpacing: 2
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }
      Label {
        text: cardRoot.hasData ? Math.round(100 - cardRoot.usedPercent) + "% left" : "—"
        color: "#e8edf5"
        font.pixelSize: 12
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }
    }
  }
}
