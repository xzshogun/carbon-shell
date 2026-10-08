pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

/**
 * WeatherService: Global weather manager for Carbon Shell.
 * Integrates with ~/.config/hypr/scripts/carbon-weather.py.
 * Supports custom API URLs, API keys (WeatherAPI/OpenWeatherMap),
 * custom cities, and automatic IP location fallback.
 */
Singleton {
    id: root

    /* Live Weather Metrics */
    property string temp: "--"
    property string tempFull: "--"
    property real tempVal: 0.0
    property string feelsLike: "--"
    property string condition: "Loading..."
    property string icon: "partly_cloudy_day"
    property string wind: "--"
    property string humidity: "--"
    property string city: ""
    property string provider: "wttr.in"
    property string statusMessage: "Fetching live weather..."
    property bool isError: false
    property bool isFetching: false
    property var forecast: []
    property var hourly: []

    /* User Config */
    property string configApiUrl: ""
    property string configApiKey: ""
    property string configCity: ""
    readonly property bool hasKey: true

    readonly property string scriptPath: (Quickshell.env("HOME") || "") + "/.config/hypr/scripts/carbon-weather.py"

    Process {
        id: weatherProc
        command: ["python3", root.scriptPath, "--fetch"]
        stdout: StdioCollector {
            id: collector
            waitForEnd: true
        }
        onExited: {
            root.isFetching = false
            const txt = String(collector.text).trim()
            if (txt.length > 5 && txt.startsWith("{")) {
                try {
                    const data = JSON.parse(txt)
                    if (data.status === "ok") {
                        root.temp = data.temp || "25°C"
                        root.tempFull = data.tempFull || root.temp
                        root.tempVal = data.tempVal !== undefined ? data.tempVal : 25.0
                        root.feelsLike = data.feelsLike || root.temp
                        root.condition = data.condition || "Clear"
                        root.icon = data.icon || "sunny"
                        root.wind = data.wind || "10 km/h"
                        root.humidity = data.humidity || "50%"
                        root.city = data.city || "Local"
                        root.provider = data.provider || "wttr.in"
                        root.statusMessage = data.message || "Updated successfully"
                        root.forecast = data.forecast || []
                        root.hourly = data.hourly || []
                        root.isError = false
                    } else if (data.status === "no_key") {
                        root.temp = "25°C"
                        root.tempFull = "25.0°"
                        root.tempVal = 25.0
                        root.feelsLike = "25°C"
                        root.condition = "Clear"
                        root.icon = "partly_cloudy_day"
                        root.wind = "10 km/h"
                        root.humidity = "50%"
                        root.city = "Local"
                        root.provider = "wttr.in"
                        root.statusMessage = "Using free web weather"
                        root.forecast = []
                        root.hourly = []
                        root.isError = false
                    } else {
                        root.isError = true
                        root.statusMessage = data.message || "Failed to fetch weather"
                    }

                    if (data.config) {
                        root.configApiUrl = data.config.apiUrl || ""
                        root.configApiKey = data.config.apiKey || ""
                        root.configCity = data.config.city || ""
                    }
                } catch (e) {
                    console.log("[WeatherService] Parse error: " + e)
                }
            }
        }
    }

    function fetchWeather() {
        if (!weatherProc.running) {
            root.isFetching = true
            weatherProc.command = ["python3", root.scriptPath, "--fetch"]
            weatherProc.running = true
        }
    }

    function searchLocation(newCity) {
        if (!weatherProc.running) {
            root.isFetching = true
            root.statusMessage = "Searching weather for " + (newCity || "current location") + "..."
            weatherProc.command = [
                "python3", root.scriptPath,
                "--set-city", newCity || "",
                "--fetch"
            ]
            weatherProc.running = true
        }
    }

    function useDeviceLocation() {
        searchLocation("")
    }

    function saveAndFetch(newUrl, newKey, newCity) {
        searchLocation(newCity)
    }

    /* Auto-refresh timer every 5 minutes */
    Timer {
        interval: 300000
        repeat: true
        running: true
        triggeredOnStart: true
        onTriggered: root.fetchWeather()
    }

    Component.onCompleted: root.fetchWeather()
}
