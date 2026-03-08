// qml/ChatMessage.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: ListView.view ? ListView.view.width : 700
    height: innerCol.implicitHeight + 28
    property string role:           "user"
    property string msgContent:     ""
    property string thinkingContent:""
    property bool   isThinking:     false
    property int    messageIndex:   -1

    property bool isAI: role === "ai"

    // ── 内部状态 ─────────────────────────────────────────────────────────────
    property bool editing:        false
    property bool thinkExpanded:  false

    property real thinkTime: 0.0
    Timer {
        id: thinkTimer
        interval: 100; running: root.isThinking; repeat: true
        onTriggered: root.thinkTime += 0.1
    }

    // ── 外层行 ───────────────────────────────────────────────────────────────
    Row {
        id: outerRow
        //anchors {
        //    left: parent.left; right: parent.right; top: parent.top
        //    leftMargin: 20; rightMargin: 20; topMargin: 14
        //}
        anchors {
            top: parent.top
            topMargin: 14
            horizontalCenter: parent.horizontalCenter
        }
        width: parent.width - 40
        spacing: 12

        // 头像
        Rectangle {
            width: 34; height: 34; radius: 7
            color: isAI ? "#F9A825" : "#5865F2"
            Text {
                anchors.centerIn: parent
                text: isAI ? "🤖" : "Me"
                color: "white"; font.bold: true; font.pixelSize: 13
            }
        }

        // 消息主体
        Column {
            id: innerCol
            width: outerRow.width - 34 - outerRow.spacing
            spacing: 6

            // 发送者 + 操作按钮行
            Row {
                width: parent.width
                spacing: 8

                Text {
                    text: isAI ? "ChatAgent AI" : "You"
                    color: "#949BA4"; font.pixelSize: 12; font.bold: true
                    //anchors.verticalCenter: parent.verticalCenter
                }

                // 操作按钮（hover 显示）
                Row {
                    spacing: 4
                    //anchors.verticalCenter: parent.verticalCenter
                    visible: msgHover.hovered

                    // 编辑按钮
                    ToolButton {
                        width: 22; height: 22
                        text: "✏️"
                        font.pixelSize: 11
                        ToolTip.text: "编辑"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        onClicked: {
                            root.editing = !root.editing
                            if (root.editing) editArea.text = root.msgContent
                        }
                    }
                    // 删除按钮
                    ToolButton {
                        width: 22; height: 22
                        text: "🗑️"
                        font.pixelSize: 11
                        ToolTip.text: "删除"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        onClicked: mainView.deleteMessage(root.messageIndex)
                    }
                    // 重新生成（仅 AI 消息）
                    ToolButton {
                        width: 22; height: 22
                        text: "🔄"
                        font.pixelSize: 11
                        visible: isAI
                        ToolTip.text: "重新生成"
                        ToolTip.visible: hovered
                        ToolTip.delay: 500
                        onClicked: mainView.resendFrom(root.messageIndex)
                    }
                }
            }

            // ── 思考过程 ──────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 4
                visible: isAI && (thinkingContent !== "" || isThinking)

                // 标题行（可点击折叠）
                Item {
                    width: parent.width
                    Row {
                        id: thinkHeaderRow
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Text { text: "🧠"; font.pixelSize: 13 }
                        Text {
                            text: isThinking
                                ? "思考中... " + thinkTime.toFixed(1) + "s"
                                : "思考完成 (" + thinkTime.toFixed(1) + "s)" +
                                (thinkingContent !== "" ? (thinkExpanded ? "  ▲" : "  ▼") : "")
                            color: "#949BA4"; font.pixelSize: 12; font.italic: true
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: if (thinkingContent !== "") root.thinkExpanded = !root.thinkExpanded
                    }
                }

                // 思考内容（可折叠）
                Rectangle {
                    width: parent.width
                    visible: thinkExpanded && thinkingContent !== ""
                    height: visible ? thinkText.implicitHeight + 10 : 0
                    color: "#1A1B1E"
                    radius: 5
                    border.color: "#2E3035"

                    Text {
                        id: thinkText
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        text: root.thinkingContent
                        color: "#72767D"; font.pixelSize: 13
                        wrapMode: Text.Wrap; lineHeight: 1.4
                    }
                }
            }

            // ── 思考占位（纯 QML，不触发 WebView）───────────────────────────
            Text {
                width: parent.width
                visible: isAI && root.msgContent === "" && root.isThinking
                text: "▍"
                color: "#949BA4"; font.pixelSize: 14
            }

            // ── 正文：Markdown 渲染 ───────────────────────────────────────────
            MarkdownRender {
                id: mdRender
                width: parent.width
                visible: root.msgContent !== ""
                markdownText: root.msgContent
                textColor: isAI ? "#DBDEE1" : "#C9CDD4"
            }

            // ── 编辑模式 ──────────────────────────────────────────────────────
            Column {
                width: parent.width
                spacing: 6
                visible: root.editing

                Rectangle {
                    width: parent.width
                    height: editArea.implicitHeight + 16
                    color: "#1E1F22"
                    radius: 6
                    border.color: "#5865F2"; border.width: 1

                    TextArea {
                        id: editArea
                        anchors { fill: parent; margins: 8 }
                        text: root.msgContent
                        color: "#DBDEE1"; font.pixelSize: 14
                        wrapMode: TextArea.Wrap
                        background: null
                        focus: root.editing
                    }
                }

                Row {
                    spacing: 8
                    Button {
                        text: "保存"
                        height: 28
                        contentItem: Text {
                            text: parent.text; color: "white"
                            font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { radius: 5; color: "#5865F2" }
                        onClicked: {
                            mainView.editMessage(root.messageIndex, editArea.text)
                            root.editing = false
                        }
                    }
                    Button {
                        text: "取消"
                        height: 28
                        contentItem: Text {
                            text: parent.text; color: "#DBDEE1"
                            font.pixelSize: 13; horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                        }
                        background: Rectangle { radius: 5; color: "#3F4147" }
                        onClicked: root.editing = false
                    }
                }
            }
        }
    }

    // Hover 检测（用于显示操作按钮）
    HoverHandler { id: msgHover }
}
