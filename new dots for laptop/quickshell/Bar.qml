// Bar.qml
// ---------------------------------------------------------------------------
// A minimal floating bar: rounded pill, soft dark palette, one muted accent
// colour, and smooth easing on every hover/press/open. Same functionality as
// a typical Hyprland quickshell bar — workspace indicator, clock, a media
// popup and a control-centre popup — plus network / battery / cpu+ram status
// chips and a much deeper "Customize" popup — kept to a single file (plus
// shell.qml) so the whole look can be edited in one place.
//
// PALETTE — change these hex strings (find & replace) to re-theme everything
// that isn't already live-editable from the Customize popup (paint-swatch
// icon in the bar). Accent colour and background colour ARE live-editable
// and persisted; everything below is the fallback / component-internal
// palette. They're repeated inline rather than pulled from a shared object
// because QML's inline `component` blocks are compiled as independent units
// and can't see each other's ids — but they CAN see each other's *types*,
// which is what lets one small file replace the original five.
//
//   BG          #1e1e2e   bar + popup background   — live via Customize
//   SURFACE     #262838   hover surface
//   SURFACE2    #33344a   borders / dividers / toggle track (off)
//   ACCENT      #8aadf4   active / primary accent   — live via Customize
//   ACCENT_BG   #2b3555   muted accent fill (active pills, toggle on-track)
//   TEXT        #cad3f5   primary text
//   MUTED       #6e738d   secondary / caption text
//
// LIVE CUSTOMIZATION (paint-swatch icon → Customize popup):
//   accent & background colour, border on/off + colour + width, bar edge
//   (top/bottom), bar alignment (stretch/left/center/right), bar height,
//   corner radius, edge gap, fill opacity, 12h/24h clock, workspace style
//   (numbers/dots), auto-hide, and per-module visibility toggles.
//
// NEW STATUS MODULES (each independently toggleable, off by default only
// for CPU/RAM since it polls every 2s):
//   Network  — polls `nmcli` every 5s; click toggles the wifi radio.
//   Battery  — reads /sys/class/power_supply/BAT*; adjust the glob in
//              batteryProc's command if your battery isn't named BAT0/BAT1.
//   CPU/RAM  — reads /proc/stat + `free` every 2s.
// These shell out rather than depending on Quickshell service modules that
// may not be present on every system (e.g. UPower), so a missing tool just
// leaves that chip blank/hidden instead of breaking the whole bar.
//
// Want real glass/blur behind the bar? Give the compositor a blur rule for
// this window and lower "Opacity" in the Customize popup (it already drives
// the fill alpha via Qt.rgba — no manual colour edit needed anymore).
// ---------------------------------------------------------------------------

import Quickshell
import Quickshell.Io
import Quickshell.Hyprland
import Quickshell.Services.Pipewire
import Quickshell.Bluetooth
import Quickshell.Services.Mpris
import QtQuick
import QtQuick.Controls
import Qt.labs.settings

