import QtQuick
import QtQuick.Controls
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "optimistprime.mouse"
  ipcTarget: "optimistprime.mouse"
  manageIpc: true

  property bool connected: false
  property string deviceName: "Logitech G Pro"
  property int battery: -1
  property string batteryStatus: "Unknown"
  property int activeDpi: 1200
  property var dpis: [400, 800, 1200, 1600, 3200, 6400]
  property int activeRate: 1000
  property var rates: [125, 250, 500, 1000]
  property real hyprSensitivity: 0.35
  property bool showPercentage: false

  // Lighting properties
  property bool lightingEnabled: true
  property string lightingMode: "theme"
  property string customColor: "#eb8b54"
  property bool breatheEnabled: false
  property int lightingBrightness: 255
  property var themeColors: ["#7d82d9", "#ffcead", "#ed5b5a", "#e9bb4f", "#eb8b54", "#92a593", "#a3bfd1", "#c89dc1"]

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight
  readonly property real openPanelIndicatorWidth: showPercentage && !button.vertical ? button.glyphPaintedWidth : 0

  readonly property color barForeground: bar ? bar.foreground : Color.foreground
  readonly property color barBackground: bar ? bar.background : Color.background
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string mouseIcon: {
    if (batteryStatus === "Charging") return "󰢝"
    return "󰍽"
  }

  function dpiOptions() {
    var list = []
    for (var i = 0; i < dpis.length; i++) {
      var d = dpis[i]
      list.push({ value: String(d), label: String(d) })
    }
    return list
  }

  function rateOptions() {
    var list = []
    for (var i = 0; i < rates.length; i++) {
      var r = rates[i]
      list.push({ value: String(r), label: r + "Hz" })
    }
    return list
  }

  function lightingModeOptions() {
    return [
      { value: "theme", label: "Theme Cycle" },
      { value: "custom", label: "Custom Color" },
      { value: "rainbow", label: "Rainbow" }
    ]
  }

  function refresh() {
    if (!refreshProc.running) {
      refreshProc.running = true
    }
  }

  readonly property string mouseControlBin: {
    var localPath = Qt.resolvedUrl("omarchy-mouse-control").toString().replace(/^file:\/\//, "")
    return localPath
  }

  function setDpi(dpi) {
    var val = parseInt(dpi, 10)
    root.activeDpi = val
    Quickshell.execDetached([root.mouseControlBin, "set-dpi", String(val)])
  }

  function setRate(rate) {
    var val = parseInt(rate, 10)
    root.activeRate = val
    Quickshell.execDetached([root.mouseControlBin, "set-rate", String(val)])
  }

  function setSensitivity(sens) {
    root.hyprSensitivity = sens
    Quickshell.execDetached([root.mouseControlBin, "set-sensitivity", sens.toFixed(2)])
  }

  function toggleLighting() {
    root.lightingEnabled = !root.lightingEnabled
    Quickshell.execDetached([root.mouseControlBin, "set-lighting-toggle", root.lightingEnabled ? "1" : "0"])
  }

  function setLightingMode(mode) {
    root.lightingMode = mode
    Quickshell.execDetached([root.mouseControlBin, "set-lighting-mode", mode])
  }

  function setCustomColor(color) {
    root.customColor = color
    Quickshell.execDetached([root.mouseControlBin, "set-lighting-color", color])
  }

  function setBreathe(breathe) {
    root.breatheEnabled = breathe
    Quickshell.execDetached([root.mouseControlBin, "set-lighting-breathe", breathe ? "1" : "0"])
  }

  function setLightingBrightness(bgt) {
    root.lightingBrightness = bgt
    Quickshell.execDetached([root.mouseControlBin, "set-lighting-brightness", String(Math.round(bgt))])
  }

  Process {
    id: refreshProc
    command: [root.mouseControlBin, "state"]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: {
        try {
          var data = JSON.parse(text || "{}")
          root.connected = data.connected === true
          if (data.name) root.deviceName = data.name
          if (data.battery !== undefined) root.battery = data.battery
          if (data.battery_status) root.batteryStatus = data.battery_status
          if (data.active_dpi) root.activeDpi = data.active_dpi
          if (data.active_rate) root.activeRate = data.active_rate
          if (Array.isArray(data.dpis) && data.dpis.length > 0) root.dpis = data.dpis
          if (Array.isArray(data.rates) && data.rates.length > 0) root.rates = data.rates
          if (data.hypr_sensitivity !== undefined && !sensSlider.dragging) {
            root.hyprSensitivity = data.hypr_sensitivity
          }
          if (data.lighting) {
            root.lightingEnabled = data.lighting.enabled !== false
            if (data.lighting.mode) root.lightingMode = data.lighting.mode
            if (data.lighting.color) root.customColor = data.lighting.color
            root.breatheEnabled = data.lighting.breathing === true
            if (data.lighting.brightness !== undefined && !lightBrightnessSlider.dragging) {
              root.lightingBrightness = data.lighting.brightness
            }
            if (Array.isArray(data.lighting.theme_colors) && data.lighting.theme_colors.length > 0) {
              root.themeColors = data.lighting.theme_colors
            }
          }
        } catch (e) {
          console.warn("optimistprime.mouse parse error:", e)
        }
      }
    }
  }

  Timer {
    interval: 5000
    running: root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Timer {
    interval: 30000
    running: !root.opened
    repeat: true
    onTriggered: root.refresh()
  }

  Component.onCompleted: root.refresh()
  onOpenedChanged: if (root.opened) root.refresh()

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: {
      var icon = root.mouseIcon
      if (root.showPercentage && !vertical && root.battery >= 0) {
        return root.battery + "% " + icon
      }
      return icon
    }
    slotSize: Style.bar.iconSlot * (root.showPercentage && !vertical && root.battery >= 0 ? 2 : 1)
    tooltipText: root.deviceName + (root.battery >= 0 ? " (" + root.battery + "%, " + root.batteryStatus + ")" : "")
    onPressed: function(b) {
      if (b === Qt.RightButton) {
        root.showPercentage = !root.showPercentage
      } else {
        root.toggle()
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(380))
    contentHeight: panel.fittedContentHeight(scrollArea.contentHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }

      ScrollView {
        id: scrollArea
        anchors.fill: parent
        clip: true
        ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
        ScrollBar.vertical.policy: contentCol.implicitHeight > height ? ScrollBar.AsNeeded : ScrollBar.AlwaysOff
        contentWidth: availableWidth
        contentHeight: contentCol.implicitHeight

        Column {
          id: contentCol
          width: scrollArea.availableWidth
          spacing: Style.space(14)

          // ---------- Hero: Mouse Icon, Device Name, Status ----------
          Item {
            width: parent.width
            implicitHeight: Math.max(heroIcon.implicitHeight, heroLabels.implicitHeight)

            Text {
              id: heroIcon
              textFormat: Text.PlainText
              text: root.mouseIcon
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              anchors.left: parent.left
              anchors.verticalCenter: parent.verticalCenter
            }

            Column {
              id: heroLabels
              anchors.left: heroIcon.right
              anchors.leftMargin: Style.space(14)
              anchors.right: heroPercent.left
              anchors.rightMargin: Style.space(10)
              anchors.verticalCenter: parent.verticalCenter
              spacing: Style.space(2)

              Text {
                text: root.deviceName
                color: root.barForeground
                font.family: root.fontFamily
                font.pixelSize: Style.font.title
                font.bold: true
                elide: Text.ElideRight
                width: parent.width
              }

              Text {
                id: heroStatus
                textFormat: Text.PlainText
                text: root.connected ? (root.battery >= 0 ? (root.batteryStatus.toUpperCase() + " · LIGHTSPEED") : "CONNECTED") : "DISCONNECTED"
                color: Qt.darker(root.barForeground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                font.letterSpacing: 1.2
                elide: Text.ElideRight
                width: parent.width
              }
            }

            Text {
              id: heroPercent
              visible: root.battery >= 0
              textFormat: Text.PlainText
              text: root.battery + "%"
              color: root.barForeground
              font.family: root.fontFamily
              font.pixelSize: Style.font.title
              font.bold: true
              anchors.right: parent.right
              anchors.verticalCenter: parent.verticalCenter
            }
          }

          // ---------- Battery Level Meter ----------
          Item {
            width: parent.width
            height: Style.space(6)
            visible: root.battery >= 0

            Rectangle {
              anchors.fill: parent
              radius: height / 2
              color: Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.12)
            }

            Rectangle {
              width: parent.width * Math.max(0, Math.min(1, root.battery / 100))
              height: parent.height
              radius: height / 2
              color: root.batteryStatus === "Charging" ? Color.accent : (root.battery <= 20 ? "#ff5555" : root.barForeground)

              Behavior on width { NumberAnimation { duration: 250; easing.type: Easing.OutQuad } }
            }
          }

          // ---------- RGB Lighting Section ----------
          PanelSeparator {
            foreground: root.barForeground
          }

          Column {
            width: parent.width
            spacing: Style.space(10)

            Item {
              width: parent.width
              implicitHeight: Math.max(lightingHeader.implicitHeight, lightingToggle.implicitHeight)

              PanelSectionHeader {
                id: lightingHeader
                text: "RGB LIGHTING"
                foreground: root.barForeground
                fontFamily: root.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              ToggleSwitch {
                id: lightingToggle
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
                checked: root.lightingEnabled
                foreground: root.barForeground
                accent: Color.accent
                onToggled: root.toggleLighting()
              }
            }

            // Controls active when lighting is enabled
            Column {
              width: parent.width
              spacing: Style.space(10)
              visible: root.lightingEnabled

              // Lighting Mode Selector
              ButtonGroup {
                options: root.lightingModeOptions()
                value: root.lightingMode
                foreground: root.barForeground
                background: root.barBackground
                accent: Color.accent
                fontFamily: root.fontFamily
                onChanged: function(val) { root.setLightingMode(val) }
              }

              // Mode 1: Theme Cycle
              Column {
                width: parent.width
                spacing: Style.space(8)
                visible: root.lightingMode === "theme"

                Row {
                  spacing: Style.space(6)
                  Repeater {
                    model: root.themeColors
                    delegate: Rectangle {
                      required property string modelData
                      width: Style.space(20)
                      height: Style.space(14)
                      radius: Style.space(3)
                      color: modelData
                      opacity: 0.9
                    }
                  }
                }

                Text {
                  text: "Slow 8-second progression through active Omarchy theme colors"
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                  width: parent.width
                  wrapMode: Text.WordWrap
                }
              }

              // Mode 2: Rainbow Cycle
              Item {
                width: parent.width
                implicitHeight: rainbowLabel.implicitHeight
                visible: root.lightingMode === "rainbow"

                Text {
                  id: rainbowLabel
                  text: "Hardware 360° RGB spectrum wave cycle"
                  color: Qt.darker(root.barForeground, 1.4)
                  font.family: root.fontFamily
                  font.pixelSize: Style.font.caption
                }
              }

              // Mode 3: Custom Color & Breathe
              Column {
                width: parent.width
                spacing: Style.space(8)
                visible: root.lightingMode === "custom"

                Item {
                  width: parent.width
                  implicitHeight: Math.max(hexField.implicitHeight, colorSwatch.implicitHeight, breatheRow.implicitHeight)

                  Row {
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Rectangle {
                      id: colorSwatch
                      width: Style.space(28)
                      height: Style.space(28)
                      radius: Style.cornerRadius
                      color: root.customColor
                      border.width: 1
                      border.color: root.barForeground
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    TextField {
                      id: hexField
                      text: root.customColor
                      placeholderText: "#RRGGBB"
                      width: Style.space(110)
                      anchors.verticalCenter: parent.verticalCenter
                      font.pixelSize: Style.font.caption
                      onAccepted: root.setCustomColor(text)
                      onEditingFinished: root.setCustomColor(text)
                    }
                  }

                  Row {
                    id: breatheRow
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: Style.space(8)

                    Text {
                      text: "Breathe"
                      color: root.breatheEnabled ? root.barForeground : Qt.darker(root.barForeground, 1.4)
                      font.family: root.fontFamily
                      font.pixelSize: Style.font.caption
                      font.bold: true
                      anchors.verticalCenter: parent.verticalCenter
                    }

                    ToggleSwitch {
                      checked: root.breatheEnabled
                      anchors.verticalCenter: parent.verticalCenter
                      foreground: root.barForeground
                      accent: Color.accent
                      onToggled: root.setBreathe(!root.breatheEnabled)
                    }
                  }
                }

                // Quick theme color chips for easy 1-click selection
                Row {
                  spacing: Style.space(8)
                  Repeater {
                    model: root.themeColors
                    delegate: Rectangle {
                      required property string modelData
                      width: Style.space(24)
                      height: Style.space(24)
                      radius: width / 2
                      color: modelData
                      border.width: root.customColor.toLowerCase() === modelData.toLowerCase() ? 2 : 1
                      border.color: root.customColor.toLowerCase() === modelData.toLowerCase() ? root.barForeground : Qt.rgba(root.barForeground.r, root.barForeground.g, root.barForeground.b, 0.25)

                      MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                          hexField.text = modelData
                          root.setCustomColor(modelData)
                        }
                      }
                    }
                  }
                }
              }

              // Brightness Slider
              Column {
                width: parent.width
                spacing: Style.space(6)

                Item {
                  width: parent.width
                  implicitHeight: Math.max(lightBgtHeader.implicitHeight, lightBgtVal.implicitHeight)

                  PanelSectionHeader {
                    id: lightBgtHeader
                    text: "BRIGHTNESS"
                    foreground: root.barForeground
                    fontFamily: root.fontFamily
                    anchors.left: parent.left
                    anchors.verticalCenter: parent.verticalCenter
                  }

                  Text {
                    id: lightBgtVal
                    text: Math.round(root.lightingBrightness / 2.55) + "%"
                    color: Qt.darker(root.barForeground, 1.4)
                    font.family: root.fontFamily
                    font.pixelSize: Style.font.caption
                    font.bold: true
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                  }
                }

                PanelSlider {
                  id: lightBrightnessSlider
                  width: parent.width
                  bar: root.bar
                  minimum: 0
                  maximum: 255
                  step: 5
                  value: root.lightingBrightness
                  onReleased: function(v) {
                    root.setLightingBrightness(v)
                  }
                }
              }
            }
          }

          // ---------- DPI (Hardware Sensitivity) ----------
          PanelSeparator {
            foreground: root.barForeground
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(dpiHeader.implicitHeight, dpiLabel.implicitHeight)

              PanelSectionHeader {
                id: dpiHeader
                text: "DPI (HARDWARE SENSITIVITY)"
                foreground: root.barForeground
                fontFamily: root.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: dpiLabel
                text: root.activeDpi + " DPI"
                color: Qt.darker(root.barForeground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            ButtonGroup {
              options: root.dpiOptions()
              value: String(root.activeDpi)
              foreground: root.barForeground
              background: root.barBackground
              accent: Color.accent
              fontFamily: root.fontFamily
              onChanged: function(val) { root.setDpi(val) }
            }
          }

          // ---------- Polling Rate ----------
          PanelSeparator {
            foreground: root.barForeground
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(rateHeader.implicitHeight, rateLabel.implicitHeight)

              PanelSectionHeader {
                id: rateHeader
                text: "POLLING RATE"
                foreground: root.barForeground
                fontFamily: root.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: rateLabel
                text: root.activeRate + " HZ"
                color: Qt.darker(root.barForeground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            ButtonGroup {
              options: root.rateOptions()
              value: String(root.activeRate)
              foreground: root.barForeground
              background: root.barBackground
              accent: Color.accent
              fontFamily: root.fontFamily
              onChanged: function(val) { root.setRate(val) }
            }
          }

          // ---------- Pointer Speed (Hyprland Sensitivity) ----------
          PanelSeparator {
            foreground: root.barForeground
          }

          Column {
            width: parent.width
            spacing: Style.space(8)

            Item {
              width: parent.width
              implicitHeight: Math.max(sensHeader.implicitHeight, sensLabel.implicitHeight)

              PanelSectionHeader {
                id: sensHeader
                text: "POINTER SPEED (HYPRLAND)"
                foreground: root.barForeground
                fontFamily: root.fontFamily
                anchors.left: parent.left
                anchors.verticalCenter: parent.verticalCenter
              }

              Text {
                id: sensLabel
                text: {
                  var v = sensSlider.dragging ? sensSlider.liveValue : root.hyprSensitivity
                  return (v >= 0 ? "+" : "") + v.toFixed(2)
                }
                color: Qt.darker(root.barForeground, 1.4)
                font.family: root.fontFamily
                font.pixelSize: Style.font.caption
                font.bold: true
                anchors.right: parent.right
                anchors.verticalCenter: parent.verticalCenter
              }
            }

            PanelSlider {
              id: sensSlider
              width: parent.width
              bar: root.bar
              minimum: -1.0
              maximum: 1.0
              step: 0.05
              value: root.hyprSensitivity
              onReleased: function(v) {
                root.setSensitivity(v)
              }
            }
          }

        }
      }
    }
  }
}
