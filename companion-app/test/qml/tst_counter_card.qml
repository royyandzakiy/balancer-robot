import QtQuick
import QtTest
import App

// Component test: CounterCard on its own, no viewmodel.
TestCase {
    id: testCase
    name: "CounterCard"
    when: windowShown
    visible: true // TestCase is invisible by default; items inside it can't be clicked until shown
    width: 400
    height: 300

    Component {
        id: cardComponent
        CounterCard {
            label: "Clicked once"
        }
    }

    SignalSpy {
        id: incrementSpy
        signalName: "incrementClicked"
    }

    function test_showsLabel() {
        const card = createTemporaryObject(cardComponent, testCase);
        verify(card);
        compare(findChild(card, "counterLabel").text, "Clicked once");
    }

    function test_clickEmitsIncrement() {
        const card = createTemporaryObject(cardComponent, testCase);
        incrementSpy.target = card;
        incrementSpy.clear();
        waitForItemPolished(card); // layouts position the buttons on polish; clicking earlier misses them
        mouseClick(findChild(card, "incrementButton"));
        compare(incrementSpy.count, 1);
    }
}
