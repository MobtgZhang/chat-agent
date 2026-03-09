// qml/MarkdownRender.qml
// 使用 Qt 内置 TextEdit MarkdownText（不含 LaTeX 时）
// 含 LaTeX 数学公式时使用 MarkdownMathRender（WebEngineView + KaTeX）
import QtQuick 2.15

Item {
    id: root
    property string markdownText: ""
    property color  textColor:    "#DBDEE1"
    property int    fontSize:     14

    implicitHeight: Math.max(20, mdText.contentHeight)
    height: implicitHeight

    TextEdit {
        id: mdText
        anchors.left: parent.left
        anchors.right: parent.right
        text: root.markdownText
        textFormat: TextEdit.MarkdownText
        wrapMode: TextEdit.Wrap
        color: root.textColor
        font.pixelSize: root.fontSize
        readOnly: true
        selectByMouse: true
    }
}
