// qml/AgentPanel.qml - 右侧面板：Agent Memory 管理 + 对话管理
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: root
    width: 280
    color: "#1E1F22"
    clip: true

    readonly property color cText: "#DBDEE1"
    readonly property color cMuted: "#949BA4"
    readonly property color cAccent: "#5865F2"
    readonly property color cInput: "#383A40"
    readonly property color cBorder: "#3F4147"
    readonly property color cHighlight: "#404249"

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 16

        // ── Agent Memory 管理 ─────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            RowLayout {
                Layout.fillWidth: true
                Text {
                    text: "🧠 Agent Memory"
                    color: cText
                    font.pixelSize: 14
                    font.bold: true
                }
                Item { Layout.fillWidth: true }
            }

            // 添加记忆
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                TextField {
                    id: factKey
                    Layout.fillWidth: true
                    placeholderText: "Key (e.g. 偏好)"
                    placeholderTextColor: cMuted
                    color: cText
                    font.pixelSize: 12
                    implicitHeight: 28
                    background: Rectangle {
                        color: cInput
                        radius: 4
                        border.color: cBorder
                    }
                }
                TextField {
                    id: factValue
                    Layout.fillWidth: true
                    placeholderText: "Value"
                    placeholderTextColor: cMuted
                    color: cText
                    font.pixelSize: 12
                    implicitHeight: 28
                    background: Rectangle {
                        color: cInput
                        radius: 4
                        border.color: cBorder
                    }
                    Keys.onReturnPressed: {
                        var k = factKey.text.trim()
                        var v = factValue.text.trim()
                        if (k !== "" && agentMemory) {
                            agentMemory.addFact(k, v)
                            factKey.text = ""
                            factValue.text = ""
                        }
                    }
                }
                Button {
                    text: "+"
                    implicitWidth: 32
                    implicitHeight: 28
                    contentItem: Text {
                        text: parent.text
                        color: "white"
                        font.pixelSize: 16
                        font.bold: true
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                    background: Rectangle { radius: 4; color: cAccent }
                    onClicked: {
                        var k = factKey.text.trim()
                        var v = factValue.text.trim()
                        if (k !== "" && agentMemory) {
                            agentMemory.addFact(k, v)
                            factKey.text = ""
                            factValue.text = ""
                        }
                    }
                }
            }

            // 记忆列表
            ScrollView {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                clip: true
                ScrollBar.vertical.policy: ScrollBar.AsNeeded

                ListView {
                    model: agentMemory ? agentMemory.longTermFacts : []
                    spacing: 4
                    delegate: Rectangle {
                        width: ListView.view.width - 4
                        height: 36
                        radius: 4
                        color: itemHover.hovered ? cHighlight : "transparent"

                        RowLayout {
                            anchors.fill: parent
                            anchors.margins: 6
                            spacing: 6
                            Text {
                                text: modelData.key + ":"
                                color: cAccent
                                font.pixelSize: 11
                                font.bold: true
                                Layout.preferredWidth: 70
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.value
                                color: cText
                                font.pixelSize: 11
                                Layout.fillWidth: true
                                elide: Text.ElideRight
                            }
                            Text {
                                text: "×"
                                color: delHover.hovered ? "#ED4245" : cMuted
                                font.pixelSize: 14
                                HoverHandler { id: delHover }
                                MouseArea {
                                    anchors.fill: parent
                                    cursorShape: Qt.PointingHandCursor
                                    onClicked: {
                                        if (agentMemory)
                                            agentMemory.removeFact(modelData.key)
                                    }
                                }
                            }
                        }
                        HoverHandler { id: itemHover }
                    }
                }
            }

            Button {
                text: "清空全部记忆"
                Layout.fillWidth: true
                implicitHeight: 28
                visible: agentMemory && agentMemory.longTermFacts.length > 0
                contentItem: Text {
                    text: parent.text
                    color: "#ED4245"
                    font.pixelSize: 11
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 4
                    color: clearHover.hovered ? "#5C2E2E" : "transparent"
                    border.color: "#ED4245"
                    border.width: 1
                }
                HoverHandler { id: clearHover }
                onClicked: clearMemDialog.open()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            height: 1
            color: cBorder
        }

        // ── 对话管理 ─────────────────────────────────────────────────────────
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 8

            Text {
                text: "📋 对话管理"
                color: cText
                font.pixelSize: 14
                font.bold: true
            }

            Column {
                spacing: 4
                Repeater {
                    model: [
                        { icon: "🗑️", label: "清空当前对话", action: "clear" },
                        { icon: "✏️", label: "新对话", action: "new" }
                    ]
                    delegate: Rectangle {
                        width: root.width - 24
                        height: 36
                        radius: 4
                        color: convHover.hovered ? cHighlight : "transparent"
                        Row {
                            anchors { fill: parent; leftMargin: 10 }
                            spacing: 10
                            Text { text: modelData.icon; color: cMuted; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                            Text { text: modelData.label; color: cText; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter }
                        }
                        HoverHandler { id: convHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (modelData.action === "clear") mainView.clearMessages()
                                else if (modelData.action === "new") mainView.newSession()
                            }
                        }
                    }
                }
            }

            Text {
                text: "当前会话: " + (mainView.sessionName || "新对话")
                color: cMuted
                font.pixelSize: 11
                Layout.fillWidth: true
                elide: Text.ElideRight
            }
        }

        Item { Layout.fillHeight: true }
    }

    Dialog {
        id: clearMemDialog
        title: "清空 Agent 记忆"
        modal: true
        anchors.centerIn: parent
        width: 300
        background: Rectangle { color: "#1E1F22"; radius: 8; border.color: cBorder }
        contentItem: Text {
            text: "确定要清空所有长期记忆吗？此操作不可撤销。"
            color: cText
            font.pixelSize: 13
        }
        footer: Row {
            spacing: 8
            layoutDirection: Qt.RightToLeft
            Button {
                text: "清空"
                width: 80
                height: 32
                contentItem: Text {
                    text: parent.text
                    color: "white"
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { radius: 5; color: "#ED4245" }
                onClicked: {
                    if (agentMemory)
                        agentMemory.clearLongTerm()
                    clearMemDialog.close()
                }
            }
            Button {
                text: "取消"
                width: 80
                height: 32
                contentItem: Text {
                    text: parent.text
                    color: cText
                    font.pixelSize: 13
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                onClicked: clearMemDialog.close()
            }
        }
    }
}
