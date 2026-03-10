// qml/ChatMessage.qml — ChatGPT 风格
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    width: ListView.view ? ListView.view.width : 700
    // 高度根据内容列自适应，保证 Markdown / 数学公式完全显示
    height: bubbleColumn.implicitHeight + 32
    property string role:           "user"
    property string msgContent:      ""

    // 主题色（Dark / Light）— 更舒适的现代配色
    readonly property bool isLight:  (typeof settings !== "undefined" && settings.theme === "light")
    readonly property color cTextAi:    isLight ? "#1A1B1E" : "#E4E6EB"
    readonly property color cTextUser:   "#FFFFFF"
    readonly property color cMuted:     isLight ? "#6B7280" : "#9CA3AF"
    readonly property color cBubbleAi:   isLight ? "#F3F4F6" : "#374151"
    readonly property color cBubbleAiBorder:   isLight ? "#E5E7EB" : "#4B5563"
    readonly property color cBubbleUser: isLight ? "#4F46E5" : "#6366F1"
    readonly property color cBubbleUserBorder: isLight ? "#4338CA" : "#818CF8"
    readonly property color cThinkBg:    isLight ? "#F8FAFC" : "#1F2937"
    readonly property color cThinkBorder: isLight ? "#E2E8F0" : "#374151"
    readonly property color cEditBg:     isLight ? "#FFFFFF" : "#374151"
    readonly property color cEditText:   isLight ? "#1A1B1E" : "#E4E6EB"
    readonly property color cActionHover: isLight ? "#E5E7EB" : "#4B5563"
    readonly property color cActionText: isLight ? "#6B7280" : "#9CA3AF"
    readonly property color cBtnCancel:   isLight ? "#F3F4F6" : "#4B5563"
    readonly property color cMenuBg:     isLight ? "#FFFFFF" : "#111827"
    readonly property color cMenuBorder: isLight ? "#E5E7EB" : "#374151"
    readonly property color cAvatarAi:    isLight ? "#F59E0B" : "#FBBF24"
    readonly property color cAvatarUser: isLight ? "#4F46E5" : "#6366F1"
    property string thinkingContent:""
    property bool   isThinking:     false
    property string ragSearchStatus: ""   // "" | "rewriting" | "searching" | "done"
    property var    ragLinks:      []     // [{text, url, snippet, index}] 可点击打开
    property int    rewriteDurationMs: 0  // 查询重写耗时
    property string rewriteThinking: ""   // 重写思考过程
    property int    searchDurationMs: 0   // 搜索耗时
    property real   ragElapsedTime: 0.0   // 重写/搜索进行中时的实时计时
    property var    blocks:        []
    property int    messageIndex:   -1

    readonly property bool useBlocks: isAI && blocks && blocks.length > 0

    // 版本导航（预留扩展：当前为 1/1，后续可接入多版本）
    property int    currentVersion: 1
    property int    totalVersions:  1

    property bool isAI: role === "ai" || role === "assistant"

    function toggleBlockExpanded(i) {
        var v = (blockExpandedList || []).slice()
        while (v.length <= i) v.push(true)
        v[i] = !v[i]
        blockExpandedList = v
    }
    function isBlockExpanded(i) {
        var v = blockExpandedList || []
        return i >= v.length || v[i] !== false
    }
    function hasMath(s) {
        if (!s || typeof s !== "string") return false
        return /\$\$|\$[^\s$]|\\[\[\()\]]/.test(s)
    }
    function hasCodeBlocks(s) {
        if (!s || typeof s !== "string") return false
        return /```[\s\S]*?```/.test(s)
    }
    function hasTable(s) {
        if (!s || typeof s !== "string") return false
        // GFM 表格分隔行：| --- | 或 |:---|:---:|---:|
        return /\|[-\s:]+\|/.test(s)
    }

    Component {
        id: mdRenderComp
        MarkdownRender { }
    }
    Component {
        id: mathRenderComp
        MarkdownMathRender { }
    }

    property bool editing:        false
    property bool thinkExpanded:  false
    property bool rewriteThinkExpanded: false  // 重写气泡默认折叠
    property var blockExpandedList: []  // agent 模式下每个思考块的展开状态 [bool...]

    Timer {
        id: ragTimer
        interval: 100
        running: isAI && (ragSearchStatus === "rewriting" || ragSearchStatus === "searching")
        repeat: true
        onTriggered: root.ragElapsedTime += 0.1
    }
    onRagSearchStatusChanged: {
        if (ragSearchStatus === "done" || ragSearchStatus === "") root.ragElapsedTime = 0
    }
    // 用户从关→开切换思考按钮时，若有已记录的思考内容则自动展开显示
    Connections {
        target: settings
        function onShowThinkingChanged() {
            if (settings.showThinking && isAI && thinkingContent !== "")
                thinkExpanded = true
        }
    }
    // 历史加载后：与思考按钮切换时保持一致的展开状态
    Component.onCompleted: {
        if (settings.showThinking && isAI && thinkingContent !== "")
            thinkExpanded = true
    }

    property real thinkTime: 0.0
    Timer {
        id: thinkTimer
        interval: 100; running: root.isThinking; repeat: true
        onTriggered: root.thinkTime += 0.1
    }
    onIsThinkingChanged: {
        if (isThinking) {
            root.thinkTime = 0  // 每次开始新一轮思考时重置计时
            if (settings.showThinking && isAI) thinkExpanded = true
        }
    }

    // ChatGPT 风格：用户右对齐，AI 左对齐
    Row {
        id: outerRow
        anchors.top: parent.top
        anchors.topMargin: 14
        width: parent.width - 48
        spacing: 14
        layoutDirection: isAI ? Qt.LeftToRight : Qt.RightToLeft

        // 头像 — 圆角+边框，主题色
        Rectangle {
            width: 36; height: 36; radius: 10
            color: isAI ? root.cAvatarAi : root.cAvatarUser
            border.width: 1
            border.color: Qt.rgba(1,1,1, isLight ? 0.35 : 0.15)
            Text {
                anchors.centerIn: parent
                text: isAI ? "🤖" : "Me"
                color: "white"
                font.bold: true
                font.pixelSize: 13
            }
        }

        // 气泡 + 内容
        Column {
            id: bubbleColumn
            width: Math.min(outerRow.width - 36 - 16, 640)
            spacing: 0

            // 重写中 / 搜索中（实时计时）；完成时显示：重写 Xs  搜索 Xs（秒）
            Item {
                width: parent.width
                height: 20
                visible: isAI && ragSearchStatus !== ""
                Row {
                    spacing: 8
                    anchors.verticalCenter: parent.verticalCenter
                    Text {
                        text: ragSearchStatus === "rewriting" ? "✏️" : "🔍"
                        font.pixelSize: 12
                    }
                    Text {
                        text: {
                            if (ragSearchStatus === "rewriting")
                                return "重写中 " + ragElapsedTime.toFixed(1) + "s"
                            if (ragSearchStatus === "searching")
                                return "搜索中 " + ragElapsedTime.toFixed(1) + "s"
                            var p = []
                            if (rewriteDurationMs > 0) p.push("重写 " + (rewriteDurationMs / 1000).toFixed(1) + "s")
                            if (searchDurationMs > 0) p.push("搜索 " + (searchDurationMs / 1000).toFixed(1) + "s")
                            return p.length > 0 ? p.join("  ") : "—"
                        }
                        color: root.cMuted
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
            }

            // 重写气泡（默认折叠，可点击展开）
            Column {
                width: parent.width
                spacing: 4
                visible: isAI && rewriteThinking !== "" && ragSearchStatus === "done"
                Item {
                    width: parent.width
                    height: 22
                    Row {
                        spacing: 6
                        anchors.verticalCenter: parent.verticalCenter
                        Text {
                            text: "✏️ 重写过程"
                            color: root.cMuted
                            font.pixelSize: 11
                            font.italic: true
                        }
                        Text {
                            text: root.rewriteThinkExpanded ? " ▲" : " ▼"
                            color: root.cMuted
                            font.pixelSize: 11
                        }
                    }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.rewriteThinkExpanded = !root.rewriteThinkExpanded
                    }
                }
                Rectangle {
                    width: parent.width - 8
                    visible: root.rewriteThinkExpanded
                    height: visible && rewriteThinkLoader.item ? (rewriteThinkLoader.item.implicitHeight || rewriteThinkLoader.item.height) + 12 : 0
                    color: root.cThinkBg
                    radius: 12
                    border.width: 1
                    border.color: root.cThinkBorder
                    Loader {
                        id: rewriteThinkLoader
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        sourceComponent: (root.hasMath(rewriteThinking) || root.hasCodeBlocks(rewriteThinking) || root.hasTable(rewriteThinking)) ? mathRenderComp : mdRenderComp
                        onLoaded: {
                            item.textColor = root.cMuted
                            item.fontSize = 12
                        }
                    }
                    Binding {
                        target: rewriteThinkLoader.item
                        property: "markdownText"
                        value: rewriteThinking || ""
                        when: rewriteThinkLoader.item
                    }
                }
            }

            // 搜索完成但无结果时的提示
            Text {
                width: parent.width - 8
                visible: isAI && ragSearchStatus === "done" && (!ragLinks || ragLinks.length === 0)
                text: "未获取到搜索结果，可能是网络或搜索引擎解析问题，可尝试切换搜索引擎或代理。"
                color: root.cMuted
                font.pixelSize: 11
                font.italic: true
                wrapMode: Text.WordWrap
            }
            // 搜索得到的网页列表（ChatGPT 风格：可复制、可打开）
            Column {
                width: parent.width - 8
                spacing: 8
                visible: isAI && ragLinks && ragLinks.length > 0
                Repeater {
                    model: root.ragLinks
                    delegate: Rectangle {
                        width: parent.width - 4
                        radius: 8
                        color: ragCardHover.hovered ? (root.isLight ? "#EBEDF1" : "#2A2C30") : (root.isLight ? "#F0F2F5" : "#25272A")
                        border.color: root.cThinkBorder
                        implicitHeight: ragCardCol.implicitHeight + 16

                        Column {
                            id: ragCardCol
                            width: parent.width - 24
                            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                            spacing: 6
                            // 可复制的正文：标题 + 摘要 + URL
                            TextArea {
                                id: ragContentArea
                                width: parent.width - 4
                                leftPadding: 0; rightPadding: 0; topPadding: 0; bottomPadding: 0
                                background: Item {}
                                readOnly: true
                                selectByMouse: true
                                wrapMode: TextArea.Wrap
                                textFormat: TextArea.PlainText
                                font.pixelSize: 12
                                color: root.cTextAi
                                text: {
                                    var d = modelData
                                    if (!d) return ""
                                    var trunc = function(s, n) { return (s && s.length > n) ? s.substring(0, n) + "…" : (s || "") }
                                    var idx = (d.index || (model.index + 1))
                                    var rawTitle = d.text || ""
                                    var rawSnip = d.snippet || ""
                                    var rawUrl = (d.url || "")
                                    var title = trunc(rawTitle, 20)
                                    var snip = trunc(rawSnip, 40)
                                    var url = trunc(rawUrl, 20)
                                    if (rawSnip && rawSnip !== rawTitle && rawSnip.length > 2)
                                        return "[" + idx + "] " + title + "\n" + snip + "\n" + url
                                    return "[" + idx + "] " + title + "\n" + url
                                }
                            }
                            Row {
                                spacing: 8
                                // 打开链接按钮（不阻挡复制）
                                Rectangle {
                                    width: openBtnText.implicitWidth + 16
                                    height: 24
                                    radius: 4
                                    color: openBtnHover.hovered ? (root.isLight ? "#D8D8DC" : "#3A3C40") : (root.isLight ? "#E8E8EC" : "#2E3035")
                                    Text {
                                        id: openBtnText
                                        anchors.centerIn: parent
                                        text: (localeBridge && localeBridge.t && localeBridge.tVersion >= 0) ? (localeBridge.t.openLink || "打开链接") : "打开链接"
                                        font.pixelSize: 11
                                        color: root.cMuted
                                    }
                                    HoverHandler { id: openBtnHover }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: {
                                            var u = (modelData && modelData.url) ? modelData.url : ""
                                            if (u && typeof clipboardBridge !== "undefined" && clipboardBridge)
                                                clipboardBridge.openUrl(u)
                                        }
                                    }
                                }
                            }
                        }
                        HoverHandler { id: ragCardHover }
                    }
                }
            }

            // 思考状态（仅 AI）：思考中 / 思考完成。agent 模式下改为每个思考块自带计时，此处仅 chat 模式显示
            Item {
                width: parent.width
                height: 20
                visible: isAI && !root.useBlocks && (isThinking || thinkTime > 0)
                Row {
                    spacing: 6
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "🧠"; font.pixelSize: 12 }
                    Text {
                        text: (localeBridge && localeBridge.t && localeBridge.tVersion >= 0)
                            ? (isThinking
                                ? (localeBridge.t.thinkingInProgress || "思考中... ") + thinkTime.toFixed(1) + (localeBridge.t.thinkingSecondsUnit || "s")
                                : (localeBridge.t.thinkingDone || "思考完成 (") + thinkTime.toFixed(1) + (localeBridge.t.thinkingSeconds || "s)") +
                                (settings.showThinking && thinkingContent !== "" ? (thinkExpanded ? "  ▲" : "  ▼") : ""))
                            : (isThinking ? "思考中... " + thinkTime.toFixed(1) + "s" : "思考完成 (" + thinkTime.toFixed(1) + "s)" +
                            (settings.showThinking && thinkingContent !== "" ? (thinkExpanded ? "  ▲" : "  ▼") : ""))
                        color: root.cMuted
                        font.pixelSize: 11
                        font.italic: true
                    }
                }
                MouseArea {
                    anchors.fill: parent
                    cursorShape: Qt.PointingHandCursor
                    onClicked: if (settings.showThinking && thinkingContent !== "") root.thinkExpanded = !root.thinkExpanded
                }
            }

            // ── 分块模式（agent/planning）：思考→回复→工具 分段显示 ──
            Column {
                width: parent.width
                spacing: 8
                visible: root.useBlocks

                Repeater {
                    model: root.blocks
                    delegate: Item {
                        width: parent.width - 16
                        height: blockCol.implicitHeight
                        Column {
                            id: blockCol
                            width: parent.width
                            spacing: 4

                            // 思考块：带思考中/完成计时 + 可折叠
                            Column {
                                id: thinkBlockCol
                                width: parent.width
                                visible: modelData.type === "thinking" && settings.showThinking
                                spacing: 4
                                property bool isCurrentThinking: modelData.type === "thinking" && index === root.blocks.length - 1 && root.isThinking
                                property real blockTime: isCurrentThinking ? root.thinkTime : (modelData.durationSec !== undefined ? modelData.durationSec : 0)
                                Item {
                                    width: parent.width
                                    height: 22
                                    visible: modelData.content !== "" || thinkBlockCol.isCurrentThinking
                                    Row {
                                        spacing: 6
                                        anchors.verticalCenter: parent.verticalCenter
                                        Text { text: "🧠"; font.pixelSize: 12 }
                                        Text {
                                            text: (localeBridge && localeBridge.t && localeBridge.tVersion >= 0)
                                                ? (thinkBlockCol.isCurrentThinking
                                                    ? (localeBridge.t.thinkingInProgress || "思考中... ") + thinkBlockCol.blockTime.toFixed(1) + (localeBridge.t.thinkingSecondsUnit || "s")
                                                    : (localeBridge.t.thinkingDone || "思考完成 (") + thinkBlockCol.blockTime.toFixed(1) + (localeBridge.t.thinkingSeconds || "s)"))
                                                : (thinkBlockCol.isCurrentThinking ? "思考中... " : "思考完成 (") + thinkBlockCol.blockTime.toFixed(1) + "s)"
                                            color: root.cMuted
                                            font.pixelSize: 11
                                            font.italic: true
                                        }
                                        Text {
                                            visible: modelData.content !== ""
                                            text: root.isBlockExpanded(index) ? "  ▲" : "  ▼"
                                            color: root.cMuted
                                            font.pixelSize: 11
                                        }
                                    }
                                    MouseArea {
                                        anchors.fill: parent
                                        cursorShape: Qt.PointingHandCursor
                                        onClicked: root.toggleBlockExpanded(index)
                                    }
                                }
                                Rectangle {
                                    width: parent.width
                                    visible: modelData.content !== "" && root.isBlockExpanded(index)
                                    height: visible && thinkBlkLoader.item ? (thinkBlkLoader.item.implicitHeight || thinkBlkLoader.item.height) + 12 : 0
                                    color: root.cThinkBg
                                    radius: 12
                                    border.width: 1
                                    border.color: root.cThinkBorder

                                    Loader {
                                        id: thinkBlkLoader
                                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                                        sourceComponent: (root.hasMath(modelData.content) || root.hasCodeBlocks(modelData.content) || root.hasTable(modelData.content)) ? mathRenderComp : mdRenderComp
                                        onLoaded: {
                                            item.textColor = root.cMuted
                                            item.fontSize = 12
                                        }
                                    }
                                    Binding {
                                        target: thinkBlkLoader.item
                                        property: "markdownText"
                                        value: modelData.content || ""
                                        when: thinkBlkLoader.item
                                    }
                                }
                            }

                            // 回复块
                            Rectangle {
                                width: parent.width
                                visible: modelData.type === "reply" && modelData.content !== ""
                                implicitHeight: visible ? (replyLoader.item ? (replyLoader.item.implicitHeight || replyLoader.item.height) + 20 : 0) : 0
                                color: root.cBubbleAi
                                radius: 16
                                border.width: 1
                                border.color: root.cBubbleAiBorder

                                Loader {
                                    id: replyLoader
                                    width: parent.width - 24
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 8
                                    sourceComponent: (root.hasMath(modelData.content) || root.hasCodeBlocks(modelData.content) || root.hasTable(modelData.content)) ? mathRenderComp : mdRenderComp
                                    onLoaded: item.textColor = root.cTextAi
                                }
                                Binding {
                                    target: replyLoader.item
                                    property: "markdownText"
                                    value: modelData.content || ""
                                    when: replyLoader.item
                                }
                            }

                            // 工具调用块：显示工具名、参数、执行结果
                            Rectangle {
                                width: parent.width
                                visible: modelData.type === "tool"
                                implicitHeight: visible ? toolCol.implicitHeight + 18 : 0
                                color: root.isLight ? "#F1F5F9" : "#374151"
                                radius: 12
                                border.width: 1
                                border.color: root.cThinkBorder

                                Column {
                                    id: toolCol
                                    width: parent.width - 16
                                    anchors.horizontalCenter: parent.horizontalCenter
                                    anchors.top: parent.top
                                    anchors.topMargin: 8
                                    anchors.bottomMargin: 8
                                    spacing: 6

                                    Row {
                                        spacing: 8
                                        Text {
                                            text: "🔧 " + (modelData.toolName || "")
                                            color: root.cMuted
                                            font.pixelSize: 12
                                            font.bold: true
                                        }
                                        Text {
                                            visible: modelData.durationSec !== undefined
                                            text: "执行 " + (modelData.durationSec !== undefined ? modelData.durationSec.toFixed(1) : "0") + "s"
                                            color: root.cMuted
                                            font.pixelSize: 11
                                            font.italic: true
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        visible: {
                                            var a = modelData.args
                                            return !!(a && Object.keys(a).length > 0)
                                        }
                                        text: {
                                            var a = modelData.args
                                            if (!a) return ""
                                            var parts = []
                                            for (var k in a) parts.push(k + ": " + a[k])
                                            return parts.join("\n")
                                        }
                                        color: root.cMuted
                                        font.pixelSize: 11
                                        font.family: "monospace"
                                        wrapMode: Text.Wrap
                                    }
                                    // web_search 专用：可点击的链接列表（与 chat 模式 ragLinks 一致）
                                    Column {
                                        width: parent.width
                                        visible: {
                                            if ((modelData.toolName || "") !== "web_search") return false
                                            try {
                                                var j = JSON.parse(modelData.result || "{}")
                                                return j.related && Array.isArray(j.related) && j.related.length > 0
                                            } catch(e) { return false }
                                        }
                                        spacing: 4
                                        Repeater {
                                            model: {
                                                var r = []
                                                try {
                                                    var j = JSON.parse(modelData.result || "{}")
                                                    if (j.related && Array.isArray(j.related))
                                                        for (var i = 0; i < j.related.length; i++)
                                                            r.push({text: (j.related[i].title || j.related[i].text || ""), url: (j.related[i].url || "")})
                                                } catch(e) {}
                                                return r
                                            }
                                            delegate: Rectangle {
                                                width: toolCol.width - 4
                                                height: webLinkRow.implicitHeight + 12
                                                radius: 6
                                                color: webLinkHover.hovered ? (root.isLight ? "#EBEDF1" : "#2A2C30") : (root.isLight ? "#F0F2F5" : "#25272A")
                                                border.color: root.cThinkBorder
                                                Row {
                                                    id: webLinkRow
                                                    anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 10 }
                                                    spacing: 8
                                                    Text { text: "🔗"; font.pixelSize: 12; color: root.cMuted; anchors.verticalCenter: parent.verticalCenter }
                                                    Text {
                                                        width: parent.width - 40
                                                        text: {
                                                            var t = (modelData && modelData.text) ? modelData.text : ""
                                                            return (t && t.length > 20) ? t.substring(0, 20) + "…" : t
                                                        }
                                                        color: root.cTextAi
                                                        font.pixelSize: 12
                                                        elide: Text.ElideRight
                                                        wrapMode: Text.WordWrap
                                                        maximumLineCount: 2
                                                        anchors.verticalCenter: parent.verticalCenter
                                                    }
                                                }
                                                HoverHandler { id: webLinkHover }
                                                MouseArea {
                                                    anchors.fill: parent
                                                    cursorShape: Qt.PointingHandCursor
                                                    hoverEnabled: true
                                                    onClicked: {
                                                        var u = (modelData && modelData.url) ? modelData.url : ""
                                                        if (u && typeof clipboardBridge !== "undefined" && clipboardBridge)
                                                            clipboardBridge.openUrl(u)
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Text {
                                        width: parent.width
                                        visible: {
                                            if ((modelData.toolName || "") === "web_search") {
                                                try {
                                                    var j = JSON.parse(modelData.result || "{}")
                                                    return !(j.related && Array.isArray(j.related) && j.related.length > 0)
                                                } catch(e) { return true }
                                            }
                                            return true
                                        }
                                        text: {
                                            var r = modelData.result || ""
                                            try {
                                                var j = JSON.parse(r)
                                                if (j.error) return "❌ " + j.error
                                                if ((modelData.toolName || "") === "web_search") {
                                                    if (j.abstract) return j.abstract
                                                    if (j.searchUrl) return "未解析到结果，请访问 searchUrl 手动搜索。"
                                                }
                                                if (typeof j.exitCode !== "undefined")
                                                    return "退出码: " + j.exitCode + (j.stdout ? "\n\n" + j.stdout : "")
                                                if (j.stdout) return j.stdout
                                            } catch(e) {}
                                            return r
                                        }
                                        color: root.cTextAi
                                        font.pixelSize: 12
                                        font.family: "monospace"
                                        wrapMode: Text.Wrap
                                    }
                                }
                            }
                        }
                    }
                }
            }

            // ── 传统模式（chat）：单一思考+单一回复 ──
            Column {
                width: parent.width
                spacing: 4
                visible: !root.useBlocks && settings.showThinking && isAI

                Rectangle {
                    id: thinkBox
                    width: parent.width
                    visible: thinkExpanded && thinkingContent !== ""
                    height: visible && thinkLoader.item ? (thinkLoader.item.implicitHeight || thinkLoader.item.height) + 12 : 0
                    color: root.cThinkBg
                    radius: 12
                    border.width: 1
                    border.color: root.cThinkBorder

                    Loader {
                        id: thinkLoader
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
                        sourceComponent: (root.hasMath(root.thinkingContent) || root.hasCodeBlocks(root.thinkingContent) || root.hasTable(root.thinkingContent)) ? mathRenderComp : mdRenderComp
                        onLoaded: {
                            item.markdownText = root.thinkingContent
                            item.textColor = root.cMuted
                            item.fontSize = 12
                        }
                    }
                }
            }

            Text {
                width: parent.width
                visible: !root.useBlocks && settings.showThinking && isAI && root.msgContent === "" && root.isThinking
                text: "▍"
                color: root.cMuted
                font.pixelSize: 14
            }

            Rectangle {
                id: bubble
                width: parent.width
                visible: !root.useBlocks
                implicitHeight: visible ? (contentCol.implicitHeight + 20) : 0
                color: isAI ? root.cBubbleAi : root.cBubbleUser
                radius: 16
                border.width: 1
                border.color: isAI ? root.cBubbleAiBorder : root.cBubbleUserBorder

                Column {
                    id: contentCol
                    width: parent.width - 28
                    anchors.horizontalCenter: parent.horizontalCenter
                    anchors.top: parent.top
                    topPadding: 12
                    bottomPadding: 12
                    spacing: 10

                    Loader {
                        id: contentLoader
                        width: contentCol.width
                        visible: root.msgContent !== "" && !root.editing
                        sourceComponent: (root.hasMath(root.msgContent) || root.hasCodeBlocks(root.msgContent) || root.hasTable(root.msgContent)) ? mathRenderComp : mdRenderComp
                        onLoaded: {
                            item.markdownText = root.msgContent
                            item.textColor = isAI ? root.cTextAi : root.cTextUser
                        }
                    }

                    Column {
                        width: parent.width
                        spacing: 8
                        visible: root.editing

                        TextArea {
                            id: editArea
                            width: parent.width
                            height: Math.max(60, implicitHeight)
                            text: root.msgContent
                            color: root.cEditText
                            font.pixelSize: 14
                            wrapMode: TextArea.Wrap
                            background: Rectangle {
                                color: root.cEditBg
                                radius: 8
                                border.color: root.isLight ? "#4F46E5" : "#6366F1"
                                border.width: 1
                            }
                            padding: 10
                        }
                    }
                }
            }

            // 气泡外边右下角：复制、修改、修改记录
            Row {
                width: parent.width
                layoutDirection: Qt.RightToLeft
                spacing: 4
                topPadding: 4

                // 非编辑模式：复制、修改、修改记录
                // 编辑模式：保存、取消

                // 修改记录（版本导航）
                Row {
                    spacing: 2
                    height: 24
                    // 仅对用户气泡显示修改记录（AI 回复不需要）
                    visible: !root.editing && !root.isAI

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 4
                        color: prevHover.hovered ? root.cActionHover : "transparent"
                        opacity: currentVersion > 1 ? 1 : 0.4
                        Text {
                            anchors.centerIn: parent
                            text: "◀"
                            color: root.cActionText
                            font.pixelSize: 10
                        }
                        HoverHandler { id: prevHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (currentVersion > 1 && typeof mainView !== "undefined")
                                    mainView.setUserMessageVersion(root.messageIndex, currentVersion - 2)
                            }
                        }
                    }

                    Text {
                        anchors.verticalCenter: parent.verticalCenter
                        text: currentVersion + "/" + totalVersions
                        color: root.cActionText
                        font.pixelSize: 11
                    }

                    Rectangle {
                        width: 22
                        height: 22
                        radius: 4
                        color: nextHover.hovered ? root.cActionHover : "transparent"
                        opacity: currentVersion < totalVersions ? 1 : 0.4
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            color: root.cActionText
                            font.pixelSize: 10
                        }
                        HoverHandler { id: nextHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (currentVersion < totalVersions && typeof mainView !== "undefined")
                                    mainView.setUserMessageVersion(root.messageIndex, currentVersion)
                            }
                        }
                    }
                }

                // 编辑模式：保存、取消
                Row {
                    spacing: 4
                    height: 24
                    visible: root.editing

                    Rectangle {
                        width: 44
                        height: 24
                        radius: 4
                        color: cancelHover.hovered ? root.cActionHover : root.cBtnCancel
                        Text {
                            anchors.centerIn: parent
                            text: (localeBridge && localeBridge.t && localeBridge.tVersion >= 0) ? localeBridge.t.cancel : "Cancel"
                            color: root.cActionText
                            font.pixelSize: 12
                        }
                        HoverHandler { id: cancelHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: root.editing = false
                        }
                    }

                    Rectangle {
                        width: 44
                        height: 24
                        radius: 4
                        color: saveHover.hovered ? "#6366F1" : (root.isLight ? "#4F46E5" : "#6366F1")
                        Text {
                            anchors.centerIn: parent
                            text: (localeBridge && localeBridge.t && localeBridge.tVersion >= 0) ? localeBridge.t.save : "Save"
                            color: "white"
                            font.pixelSize: 12
                        }
                        HoverHandler { id: saveHover }
                        MouseArea {
                            anchors.fill: parent
                            cursorShape: Qt.PointingHandCursor
                            onClicked: {
                                if (typeof mainView !== "undefined") {
                                    mainView.editAndRegenerate(root.messageIndex, editArea.text)
                                    root.editing = false
                                }
                            }
                        }
                    }
                }

                // 修改（铅笔图标）
                Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: editHover.hovered ? root.cActionHover : "transparent"
                    // 仅用户消息支持“修改”
                    visible: !root.editing && !root.isAI
                    Image {
                        anchors.centerIn: parent
                        source: root.isLight ? "qrc:/src/icons/pencil_light.svg" : "qrc:/src/icons/pencil.svg"
                        sourceSize: Qt.size(14, 14)
                        opacity: 0.9
                    }
                    HoverHandler { id: editHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            root.editing = true
                            editArea.text = root.msgContent
                            editArea.forceActiveFocus()
                        }
                    }
                }

                // 重新生成（仅用户消息：截断后续并重新请求）
                Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: regenHover.hovered ? root.cActionHover : "transparent"
                    visible: !root.editing && !root.isAI
                    Image {
                        anchors.centerIn: parent
                        source: root.isLight ? "qrc:/src/icons/regenerate_light.svg" : "qrc:/src/icons/regenerate.svg"
                        sourceSize: Qt.size(14, 14)
                        opacity: 0.9
                    }
                    HoverHandler { id: regenHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof mainView !== "undefined")
                                mainView.resendFrom(root.messageIndex + 1)
                        }
                    }
                }

                // 复制（与代码块复制按钮一致）
                Rectangle {
                    width: 24
                    height: 24
                    radius: 4
                    color: copyHover.hovered ? root.cActionHover : "transparent"
                    visible: !root.editing
                    Image {
                        anchors.centerIn: parent
                        source: root.isLight ? "qrc:/src/icons/copy_light.svg" : "qrc:/src/icons/copy.svg"
                        sourceSize: Qt.size(14, 14)
                        opacity: 0.9
                    }
                    HoverHandler { id: copyHover }
                    MouseArea {
                        anchors.fill: parent
                        cursorShape: Qt.PointingHandCursor
                        onClicked: {
                            if (typeof mainView === "undefined")
                                return

                            // 用户消息：永远只复制正文
                            if (!root.isAI) {
                                if (root.msgContent)
                                    mainView.copyToClipboard(root.msgContent)
                                return
                            }

                            // AI 消息：
                            // - 思考过程开：复制「思考过程 + 两个换行 + 正文」
                            // - 思考过程关：只复制正文
                            var text = ""
                            if (settings.showThinking && root.thinkingContent) {
                                text = root.thinkingContent
                                if (root.msgContent)
                                    text += "\n\n" + root.msgContent
                            } else {
                                text = root.msgContent
                            }
                            if (text)
                                mainView.copyToClipboard(text)
                        }
                    }
                }
            }
        }
    }

    // 更多菜单：删除（用户）、重新生成（AI）
    Menu {
        id: moreMenu
        width: 140
        background: Rectangle {
            color: root.cMenuBg
            border.color: root.cMenuBorder
            radius: 6
        }

        MenuItem {
            text: (localeBridge && localeBridge.t && localeBridge.tVersion >= 0) ? localeBridge.t.deleteMessage : "Delete message"
            visible: !root.isAI
            implicitWidth: 140
            contentItem: Text {
                text: parent.text
                color: root.cTextAi
                font.pixelSize: 13
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: parent.highlighted ? root.cActionHover : "transparent"; radius: 4 }
            indicator: Item { width: 0 }
            onTriggered: mainView.deleteMessage(root.messageIndex)
        }
        MenuItem {
            text: (localeBridge && localeBridge.t && localeBridge.tVersion >= 0) ? localeBridge.t.regenerate : "Regenerate"
            visible: root.isAI
            implicitWidth: 140
            contentItem: Text {
                text: parent.text
                color: root.cTextAi
                font.pixelSize: 13
                leftPadding: 12
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { color: parent.highlighted ? root.cActionHover : "transparent"; radius: 4 }
            indicator: Item { width: 0 }
            onTriggered: mainView.resendFrom(root.messageIndex)
        }
    }

    onMsgContentChanged: {
        if (contentLoader.item) {
            contentLoader.item.markdownText = root.msgContent
            contentLoader.item.textColor = isAI ? root.cTextAi : root.cTextUser
        }
    }
    Connections {
        target: typeof settings !== "undefined" ? settings : null
        function onThemeChanged() {
            if (contentLoader.item)
                contentLoader.item.textColor = root.isAI ? root.cTextAi : root.cTextUser
            if (thinkLoader.item)
                thinkLoader.item.textColor = root.cMuted
        }
    }
    onThinkingContentChanged: {
        if (!isThinking && settings.showThinking && isAI && thinkingContent !== "")
            thinkExpanded = true
        if (thinkLoader.item)
            thinkLoader.item.markdownText = root.thinkingContent
    }
}
