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
  property string cfg_orientation: Plasmoid.configuration.orientation || "horizontal"

  // Aliases bind to control properties
  property alias cfg_refreshIntervalSec: refreshField.value
  property alias cfg_historyEnabled: historyEnabledBox.checked
  property alias cfg_intervalRetentionDays: intervalRetentionField.value
  property alias cfg_weeklyRetentionDays: weeklyRetentionField.value
  property bool cfg_historyClearRequested: Plasmoid.configuration.historyClearRequested === true

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
      from: 60
      to: 3600
      stepSize: 30
      editable: true
      value: 300
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

    QQC2.ComboBox {
      id: orientationCombo
      Kirigami.FormData.label: i18n("Layout:")
      Layout.fillWidth: true
      model: [
        { text: i18n("Horizontal (side by side)"), value: "horizontal" },
        { text: i18n("Vertical (stacked)"), value: "vertical" }
      ]
      textRole: "text"
      valueRole: "value"
      currentIndex: configGeneral.cfg_orientation === "vertical" ? 1 : 0
      onActivated: configGeneral.cfg_orientation = model[currentIndex].value
    }

    Item {
      Kirigami.FormData.isSection: true
      Kirigami.FormData.label: i18n("History & Stats")
    }

    QQC2.CheckBox {
      id: historyEnabledBox
      Kirigami.FormData.label: i18n("Collect history:")
      text: i18n("Store quota samples for the stats charts")
      checked: configGeneral.cfg_historyEnabled !== false
      onToggled: configGeneral.cfg_historyEnabled = checked
    }

    QQC2.SpinBox {
      id: intervalRetentionField
      Kirigami.FormData.label: i18n("5h retention (days):")
      from: 1
      to: 30
      stepSize: 1
      editable: true
      value: 7
      Layout.fillWidth: true
      enabled: historyEnabledBox.checked
    }

    QQC2.SpinBox {
      id: weeklyRetentionField
      Kirigami.FormData.label: i18n("Weekly retention (days):")
      from: 7
      to: 365
      stepSize: 7
      editable: true
      value: 90
      Layout.fillWidth: true
      enabled: historyEnabledBox.checked
    }

    QQC2.Button {
      text: i18n("Clear history now")
      Layout.fillWidth: true
      enabled: historyEnabledBox.checked
      onClicked: clearConfirmDialog.open()
    }

    Kirigami.Dialog {
      id: clearConfirmDialog
      title: i18n("Clear stored history?")
      QQC2.Label {
        text: i18n("Removes every collected sample for both windows. " +
                   "Charts will start empty until new data accumulates. " +
                   "This does not affect the API key or other settings.")
        wrapMode: Text.Wrap
      }
      standardButtons: Kirigami.Dialog.No | Kirigami.Dialog.Yes
      onAccepted: {
        Plasmoid.configuration.historyClearRequested = true
        clearConfirmDialog.close()
      }
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
