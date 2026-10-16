import QtQuick
import QtTest
import App

// Component test: ModelViewer's buttons drive the camera (zoom limits, reset, auto-rotate).
TestCase {
    id: testCase
    name: "ModelViewer"
    when: windowShown
    visible: true // TestCase is invisible by default; items inside it can't be clicked until shown
    width: 640
    height: 480

    Component {
        id: viewerComponent
        ModelViewer {
            anchors.fill: parent
        }
    }

    function createViewer() {
        const viewer = createTemporaryObject(viewerComponent, testCase);
        verify(viewer);
        waitForItemPolished(viewer);
        return viewer;
    }

    function test_zoomButtonsMoveCamera() {
        const viewer = createViewer();
        const start = viewer.distance;

        mouseClick(findChild(viewer, "zoomInButton"));
        verify(viewer.distance < start, "zoom in moves the camera closer");

        mouseClick(findChild(viewer, "zoomOutButton"));
        mouseClick(findChild(viewer, "zoomOutButton"));
        verify(viewer.distance > start, "zoom out moves the camera away");
    }

    function test_zoomIsClamped() {
        const viewer = createViewer();
        for (let i = 0; i < 20; ++i)
            viewer.zoomIn();
        compare(viewer.distance, viewer.minDistance);
        verify(!findChild(viewer, "zoomInButton").enabled, "zoom in disabled at the limit");

        for (let i = 0; i < 20; ++i)
            viewer.zoomOut();
        compare(viewer.distance, viewer.maxDistance);
        verify(!findChild(viewer, "zoomOutButton").enabled, "zoom out disabled at the limit");
    }

    function test_resetRestoresDefaultDistance() {
        const viewer = createViewer();
        viewer.zoomIn();
        mouseClick(findChild(viewer, "resetViewButton"));
        compare(viewer.distance, viewer.defaultDistance);
    }

    function test_autoRotateSpinsCube() {
        const viewer = createViewer();
        const cube = findChild(viewer, "cube");
        const before = cube.eulerRotation.y;
        mouseClick(findChild(viewer, "autoRotateSwitch"));
        verify(viewer.autoRotate);
        tryVerify(() => cube.eulerRotation.y !== before, 2000, "cube rotates while auto-rotate is on");
    }
}
