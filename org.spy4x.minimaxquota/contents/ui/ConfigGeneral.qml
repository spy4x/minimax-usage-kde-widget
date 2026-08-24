import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.kcmutils as KCMUtils
import org.kde.kirigami as Kirigami
import org.kde.plasma.plasmoid

KCMUtils.SimpleKCM {
  id: configGeneral

  // Direct bindings to Plasmoid.configuration.<name>
  property string cfg_apiKey: Plasmoid.configuration.apiKey
  property string cfg_endpoint: Plasmoid.configuration.endpoint

  // Aliases bind to control properties
  property alias cfg_refreshIntervalSec: refreshField.value

  Kirigami.FormLayout {
    anchors.fill: parent
    wideMode: true

    QQC2.TextField {
      id: apiKeyField
      Kirigami.FormData.label: i18n("API Key:")
      Layout.fillWidth: true
      placeholderText: "sk-cp-..."
      echoMode: TextInput.Password
      selectByMouse: true
      font.family: "monospace"
      text: configGeneral.cfg_apiKey
      onTextChanged: configGeneral.cfg_apiKey = text
    }

    QQC2.SpinBox {
      id: refreshField
      Kirigami.FormData.label: i18n("Refresh (sec):")
      from: 15
      to: 3600
      stepSize: 15
      editable: true
      Layout.fillWidth: true
    }

    QQC2.TextField {
      id: endpointField
      Kirigami.FormData.label: i18n("Endpoint:")
      Layout.fillWidth: true
      placeholderText: "https://www.minimax.io/v1/token_plan/remains"
      font.family: "monospace"
      text: configGeneral.cfg_endpoint
      onTextChanged: configGeneral.cfg_endpoint = text
    }

    Item {
      Kirigami.FormData.isSection: true
    }

    QQC2.Label {
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
