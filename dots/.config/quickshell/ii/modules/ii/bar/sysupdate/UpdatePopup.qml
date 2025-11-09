import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets

import QtQuick
import QtQuick.Layouts
import "../"

StyledPopup {
    id: root

    component ResourceItem: RowLayout {
        id: resourceItem
        required property string icon
        required property string label
        required property string value
        spacing: 4

        MaterialSymbol {
            text: resourceItem.icon
            color: Appearance.colors.colOnSurfaceVariant
            iconSize: Appearance.font.pixelSize.large
        }
        StyledText {
            text: resourceItem.label
            color: Appearance.colors.colOnSurfaceVariant
        }
        StyledText {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignRight
            visible: resourceItem.value !== ""
            color: Appearance.colors.colOnSurfaceVariant
            text: resourceItem.value
        }
    }

    component ResourceHeaderItem: Row {
        id: headerItem
        required property var icon
        required property var label
        spacing: 5

        MaterialSymbol {
            anchors.verticalCenter: parent.verticalCenter
            fill: 0
            font.weight: Font.Medium
            text: headerItem.icon
            iconSize: Appearance.font.pixelSize.large
            color: Appearance.colors.colOnSurfaceVariant
        }

        StyledText {
            anchors.verticalCenter: parent.verticalCenter
            text: headerItem.label
            font {
                weight: Font.Medium
                pixelSize: Appearance.font.pixelSize.normal
            }
            color: Appearance.colors.colOnSurfaceVariant
        }
    }

    Row {
        anchors.centerIn: parent
        spacing: 12

        Column {
            anchors.top: parent.top
            spacing: 8

            ResourceHeaderItem {
                icon: "update"
                label: "Updates"
            }
            Column {
                spacing: 4
                ResourceItem {
                    icon: "update"
                    label: Translation.tr("Pacman:")
                    value: SysUpdate.pacmanCount > 0 ? SysUpdate.pacmanCount : Translation.tr("None")
                }
            }

            Column {
                spacing: 4
                ResourceItem {
                    icon: "update"
                    label: Translation.tr("Aur:")
                    value: SysUpdate.aurCount > 0 ? SysUpdate.aurCount : Translation.tr("None")
                }
            }

            Column {
                spacing: 4
                ResourceItem {
                    icon: "update"
                    label: Translation.tr("Flatpak:")
                    value: SysUpdate.flatpakCount > 0 ? SysUpdate.flatpakCount : Translation.tr("None")
                }
            }
        }
    }
}
