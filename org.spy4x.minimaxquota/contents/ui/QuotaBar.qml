import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

ColumnLayout {
  id: barRoot
  property string label: ""
  property string resetText: ""
  property real remainingPercent: 0
  property var formatFn: function(ms) { return "—" }
  property var usedFn: function(rp) { return 0 }
  property var colorFn: function(used) { return "#5cb85c" }

  spacing: 4

  RowLayout {
    Layout.fillWidth: true
    spacing: 8

    ColumnLayout {
      spacing: 0
      Layout.preferredWidth: 170
      Label {
        text: barRoot.label
        color: theme.textColor
        font.pixelSize: 13
      }
      Label {
        text: barRoot.resetText
        color: theme.subTextColor
        font.pixelSize: 10
      }
    }
    Item { Layout.fillWidth: true }
    ColumnLayout {
      spacing: 0
      Layout.alignment: Qt.AlignRight
      Label {
        text: "Total quota 100%"
        color: theme.textColor
        font.pixelSize: 13
        horizontalAlignment: Text.AlignRight
      }
      Label {
        text: "Used " + Math.round(barRoot.usedFn(barRoot.remainingPercent)) + "%"
        color: theme.subTextColor
        font.pixelSize: 11
        horizontalAlignment: Text.AlignRight
      }
    }
  }

  Rectangle {
    Layout.fillWidth: true
    implicitHeight: 6
    radius: 3
    color: Qt.lighter(theme.backgroundColor, 1.6)

    Rectangle {
      anchors.left: parent.left
      anchors.top: parent.top
      anchors.bottom: parent.bottom
      width: parent.width * Math.max(0, Math.min(100, barRoot.usedFn(barRoot.remainingPercent))) / 100
      radius: 3
      color: barRoot.colorFn(barRoot.usedFn(barRoot.remainingPercent))
    }
  }
}