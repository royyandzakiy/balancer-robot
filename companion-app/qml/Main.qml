import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ApplicationWindow {
    id: root
    objectName: "mainWindow" // root of Spix item paths, e.g. "mainWindow/incrementButton"
    visible: true
    width: 640
    height: 480
    title: Qt.application.name + " (v" + Qt.application.version + ")"

    // C++ viewmodel, registered with QML_ELEMENT (src/viewmodels/counter_view_model.hpp)
    CounterViewModel {
        id: counter
    }

    header: TabBar {
        id: tabBar
        objectName: "tabBar"

        TabButton {
            objectName: "counterTab"
            text: "Counter"
        }
        TabButton {
            objectName: "viewerTab"
            text: "3D Viewer"
        }
    }

    StackLayout {
        anchors.fill: parent
        currentIndex: tabBar.currentIndex

        // Tab 1: C++ viewmodel + reusable component
        Item {
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 16

                Label {
                    Layout.alignment: Qt.AlignHCenter
                    text: "Hello, QML"
                    font.pixelSize: 24
                }

                CounterCard {
                    objectName: "counterCard"
                    Layout.alignment: Qt.AlignHCenter
                    label: counter.label
                    onIncrementClicked: counter.increment()
                    onResetClicked: counter.reset()
                }
            }
        }

        // Tab 2: Qt Quick 3D
        ModelViewer {
            objectName: "modelViewer"
        }
    }
}
