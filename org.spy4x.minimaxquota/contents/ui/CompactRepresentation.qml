import QtQuick
import QtQuick.Controls

Item {
  id: compactRoot
  implicitWidth: 40
  implicitHeight: 40

  // Prefer the latest value pushed by the full representation.
  // If the widget is only shown as compact (panel), we show a stale or default value.
  property real minPercent: {
    const i = plasmoid.intervalData && plasmoid.intervalData.remainingPercent !== null
      ? plasmoid.intervalData.remainingPercent : 100
    const w = plasmoid.weeklyData && plasmoid.weeklyData.remainingPercent !== null
      ? plasmoid.weeklyData.remainingPercent : 100
    return Math.min(i, w)
  }

  Rectangle {
    anchors.fill: parent
    anchors.margins: 4
    radius: width / 2
    color: compactRoot.minPercent < 20 ? "#d9534f"
         : compactRoot.minPercent < 50 ? "#f0ad4e"
         : "#5cb85c"
    opacity: 0.75
  }
  Label {
    anchors.centerIn: parent
    text: compactRoot.minPercent !== null ? Math.round(compactRoot.minPercent) + "%" : "—"
    font.pixelSize: 10
    font.bold: true
    color: "#ffffff"
  }
}