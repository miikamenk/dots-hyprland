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
    property int pollIntervalMs: 60000 * 10 // poll every 10 minutes
    property string scriptPath: `${Directories.scriptPath}/custom/check-updates.sh`.replace(/file:\/\//, "")

    signal refreshRequested()


    /* function to start the check process (will kill any previous run) */
    function runCheckScript() {
        if (checkProcess.running) {
            // stop previous run to avoid overlapping executions
            try {
                checkProcess.kill()
            } catch (e) {
                console.log("Could not kill existing check process:", e)
            }
        }
        checkProcess.start()
    }

    Process {
        id: runCheckScript
        running: true
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

    onRefreshRequested: {
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
