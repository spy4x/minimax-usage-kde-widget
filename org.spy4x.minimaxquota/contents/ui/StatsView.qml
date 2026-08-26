import QtQuick
import QtQuick.Layouts
import QtQuick.Controls

// Statistics view: two stacked history charts (5h, weekly) inside the
// page. Charts share the available vertical space equally; the outer
// page background (`#0e1424` from main.qml) shows through the gap
// between them, matching the two-card-on-dark-canvas look.
ColumnLayout {
  id: statsRoot
  spacing: 10

  property var intervalPoints: []
  property var weeklyPoints: []

  HistoryChart {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 200
    title: "5-HOUR WINDOW — LAST 7 DAYS"
    points: statsRoot.intervalPoints
  }

  HistoryChart {
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.minimumHeight: 200
    title: "WEEKLY WINDOW — LAST 90 DAYS"
    points: statsRoot.weeklyPoints
  }
}
