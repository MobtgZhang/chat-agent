// qml/Main.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

ApplicationWindow {
    id: appWindow
    width: 1060; height: 720
    minimumWidth: 800; minimumHeight: 560
    visible: true
    title: "ChatAgent — " + mainView.sessionName
    color: "#2B2D31"
    // ── 全局色板（参考 chat-agent）──────────────────────────────────────────────
    readonly property color cBg:        "#2B2D31"
    readonly property color cSidebar:   "#1E1F22"
    readonly property color cInput:     "#383A40"
    readonly property color cBorder:    "#3F4147"
    readonly property color cHighlight: "#404249"
    readonly property color cText:      "#DBDEE1"
    readonly property color cMuted:     "#949BA4"
    readonly property color cAccent:    "#5865F2"

    // ── 弹窗（懒创建）────────────────────────────────────────────────────────
    property var settingsWin: null
    property var aboutWin:    null

    function openSettings() {
        if (!settingsWin) {
            var comp = Qt.createComponent("qrc:/src/qml/Settings.qml")
            if (comp.status === Component.Ready) {
                settingsWin = comp.createObject(appWindow)
            } else if (comp.status === Component.Error) {
                console.error("❌ Settings.qml 加载失败:", comp.errorString())
                return
            }
        }
        if (settingsWin) {
            settingsWin.show()
            settingsWin.raise()
            settingsWin.requestActivate()
        }
    }

    function openAbout() {
        if (!aboutWin) {
            var comp = Qt.createComponent("qrc:/src/qml/About.qml")
            if (comp.status === Component.Ready) {
                aboutWin = comp.createObject(appWindow)
            } else if (comp.status === Component.Error) {
                console.error("❌ About.qml 加载失败:", comp.errorString())
                return
            }
        }
        if (aboutWin) {
            aboutWin.show()
            aboutWin.raise()
            aboutWin.requestActivate()
        }
    }


    // ── 清空确认对话框 ────────────────────────────────────────────────────────
    Dialog {
        id: clearDialog
        title: "清空对话"
        modal: true
        anchors.centerIn: parent
        width: 300

        background: Rectangle { color: "#1E1F22"; radius: 8; border.color: cBorder }

        contentItem: Column {
            spacing: 12; padding: 16
            Text {
                text: "确定要清空当前对话记录吗？\n此操作不可撤销。"
                color: cText; font.pixelSize: 14; lineHeight: 1.5; wrapMode: Text.Wrap
                width: 260
            }
        }

        footer: Row {
            spacing: 8; padding: 12; layoutDirection: Qt.RightToLeft
            Button {
                text: "清空"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: "#ED4245" }
                onClicked: { mainView.clearMessages(); clearDialog.close() }
            }
            Button {
                text: "取消"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: cText; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                onClicked: clearDialog.close()
            }
        }
    }

    // ── 重命名输入框 ──────────────────────────────────────────────────────────
    Dialog {
        id: renameDialog
        title: "重命名"
        modal: true
        anchors.centerIn: parent
        width: 320

        background: Rectangle { color: "#1E1F22"; radius: 8; border.color: cBorder }

        contentItem: Column {
            spacing: 10; padding: 16
            Text { text: "请输入新名称："; color: cText; font.pixelSize: 13 }
            TextField {
                id: renameField
                width: 280; height: 36
                color: cText; font.pixelSize: 13
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                leftPadding: 10
                selectByMouse: true
                Keys.onReturnPressed: { mainView.renameSession(text); renameDialog.close() }
            }
        }

        footer: Row {
            spacing: 8; padding: 12; layoutDirection: Qt.RightToLeft
            Button {
                text: "确定"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: cAccent }
                onClicked: { mainView.renameSession(renameField.text); renameDialog.close() }
            }
            Button {
                text: "取消"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: cText; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                onClicked: renameDialog.close()
            }
        }

        onAboutToShow: {
            renameField.text = mainView.sessionName
            renameField.forceActiveFocus()
            renameField.selectAll()
        }
    }

    // ── 新建文件夹对话框 ──────────────────────────────────────────────────────
    Dialog {
        id: folderDialog
        title: "新建文件夹"
        modal: true
        anchors.centerIn: parent
        width: 320

        background: Rectangle { color: "#1E1F22"; radius: 8; border.color: cBorder }

        contentItem: Column {
            spacing: 10; padding: 16
            Text { text: "文件夹名称："; color: cText; font.pixelSize: 13 }
            TextField {
                id: folderNameField
                width: 280; height: 36
                color: cText; font.pixelSize: 13
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                leftPadding: 10
                selectByMouse: true
                Keys.onReturnPressed: { history.createFolder(text); folderDialog.close() }
            }
        }

        footer: Row {
            spacing: 8; padding: 12; layoutDirection: Qt.RightToLeft
            Button {
                text: "创建"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: cAccent }
                onClicked: { history.createFolder(folderNameField.text); folderDialog.close() }
            }
            Button {
                text: "取消"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: cText; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                onClicked: folderDialog.close()
            }
        }

        onAboutToShow: { folderNameField.text = ""; folderNameField.forceActiveFocus() }
    }

    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    //                           主布局
    // ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
    RowLayout {
        anchors.fill: parent
        spacing: 0

        // ═══════════════════════════ 左侧：侧边栏 ════════════════════════════
        Rectangle {
            Layout.preferredWidth: 248
            Layout.fillHeight: true
            color: cSidebar

            ColumnLayout {
                anchors.fill: parent
                spacing: 0

                // App 标题
                Rectangle {
                    Layout.fillWidth: true; height: 58
                    color: "transparent"
                    RowLayout {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        spacing: 10
                        Rectangle {
                            width: 32; height: 32; radius: 8; color: "#F9A825"
                            Text { anchors.centerIn: parent; text: "💬"; font.pixelSize: 18 }
                        }
                        Column {
                            spacing: 1; Layout.fillWidth: true
                            Text { text: "ChatAgent"; color: cText; font.bold: true; font.pixelSize: 15 }
                            Text { text: "Community Edition"; color: cMuted; font.pixelSize: 10 }
                        }
                    }
                    Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: "#2E3035" }
                }

                // 新建按钮行
                Rectangle {
                    Layout.fillWidth: true; height: 42
                    color: "transparent"

                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
                        spacing: 6

                        // 新对话
                        Rectangle {
                            Layout.fillWidth: true; height: 30; radius: 5
                            color: newChatHover.hovered ? cHighlight : "#2E3035"
                            Row {
                                anchors.centerIn: parent; spacing: 6
                                Text { text: "✏️"; font.pixelSize: 13 }
                                Text { text: "新对话"; color: cText; font.pixelSize: 12 }
                            }
                            HoverHandler { id: newChatHover }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: mainView.newSession()
                            }
                        }

                        // 新建文件夹
                        Rectangle {
                            width: 30; height: 30; radius: 5
                            color: folderHover.hovered ? cHighlight : "#2E3035"
                            Text { anchors.centerIn: parent; text: "📁"; font.pixelSize: 15 }
                            ToolTip.text: "新建文件夹"
                            ToolTip.visible: folderHover.hovered
                            ToolTip.delay: 600
                            HoverHandler { id: folderHover }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: folderDialog.open()
                            }
                        }
                    }
                }

                // ── 历史树列表（可上下滚动）────────────────────────────────────
                ListView {
                    id: historyList
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    Layout.minimumHeight: 80
                    clip: true
                    model: history.flatNodes
                    spacing: 1
                    ScrollBar.vertical: ScrollBar {
                        policy: ScrollBar.AsNeeded
                        contentItem: Rectangle {
                            implicitWidth: 6
                            radius: 3
                            color: parent.pressed ? "#60636A" : (parent.hovered ? "#60636A" : "#484B52")
                        }
                        background: Rectangle {
                            implicitWidth: 6
                            color: "#2E3035"
                            radius: 3
                        }
                    }

                    delegate: Item {
                        width: historyList.width
                        height: 36

                        readonly property var  node:      modelData
                        readonly property bool isSession: node.type === "session"
                        readonly property bool isFolder:  node.type === "folder"
                        readonly property bool isCurrent: isSession && node.id === mainView.currentSession

                        Rectangle {
                            anchors { fill: parent; leftMargin: 6; rightMargin: 6}
                            radius: 5
                            color: isCurrent ? "#3D4270"
                                : itemHover.hovered ? cHighlight : "transparent"

                            RowLayout {
                                anchors { fill: parent; leftMargin: node.depth * 14 + 8; rightMargin: 8 }
                                spacing: 6

                                Text {
                                    font.pixelSize: 13
                                    text: isFolder
                                        ? (node.expanded ? "📂" : "📁")
                                        : (isCurrent ? "🗨️" : "💬")
                                }

                                Text {
                                    Layout.fillWidth: true
                                    text: node.name
                                    color: isCurrent ? "white" : cText
                                    font.pixelSize: 12; font.bold: isCurrent
                                    elide: Text.ElideRight
                                }

                                Row {
                                    spacing: 2
                                    visible: itemHover.hovered

                                    Text {
                                        text: "🗑"; font.pixelSize: 12
                                        color: delHover.hovered ? "#ED4245" : cMuted
                                        HoverHandler { id: delHover }
                                        MouseArea {
                                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                            onClicked: history.deleteNode(node.id)
                                        }
                                    }
                                }
                            }

                            HoverHandler { id: itemHover }
                            MouseArea {
                                anchors.fill: parent
                                cursorShape: Qt.PointingHandCursor
                                acceptedButtons: Qt.LeftButton | Qt.RightButton
                                onClicked: function(mouse) {
                                    if (mouse.button === Qt.RightButton) {
                                        if (historyItemMenu.visible)
                                            return
                                        historyItemMenu.targetNode = node
                                        historyItemMenu.open()
                                        return
                                    }

                                    if (isFolder)
                                        history.toggleExpand(node.id)
                                    else
                                        mainView.loadSession(node.id)
                                }
                            }

                            Drag.active: dragArea.drag.active
                            Drag.hotSpot.x: width / 2
                            Drag.hotSpot.y: height / 2
                            Drag.mimeData: { "application/x-history-id": node.id }

                            MouseArea {
                                id: dragArea
                                anchors.fill: parent
                                drag.target: null
                                acceptedButtons: Qt.LeftButton
                            }

                            DropArea {
                                anchors.fill: parent
                                enabled: isFolder
                                keys: [ "application/x-history-id" ]
                                onDropped: function(drop) {
                                    var srcId = drop.mimeData["application/x-history-id"]
                                    if (!srcId || srcId === node.id)
                                        return
                                    history.moveNode(srcId, node.id)
                                    drop.acceptProposedAction()
                                }
                            }
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#2E3035" }

                // ── Agent Memory（自动总结的记忆，可删除）───────────────────────────
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 6

                    Text {
                        text: "🧠 Agent Memory（自动总结）"
                        color: cText
                        font.pixelSize: 13
                        font.bold: true
                        Layout.leftMargin: 10
                    }

                    ScrollView {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 120
                        clip: true
                        ScrollBar.vertical.policy: ScrollBar.AsNeeded

                        ListView {
                            model: typeof agentMemory !== "undefined" && agentMemory ? agentMemory.longTermFacts : []
                            spacing: 2
                            delegate: Rectangle {
                                width: ListView.view.width - 4
                                height: 32
                                radius: 4
                                color: memHover.hovered ? cHighlight : "transparent"

                                RowLayout {
                                    anchors.fill: parent
                                    anchors.margins: 6
                                    spacing: 6
                                    Text {
                                        text: modelData.key + ":"
                                        color: cAccent
                                        font.pixelSize: 11
                                        font.bold: true
                                        Layout.preferredWidth: 60
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
                                        color: memDelHover.hovered ? "#ED4245" : cMuted
                                        font.pixelSize: 12
                                        HoverHandler { id: memDelHover }
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
                                HoverHandler { id: memHover }
                            }
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        Layout.leftMargin: 10
                        Layout.rightMargin: 10
                        height: 28
                        visible: agentMemory && agentMemory.longTermFacts.length > 0
                        color: memClearHover.hovered ? "#5C2E2E" : "transparent"
                        radius: 4
                        border.color: "#ED4245"
                        border.width: 1
                        Row {
                            anchors.centerIn: parent
                            spacing: 4
                            Text { text: "清空全部记忆"; color: "#ED4245"; font.pixelSize: 11 }
                        }
                        HoverHandler { id: memClearHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: memClearDialog.open()
                        }
                    }
                }

                // 清空记忆确认对话框
                Dialog {
                    id: memClearDialog
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
                                memClearDialog.close()
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
                            onClicked: memClearDialog.close()
                        }
                    }
                }

                Rectangle { Layout.fillWidth: true; height: 1; color: "#2E3035" }

                // ── 底部按钮 ──────────────────────────────────────────────────
                Column {
                    Layout.fillWidth: true
                    Layout.bottomMargin: 8
                    spacing: 2
                    padding: 8

                    Repeater {
                        model: [
                            { icon: "⚙️", label: "设置",         action: "settings" },
                            { icon: "ℹ️", label: "关于 v1.0.0",  action: "about"    }
                        ]
                        delegate: Rectangle {
                            width: parent.width - 16; height: 36; radius: 5
                            color: sideHover.hovered ? cHighlight : "transparent"
                            Row {
                                anchors { left: parent.left; verticalCenter: parent.verticalCenter; leftMargin: 10 }
                                spacing: 10
                                Text { text: modelData.icon;  color: cMuted; font.pixelSize: 15 }
                                Text { text: modelData.label; color: cText;  font.pixelSize: 12 }
                            }
                            HoverHandler { id: sideHover }
                            MouseArea {
                                anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                onClicked: {
                                    if (modelData.action === "settings") openSettings()
                                    else openAbout()
                                }
                            }
                        }
                    }
                }
            }
        }

        // ═══════════════════════════ 中间：聊天区 ════════════════════════════
        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            // ── 顶部 Header ───────────────────────────────────────────────────
            Rectangle {
                id: chatHeader
                anchors { top: parent.top; left: parent.left; right: parent.right }
                height: 56
                color: "transparent"

                RowLayout {
                    anchors { fill: parent; leftMargin: 20; rightMargin: 16 }
                    spacing: 8

                    // 会话名（双击重命名）
                    Text {
                        id: sessionNameLabel
                        text: mainView.sessionName
                        color: cText; font.pixelSize: 15; font.bold: true
                        Layout.fillWidth: true
                        elide: Text.ElideRight
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onDoubleClicked: renameDialog.open()
                        }
                        ToolTip.text: "双击重命名"
                        ToolTip.visible: nameTipHover.hovered
                        ToolTip.delay: 800
                        HoverHandler { id: nameTipHover }
                    }

                    // 停止生成
                    Rectangle {
                        width: 80; height: 30; radius: 5
                        visible: mainView.isStreaming
                        color: "#ED4245"
                        Row {
                            anchors.centerIn: parent; spacing: 5
                            Text { text: "⏹"; font.pixelSize: 12 }
                            Text { text: "停止"; color: "white"; font.pixelSize: 12 }
                        }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: mainView.stopGeneration()
                        }
                    }

                    // 清空对话
                    Rectangle {
                        width: 80; height: 30; radius: 5
                        color: clearHover.hovered ? "#ED4245" : cHighlight
                        Row {
                            anchors.centerIn: parent; spacing: 5
                            Text { text: "🗑️"; font.pixelSize: 12 }
                            Text { text: "清空"; color: cText; font.pixelSize: 12 }
                        }
                        HoverHandler { id: clearHover }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: clearDialog.open()
                        }
                    }

                    // 显示/隐藏思考过程（右上角）
                    Rectangle {
                        width: 110; height: 30; radius: 5
                        color: thinkToggleHover.hovered
                            ? Qt.lighter(cHighlight, 1.12)
                            : (settings.showThinking ? "#3D4270" : cHighlight)
                        border.color: settings.showThinking ? cAccent : "transparent"
                        Row {
                            anchors.centerIn: parent; spacing: 6
                            Text { text: "🧠"; font.pixelSize: 12 }
                            Text {
                                text: settings.showThinking ? "思考：开" : "思考：关"
                                color: cText
                                font.pixelSize: 12
                            }
                        }
                        ToolTip.text: settings.showThinking ? "点击隐藏思考过程" : "点击显示思考过程"
                        ToolTip.visible: thinkToggleHover.hovered
                        ToolTip.delay: 600
                        HoverHandler { id: thinkToggleHover }
                        MouseArea {
                            anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                            onClicked: settings.showThinking = !settings.showThinking
                        }
                    }
                }

                Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 1; color: cBorder }
            }

            // ── 输入区 ────────────────────────────────────────────────────────
            Rectangle {
                id: inputPanel
                anchors { bottom: parent.bottom; left: parent.left; right: parent.right }
                height: 130
                color: cSidebar

                Rectangle {
                    anchors { fill: parent; margins: 16; topMargin: 10 }
                    color: cInput; radius: 8
                    border.color: inputArea.activeFocus ? "#5865F2" : cBorder

                    ColumnLayout {
                        anchors { fill: parent; margins: 10 }
                        spacing: 0

                        ScrollView {
                            Layout.fillWidth: true; Layout.fillHeight: true
                            clip: true
                            TextArea {
                                id: inputArea
                                placeholderText: "输入消息… (Enter 发送，Shift+Enter 换行)"
                                placeholderTextColor: cMuted
                                color: cText; font.pixelSize: 14
                                wrapMode: TextArea.Wrap
                                background: null
                                enabled: typeof mainView !== "undefined" ? !mainView.isStreaming : true

                                Keys.onPressed: (event) => {
                                    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) {
                                        if (event.modifiers & Qt.ShiftModifier) {
                                        } else {
                                            event.accepted = true
                                            _sendMsg()
                                        }
                                    }
                                }
                            }
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8

                            // 左侧：模式下拉菜单
                            ComboBox {
                                id: modeCombo
                                implicitWidth: 120
                                implicitHeight: 32
                                model: ["对话", "智能体", "规划"]
                                currentIndex: {
                                    var m = mainView.chatMode
                                    if (m === "chat") return 0
                                    if (m === "agent") return 1
                                    if (m === "planning") return 2
                                    return 0
                                }
                                onCurrentIndexChanged: {
                                    var modes = ["chat", "agent", "planning"]
                                    if (mainView.chatMode !== modes[currentIndex])
                                        mainView.chatMode = modes[currentIndex]
                                }
                                contentItem: Text {
                                    leftPadding: 10
                                    text: modeCombo.displayText
                                    color: cText
                                    font.pixelSize: 12
                                    verticalAlignment: Text.AlignVCenter
                                }
                                background: Rectangle {
                                    color: cInput
                                    radius: 6
                                    border.color: cBorder
                                }
                            }

                            // 字数提示
                            Text {
                                text: inputArea.text.length > 0
                                    ? inputArea.text.length + " 字"
                                    : ""
                                color: cMuted; font.pixelSize: 11
                                Layout.fillWidth: true
                            }

                            // 发送按钮
                            Rectangle {
                                width: 36; height: 32; radius: 6
                                color: (inputArea.text.trim().length > 0 && !mainView.isStreaming)
                                    ? cAccent : cHighlight

                                Text {
                                    anchors.centerIn: parent; text: "➤"; font.pixelSize: 17
                                    color: (inputArea.text.trim().length > 0 && !mainView.isStreaming)
                                        ? "white" : cMuted
                                }
                                MouseArea {
                                    anchors.fill: parent; cursorShape: Qt.PointingHandCursor
                                    onClicked: _sendMsg()
                                }
                            }
                        }
                    }
                }
            }

            // ── 消息列表 ──────────────────────────────────────────────────────
            ListView {
                id: chatListView
                anchors {
                    top:    chatHeader.bottom
                    bottom: inputPanel.top
                    left:   parent.left
                    right:  parent.right
                }
                clip: true
                spacing: 8
                topMargin: 16; bottomMargin: 8
                cacheBuffer: 3000
                reuseItems: true

                ScrollBar.vertical: ScrollBar {
                    policy: ScrollBar.AsNeeded
                    contentItem: Rectangle {
                        implicitWidth: 6
                        radius: 3
                        color: parent.pressed ? "#60636A" : (parent.hovered ? "#60636A" : "#484B52")
                    }
                    background: Rectangle {
                        implicitWidth: 6
                        color: "#2E3035"
                        radius: 3
                    }
                }

                model: mainView.messagesModel

                delegate: ChatMessage {
                    width: chatListView.width
                    role: (model && model.role) ? model.role : "user"
                    msgContent: (model && model.content) ? model.content : ""
                    thinkingContent: (model && model.thinking) ? model.thinking : ""
                    isThinking: (model && model.isThinking) ? true : false
                    messageIndex:     index
                }

                onCountChanged: Qt.callLater(function() {
                    if (typeof mainView !== "undefined" && (mainView.isStreaming || atYEnd))
                        positionViewAtEnd()
                })
                onContentHeightChanged: Qt.callLater(function() {
                    if (typeof mainView !== "undefined" && (mainView.isStreaming || atYEnd))
                        positionViewAtEnd()
                })
            }

            // 覆盖层：鼠标置于对话区域时，滚轮可上下滚动对话列表（acceptedButtons: NoButton 不拦截点击）
            MouseArea {
                anchors {
                    top: chatHeader.bottom
                    bottom: inputPanel.top
                    left: parent.left
                    right: parent.right
                }
                z: 10
                acceptedButtons: Qt.NoButton
                onWheel: function(wheel) {
                    // 这里是调节鼠标滑动速度，现在是2倍速度
                    var dy = wheel.angleDelta.y * 2
                    if (chatListView.verticalOvershoot !== 0.0 ||
                        (dy > 0 && chatListView.verticalVelocity <= 0) ||
                        (dy < 0 && chatListView.verticalVelocity >= 0)) {
                        chatListView.flick(0, dy - chatListView.verticalVelocity)
                    } else {
                        chatListView.cancelFlick()
                    }
                    wheel.accepted = true
                }
            }

            Timer {
                interval: 200
                repeat: true
                running: typeof mainView !== "undefined" && mainView.isStreaming
                onTriggered: {
                    if (mainView.isStreaming && chatListView.atYEnd)
                        chatListView.positionViewAtEnd()
                }
            }

            // ── 右下角：对话进度 ────────────────────────────────────────────────
            Text {
                anchors {
                    right: parent.right
                    bottom: inputPanel.top
                    rightMargin: 14
                    bottomMargin: 4
                }
                text: chatListView.count > 0
                      ? (chatListView.count + " / " + chatListView.count)
                      : "0 / 0"
                color: cMuted
                font.pixelSize: 11
            }
        }
    }

    // 文件夹重命名对话框（用于历史树右键）
    Dialog {
        id: folderRenameDialog
        title: "重命名文件夹"
        modal: true
        anchors.centerIn: parent
        width: 320

        property string targetId: ""

        background: Rectangle { color: "#1E1F22"; radius: 8; border.color: cBorder }

        contentItem: Column {
            spacing: 10; padding: 16
            Text { text: "请输入新名称："; color: cText; font.pixelSize: 13 }
            TextField {
                id: folderRenameField
                width: 280; height: 36
                color: cText; font.pixelSize: 13
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                leftPadding: 10
                selectByMouse: true
                Keys.onReturnPressed: {
                    if (folderRenameDialog.targetId !== "") {
                        history.renameNode(folderRenameDialog.targetId, text)
                    }
                    folderRenameDialog.close()
                }
            }
        }

        footer: Row {
            spacing: 8; padding: 12; layoutDirection: Qt.RightToLeft
            Button {
                text: "确定"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: cAccent }
                onClicked: {
                    if (folderRenameDialog.targetId !== "") {
                        history.renameNode(folderRenameDialog.targetId, folderRenameField.text)
                    }
                    folderRenameDialog.close()
                }
            }
            Button {
                text: "取消"; width: 80; height: 32
                contentItem: Text { text: parent.text; color: cText; font.pixelSize: 13;
                                    horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
                background: Rectangle { radius: 5; color: cInput; border.color: cBorder }
                onClicked: folderRenameDialog.close()
            }
        }

        onAboutToShow: {
            folderRenameField.forceActiveFocus()
            folderRenameField.selectAll()
        }
    }

    // ── 历史项右键菜单 ──────────────────────────────────────────────────────────
    Menu {
        id: historyItemMenu
        property var targetNode: null

        MenuItem {
            text: "重命名"
            onTriggered: {
                if (!historyItemMenu.targetNode)
                    return
                var n = historyItemMenu.targetNode
                if (n.type === "session") {
                    if (n.id !== mainView.currentSession)
                        mainView.loadSession(n.id)
                    renameDialog.open()
                } else if (n.type === "folder") {
                    folderRenameDialog.targetId = n.id
                    folderRenameField.text = n.name
                    folderRenameDialog.open()
                }
            }
        }

        MenuItem {
            text: "删除"
            onTriggered: {
                if (!historyItemMenu.targetNode)
                    return
                history.deleteNode(historyItemMenu.targetNode.id)
            }
        }

        MenuSeparator {}

        MenuItem {
            text: "新建文件夹"
            onTriggered: {
                if (!historyItemMenu.targetNode)
                    return
                var n = historyItemMenu.targetNode
                var pid = ""
                if (n.type === "folder")
                    pid = n.id
                else if (n.parentId)
                    pid = n.parentId
                history.createFolder("新文件夹", pid)
            }
        }
    }

    // ── 发送函数 ──────────────────────────────────────────────────────────────
    function _sendMsg() {
        let t = inputArea.text.trim()
        if (t !== "" && !mainView.isStreaming) {
            mainView.sendMessage(t)
            inputArea.text = ""
        }
    }
}
