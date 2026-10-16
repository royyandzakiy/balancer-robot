#include "counter_view_model.hpp"

#include <QSignalSpy>
#include <QTest>

// QtTest, not GTest: QSignalSpy and Qt's own types make viewmodel checks straightforward.
class TestCounterViewModel : public QObject {
	Q_OBJECT

  private slots:
	void incrementNotifiesQml() {
		CounterViewModel vm;
		const QSignalSpy spy(&vm, &CounterViewModel::countChanged);

		vm.increment();

		QCOMPARE(spy.count(), 1);
		QCOMPARE(vm.count(), 1);
		QCOMPARE(vm.label(), QStringLiteral("Clicked once"));
	}

	void resetAtZeroDoesNotNotify() {
		CounterViewModel vm;
		const QSignalSpy spy(&vm, &CounterViewModel::countChanged);

		vm.reset();

		QCOMPARE(spy.count(), 0);
	}
};

QTEST_APPLESS_MAIN(TestCounterViewModel)
#include "test_counter_view_model.moc"
