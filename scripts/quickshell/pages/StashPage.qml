import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io

Item {
    id: root
    property var island

    // LocalSend state
    property string pendingFile: ""
    property string lsState: "idle"   // idle | scanning | ready | sending

    ListModel { id: deviceModel }

    Component.onCompleted: {
        island.exec("mkdir -p ~/Downloads/qs_stash")
    }

    Process {
        id: discoverProc
        command: ["bash", "-c", "exec \"$HOME/.config/hypr/scripts/quickshell/stash/localsend_discover.sh\""]
        stdout: StdioCollector { id: discoverOut }
        onExited: {
            if (root.lsState !== "scanning") return
            deviceModel.clear()
            var lines = discoverOut.text.trim().split('\n')
            for (var i = 0; i < lines.length; i++) {
                var line = lines[i]
                if (!line) continue
                var parts = line.split('\t')
                if (parts.length >= 2)
                    deviceModel.append({ alias: parts[0].trim(), ip: parts[1].trim() })
            }
            root.lsState = "ready"
        }
    }

    Process {
        id: sendProc
        stdout: StdioCollector {}
        stderr: StdioCollector {}
        onExited: function(code) {
            root.lsState = "idle"
            root.pendingFile = ""
        }
    }

    function openSendPicker(file) {
        pendingFile = file
        deviceModel.clear()
        lsState = "scanning"
        discoverProc.running = true
    }

    function sendTo(ip) {
        lsState = "sending"
        sendProc.command = ["bash", "-c",
            "~/.config/hypr/scripts/quickshell/stash/localsend_send.sh '" + pendingFile + "' '" + ip + "'"]
        sendProc.running = true
    }

    // ── Main content ──────────────────────────────────────────────────────────
    Item {
        anchors.fill: parent
        anchors.margins: island.s(12)

        Rectangle {
            id: dropZone
            anchors.fill: parent
            color: island.isDragHovered ? Qt.rgba(island.mauve.r, island.mauve.g, island.mauve.b, 0.2) : "transparent"
            radius: island.s(16)

            // ── Empty state ───────────────────────────────────────────────────
            ColumnLayout {
                anchors.centerIn: parent
                spacing: island.s(8)
                visible: island.stashModel.count === 0

                Image {
                    source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='white'><path d='M4 6C4 4.895 4.895 4 6 4H18C19.105 4 20 4.895 20 6C20 7.105 19.105 8 18 8H6C4.895 8 4 7.105 4 6ZM5 10C5 8.895 5.895 8 7 8H17C18.105 8 19 8.895 19 10V18C19 19.105 18.105 20 17 20H7C5.895 20 5 19.105 5 18V10Z'/><path d='M9 12C9 11.448 9.448 11 10 11H14C14.552 11 15 11.448 15 12C15 12.552 14.552 13 14 13H10C9.448 13 9 12.552 9 12Z' fill='%231e1e2e'/></svg>"
                    Layout.preferredWidth: island.s(32)
                    Layout.preferredHeight: island.s(32)
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Files Tray"
                    color: "white"
                    font.family: "JetBrains Mono"
                    font.pixelSize: island.s(16)
                    font.bold: true
                    Layout.alignment: Qt.AlignHCenter
                }
                Text {
                    text: "Drag and drop files"
                    color: island.subtext0 || "lightgray"
                    font.family: "JetBrains Mono"
                    font.pixelSize: island.s(14)
                    Layout.alignment: Qt.AlignHCenter
                }
            }

            // ── File grid ─────────────────────────────────────────────────────
            GridView {
                id: imageGrid
                anchors.fill: parent
                model: island.stashModel
                cellWidth: island.s(110)
                cellHeight: island.s(110)
                clip: true

                delegate: Item {
                    width: imageGrid.cellWidth
                    height: imageGrid.cellHeight

                    MouseArea {
                        id: delegateMouse
                        anchors.fill: parent
                        anchors.margins: island.s(5)
                        drag.target: dragItem
                        hoverEnabled: true

                        Rectangle {
                            anchors.fill: parent
                            color: island.surface1
                            radius: island.s(8)
                            clip: true

                            Image {
                                id: imgPreview
                                anchors.fill: parent
                                source: isDir ? "" : fileURL
                                fillMode: Image.PreserveAspectCrop
                                visible: !isDir && status === Image.Ready
                            }

                            Text {
                                anchors.centerIn: parent
                                text: {
                                    if (isDir) {
                                        if (filePath.indexOf("/group_") !== -1) return "";
                                        return "󰉋";
                                    }
                                    if (imgPreview.status === Image.Ready) return "";
                                    var ext = filePath.split('.').pop().toLowerCase();
                                    if (['pdf'].includes(ext))                   return "󰈦";
                                    if (['txt','md','log','csv'].includes(ext))  return "󰈙";
                                    if (['zip','tar','gz','rar','7z'].includes(ext)) return "󰛫";
                                    if (['mp3','wav','flac'].includes(ext))      return "󰎆";
                                    if (['mp4','mkv','avi','mov'].includes(ext)) return "󰕧";
                                    return "󰈔";
                                }
                                color: island.text
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: island.s(48)
                                visible: isDir || (imgPreview.status !== Image.Ready && imgPreview.status !== Image.Loading)
                            }

                            Item {
                                id: dragItem
                                width: parent.width; height: parent.height
                                Drag.active: delegateMouse.drag.active
                                Drag.dragType: Drag.Automatic
                                Drag.supportedActions: Qt.CopyAction
                                Drag.mimeData: { "text/uri-list": fileURL }
                                Drag.onActiveChanged: {
                                    if (Drag.active) island.expanded = false
                                }
                            }

                            // ── Action buttons ────────────────────────────────
                            Row {
                                anchors.top: parent.top
                                anchors.right: parent.right
                                anchors.margins: island.s(6)
                                spacing: island.s(5)
                                opacity: delegateMouse.containsMouse ? 1.0 : 0.0
                                Behavior on opacity { NumberAnimation { duration: 150 } }

                                // Star
                                Rectangle {
                                    width: island.s(24); height: island.s(24)
                                    radius: width / 2
                                    color: Qt.rgba(island.base.r, island.base.g, island.base.b, 0.75)
                                    border.color: isFav ? Qt.rgba(island.yellow.r, island.yellow.g, island.yellow.b, 0.8) : "transparent"
                                    border.width: island.s(1)
                                    Text {
                                        anchors.centerIn: parent
                                        text: isFav ? "󰓎" : "󰓒"
                                        color: isFav ? island.yellow : island.subtext0
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: island.s(13)
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            var f = !isFav
                                            island.stashModel.setProperty(index, "isFav", f)
                                            island.stashModel.move(index, f ? 0 : island.stashModel.count - 1, 1)
                                        }
                                    }
                                }

                                // LocalSend
                                Rectangle {
                                    width: island.s(24); height: island.s(24)
                                    radius: width / 2
                                    color: Qt.rgba(island.teal.r, island.teal.g, island.teal.b, 0.85)
                                    Image {
                                        anchors.centerIn: parent
                                        width: parent.width * 0.58
                                        height: parent.height * 0.58
                                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='white'><path d='M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92 1.61 0 2.92-1.31 2.92-2.92s-1.31-2.92-2.92-2.92z'/></svg>"
                                        fillMode: Image.PreserveAspectFit
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: root.openSendPicker(filePath)
                                    }
                                }

                                // Delete
                                Rectangle {
                                    width: island.s(24); height: island.s(24)
                                    radius: width / 2
                                    color: Qt.rgba(island.red.r, island.red.g, island.red.b, 0.85)
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰆴"
                                        color: "white"
                                        font.family: "Iosevka Nerd Font"
                                        font.pixelSize: island.s(13)
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        onClicked: {
                                            island.exec("rm -rf '" + filePath + "'")
                                            island.stashModel.remove(index)
                                            if (island.stashModel.count === 0) island.expanded = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── LocalSend device picker overlay ───────────────────────────────
            Rectangle {
                anchors.fill: parent
                radius: island.s(12)
                color: Qt.rgba(island.base.r, island.base.g, island.base.b, 0.97)
                visible: root.lsState !== "idle"
                z: 20

                // Header row
                RowLayout {
                    id: pickerHeader
                    anchors.top: parent.top
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: island.s(12)
                    anchors.topMargin: island.s(10)
                    height: island.s(26)
                    spacing: island.s(8)

                    Image {
                        Layout.preferredWidth: island.s(16)
                        Layout.preferredHeight: island.s(16)
                        Layout.alignment: Qt.AlignVCenter
                        source: "data:image/svg+xml;utf8,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='white'><path d='M18 16.08c-.76 0-1.44.3-1.96.77L8.91 12.7c.05-.23.09-.46.09-.7s-.04-.47-.09-.7l7.05-4.11c.54.5 1.25.81 2.04.81 1.66 0 3-1.34 3-3s-1.34-3-3-3-3 1.34-3 3c0 .24.04.47.09.7L8.04 9.81C7.5 9.31 6.79 9 6 9c-1.66 0-3 1.34-3 3s1.34 3 3 3c.79 0 1.5-.31 2.04-.81l7.12 4.16c-.05.21-.08.43-.08.65 0 1.61 1.31 2.92 2.92 2.92 1.61 0 2.92-1.31 2.92-2.92s-1.31-2.92-2.92-2.92z'/></svg>"
                        fillMode: Image.PreserveAspectFit
                    }

                    Text {
                        Layout.alignment: Qt.AlignVCenter
                        text: root.lsState === "scanning" ? "Scanning…"
                            : root.lsState === "sending"  ? "Sending…"
                            : deviceModel.count === 0     ? "No devices found"
                            : "Send to"
                        color: island.text
                        font.family: "JetBrains Mono"
                        font.pixelSize: island.s(13)
                        font.weight: Font.Bold
                    }

                    // Spinner
                    Rectangle {
                        Layout.preferredWidth: island.s(14)
                        Layout.preferredHeight: island.s(14)
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: "transparent"
                        border.width: island.s(2)
                        border.color: island.teal
                        visible: root.lsState === "scanning" || root.lsState === "sending"

                        Rectangle {
                            width: island.s(3); height: island.s(3)
                            radius: width / 2
                            color: island.teal
                            anchors.top: parent.top
                            anchors.horizontalCenter: parent.horizontalCenter
                            transform: Rotation {
                                origin.x: 0; origin.y: island.s(7); angle: 0
                                RotationAnimation on angle {
                                    running: root.lsState === "scanning" || root.lsState === "sending"
                                    from: 0; to: 360; duration: 900; loops: Animation.Infinite
                                }
                            }
                        }
                    }

                    Item { Layout.fillWidth: true }

                    // Close button
                    Rectangle {
                        Layout.preferredWidth: island.s(20)
                        Layout.preferredHeight: island.s(20)
                        Layout.alignment: Qt.AlignVCenter
                        radius: width / 2
                        color: closeMouse.containsMouse
                            ? Qt.rgba(island.surface2.r, island.surface2.g, island.surface2.b, 0.8)
                            : "transparent"
                        Behavior on color { ColorAnimation { duration: 120 } }
                        Text {
                            anchors.centerIn: parent
                            text: "✕"
                            color: island.subtext0
                            font.pixelSize: island.s(10)
                            font.family: "JetBrains Mono"
                        }
                        MouseArea {
                            id: closeMouse
                            anchors.fill: parent
                            hoverEnabled: true
                            onClicked: {
                                root.lsState = "idle"
                                root.pendingFile = ""
                                discoverProc.running = false
                            }
                        }
                    }
                }

                // Device list
                ListView {
                    anchors.top: pickerHeader.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.bottom: parent.bottom
                    anchors.margins: island.s(8)
                    anchors.topMargin: island.s(4)
                    model: deviceModel
                    clip: true
                    spacing: island.s(4)

                    delegate: Rectangle {
                        width: parent ? parent.width : 0
                        height: island.s(34)
                        radius: island.s(8)
                        color: deviceHover.containsMouse
                            ? Qt.rgba(island.teal.r, island.teal.g, island.teal.b, 0.18)
                            : Qt.rgba(island.surface0.r, island.surface0.g, island.surface0.b, 0.6)
                        Behavior on color { ColorAnimation { duration: 120 } }

                        RowLayout {
                            anchors.left: parent.left
                            anchors.right: parent.right
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.leftMargin: island.s(12)
                            anchors.rightMargin: island.s(8)
                            spacing: island.s(10)

                            Text {
                                text: "󱁞"
                                font.family: "Iosevka Nerd Font"
                                font.pixelSize: island.s(16)
                                color: island.teal
                                Layout.alignment: Qt.AlignVCenter
                            }
                            Column {
                                Layout.alignment: Qt.AlignVCenter
                                Layout.fillWidth: true
                                Text {
                                    text: model.alias
                                    color: island.text
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: island.s(12)
                                    font.weight: Font.Medium
                                }
                                Text {
                                    text: model.ip
                                    color: island.subtext0
                                    font.family: "JetBrains Mono"
                                    font.pixelSize: island.s(10)
                                }
                            }
                        }

                        MouseArea {
                            id: deviceHover
                            anchors.fill: parent
                            hoverEnabled: true
                            enabled: root.lsState === "ready"
                            onClicked: root.sendTo(model.ip)
                        }
                    }
                }
            }
        }
    }
}
