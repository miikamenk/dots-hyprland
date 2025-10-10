pragma Singleton
pragma ComponentBehavior: Bound

import Quickshell
import Quickshell.Io
import QtQuick
import QtPositioning

import qs.modules.common

Singleton {
    id: root
    property int pacmanCount: 0
    property int aurCount: 0
    property int flatpakCount: 0
    property int totalCount: pacmanCount + aurCount + flatpakCount
    property int pollIntervalMs: 60000 * Config.options.bar.updates.fetchInterval // poll every x minutes (default 10)
    property string scriptPath: `${Directories.scriptPath}/custom/check-updates.sh`.replace(/file:\/\//, "")


    /* function to start the check process (will kill any previous run) */
    function runCheckScript() {
        checkProcess.running = true
        checkProcess.start()
    }

    Process {
        id: checkProcess
        running: false
        command: ["bash", "-c", root.scriptPath]
        stdout: SplitParser {
            onRead: data => {
                try {
                    if (data.length === 0) return;
                    const dataJson = JSON.parse(data);

                    root.pacmanCount = Number(dataJson.pacman) || 0
                    root.aurCount = Number(dataJson.aur) || 0
                    root.flatpakCount = Number(dataJson.flatpak) || 0
                } catch (e) {
                    console.log("Could not fetch updates:", e);
                }
            }
        }
    }

    Component.onCompleted: {
      root.runCheckScript()
    }

    Timer {
      id: pollTimer
      interval: pollIntervalMs
      repeat: true
      running: true
      onTriggered: root.runCheckScript()
    }
}
