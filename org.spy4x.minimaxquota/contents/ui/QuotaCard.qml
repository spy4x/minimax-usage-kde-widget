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
  property var formatFn: function(ms) { return "—" }

  readonly property bool hasData: remainingPercent !== null && remainingPercent !== undefined
  readonly property real usedPercent: hasData
    ? Math.max(0, Math.min(100, 100 - remainingPercent))
    : -1

  // Color tied to time-until-reset: cyan when plenty, orange < 1h,
  // red < 30m. Matches reference (5h shows orange because 21m left).
  readonly property color arcColor: {
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

    readonly property real ringSize: Math.min(width, height) * 0.86

    Shape {
      id: ringShape
      width: ringArea.ringSize
      height: ringArea.ringSize
      anchors.centerIn: parent

      // Track (full circle, dim)
      ShapePath {
        strokeColor: "#252b3d"
        strokeWidth: 7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: ringShape.width / 2
          centerY: ringShape.height / 2
          radiusX: Math.min(ringShape.width, ringShape.height) / 2 - 4
          radiusY: radiusX
          startAngle: -90
          sweepAngle: 360
        }
      }
      // Progress arc (used percent)
      ShapePath {
        strokeColor: cardRoot.arcColor
        strokeWidth: 7
        fillColor: "transparent"
        capStyle: ShapePath.RoundCap
        PathAngleArc {
          centerX: ringShape.width / 2
          centerY: ringShape.height / 2
          radiusX: Math.min(ringShape.width, ringShape.height) / 2 - 4
          radiusY: radiusX
          startAngle: -90
          sweepAngle: cardRoot.hasData ? 360 * cardRoot.usedPercent / 100 : 0
        }
      }
    }

    // Center text overlay
    ColumnLayout {
      anchors.centerIn: ringShape
      spacing: 4

      Label {
        text: cardRoot.hasData ? cardRoot.formatFn(cardRoot.resetMs) : "—"
        color: cardRoot.arcColor
        font.pixelSize: 30
        font.bold: true
        font.family: "monospace"
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }
      Label {
        text: cardRoot.label
        color: "#8a93a8"
        font.pixelSize: 10
        font.letterSpacing: 2
        font.bold: true
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }
      Label {
        text: cardRoot.hasData ? Math.round(100 - cardRoot.usedPercent) + "% left" : "—"
        color: "#e8edf5"
        font.pixelSize: 13
        horizontalAlignment: Text.AlignHCenter
        Layout.alignment: Qt.AlignHCenter
      }
    }
  }
}
