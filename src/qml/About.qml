// qml/About.qml
import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import QtQuick.Window 2.15

Window {
    id: aboutWin
    title: "关于"
    width: 380; height: 300
    minimumWidth: 360; minimumHeight: 280
    color: "#2B2D31"
    flags: Qt.Dialog
    modality: Qt.ApplicationModal
    ColumnLayout {
        anchors.centerIn: parent
        spacing: 14
        width: parent.width - 60

        // Logo + 名称
        Row {
            Layout.alignment: Qt.AlignHCenter
            spacing: 14
            Rectangle {
                width: 54; height: 54; radius: 12; color: "#F9A825"
                Text { anchors.centerIn: parent; text: "💬"; font.pixelSize: 28 }
            }
            Column {
                anchors.verticalCenter: parent.verticalCenter
                spacing: 4
                Text { text: about.appName;  color: "#DBDEE1"; font.pixelSize: 20; font.bold: true }
                Text { text: "v" + about.version; color: "#949BA4"; font.pixelSize: 13 }
            }
        }

        Rectangle { Layout.fillWidth: true; height: 1; color: "#3F4147" }

        Text {
            Layout.fillWidth: true
            text: about.description
            color: "#949BA4"; font.pixelSize: 13
            wrapMode: Text.Wrap
            lineHeight: 1.5
            horizontalAlignment: Text.AlignHCenter
        }

        Grid {
            Layout.alignment: Qt.AlignHCenter
            columns: 2; rowSpacing: 6; columnSpacing: 20
            Repeater {
                model: [
                    ["授权协议", about.license],
                    ["Qt 版本",  about.qtVersion],
                    ["编译时间", about.buildDate]
                ]
                delegate: Row {
                    spacing: 6
                    Text { text: modelData[0] + "："; color: "#949BA4"; font.pixelSize: 12 }
                    Text { text: modelData[1];         color: "#DBDEE1"; font.pixelSize: 12 }
                }
            }
        }

        Button {
            Layout.alignment: Qt.AlignHCenter
            text: "关闭"; width: 100; height: 32
            contentItem: Text { text: parent.text; color: "white"; font.pixelSize: 13;
                                horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            background: Rectangle { radius: 6; color: "#5865F2" }
            onClicked: aboutWin.close()
        }
    }
}
