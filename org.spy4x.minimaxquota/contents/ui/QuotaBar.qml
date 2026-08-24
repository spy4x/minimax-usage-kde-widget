import QtQuick
import QtQuick.Layouts
import QtQuick.Controls
import org.kde.plasma.core as PlasmaCore

ColumnLayout {
  id: barRoot
  property string label: ""
  property string resetText: ""
  // var (not real) so null is preserved — QML coerces null to 0 on real,
  // which makes a "no data" state look like 100% used / red.
  property var remainingPercent: null
  property var formatFn: function(ms) { return "—" }
  property var usedFn: function(rp) { return 0 }
  property var colorFn: function(used) { return "#5cb85c" }

  readonly property bool hasData: remainingPercent !== null && remainingPercent !== undefined
  readonly property real usedPercent: {
    if (!hasData) return -1
    const v = usedFn(remainingPercent)
    return (v === null || v === undefined || isNaN(v)) ? -1 : v
  }

  spacing: 4

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    ColumnLayout {
      spacing: 0
      Layout.preferredWidth: 170
      Label {
        text: barRoot.label
        color: PlasmaCore.Theme.textColor
        font.pixelSize: 13
      }
      Label {
        text: barRoot.resetText
        color: PlasmaCore.Theme.subTextColor
        font.pixelSize: 10
      }
    }
    Item { Layout.fillWidth: true }
    ColumnLayout {
      spacing: 0
      Layout.alignment: Qt.AlignRight
      Label {
        text: barRoot.hasData ? "Total quota " + Math.round(100 - barRoot.usedPercent) + "%" : "Total quota —"
        color: PlasmaCore.Theme.textColor
        font.pixelSize: 13
        horizontalAlignment: Text.AlignRight
      }
      Label {
        text: barRoot.hasData ? "Used " + Math.round(barRoot.usedPercent) + "%" : "Used —"
        color: PlasmaCore.Theme.subTextColor
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: 6
    radius: 3
    color: Qt.lighter(PlasmaCore.Theme.backgroundColor, 1.6)

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * (barRoot.hasData ? Math.max(0, Math.min(100, barRoot.usedPercent)) / 100 : 0)
      radius: 3
      color: barRoot.hasData
        ? barRoot.colorFn(barRoot.usedPercent)
        : Qt.lighter(PlasmaCore.Theme.backgroundColor, 1.3)
    }
  }
}