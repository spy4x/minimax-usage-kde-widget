import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Statistics view: two stacked history charts (5h, weekly) inside a card.
ColumnLayout {
  id: statsRoot
  spacing: 14

  property var intervalPoints: []
  property var weeklyPoints: []

  Rectangle {
    Layout.fillWidth: true
    Layout.fillHeight: true
    color: "#0e1424"
    radius: 12
    border.color: "#252b3d"
    border.width: 1
  }

  HistoryChart {
    Layout.fillWidth: true
    Layout.preferredHeight: 230
    title: "5-HOUR WINDOW — LAST 7 DAYS"
    points: statsRoot.intervalPoints
  }

  HistoryChart {
    Layout.fillWidth: true
    Layout.preferredHeight: 230
    title: "WEEKLY WINDOW — LAST 90 DAYS"
    points: statsRoot.weeklyPoints
  }
}