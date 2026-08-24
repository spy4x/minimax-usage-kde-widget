import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import org.kde.kcmutils as KCM

KCM.SimpleKCM {
  id: configRoot

  // The `cfg_` prefix binds these to plasmoid.configuration.<name>.
  property alias cfg_apiKey: apiKeyField.text
  property alias cfg_refreshIntervalSec: refreshField.value
  property alias cfg_endpoint: endpointField.text

  GridLayout {
    columns: 2
    rowSpacing: 10
    columnSpacing: 8
    anchors.fill: parent
    anchors.margins: 12

    Label {
      text: "API Key:"
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }
    TextField {
      id: apiKeyField
      Layout.fillWidth: true
      placeholderText: "sk-cp-..."
      echoMode: TextInput.Password
      selectByMouse: true
      font.family: "monospace"
    }

    Label {
      text: "Refresh (sec):"
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }
    SpinBox {
      id: refreshField
      from: 15
      to: 3600
      stepSize: 15
      value: 60
      editable: true
      Layout.fillWidth: true
    }

    Label {
      text: "Endpoint:"
      Layout.alignment: Qt.AlignRight | Qt.AlignVCenter
    }
    TextField {
      id: endpointField
      Layout.fillWidth: true
      placeholderText: "https://www.minimax.io/v1/token_plan/remains"
      font.family: "monospace"
    }

    Item { Layout.columnSpan: 2; Layout.fillHeight: true }

    Label {
      Layout.columnSpan: 2
      Layout.fillWidth: true
      wrapMode: Text.Wrap
      font.pixelSize: 10
      opacity: 0.7
      text: "Your API key is stored via QtCore.Settings to a file under " +
            "~/.config/plasma-workspace/.\n" +
            "For extra hardening run `chmod 600` on that file. " +
            "Never share this key — rotate it in the MiniMax dashboard if leaked."
    }
  }
}