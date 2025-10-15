import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import Quickshell
import Quickshell.Io

/*
  QuickToggleButton for VPN using nmcli
  - Click toggles the first configured VPN connection (or the one from Config.options.vpnConnection)
  - Right-click (altAction) opens the nm-connection-editor or a configurable VPN app
  - Tooltip shows active VPN name and count of active VPN connections

  Customize by setting Config.options.vpnConnection to a connection NAME you want to toggle.
*/

QuickToggleButton {
    id: root

    /**
     * If Config.options.vpnConnection is set, the button will try to use that connection name.
     * Otherwise it will fall back to the first saved connection that has TYPE "vpn".
     */
    property string configuredVpn: Config.options?.vpnConnection || ""
    property string activeVpnName: ""
    property int activeVpnCount: 0
    property bool vpnAvailable: true

    // Decide icon based on state
    buttonIcon: activeVpnCount > 0 ? "vpn_key" : vpnAvailable ? "vpn_key" : "vpn_key_off"

    // initial probe when component is created
    Component.onCompleted: updateVpnStatus()

    // toggle VPN when clicked
    onClicked: {
        // if there is an active VPN, disconnect all active VPNs
        if (activeVpnCount > 0) {
            // nmcli connection down id <NAME> for each active VPN
            // We'll call nmcli to fetch active VPN names and disconnect them
            let cmd = `bash -c "nmcli -t -f NAME,TYPE connection show --active | awk -F:\\: '$2==\"vpn\" {print \$1}'`
            Quickshell.execDetached(["bash","-c", cmd + " | xargs -r -I{} nmcli connection down id '{}'" ])
            // update UI optimisticly
            activeVpnName = ""
            activeVpnCount = 0
            buttonIcon = "vpn"
        } else {
            // try to bring up configured connection, or first available vpn connection
            let connectName = configuredVpn
            if (!connectName) {
                // find first saved vpn connection
                let findCmd = `bash -c "nmcli -t -f NAME,TYPE connection show | awk -F:\\: '$2==\"vpn\" {print \$1; exit}'"`
                let out = Quickshell.exec(findCmd)
                connectName = (out || "").trim()
            }

            if (!connectName) {
                // nothing to connect
                vpnAvailable = false
                StyledToolTip.show(Translation.tr("No VPN connections found"))
                return
            }

            // bring up the connection
            Quickshell.execDetached(["bash","-c", `nmcli connection up id '${connectName.replace(/'/g,"'\\''")}'`])
            // optimistic update
            activeVpnName = connectName
            activeVpnCount = 1
            buttonIcon = "vpn_connected"
        }

        // schedule a status refresh after a short delay (nmcli may take a moment)
        Qt.callLater(updateVpnStatus)
    }

    // alternative action (right-click) - open editor or custom app
    altAction: () => {
        let opener = Config.options?.apps?.vpn || "nm-connection-editor"
        Quickshell.execDetached(["bash","-c", `${opener}`])
        GlobalStates.sidebarRightOpen = false
    }

    StyledToolTip {
        id: tip
        text: Translation.tr("%1 | Right-click to configure").arg(
            (activeVpnName ? activeVpnName : Translation.tr("VPN"))
            + (activeVpnCount > 1 ? ` +${activeVpnCount - 1}` : "")
        )
    }

    // small helper function to update status by querying nmcli
    function updateVpnStatus() {
        // get active vpn connections
        let cmd = `bash -c "nmcli -t -f NAME,TYPE connection show --active | awk -F:\\: '$2==\"vpn\" {print \$1}' | sed '/^$/d'"`
        let out = Quickshell.exec(cmd) || ""
        let lines = out.split(/\r?\n/).filter(function(l) { return l.trim() !== "" })
        activeVpnCount = lines.length
        activeVpnName = lines.length > 0 ? lines[0] : ""

        // check if any vpn connections exist in saved list
        let findAnyCmd = `bash -c "nmcli -t -f NAME,TYPE connection show | awk -F:\\: '$2==\"vpn\" {print \$1; exit}'"`
        let anyOut = Quickshell.exec(findAnyCmd) || ""
        vpnAvailable = anyOut.trim() !== ""

        // update icon
        buttonIcon = activeVpnCount > 0 ? "vpn_connected" : vpnAvailable ? "vpn" : "vpn_disabled"
    }

    // poll occasionally to keep status in sync
    Timer {
        interval: 5000
        repeat: true
        running: true
        onTriggered: updateVpnStatus()
    }
}