Scope {
    id: root

    // -----------------------------------------------------------------
    // user-customisable appearance & layout — edit live from the new
    // "Customize" popup (paint-swatch icon in the bar), persisted to
    // disk automatically via Settings below so it survives restarts.
    // -----------------------------------------------------------------
    property string accentColor: "#8aadf4"
    property string bgColor: "#1e1e2e"      // bar + popup background base
    property bool barBorderEnabled: true
    property string barBorderColor: "#33344a"
    property real barBorderWidth: 1
    property string barEdge: "top"          // "top" | "bottom"
    property string barPosition: "stretch"  // "stretch" | "left" | "center" | "right"
    property real floatingWidth: 480        // pill width when not "stretch"

    // extra appearance knobs
    property real barHeight: 46
    property real barRadius: 16
    property real barGap: 7                 // inset from the screen edges
    property real barOpacity: 1.0           // 0.4-1.0, fill alpha (pairs with a compositor blur rule)

    // behaviour knobs
    property bool clock24h: true
    property bool showSeconds: false
    property string workspaceStyle: "number" // "number" | "dot"
    property bool autoHideEnabled: false
    property real autoHideRevealPx: 6        // hover-trigger strip height when hidden

    // module visibility
    property bool showWorkspaces: true
    property bool showNixButton: true
    property bool showNetwork: true
    property bool showBattery: true
    property bool showCpuRam: false          // off by default — polling has a small cost

    // color-typed convenience mirrors, for inline (non-component) code below
    // that needs .r/.g/.b to build translucent fills.
    readonly property color accentColorObj: root.accentColor
    readonly property color bgColorObj: root.bgColor

    Settings {
        id: appearanceSettings
        category: "quickshellBarAppearance"
        property alias accentColor: root.accentColor
        property alias bgColor: root.bgColor
        property alias barBorderEnabled: root.barBorderEnabled
        property alias barBorderColor: root.barBorderColor
        property alias barBorderWidth: root.barBorderWidth
        property alias barEdge: root.barEdge
        property alias barPosition: root.barPosition
        property alias barHeight: root.barHeight
        property alias barRadius: root.barRadius
        property alias barGap: root.barGap
        property alias barOpacity: root.barOpacity
        property alias clock24h: root.clock24h
        property alias showSeconds: root.showSeconds
        property alias workspaceStyle: root.workspaceStyle
        property alias autoHideEnabled: root.autoHideEnabled
        property alias showWorkspaces: root.showWorkspaces
        property alias showNixButton: root.showNixButton
        property alias showNetwork: root.showNetwork
        property alias showBattery: root.showBattery
        property alias showCpuRam: root.showCpuRam
    }

    // -----------------------------------------------------------------
    // small reusable pieces (buttons, slider, toggle) used below
    // -----------------------------------------------------------------
    component IconButton: Item {
        id: btn
        property string icon: ""
        property bool active: false
        property real size: 30
        property color accent: "#8aadf4"
        signal clicked()
        signal wheelUp()
        signal wheelDown()

        implicitWidth: size
        implicitHeight: size

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: btn.active ? Qt.rgba(btn.accent.r, btn.accent.g, btn.accent.b, 0.25) : (mouse.containsMouse ? "#262838" : "transparent")
            Behavior on color { ColorAnimation { duration: 150; easing.type: Easing.OutQuad } }
        }

        Text {
            anchors.centerIn: parent
            text: btn.icon
            font.pixelSize: Math.round(btn.size * 0.42)
            color: btn.active ? btn.accent : "#cad3f5"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: btn.clicked()
            onWheel: wheel => {
                if (wheel.angleDelta.y > 0) btn.wheelUp();
                else if (wheel.angleDelta.y < 0) btn.wheelDown();
            }
        }

        scale: mouse.pressed ? 0.85 : (mouse.containsMouse ? 1.1 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
    }

    // Rounded text pill — used for the mute/unmute readout.
    component Chip: Item {
        id: chip
        property string text: ""
        property bool active: false
        property color accent: "#8aadf4"
        signal clicked()

        implicitWidth: label.implicitWidth + 20
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: chip.active ? Qt.rgba(chip.accent.r, chip.accent.g, chip.accent.b, 0.25) : (mouse.containsMouse ? "#262838" : "transparent")
            border.color: chip.active ? chip.accent : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        Text {
            id: label
            anchors.centerIn: parent
            text: chip.text
            font.pixelSize: 12
            color: chip.active ? chip.accent : "#cad3f5"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: chip.clicked()
        }

        scale: mouse.pressed ? 0.9 : (mouse.containsMouse ? 1.05 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    }

    // iOS-style sliding switch — bluetooth power.
    component PillToggle: Item {
        id: toggle
        property bool checked: false
        property color accent: "#8aadf4"
        signal clicked()

        implicitWidth: 40
        implicitHeight: 22

        Rectangle {
            anchors.fill: parent
            radius: height / 2
            color: toggle.checked ? toggle.accent : "#33344a"
            Behavior on color { ColorAnimation { duration: 160 } }
        }

        Rectangle {
            width: 16; height: 16; radius: 8
            color: "#1e1e2e"
            anchors.verticalCenter: parent.verticalCenter
            x: toggle.checked ? parent.width - width - 3 : 3
            Behavior on x { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 1.6 } }
        }

        MouseArea {
            id: toggleMouse
            anchors.fill: parent
            cursorShape: Qt.PointingHandCursor
            onClicked: toggle.clicked()
        }

        scale: toggleMouse.pressed ? 0.92 : 1.0
        Behavior on scale { NumberAnimation { duration: 120; easing.type: Easing.OutBack; easing.overshoot: 2 } }
    }

    // Draggable rounded slider — volume + media seek bar.
    component MinimalSlider: Item {
        id: slider
        property real value: 0        // 0..1
        property bool interactive: true
        property color accent: "#8aadf4"
        signal moved(real frac)

        implicitHeight: 18

        Rectangle {
            id: track
            anchors.verticalCenter: parent.verticalCenter
            width: parent.width
            height: 6
            radius: 3
            color: "#33344a"

            Rectangle {
                height: parent.height
                radius: 3
                color: slider.accent
                width: Math.max(6, parent.width * Math.max(0, Math.min(1, slider.value)))
                Behavior on width { NumberAnimation { duration: 120; easing.type: Easing.OutQuad } }
                Behavior on color { ColorAnimation { duration: 150 } }
            }

            Rectangle {
                width: mouseArea.pressed ? 14 : 10
                height: width
                radius: width / 2
                color: "#cad3f5"
                anchors.verticalCenter: parent.verticalCenter
                x: Math.max(0, Math.min(track.width, track.width * slider.value)) - width / 2
                Behavior on width { NumberAnimation { duration: 100; easing.type: Easing.OutQuad } }
            }
        }

        MouseArea {
            id: mouseArea
            anchors.fill: parent
            enabled: slider.interactive
            cursorShape: Qt.PointingHandCursor
            function apply(mx) { slider.moved(Math.max(0, Math.min(1, mx / width))); }
            onPressed: mouse => apply(mouse.x)
            onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
        }
    }

    // Plain text tile — quick-action grid entries. No icon glyphs, so nothing
    // depends on an emoji/nerd font being installed.
    component ActionTile: Item {
        id: tile
        property string caption: ""
        property bool active: false
        property color accent: "#8aadf4"
        signal clicked()

        implicitWidth: 84
        implicitHeight: 44

        Rectangle {
            anchors.fill: parent
            radius: 12
            color: tile.active ? Qt.rgba(tile.accent.r, tile.accent.g, tile.accent.b, 0.25) : (mouse.containsMouse ? "#33344a" : "#262838")
            border.color: tile.active ? tile.accent : "transparent"
            border.width: 1
            Behavior on color { ColorAnimation { duration: 150 } }
            Behavior on border.color { ColorAnimation { duration: 150 } }
        }

        Text {
            anchors.centerIn: parent
            text: tile.caption
            font.pixelSize: 11
            color: tile.active ? tile.accent : "#cad3f5"
            Behavior on color { ColorAnimation { duration: 150 } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: tile.clicked()
        }

        scale: mouse.pressed ? 0.92 : (mouse.containsMouse ? 1.04 : 1.0)
        Behavior on scale { NumberAnimation { duration: 130; easing.type: Easing.OutBack; easing.overshoot: 2.2 } }
    }

    // Small round colour swatch — used in the customisation menu for
    // picking accent / border colours.
    component ColorSwatch: Item {
        id: swatch
        property color swatchColor: "#8aadf4"
        property bool selected: false
        signal clicked()

        implicitWidth: 26
        implicitHeight: 26

        Rectangle {
            anchors.fill: parent
            radius: width / 2
            color: swatch.swatchColor
            border.color: swatch.selected ? "#cad3f5" : "transparent"
            border.width: 2
            Behavior on border.color { ColorAnimation { duration: 120 } }
        }

        MouseArea {
            id: mouse
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: swatch.clicked()
        }

        scale: mouse.pressed ? 0.8 : (swatch.selected ? 1.15 : (mouse.containsMouse ? 1.1 : 1.0))
        Behavior on scale { NumberAnimation { duration: 160; easing.type: Easing.OutBack; easing.overshoot: 2.6 } }
    }

    // ---------------------------------------------------------------------------
    // popups
    // ---------------------------------------------------------------------------

    component ControlCenterPopup: PopupWindow {
        id: popup
        property var anchorWindow
        property string edge: "top"
        property color accent: "#8aadf4"
        property color bg: "#1e1e2e"
        property bool borderEnabled: true
        property color borderColor: "#33344a"
        property real borderWidth: 1

        implicitWidth: 300
        implicitHeight: content.implicitHeight + 32
        color: "transparent"
        visible: false

        anchor.window: anchorWindow
        anchor.rect.x: anchorWindow ? anchorWindow.shellRight - implicitWidth - 8 : 0
        anchor.rect.y: anchorWindow ? (popup.edge === "top" ? anchorWindow.shellBottom + 4 : anchorWindow.shellTop - implicitHeight - 4) : 0

        readonly property var sink: Pipewire.defaultAudioSink
        PwObjectTracker { objects: [popup.sink] }

        // "caffeine" — keeps the system from idling/sleeping while enabled,
        // by holding a systemd inhibitor lock open for as long as this runs.
        property bool caffeineOn: false
        Process {
            command: ["systemd-inhibit", "--what=idle:sleep", "--who=quickshell", "--why=caffeine mode", "sleep", "infinity"]
            running: popup.caffeineOn
        }

        function setVolume(v) {
            if (popup.sink && popup.sink.ready && popup.sink.audio) {
                popup.sink.audio.muted = false;
                popup.sink.audio.volume = Math.max(0, Math.min(1, v));
            }
        }
        function toggleMute() {
            if (popup.sink && popup.sink.audio) popup.sink.audio.muted = !popup.sink.audio.muted;
        }

        // Pop-open / pop-close — a bit of overshoot and a tiny rotational
        // "kick" makes the menu feel snappy rather than just fading in.
        function openPopup() {
            closeAnim.stop();
            visible = true;
            card.opacity = 0;
            card.scale = 0.88;
            card.rotation = popup.edge === "top" ? -3 : 3;
            openAnim.restart();
        }
        function closePopup() { closeAnim.restart(); }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            NumberAnimation { target: card; property: "rotation"; to: 0; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: card; property: "scale"; to: 0.9; duration: 130; easing.type: Easing.InQuad }
            onFinished: popup.visible = false
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 18
            color: popup.bg
            border.color: popup.borderEnabled ? popup.borderColor : "transparent"
            border.width: popup.borderEnabled ? popup.borderWidth : 0
            transformOrigin: popup.edge === "top" ? Item.Top : Item.Bottom
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on border.width { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                color: "#33344a"
                opacity: 0.6
                visible: popup.edge === "top"
            }

            Column {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 16

                Text { text: "Control Center"; color: "#cad3f5"; font.pixelSize: 14; font.bold: true }

                // ---------------- volume ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        width: parent.width
                        spacing: 10

                        Chip {
                            accent: popup.accent
                            text: (popup.sink && popup.sink.audio && popup.sink.audio.muted) ? "Unmute" : "Mute"
                            active: popup.sink && popup.sink.audio && popup.sink.audio.muted
                            onClicked: popup.toggleMute()
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Volume"
                            color: "#6e738d"
                            font.pixelSize: 11
                        }
                        Item { width: parent.width - 190; height: 1 }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: (popup.sink && popup.sink.audio) ? Math.round(popup.sink.audio.volume * 100) + "%" : "--"
                            color: "#cad3f5"
                            font.pixelSize: 11
                        }
                    }

                    MinimalSlider {
                        width: parent.width
                        accent: popup.accent
                        value: (popup.sink && popup.sink.audio) ? popup.sink.audio.volume : 0
                        onMoved: frac => popup.setVolume(frac)
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- bluetooth ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        width: parent.width
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Bluetooth"
                            color: "#6e738d"
                            font.pixelSize: 11
                        }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle {
                            accent: popup.accent
                            checked: Bluetooth.defaultAdapter ? Bluetooth.defaultAdapter.enabled : false
                            onClicked: if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !Bluetooth.defaultAdapter.enabled
                        }
                    }

                    Repeater {
                        model: Bluetooth.devices
                        delegate: Row {
                            width: content.width
                            spacing: 8

                            Text {
                                width: parent.width - 90
                                anchors.verticalCenter: parent.verticalCenter
                                elide: Text.ElideRight
                                text: modelData.name
                                color: "#cad3f5"
                                opacity: modelData.connected ? 1 : 0.55
                                font.pixelSize: 12
                            }

                            Rectangle {
                                width: 78; height: 24; radius: 12
                                color: modelData.connected ? Qt.rgba(popup.accent.r, popup.accent.g, popup.accent.b, 0.25) : "#33344a"
                                border.color: modelData.connected ? popup.accent : "transparent"
                                border.width: 1
                                Behavior on color { ColorAnimation { duration: 150 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: modelData.connected ? "Disconnect" : "Connect"
                                    font.pixelSize: 10
                                    color: modelData.connected ? popup.accent : "#cad3f5"
                                }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: modelData.connected ? modelData.disconnect() : modelData.connect()
                                }
                            }
                        }
                    }

                    Text {
                        visible: Bluetooth.devices.count === 0
                        text: "No devices found"
                        color: "#6e738d"
                        font.pixelSize: 11
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- quick actions ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Text { text: "Quick Actions"; color: "#6e738d"; font.pixelSize: 11 }

                    Grid {
                        columns: 3
                        columnSpacing: 8
                        rowSpacing: 8

                        ActionTile { accent: popup.accent; caption: "Lock"; onClicked: Quickshell.execDetached(["sh", "-c", "hyprlock || swaylock"]) }
                        ActionTile {
                            accent: popup.accent
                            caption: "Screenshot"
                            onClicked: Quickshell.execDetached({
                                command: ["sh", "-c", "mkdir -p ~/Pictures && grim -g \"$(slurp)\" ~/Pictures/shot_$(date +%s).png"]
                            })
                        }
                        ActionTile { accent: popup.accent; caption: "Reload"; onClicked: Quickshell.reload(true) }
                        ActionTile { accent: popup.accent; caption: "Audio App"; onClicked: Quickshell.execDetached(["pavucontrol"]) }
                        ActionTile { accent: popup.accent; caption: "BT App"; onClicked: Quickshell.execDetached(["blueman-manager"]) }
                        ActionTile {
                            accent: popup.accent
                            caption: popup.caffeineOn ? "Caffeine: On" : "Caffeine"
                            active: popup.caffeineOn
                            onClicked: popup.caffeineOn = !popup.caffeineOn
                        }
                        ActionTile {
                            accent: popup.accent
                            caption: "Edit Config"
                            onClicked: Quickshell.execDetached(["sh", "-c",
                                "$TERMINAL -e sudo vim /etc/nixos/configuration.nix || kitty -e sudo vim /etc/nixos/configuration.nix || alacritty -e sudo vim /etc/nixos/configuration.nix || foot -e sudo vim /etc/nixos/configuration.nix || xterm -e sudo vim /etc/nixos/configuration.nix"])
                        }
                    }
                }
            }
        }
    }

    component MediaMenuPopup: PopupWindow {
        id: popup
        property var anchorWindow
        property string edge: "top"
        property color accent: "#8aadf4"
        property color bg: "#1e1e2e"
        property bool borderEnabled: true
        property color borderColor: "#33344a"
        property real borderWidth: 1

        implicitWidth: 280
        implicitHeight: content.implicitHeight + 32
        color: "transparent"
        visible: false

        anchor.window: anchorWindow
        anchor.rect.x: anchorWindow ? anchorWindow.shellRight - implicitWidth - 8 : 0
        anchor.rect.y: anchorWindow ? (popup.edge === "top" ? anchorWindow.shellBottom + 4 : anchorWindow.shellTop - implicitHeight - 4) : 0

        readonly property var player: {
            const list = Mpris.players ? Mpris.players.values : [];
            for (let i = 0; i < list.length; i++) {
                if (list[i].playbackState === MprisPlaybackState.Playing) return list[i];
            }
            return list.length > 0 ? list[0] : null;
        }
        readonly property bool hasPlayer: popup.player !== null
        readonly property real lengthSafe: (hasPlayer && popup.player.length > 0) ? popup.player.length : 1
        property real displayPosition: hasPlayer ? popup.player.position : 0

        Timer {
            interval: 1000
            repeat: true
            running: popup.visible && popup.hasPlayer && popup.player.playbackState === MprisPlaybackState.Playing
            onTriggered: popup.displayPosition = popup.player.position
        }

        function fmt(seconds) {
            if (!seconds || seconds <= 0) return "0:00";
            const m = Math.floor(seconds / 60);
            const s = Math.floor(seconds % 60);
            return m + ":" + (s < 10 ? "0" : "") + s;
        }

        function openPopup() {
            closeAnim.stop();
            if (hasPlayer) displayPosition = popup.player.position;
            visible = true;
            card.opacity = 0;
            card.scale = 0.88;
            card.rotation = popup.edge === "top" ? -3 : 3;
            openAnim.restart();
        }
        function closePopup() { closeAnim.restart(); }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            NumberAnimation { target: card; property: "rotation"; to: 0; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: card; property: "scale"; to: 0.9; duration: 130; easing.type: Easing.InQuad }
            onFinished: popup.visible = false
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 18
            color: popup.bg
            border.color: popup.borderEnabled ? popup.borderColor : "transparent"
            border.width: popup.borderEnabled ? popup.borderWidth : 0
            transformOrigin: popup.edge === "top" ? Item.Top : Item.Bottom
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on border.width { NumberAnimation { duration: 150 } }

            Column {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text { text: "Now Playing"; color: "#cad3f5"; font.pixelSize: 14; font.bold: true }

                Rectangle {
                    width: parent.width
                    height: width
                    radius: 14
                    color: "#262838"
                    clip: true

                    Image {
                        anchors.fill: parent
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        source: (popup.hasPlayer && popup.player.trackArtUrl) ? popup.player.trackArtUrl : ""
                        visible: source !== ""
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !popup.hasPlayer || !popup.player.trackArtUrl
                        text: popup.hasPlayer ? "♪" : "Nothing playing"
                        color: "#6e738d"
                        font.pixelSize: popup.hasPlayer ? 30 : 12
                    }
                }

                Column {
                    width: parent.width
                    spacing: 2

                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (popup.hasPlayer && popup.player.trackTitle) ? popup.player.trackTitle : "—"
                        color: "#cad3f5"
                        font.pixelSize: 13
                        font.bold: true
                    }
                    Text {
                        width: parent.width
                        elide: Text.ElideRight
                        text: (popup.hasPlayer && popup.player.trackArtist) ? popup.player.trackArtist : ""
                        color: "#6e738d"
                        font.pixelSize: 11
                    }
                }

                Column {
                    width: parent.width
                    spacing: 4

                    MinimalSlider {
                        width: parent.width
                        accent: popup.accent
                        interactive: popup.hasPlayer && popup.player.canSeek
                        value: Math.max(0, Math.min(1, popup.displayPosition / popup.lengthSafe))
                        onMoved: frac => {
                            if (popup.hasPlayer && popup.player.canSeek) {
                                popup.player.position = frac * popup.lengthSafe;
                                popup.displayPosition = popup.player.position;
                            }
                        }
                    }
                    Row {
                        width: parent.width
                        Text { text: popup.fmt(popup.displayPosition); color: "#6e738d"; font.pixelSize: 10 }
                        Item { width: parent.width - 70; height: 1 }
                        Text { text: popup.fmt(popup.hasPlayer ? popup.player.length : 0); color: "#6e738d"; font.pixelSize: 10 }
                    }
                }

                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: 18

                    IconButton {
                        accent: popup.accent
                        icon: "⏮"
                        size: 30
                        onClicked: { if (popup.hasPlayer && popup.player.canGoPrevious) popup.player.previous(); }
                    }
                    IconButton {
                        accent: popup.accent
                        icon: (popup.hasPlayer && popup.player.playbackState === MprisPlaybackState.Playing) ? "⏸" : "▶"
                        size: 40
                        active: true
                        onClicked: {
                            if (!popup.hasPlayer) return;
                            if (popup.player.playbackState === MprisPlaybackState.Playing) popup.player.pause();
                            else popup.player.play();
                        }
                    }
                    IconButton {
                        accent: popup.accent
                        icon: "⏭"
                        size: 30
                        onClicked: { if (popup.hasPlayer && popup.player.canGoNext) popup.player.next(); }
                    }
                }
            }
        }
    }

    // Small compact popup with session/power actions.
    component PowerMenuPopup: PopupWindow {
        id: popup
        property var anchorWindow
        property string edge: "top"
        property color accent: "#8aadf4"
        property color bg: "#1e1e2e"
        property bool borderEnabled: true
        property color borderColor: "#33344a"
        property real borderWidth: 1

        implicitWidth: 220
        implicitHeight: content.implicitHeight + 32
        color: "transparent"
        visible: false

        anchor.window: anchorWindow
        anchor.rect.x: anchorWindow ? anchorWindow.shellRight - implicitWidth - 8 : 0
        anchor.rect.y: anchorWindow ? (popup.edge === "top" ? anchorWindow.shellBottom + 4 : anchorWindow.shellTop - implicitHeight - 4) : 0

        function openPopup() {
            closeAnim.stop();
            visible = true;
            card.opacity = 0;
            card.scale = 0.88;
            card.rotation = popup.edge === "top" ? -3 : 3;
            openAnim.restart();
        }
        function closePopup() { closeAnim.restart(); }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            NumberAnimation { target: card; property: "rotation"; to: 0; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: card; property: "scale"; to: 0.9; duration: 130; easing.type: Easing.InQuad }
            onFinished: popup.visible = false
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 18
            color: popup.bg
            border.color: popup.borderEnabled ? popup.borderColor : "transparent"
            border.width: popup.borderEnabled ? popup.borderWidth : 0
            transformOrigin: popup.edge === "top" ? Item.Top : Item.Bottom
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on border.width { NumberAnimation { duration: 150 } }

            Column {
                id: content
                anchors.fill: parent
                anchors.margins: 16
                spacing: 12

                Text { text: "Power"; color: "#cad3f5"; font.pixelSize: 14; font.bold: true }

                Grid {
                    columns: 2
                    columnSpacing: 8
                    rowSpacing: 8

                    ActionTile { accent: popup.accent; caption: "Lock"; onClicked: Quickshell.execDetached(["sh", "-c", "hyprlock || swaylock"]) }
                    ActionTile { accent: popup.accent; caption: "Log Out"; onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "exit"]) }
                    ActionTile { accent: popup.accent; caption: "Suspend"; onClicked: Quickshell.execDetached(["systemctl", "suspend"]) }
                    ActionTile { accent: popup.accent; caption: "Reboot"; onClicked: Quickshell.execDetached(["systemctl", "reboot"]) }
                    ActionTile { accent: popup.accent; caption: "Shut Down"; onClicked: Quickshell.execDetached(["systemctl", "poweroff"]) }
                }
            }
        }
    }

    // Appearance & layout customisation — accent colour, optional border,
    // and where the bar sits on screen. All changes apply live and persist
    // (via the Settings block at the top of this file) across restarts.
    component CustomizePopup: PopupWindow {
        id: popup
        property var anchorWindow
        property string edge: "top"

        property string accent: "#8aadf4"
        property string bg: "#1e1e2e"
        property bool borderEnabled: true
        property string borderColor: "#33344a"
        property real borderWidth: 1
        property string barEdge: "top"
        property string barPosition: "stretch"

        property real barHeight: 46
        property real barRadius: 16
        property real barGap: 7
        property real barOpacity: 1.0
        property bool clock24h: true
        property bool showSeconds: false
        property string workspaceStyle: "number"
        property bool autoHideEnabled: false
        property bool showWorkspaces: true
        property bool showNixButton: true
        property bool showNetwork: true
        property bool showBattery: true
        property bool showCpuRam: false

        signal accentPicked(string c)
        signal bgPicked(string c)
        signal borderTogglePicked(bool v)
        signal borderColorPicked(string c)
        signal borderWidthPicked(real w)
        signal edgePicked(string e)
        signal positionPicked(string p)
        signal barHeightPicked(real h)
        signal barRadiusPicked(real r)
        signal barGapPicked(real g)
        signal barOpacityPicked(real o)
        signal clock24hPicked(bool v)
        signal showSecondsPicked(bool v)
        signal workspaceStylePicked(string s)
        signal autoHidePicked(bool v)
        // generic on/off switch for the simple module-visibility toggles,
        // keyed by the root property name they control
        signal modulePicked(string key, bool value)

        // capped height — once the sections below add up to more than this,
        // the card scrolls instead of the popup just growing to fit them all
        property real maxContentHeight: 360

        implicitWidth: 300
        implicitHeight: Math.min(content.implicitHeight + 32, maxContentHeight)
        color: "transparent"
        visible: false

        anchor.window: anchorWindow
        anchor.rect.x: anchorWindow ? anchorWindow.shellRight - implicitWidth - 8 : 0
        anchor.rect.y: anchorWindow ? (popup.edge === "top" ? anchorWindow.shellBottom + 4 : anchorWindow.shellTop - implicitHeight - 4) : 0

        function openPopup() {
            closeAnim.stop();
            visible = true;
            card.opacity = 0;
            card.scale = 0.88;
            card.rotation = popup.edge === "top" ? -3 : 3;
            openAnim.restart();
        }
        function closePopup() { closeAnim.restart(); }

        ParallelAnimation {
            id: openAnim
            NumberAnimation { target: card; property: "opacity"; to: 1; duration: 150; easing.type: Easing.OutQuad }
            NumberAnimation { target: card; property: "scale"; to: 1; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 1.8 }
            NumberAnimation { target: card; property: "rotation"; to: 0; duration: 230; easing.type: Easing.OutBack; easing.overshoot: 2 }
        }
        ParallelAnimation {
            id: closeAnim
            NumberAnimation { target: card; property: "opacity"; to: 0; duration: 120; easing.type: Easing.InQuad }
            NumberAnimation { target: card; property: "scale"; to: 0.9; duration: 130; easing.type: Easing.InQuad }
            onFinished: popup.visible = false
        }

        Rectangle {
            id: card
            anchors.fill: parent
            radius: 18
            color: popup.bg
            border.color: popup.borderEnabled ? popup.borderColor : "transparent"
            border.width: popup.borderEnabled ? popup.borderWidth : 0
            transformOrigin: popup.edge === "top" ? Item.Top : Item.Bottom
            Behavior on border.color { ColorAnimation { duration: 150 } }
            Behavior on border.width { NumberAnimation { duration: 150 } }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.right: parent.right
                anchors.margins: 1
                height: 1
                color: "#33344a"
                opacity: 0.6
                visible: popup.edge === "top"
            }

            ScrollView {
                id: scrollArea
                anchors.fill: parent
                anchors.margins: 16
                clip: true
                contentWidth: availableWidth
                ScrollBar.horizontal.policy: ScrollBar.AlwaysOff
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                Column {
                    id: content
                    width: scrollArea.availableWidth
                    spacing: 16

                    Text { text: "Customize"; color: "#cad3f5"; font.pixelSize: 14; font.bold: true }

                // ---------------- accent colour ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Text { text: "Accent Colour"; color: "#6e738d"; font.pixelSize: 11 }

                    Grid {
                        columns: 8
                        columnSpacing: 8
                        rowSpacing: 8
                        Repeater {
                            model: ["#8aadf4", "#a6da95", "#ed8796", "#eed49f", "#c6a0f6", "#8bd5ca", "#f5a97f", "#f5bde6"]
                            delegate: ColorSwatch {
                                swatchColor: modelData
                                selected: popup.accent.toLowerCase() === modelData.toLowerCase()
                                onClicked: popup.accentPicked(modelData)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 24; height: 24; radius: 6
                            color: popup.accent
                            border.color: "#33344a"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Rectangle {
                            width: parent.width - 32
                            height: 26
                            radius: 8
                            color: "#262838"
                            border.color: hexInput.activeFocus ? popup.accent : "#33344a"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            TextInput {
                                id: hexInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#cad3f5"
                                font.pixelSize: 11
                                text: popup.accent
                                selectByMouse: true
                                onAccepted: {
                                    if (/^#[0-9a-fA-F]{6}$/.test(text)) popup.accentPicked(text);
                                }
                                // typing breaks the declarative "text: popup.accent"
                                // binding above, so re-sync explicitly whenever the
                                // accent changes elsewhere (e.g. a swatch click)
                                Connections {
                                    target: popup
                                    function onAccentChanged() { hexInput.text = popup.accent; }
                                }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- background colour ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Text { text: "Background Colour"; color: "#6e738d"; font.pixelSize: 11 }

                    Grid {
                        columns: 8
                        columnSpacing: 8
                        rowSpacing: 8
                        Repeater {
                            model: ["#1e1e2e", "#24273a", "#181825", "#11111b", "#0d1117", "#232634", "#292c3c", "#1a1b26"]
                            delegate: ColorSwatch {
                                swatchColor: modelData
                                selected: popup.bg.toLowerCase() === modelData.toLowerCase()
                                onClicked: popup.bgPicked(modelData)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 8

                        Rectangle {
                            width: 24; height: 24; radius: 6
                            color: popup.bg
                            border.color: "#33344a"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on color { ColorAnimation { duration: 150 } }
                        }

                        Rectangle {
                            width: parent.width - 32
                            height: 26
                            radius: 8
                            color: "#262838"
                            border.color: bgHexInput.activeFocus ? popup.accent : "#33344a"
                            border.width: 1
                            anchors.verticalCenter: parent.verticalCenter
                            Behavior on border.color { ColorAnimation { duration: 150 } }

                            TextInput {
                                id: bgHexInput
                                anchors.fill: parent
                                anchors.leftMargin: 8
                                anchors.rightMargin: 8
                                verticalAlignment: TextInput.AlignVCenter
                                color: "#cad3f5"
                                font.pixelSize: 11
                                text: popup.bg
                                selectByMouse: true
                                onAccepted: {
                                    if (/^#[0-9a-fA-F]{6}$/.test(text)) popup.bgPicked(text);
                                }
                                Connections {
                                    target: popup
                                    function onBgChanged() { bgHexInput.text = popup.bg; }
                                }
                            }
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- shape & opacity ----------------
                Column {
                    width: parent.width
                    spacing: 10

                    Text { text: "Shape & Opacity"; color: "#6e738d"; font.pixelSize: 11 }

                    Row {
                        width: parent.width
                        spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Height"; color: "#6e738d"; font.pixelSize: 11; width: 50 }
                        MinimalSlider {
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                            accent: popup.accent
                            value: (popup.barHeight - 34) / (64 - 34)
                            onMoved: frac => popup.barHeightPicked(Math.round(34 + frac * (64 - 34)))
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(popup.barHeight) + "px"; color: "#cad3f5"; font.pixelSize: 10 }
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Radius"; color: "#6e738d"; font.pixelSize: 11; width: 50 }
                        MinimalSlider {
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                            accent: popup.accent
                            value: popup.barRadius / 24
                            onMoved: frac => popup.barRadiusPicked(Math.round(frac * 24))
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(popup.barRadius) + "px"; color: "#cad3f5"; font.pixelSize: 10 }
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Gap"; color: "#6e738d"; font.pixelSize: 11; width: 50 }
                        MinimalSlider {
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                            accent: popup.accent
                            value: popup.barGap / 20
                            onMoved: frac => popup.barGapPicked(Math.round(frac * 20))
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(popup.barGap) + "px"; color: "#cad3f5"; font.pixelSize: 10 }
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Opacity"; color: "#6e738d"; font.pixelSize: 11; width: 50 }
                        MinimalSlider {
                            width: parent.width - 140
                            anchors.verticalCenter: parent.verticalCenter
                            accent: popup.accent
                            value: (popup.barOpacity - 0.4) / 0.6
                            onMoved: frac => popup.barOpacityPicked(Math.round((0.4 + frac * 0.6) * 100) / 100)
                        }
                        Text { anchors.verticalCenter: parent.verticalCenter; text: Math.round(popup.barOpacity * 100) + "%"; color: "#cad3f5"; font.pixelSize: 10 }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- clock & workspaces ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "24-hour Clock"; color: "#6e738d"; font.pixelSize: 11 }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle { accent: popup.accent; checked: popup.clock24h; onClicked: popup.clock24hPicked(!popup.clock24h) }
                    }

                    Text { text: "Workspace Style"; color: "#6e738d"; font.pixelSize: 11 }
                    Row {
                        spacing: 8
                        Chip { accent: popup.accent; text: "Numbers"; active: popup.workspaceStyle === "number"; onClicked: popup.workspaceStylePicked("number") }
                        Chip { accent: popup.accent; text: "Dots"; active: popup.workspaceStyle === "dot"; onClicked: popup.workspaceStylePicked("dot") }
                    }

                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Auto-hide Bar"; color: "#6e738d"; font.pixelSize: 11 }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle { accent: popup.accent; checked: popup.autoHideEnabled; onClicked: popup.autoHidePicked(!popup.autoHideEnabled) }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- modules ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Text { text: "Modules"; color: "#6e738d"; font.pixelSize: 11 }

                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Workspaces"; color: "#cad3f5"; font.pixelSize: 12 }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle { accent: popup.accent; checked: popup.showWorkspaces; onClicked: popup.modulePicked("showWorkspaces", !popup.showWorkspaces) }
                    }
                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "NixOS Button"; color: "#cad3f5"; font.pixelSize: 12 }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle { accent: popup.accent; checked: popup.showNixButton; onClicked: popup.modulePicked("showNixButton", !popup.showNixButton) }
                    }
                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Network"; color: "#cad3f5"; font.pixelSize: 12 }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle { accent: popup.accent; checked: popup.showNetwork; onClicked: popup.modulePicked("showNetwork", !popup.showNetwork) }
                    }
                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "Battery"; color: "#cad3f5"; font.pixelSize: 12 }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle { accent: popup.accent; checked: popup.showBattery; onClicked: popup.modulePicked("showBattery", !popup.showBattery) }
                    }
                    Row {
                        width: parent.width
                        Text { anchors.verticalCenter: parent.verticalCenter; text: "CPU / RAM"; color: "#cad3f5"; font.pixelSize: 12 }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle { accent: popup.accent; checked: popup.showCpuRam; onClicked: popup.modulePicked("showCpuRam", !popup.showCpuRam) }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- border ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Row {
                        width: parent.width
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Border"
                            color: "#6e738d"
                            font.pixelSize: 11
                        }
                        Item { width: parent.width - 150; height: 1 }
                        PillToggle {
                            accent: popup.accent
                            checked: popup.borderEnabled
                            onClicked: popup.borderTogglePicked(!popup.borderEnabled)
                        }
                    }

                    Grid {
                        columns: 8
                        columnSpacing: 8
                        rowSpacing: 8
                        opacity: popup.borderEnabled ? 1 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Repeater {
                            model: ["#33344a", "#6e738d", "#cad3f5", "#8aadf4", "#a6da95", "#ed8796", "#eed49f", "#c6a0f6"]
                            delegate: ColorSwatch {
                                swatchColor: modelData
                                selected: popup.borderColor.toLowerCase() === modelData.toLowerCase()
                                onClicked: if (popup.borderEnabled) popup.borderColorPicked(modelData)
                            }
                        }
                    }

                    Row {
                        width: parent.width
                        spacing: 10
                        opacity: popup.borderEnabled ? 1 : 0.35
                        Behavior on opacity { NumberAnimation { duration: 150 } }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: "Width"
                            color: "#6e738d"
                            font.pixelSize: 11
                        }
                        MinimalSlider {
                            width: parent.width - 90
                            anchors.verticalCenter: parent.verticalCenter
                            accent: popup.accent
                            interactive: popup.borderEnabled
                            value: Math.max(0, Math.min(1, popup.borderWidth / 4))
                            onMoved: frac => popup.borderWidthPicked(Math.round(frac * 4 * 2) / 2)
                        }
                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            text: popup.borderWidth.toFixed(1) + "px"
                            color: "#cad3f5"
                            font.pixelSize: 10
                        }
                    }
                }

                Rectangle { width: parent.width; height: 1; color: "#33344a" }

                // ---------------- position on screen ----------------
                Column {
                    width: parent.width
                    spacing: 8

                    Text { text: "Screen Edge"; color: "#6e738d"; font.pixelSize: 11 }
                    Row {
                        spacing: 8
                        Chip { accent: popup.accent; text: "Top"; active: popup.barEdge === "top"; onClicked: popup.edgePicked("top") }
                        Chip { accent: popup.accent; text: "Bottom"; active: popup.barEdge === "bottom"; onClicked: popup.edgePicked("bottom") }
                    }

                    Text { text: "Alignment"; color: "#6e738d"; font.pixelSize: 11 }
                    Row {
                        spacing: 8
                        Chip { accent: popup.accent; text: "Stretch"; active: popup.barPosition === "stretch"; onClicked: popup.positionPicked("stretch") }
                        Chip { accent: popup.accent; text: "Left"; active: popup.barPosition === "left"; onClicked: popup.positionPicked("left") }
                        Chip { accent: popup.accent; text: "Center"; active: popup.barPosition === "center"; onClicked: popup.positionPicked("center") }
                        Chip { accent: popup.accent; text: "Right"; active: popup.barPosition === "right"; onClicked: popup.positionPicked("right") }
                    }
                }
            }
            }
        }
    }

    // -----------------------------------------------------------------
    // the bar itself
    // -----------------------------------------------------------------

    property string time: ""
    property bool showFullDate: false

    // Tracked at the top level (not just inside the control-centre popup) so
    // the scroll-to-adjust-volume feature on the bar itself works even when
    // that popup has never been opened.
    readonly property var audioSink: Pipewire.defaultAudioSink
    PwObjectTracker { objects: [root.audioSink] }
    function bumpVolume(delta) {
        if (root.audioSink && root.audioSink.ready && root.audioSink.audio) {
            root.audioSink.audio.muted = false;
            root.audioSink.audio.volume = Math.max(0, Math.min(1, root.audioSink.audio.volume + delta));
        }
    }

    // -----------------------------------------------------------------
    // lightweight status modules — network / battery / cpu+ram.
    // These shell out on a slow timer rather than depending on service
    // modules that may not be present on every system, so they degrade
    // gracefully (blank text) instead of failing the whole bar.
    // -----------------------------------------------------------------

    // ---- network (nmcli) ----
    property string networkSSID: ""
    property bool networkConnected: false
    property bool wifiEnabled: true

    Process {
        id: networkProc
        // "yes:SSID" for the active wifi connection, or "" if offline/wired only
        command: ["sh", "-c", "nmcli -t -f active,ssid dev wifi 2>/dev/null | grep '^yes' | head -n1; nmcli radio wifi 2>/dev/null"]
        running: false
        stdout: SplitParser {
            onRead: data => {
                if (data.startsWith("yes:")) {
                    root.networkSSID = data.slice(4);
                    root.networkConnected = true;
                } else if (data === "enabled" || data === "disabled") {
                    root.wifiEnabled = data === "enabled";
                    if (!root.wifiEnabled) { root.networkConnected = false; root.networkSSID = ""; }
                } else if (data.length === 0) {
                    root.networkConnected = false;
                    root.networkSSID = "";
                }
            }
        }
    }
    function toggleWifi() {
        Quickshell.execDetached(["sh", "-c", root.wifiEnabled ? "nmcli radio wifi off" : "nmcli radio wifi on"]);
    }

    // ---- battery (sysfs — adjust BAT0 below if your battery is named differently) ----
    property bool batteryPresent: false
    property int batteryPercent: 0
    property bool batteryCharging: false

    Process {
        id: batteryProc
        command: ["sh", "-c", "cat /sys/class/power_supply/BAT*/capacity 2>/dev/null | head -n1; cat /sys/class/power_supply/BAT*/status 2>/dev/null | head -n1"]
        running: false
        property int line: 0
        stdout: SplitParser {
            onRead: data => {
                if (batteryProc.line === 0) {
                    const n = parseInt(data, 10);
                    if (!isNaN(n)) { root.batteryPercent = n; root.batteryPresent = true; }
                    else root.batteryPresent = false;
                } else {
                    root.batteryCharging = (data === "Charging" || data === "Full");
                    batteryProc.line = -1; // reset below
                }
                batteryProc.line = batteryProc.line === -1 ? 0 : batteryProc.line + 1;
            }
        }
    }

    // ---- cpu + ram (via /proc) ----
    property real cpuUsage: 0     // 0..1
    property real ramUsage: 0     // 0..1
    property var _prevCpu: null

    Process {
        id: cpuRamProc
        command: ["sh", "-c", "head -n1 /proc/stat; free | awk '/Mem:/ {print $3\"/\"$2}'"]
        running: false
        property int line: 0
        stdout: SplitParser {
            onRead: data => {
                if (cpuRamProc.line === 0) {
                    const parts = data.trim().split(/\s+/).slice(1).map(Number);
                    const idle = parts[3] + (parts[4] || 0);
                    const total = parts.reduce((a, b) => a + b, 0);
                    if (root._prevCpu) {
                        const dTotal = total - root._prevCpu.total;
                        const dIdle = idle - root._prevCpu.idle;
                        if (dTotal > 0) root.cpuUsage = Math.max(0, Math.min(1, 1 - dIdle / dTotal));
                    }
                    root._prevCpu = { total, idle };
                } else {
                    const [used, tot] = data.split("/").map(Number);
                    if (tot > 0) root.ramUsage = used / tot;
                    cpuRamProc.line = -1;
                }
                cpuRamProc.line = cpuRamProc.line === -1 ? 0 : cpuRamProc.line + 1;
            }
        }
    }

    Timer {
        interval: 5000
        running: root.showNetwork
        repeat: true
        triggeredOnStart: true
        onTriggered: networkProc.running = true
    }
    Timer {
        interval: 15000
        running: root.showBattery
        repeat: true
        triggeredOnStart: true
        onTriggered: batteryProc.running = true
    }
    Timer {
        interval: 2000
        running: root.showCpuRam
        repeat: true
        triggeredOnStart: true
        onTriggered: cpuRamProc.running = true
    }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: bar
            required property var modelData
            screen: modelData

            anchors {
                top: root.barEdge === "top"
                bottom: root.barEdge === "bottom"
                left: true
                right: true
            }
            implicitHeight: root.barHeight
            color: "transparent"

            // Geometry of the visible pill (not necessarily the full window —
            // see the "left"/"center"/"right" position states below), so
            // popups can anchor to where the bar actually is drawn.
            readonly property real shellRight: shell.x + shell.width
            readonly property real shellTop: shell.y
            readonly property real shellBottom: shell.y + shell.height

            // Opens one popup and animates the others closed, so they never
            // stack on top of each other at the same anchor point.
            function openOnly(which) {
                const menus = { control: controlCenter, media: mediaMenu, power: powerMenu, customize: customizeMenu };
                for (const key in menus) {
                    const p = menus[key];
                    if (key === which) p.openPopup();
                    else if (p.visible) p.closePopup();
                }
            }

            // floating rounded pill, inset from the screen edges. Defaults to
            // spanning the full window ("stretch"); the Customize menu can
            // switch it to a fixed-width pill docked left/center/right instead.
            Rectangle {
                id: shell
                anchors.top: parent.top
                anchors.bottom: parent.bottom
                anchors.margins: root.barGap
                anchors.left: parent.left
                width: parent.width - (root.barGap * 2)
                radius: root.barRadius
                color: Qt.rgba(root.bgColorObj.r, root.bgColorObj.g, root.bgColorObj.b, root.barOpacity)
                border.color: root.barBorderEnabled ? root.barBorderColor : "transparent"
                border.width: root.barBorderEnabled ? root.barBorderWidth : 0
                Behavior on color { ColorAnimation { duration: 150 } }
                Behavior on border.color { ColorAnimation { duration: 150 } }
                Behavior on border.width { NumberAnimation { duration: 150 } }
                Behavior on radius { NumberAnimation { duration: 150 } }

                // ---- auto-hide: slide off-screen except a thin reveal strip,
                // pop back down on hover. No-op (fully visible) when disabled.
                // Uses a transform (not y:) because `shell` already has both
                // anchors.top and anchors.bottom set, which would fight a
                // direct y binding.
                property bool revealed: !root.autoHideEnabled
                transform: Translate {
                    id: hideTranslate
                    y: shell.revealed ? 0 : (root.barEdge === "top" ? -(shell.height - root.autoHideRevealPx) : (shell.height - root.autoHideRevealPx))
                    Behavior on y { NumberAnimation { duration: 180; easing.type: Easing.OutQuad } }
                }

                // HoverHandler (not MouseArea) so it never steals clicks/hover
                // from the real buttons layered on top of it.
                HoverHandler {
                    id: revealHover
                    onHoveredChanged: {
                        if (!root.autoHideEnabled) return;
                        if (hovered) { hideTimer.stop(); shell.revealed = true; }
                        else hideTimer.restart();
                    }
                }
                Timer { id: hideTimer; interval: 900; onTriggered: shell.revealed = false }
                // imperative assignments above break the initial declarative
                // binding, so re-sync explicitly when auto-hide is toggled off
                Connections {
                    target: root
                    function onAutoHideEnabledChanged() { if (!root.autoHideEnabled) shell.revealed = true; }
                }

                // little startup "pop" so the bar doesn't just appear
                opacity: 0
                scale: 0.9
                transformOrigin: Item.Center
                Component.onCompleted: shellEntrance.start()
                ParallelAnimation {
                    id: shellEntrance
                    NumberAnimation { target: shell; property: "opacity"; to: 1; duration: 380; easing.type: Easing.OutQuad }
                    NumberAnimation { target: shell; property: "scale"; to: 1; duration: 420; easing.type: Easing.OutBack; easing.overshoot: 1.4 }
                }

                states: [
                    State {
                        name: "left"
                        when: root.barPosition === "left"
                        PropertyChanges { target: shell; width: root.floatingWidth }
                    },
                    State {
                        name: "center"
                        when: root.barPosition === "center"
                        AnchorChanges { target: shell; anchors.left: undefined; anchors.horizontalCenter: shell.parent.horizontalCenter }
                        PropertyChanges { target: shell; width: root.floatingWidth }
                    },
                    State {
                        name: "right"
                        when: root.barPosition === "right"
                        AnchorChanges { target: shell; anchors.left: undefined; anchors.right: shell.parent.right }
                        PropertyChanges { target: shell; width: root.floatingWidth }
                    }
                ]
                transitions: Transition {
                    AnchorAnimation { duration: 260; easing.type: Easing.OutQuad }
                    NumberAnimation { property: "width"; duration: 260; easing.type: Easing.OutQuad }
                }

                // faint top highlight for a bit of glassy depth
                Rectangle {
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 1
                    height: 1
                    color: "#3a3c56"
                    opacity: 0.6
                }

                // ---------- left: nixos button + workspace switcher ----------
                Row {
                    anchors.left: parent.left
                    anchors.leftMargin: 8
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 10

                    // Opens the NixOS system config in a terminal editor.
                    // Swap the glyph below for a Nerd Font nixos icon
                    // (e.g. "\uf313") if you have one installed.
                    IconButton {
                        visible: root.showNixButton
                        width: visible ? implicitWidth : 0
                        icon: "\uf313"
                        size: 26
                        anchors.verticalCenter: parent.verticalCenter
                        onClicked: Quickshell.execDetached(["sh", "-c",
                            "$TERMINAL -e sudo vim /etc/nixos/configuration.nix || kitty -e sudo vim /etc/nixos/configuration.nix || alacritty -e sudo vim /etc/nixos/configuration.nix || foot -e sudo vim /etc/nixos/configuration.nix || xterm -e sudo vim /etc/nixos/configuration.nix"])
                    }

                    Rectangle {
                        visible: root.showNixButton && root.showWorkspaces
                        width: visible ? 1 : 0; height: 18
                        color: "#33344a"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    // Clickable workspace pills — click to switch, active one highlighted.
                    // Two visual styles: numbered pills, or minimal dots.
                    Row {
                        visible: root.showWorkspaces
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: root.workspaceStyle === "dot" ? 6 : 4

                        Repeater {
                            model: Hyprland.workspaces ? Hyprland.workspaces.values : []
                            delegate: Rectangle {
                                readonly property bool active: Hyprland.focusedWorkspace && modelData.id === Hyprland.focusedWorkspace.id
                                readonly property bool dot: root.workspaceStyle === "dot"
                                width: dot ? (active ? 14 : 8) : 24
                                height: dot ? 8 : 24
                                radius: dot ? 4 : 8
                                anchors.verticalCenter: parent.verticalCenter
                                color: dot
                                    ? (active ? root.accentColor : "#33344a")
                                    : (active ? Qt.rgba(root.accentColorObj.r, root.accentColorObj.g, root.accentColorObj.b, 0.25) : (wsMouse.containsMouse ? "#262838" : "transparent"))
                                Behavior on color { ColorAnimation { duration: 150 } }
                                Behavior on width { NumberAnimation { duration: 150; easing.type: Easing.OutQuad } }
                                scale: (!dot && active) ? 1.1 : 1.0
                                Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack; easing.overshoot: 3 } }

                                Text {
                                    anchors.centerIn: parent
                                    visible: !parent.dot
                                    text: modelData.id
                                    font.pixelSize: 11
                                    color: parent.active ? root.accentColor : "#cad3f5"
                                    Behavior on color { ColorAnimation { duration: 150 } }
                                }

                                MouseArea {
                                    id: wsMouse
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: Quickshell.execDetached(["hyprctl", "dispatch", "workspace", String(modelData.id)])
                                }
                            }
                        }
                    }
                }

                // ---------- center: clock (click to toggle full date) ----------
                Item {
                    anchors.centerIn: parent
                    width: clockText.implicitWidth
                    height: clockText.implicitHeight

                    Text {
                        id: clockText
                        text: root.showFullDate ? root.time.split("||")[1] : root.time.split("||")[0]
                        color: "#cad3f5"
                        font.pixelSize: 13
                        font.letterSpacing: 0.4
                    }

                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.showFullDate = !root.showFullDate
                    }
                }

                // ---------- right: quick-launch buttons ----------
                Row {
                    anchors.right: parent.right
                    anchors.rightMargin: 10
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 4

                    // ---- cpu / ram ----
                    Chip {
                        visible: root.showCpuRam
                        accent: root.accentColorObj
                        text: Math.round(root.cpuUsage * 100) + "% · " + Math.round(root.ramUsage * 100) + "%"
                        onClicked: bar.openOnly(controlCenter.visible ? "" : "control")
                    }

                    // ---- battery ----
                    Chip {
                        visible: root.showBattery && root.batteryPresent
                        accent: root.batteryPercent <= 15 && !root.batteryCharging ? "#ed8796" : root.accentColorObj
                        active: root.batteryCharging
                        text: (root.batteryCharging ? "⚡" : "") + root.batteryPercent + "%"
                        onClicked: bar.openOnly(controlCenter.visible ? "" : "control")
                    }

                    // ---- network ----
                    Chip {
                        visible: root.showNetwork
                        accent: root.accentColorObj
                        active: root.networkConnected
                        text: !root.wifiEnabled ? "Wi-Fi Off" : (root.networkConnected ? root.networkSSID : "Offline")
                        onClicked: root.toggleWifi()
                    }

                    Rectangle {
                        visible: root.showCpuRam || root.showBattery || root.showNetwork
                        width: 1; height: 18
                        color: "#33344a"
                        anchors.verticalCenter: parent.verticalCenter
                    }

                    IconButton {
                        accent: root.accentColorObj
                        icon: "♫"
                        active: mediaMenu.visible
                        onClicked: bar.openOnly(mediaMenu.visible ? "" : "media")
                    }
                    IconButton {
                        accent: root.accentColorObj
                        icon: "⚙"
                        active: controlCenter.visible
                        onClicked: bar.openOnly(controlCenter.visible ? "" : "control")
                        // scroll over the control-centre icon to nudge volume
                        // without having to open the popup at all
                        onWheelUp: root.bumpVolume(0.05)
                        onWheelDown: root.bumpVolume(-0.05)
                    }
                    IconButton {
                        accent: root.accentColorObj
                        icon: "◈"
                        active: customizeMenu.visible
                        onClicked: bar.openOnly(customizeMenu.visible ? "" : "customize")
                    }
                    IconButton {
                        accent: root.accentColorObj
                        icon: "⏻"
                        active: powerMenu.visible
                        onClicked: bar.openOnly(powerMenu.visible ? "" : "power")
                    }
                }
            }

            ControlCenterPopup {
                id: controlCenter
                anchorWindow: bar
                edge: root.barEdge
                accent: root.accentColorObj
                bg: root.bgColorObj
                borderEnabled: root.barBorderEnabled
                borderColor: root.barBorderColor
                borderWidth: root.barBorderWidth
            }
            MediaMenuPopup {
                id: mediaMenu
                anchorWindow: bar
                edge: root.barEdge
                accent: root.accentColorObj
                bg: root.bgColorObj
                borderEnabled: root.barBorderEnabled
                borderColor: root.barBorderColor
                borderWidth: root.barBorderWidth
            }
            PowerMenuPopup {
                id: powerMenu
                anchorWindow: bar
                edge: root.barEdge
                accent: root.accentColorObj
                bg: root.bgColorObj
                borderEnabled: root.barBorderEnabled
                borderColor: root.barBorderColor
                borderWidth: root.barBorderWidth
            }
            CustomizePopup {
                id: customizeMenu
                anchorWindow: bar
                edge: root.barEdge
                accent: root.accentColor
                bg: root.bgColor
                borderEnabled: root.barBorderEnabled
                borderColor: root.barBorderColor
                borderWidth: root.barBorderWidth
                barEdge: root.barEdge
                barPosition: root.barPosition
                barHeight: root.barHeight
                barRadius: root.barRadius
                barGap: root.barGap
                barOpacity: root.barOpacity
                clock24h: root.clock24h
                showSeconds: root.showSeconds
                workspaceStyle: root.workspaceStyle
                autoHideEnabled: root.autoHideEnabled
                showWorkspaces: root.showWorkspaces
                showNixButton: root.showNixButton
                showNetwork: root.showNetwork
                showBattery: root.showBattery
                showCpuRam: root.showCpuRam
                onAccentPicked: c => root.accentColor = c
                onBgPicked: c => root.bgColor = c
                onBorderTogglePicked: v => root.barBorderEnabled = v
                onBorderColorPicked: c => root.barBorderColor = c
                onBorderWidthPicked: w => root.barBorderWidth = w
                onEdgePicked: e => root.barEdge = e
                onPositionPicked: p => root.barPosition = p
                onBarHeightPicked: h => root.barHeight = h
                onBarRadiusPicked: r => root.barRadius = r
                onBarGapPicked: g => root.barGap = g
                onBarOpacityPicked: o => root.barOpacity = o
                onClock24hPicked: v => root.clock24h = v
                onShowSecondsPicked: v => root.showSeconds = v
                onWorkspaceStylePicked: s => root.workspaceStyle = s
                onAutoHidePicked: v => root.autoHideEnabled = v
                onModulePicked: (key, value) => { root[key] = value; }
            }
        }
    }

    Process {
        id: dateProc
        readonly property string timeFmt: (root.clock24h ? "%H:%M" : "%I:%M %p") + (root.showSeconds ? ":%S" : "")
        command: ["date", "+%a " + timeFmt + "||%A, %B %d, %Y"]
        running: true
        stdout: SplitParser { onRead: data => root.time = data }
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: dateProc.running = true
    }
}
