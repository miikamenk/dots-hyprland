pragma Singleton
pragma ComponentBehavior: Bound

import qs.modules.common
import QtQuick
import Quickshell
import Quickshell.Io
import Qt.labs.folderlistmodel 2.1

/**
 * Simple polled resource usage service with RAM, Swap, and CPU usage.
 */
Singleton {
    property double memoryTotal: 1
    property double memoryFree: 1
    property double memoryUsed: memoryTotal - memoryFree
    property double memoryUsedPercentage: memoryUsed / memoryTotal
    property double swapTotal: 1
    property double swapFree: 1
    property double swapUsed: swapTotal - swapFree
    property double swapUsedPercentage: swapTotal > 0 ? (swapUsed / swapTotal) : 0
    property double cpuUsage: 0
    property double cpuTemp: 0
    property var previousCpuStats
    property double gpuUsage: 0
    property double gpuTemp: 0
    property string gpuType: "NONE"


    Timer {
      interval: 1
      running: true 
      repeat: true
      onTriggered: {
            // Reload files
            fileMeminfo.reload()
            fileStat.reload()

            // Parse memory and swap usage
            const textMeminfo = fileMeminfo.text()
            memoryTotal = Number(textMeminfo.match(/MemTotal: *(\d+)/)?.[1] ?? 1)
            memoryFree = Number(textMeminfo.match(/MemAvailable: *(\d+)/)?.[1] ?? 0)
            swapTotal = Number(textMeminfo.match(/SwapTotal: *(\d+)/)?.[1] ?? 1)
            swapFree = Number(textMeminfo.match(/SwapFree: *(\d+)/)?.[1] ?? 0)

            // Parse CPU usage
            const textStat = fileStat.text()
            const cpuLine = textStat.match(/^cpu\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)\s+(\d+)/)
            if (cpuLine) {
                const stats = cpuLine.slice(1).map(Number)
                const total = stats.reduce((a, b) => a + b, 0)
                const idle = stats[3]

                if (previousCpuStats) {
                    const totalDiff = total - previousCpuStats.total
                    const idleDiff = idle - previousCpuStats.idle
                    cpuUsage = totalDiff > 0 ? (1 - idleDiff / totalDiff) : 0
                }

                previousCpuStats = { total, idle }
              }
            gpuTypeCheck.running = true

            // Trigger the GPU usage and sensors processes to run now
            gpuUsageProc.running = true
            sensorsProc.running = true
            interval = Config.options?.resources?.updateInterval ?? 3000
      }
    }
    Process {
        id: gpuTypeCheck
        // only run when no explicit Config.services.gpuType
        running: false
        command: ["sh", "-c", "if command -v nvidia-smi &>/dev/null && nvidia-smi -L &>/dev/null; then echo NVIDIA; elif ls /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null | grep -q .; then echo GENERIC; else echo NONE; fi"]
        stdout: StdioCollector {
            onStreamFinished: {
                // Set auto-detected type (this affects subsequent gpuUsageProc command selection)
                gpuType = text.trim()
            }
        }
    }

    Process {
        id: gpuUsageProc
        running: false
        // command depends on gpuType (NVIDIA vs GENERIC vs NONE)
        // For GENERIC we cat gpu_busy_percent files; for NVIDIA we call nvidia-smi to get usage and temp; else echo empty
        command: (gpuType === "GENERIC") ?
                    ["sh", "-c", "cat /sys/class/drm/card*/device/gpu_busy_percent 2>/dev/null || echo"] :
                 (gpuType === "NVIDIA") ?
                    ["sh", "-c", "nvidia-smi --query-gpu=utilization.gpu,temperature.gpu --format=csv,noheader,nounits 2>/dev/null || echo"] :
                    ["sh", "-c", "echo"]
        stdout: StdioCollector {
            onStreamFinished: {
                const out = text.trim()
                if (gpuType === "GENERIC") {
                    if (out === "") {
                        gpuUsage = 0
                        // leave gpuTemp as-is; sensorsProc will try to update it
                    } else {
                        const percs = out.split("\n").map(l => parseInt(l, 10) || 0)
                        const sum = percs.reduce((acc, d) => acc + d, 0)
                        // convert 0..100 to 0..1
                        gpuUsage = percs.length > 0 ? (sum / percs.length) / 100 : 0
                    }
                } else if (gpuType === "NVIDIA") {
                    // nvidia-smi returns lines like: " 12 %, 42 C" or "12, 42"
                    // We requested csv,noheader,nounits -> "12, 42"
                    if (out === "") {
                        gpuUsage = 0
                        gpuTemp = 0
                    } else {
                        // If multiple GPUs present, take the average of usages and temps
                        const lines = out.split("\n").map(l => l.trim()).filter(l => l !== "")
                        let sumUsage = 0, sumTemp = 0, cnt = 0
                        for (const line of lines) {
                            const parts = line.split(",").map(p => p.trim())
                            const usage = parseInt(parts[0], 10) || 0
                            const temp = parseInt(parts[1], 10) || 0
                            sumUsage += usage
                            sumTemp += temp
                            cnt++
                        }
                        gpuUsage = cnt > 0 ? (sumUsage / cnt) / 100 : 0
                        gpuTemp = cnt > 0 ? (sumTemp / cnt) : 0
                    }
                } else {
                    gpuUsage = 0
                    // gpuTemp will be attempted to be filled by sensorsProc below
                }
            }
        }
    }

    Process {
        id: sensorsProc
        running: false
        command: ["sensors"]
        environment: ({
                LANG: "C.UTF-8",
                LC_ALL: "C.UTF-8"
            })
        stdout: StdioCollector {
            onStreamFinished: {
                const txt = text

                // CPU temperature detection similar to second file
                let cpuTempMatch = txt.match(/(?:Package id [0-9]+|Tdie):\s+((\+|-)[0-9.]+)(°| )C/)
                if (!cpuTempMatch)
                    cpuTempMatch = txt.match(/Tctl:\s+((\+|-)[0-9.]+)(°| )C/)

                if (cpuTempMatch) {
                    cpuTemp = parseFloat(cpuTempMatch[1])
                }

                // If GPU is GENERIC, parse GPU adapter blocks for temps
                if (gpuType !== "GENERIC")
                    return

                let eligible = false
                let sum = 0
                let count = 0

                for (const line of txt.trim().split("\n")) {
                    if (line === "Adapter: PCI adapter")
                        eligible = true
                    else if (line === "")
                        eligible = false
                    else if (eligible) {
                        let match = line.match(/^(temp[0-9]+|GPU core|edge)+:\s+\+([0-9]+\.[0-9]+)(°| )C/)
                        if (!match)
                            match = line.match(/^(junction|mem)+:\s+\+([0-9]+\.[0-9]+)(°| )C/)

                        if (match) {
                            sum += parseFloat(match[2])
                            count++
                        }
                    }
                }

                gpuTemp = count > 0 ? sum / count : gpuTemp
            }
        }
    }

	FileView { id: fileMeminfo; path: "/proc/meminfo" }
  FileView { id: fileStat; path: "/proc/stat" }
}
