import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Reusable piece of UI: shows a label and two buttons, knows nothing about where the data comes from.
// objectNames are what tests use to find items (Qt Quick Test findChild, Spix item paths).
Frame {
    id: card

    required property string label
    signal incrementClicked
    signal resetClicked

    ColumnLayout {
        anchors.fill: parent
        spacing: 12

        Label {
            objectName: "counterLabel"
            Layout.alignment: Qt.AlignHCenter
            text: card.label
            font.pixelSize: 18
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Button {
                objectName: "incrementButton"
                text: "Click me"
                onClicked: card.incrementClicked()
            }
            Button {
                objectName: "resetButton"
                text: "Reset"
                onClicked: card.resetClicked()
            }
        }
    }
}
