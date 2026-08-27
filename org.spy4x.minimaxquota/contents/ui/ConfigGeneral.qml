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
  property alias cfg_intervalRetentionDays: intervalRetentionField.value
  property alias cfg_weeklyRetentionDays: weeklyRetentionField.value
  property bool cfg_historyClearRequested: Plasmoid.configuration.historyClearRequested === true

  Kirigami.FormLayout {
    anchors.fill: parent
    // Cap the form width. Without this, KCM.SimpleKCM auto-sizes the
    // config dialog to fit the form's implicitWidth — which can balloon
    // past the saved DialogWidth when a single long translated label
    // (e.g. "Weekly retention (days):") forces a wider label column.
    // User then sees labels clipped on the left with a horizontal
    // scrollbar. Capping forces the dialog to respect its saved size
    // (or anything narrower).
    Layout.maximumWidth: 720
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

    QQC2.Label {
      Layout.fillWidth: true
      Layout.bottomMargin: Kirigami.Units.smallSpacing
      wrapMode: Text.Wrap
      font.pixelSize: 10
      opacity: 0.7
      text: i18n("History is always collected while an API key is set, " +
                 "keyed to this subscription so it isn't mixed with other " +
                 "subscriptions and survives widget removal/re-add.")
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
    }

    QQC2.Button {
      text: i18n("Clear history now")
      Layout.fillWidth: true
      onClicked: clearConfirmDialog.open()
    }

    Kirigami.Dialog {
      id: clearConfirmDialog
      title: i18n("Clear stored history?")
      QQC2.Label {
        text: i18n("Removes every collected sample for THIS subscription " +
                   "key only. Charts will start empty until new data accumulates. " +
                   "Other subscriptions (and their history) are unaffected.")
        wrapMode: Text.Wrap
      }
      standardButtons: Kirigami.Dialog.No | Kirigami.Dialog.Yes
      onAccepted: {
        Plasmoid.configuration.historyClearRequested = true
        clearConfirmDialog.close()
      }
    }

    // ---- Backup / Restore / Seed (developer tools) ----

    Item {
      Kirigami.FormData.isSection: true
      Kirigami.FormData.label: i18n("Backup & dev tools")
    }

    QQC2.Label {
      Layout.fillWidth: true
      Layout.bottomMargin: Kirigami.Units.smallSpacing
      wrapMode: Text.Wrap
      font.pixelSize: 10
      opacity: 0.7
      text: i18n("These buttons let you snapshot the current history, " +
                 "restore a previous snapshot, or fill history with realistic " +
                 "fake samples so the stats charts have visible bars to render. " +
                 "All three are gated by a confirmation dialog.")
    }

    QQC2.Button {
      text: i18n("Backup current history")
      Layout.fillWidth: true
      enabled: Plasmoid.configuration.apiKey.length > 0
      onClicked: backupResultDialog.showWith("backup")
    }
    QQC2.Button {
      text: i18n("Restore from backup")
      Layout.fillWidth: true
      enabled: Plasmoid.configuration.historyStoreHasBackup === true
      onClicked: restoreConfirmDialog.open()
    }
    QQC2.Button {
      text: i18n("Fill with fake samples")
      Layout.fillWidth: true
      enabled: Plasmoid.configuration.apiKey.length > 0
      onClicked: seedConfirmDialog.open()
    }

    // Restore needs a separate confirmation — overwriting the live data
    // without a snapshot would lose real history if no backup exists.
    Kirigami.Dialog {
      id: restoreConfirmDialog
      title: i18n("Restore history from backup?")
      QQC2.Label {
        text: i18n("Replaces the current history for this subscription " +
                   "with the previously-saved snapshot, then clears the " +
                   "backup so it can't be re-applied by mistake.")
        wrapMode: Text.Wrap
      }
      standardButtons: Kirigami.Dialog.No | Kirigami.Dialog.Yes
      onAccepted: {
        backupResultDialog.showWith("restore")
        restoreConfirmDialog.close()
      }
    }

    Kirigami.Dialog {
      id: seedConfirmDialog
      title: i18n("Fill history with fake samples?")
      QQC2.Label {
        text: i18n("Generates ~2k samples over 7 days (5h window) and ~26k " +
                   "samples over 90 days (weekly) as a sawtooth pattern, then " +
                   "overwrites the current history for this subscription. " +
                   "The fake data is deterministic — same window produces " +
                   "same endRemaining on every run. Use the Backup button " +
                   "first if you have real history you want to keep.")
        wrapMode: Text.Wrap
      }
      standardButtons: Kirigami.Dialog.No | Kirigami.Dialog.Yes
      onAccepted: {
        backupResultDialog.showWith("seed")
        seedConfirmDialog.close()
      }
    }

    // Single result dialog driven by `kind` so we can reuse it for all
    // three actions without three near-identical dialogs. The actual
    // call happens in main.qml when the corresponding Plasmoid flag flips
    // true→false; we just observe the flip and read the JSON result.
    Kirigami.Dialog {
      id: backupResultDialog
      title: i18n("Result")
      property string message: ""

      function showWith(k) {
        // Trigger the action by flipping the flag — main.qml will run
        // the matching function and write historyStoreLastResult.
        if (k === "backup") Plasmoid.configuration.historyStoreBackup = true
        else if (k === "restore") Plasmoid.configuration.historyStoreRestore = true
        else if (k === "seed") Plasmoid.configuration.historyStoreSeed = true
      }

      Connections {
        target: Plasmoid.configuration
        // True→False on historyStoreBackup / historyStoreRestore /
        // historyStoreSeed means main.qml finished the action. Read
        // historyStoreLastResult for the JSON payload.
        function onHistoryStoreBackupChanged() {
          if (Plasmoid.configuration.historyStoreBackup === false) {
            backupResultDialog.displayResult("backup")
          }
        }
        function onHistoryStoreRestoreChanged() {
          if (Plasmoid.configuration.historyStoreRestore === false) {
            backupResultDialog.displayResult("restore")
          }
        }
        function onHistoryStoreSeedChanged() {
          if (Plasmoid.configuration.historyStoreSeed === false) {
            backupResultDialog.displayResult("seed")
          }
        }
      }

      function displayResult(k) {
        const raw = Plasmoid.configuration.historyStoreLastResult || "{}"
        let res = {}
        try { res = JSON.parse(raw) } catch (e) { res = { ok: false, error: String(e) } }
        const ok = !!(res && res.ok)
        if (ok) {
          if (k === "backup") message = i18n("Backed up %1 sample(s) to the snapshot slot.").arg(res.samples || 0)
          else if (k === "restore") message = i18n("Restored %1 sample(s) from the snapshot.").arg(res.samples || 0)
          else message = i18n("Generated %1 interval + %2 weekly fake samples.")
                          .arg(res.intervalSamples || 0).arg(res.weeklySamples || 0)
        } else {
          message = (res && res.error) ? res.error : i18n("Unknown error.")
        }
        open()
      }

      QQC2.Label {
        text: backupResultDialog.message
        wrapMode: Text.Wrap
      }
      standardButtons: Kirigami.Dialog.Ok
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
