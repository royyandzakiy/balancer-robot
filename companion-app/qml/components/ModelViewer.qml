import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick3D
import QtQuick3D.Helpers

// Minimal 3D viewer: a lit cube you can orbit (drag), zoom (mouse wheel or buttons) and auto-rotate.
// Uses Quick 3D's built-in "#Cube" primitive, so no model file or asset importer is needed. To show a
// real model, convert it with Qt's balsam tool (.gltf/.obj -> .mesh + QML) and point `source` at it.
Item {
    id: viewer

    readonly property real defaultDistance: 400
    readonly property real minDistance: 150
    readonly property real maxDistance: 1500
    readonly property real distance: camera.z // read by tests and Spix
    property alias autoRotate: autoRotateSwitch.checked

    function zoomIn() {
        camera.z = Math.max(minDistance, camera.z * 0.8);
    }
    function zoomOut() {
        camera.z = Math.min(maxDistance, camera.z * 1.25);
    }
    function resetView() {
        camera.z = defaultDistance;
        cameraOrigin.eulerRotation = Qt.vector3d(-20, 30, 0);
        cameraOrigin.position = Qt.vector3d(0, 0, 0);
        cube.eulerRotation = Qt.vector3d(0, 0, 0);
    }

    ColumnLayout {
        anchors.fill: parent
        spacing: 8

        Item {
            Layout.fillWidth: true
            Layout.fillHeight: true

            View3D {
                id: view
                objectName: "view3d"
                anchors.fill: parent

                environment: SceneEnvironment {
                    backgroundMode: SceneEnvironment.Color
                    clearColor: "#1e2228"
                    antialiasingMode: SceneEnvironment.MSAA
                    antialiasingQuality: SceneEnvironment.High
                }

                // The orbit controller rotates this node; the camera sits on its local z axis.
                Node {
                    id: cameraOrigin
                    eulerRotation: Qt.vector3d(-20, 30, 0)

                    PerspectiveCamera {
                        id: camera
                        z: viewer.defaultDistance
                    }
                }

                DirectionalLight {
                    eulerRotation: Qt.vector3d(-40, -30, 0)
                    ambientColor: Qt.rgba(0.25, 0.25, 0.25, 1)
                }

                Model {
                    id: cube
                    objectName: "cube"
                    source: "#Cube"
                    materials: PrincipledMaterial {
                        baseColor: "#41cd52"
                        metalness: 0.1
                        roughness: 0.35
                    }
                }
            }

            // Mouse/touch: drag to orbit, wheel to zoom, right-drag to pan.
            OrbitCameraController {
                anchors.fill: parent
                origin: cameraOrigin
                camera: camera
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignHCenter
            spacing: 8

            Button {
                objectName: "zoomInButton"
                text: "Zoom in"
                enabled: viewer.distance > viewer.minDistance
                onClicked: viewer.zoomIn()
            }
            Button {
                objectName: "zoomOutButton"
                text: "Zoom out"
                enabled: viewer.distance < viewer.maxDistance
                onClicked: viewer.zoomOut()
            }
            Button {
                objectName: "resetViewButton"
                text: "Reset view"
                onClicked: viewer.resetView()
            }
            Switch {
                id: autoRotateSwitch
                objectName: "autoRotateSwitch"
                text: "Auto-rotate"
            }
        }
    }

    // Spins the cube while auto-rotate is on; frame-time based, so speed doesn't depend on refresh rate.
    FrameAnimation {
        running: viewer.autoRotate && viewer.visible
        onTriggered: cube.eulerRotation.y += frameTime * 45
    }
}
