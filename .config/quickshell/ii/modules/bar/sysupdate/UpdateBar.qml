pragma ComponentBehavior: Bound
import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs
import Quickshell
import QtQuick
import QtQuick.Layouts

MouseArea {
    id: root
    property bool hovered: false
    implicitWidth: rowLayout.implicitWidth + 10 * 2
    implicitHeight: Appearance.sizes.barHeight

    hoverEnabled: true

    onClicked: {
        Quickshell.execDetached(["notify-send", 
            Translation.tr("Updates"), 
            Translation.tr("Refreshing (manually triggered)")
            , "-a", "Shell"
        ])
        SysUpdate.runCheckScript();
    }

    RowLayout {
        id: rowLayout
        anchors.centerIn: parent

        MaterialSymbol {
            fill: 0
            text: "update"
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnLayer1
            Layout.alignment: Qt.AlignVCenter
        }

        StyledText {
            visible: true
            font.pixelSize: Appearance.font.pixelSize.small
            color: Appearance.colors.colOnLayer1
            text: SysUpdate.totalCount ?? "0"
            Layout.alignment: Qt.AlignVCenter
        }
    }

    UpdatePopup {
        id: updatePopup
        hoverTarget: root
    }
}
