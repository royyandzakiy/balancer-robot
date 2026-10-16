#pragma once
#include "core/counter.hpp"

#include <QObject>
#include <QString>
#include <QtQml/qqmlregistration.h>

// Bridges core::Counter to QML. QML_ELEMENT registers it in the App module, so QML creates it
// directly (`CounterViewModel { id: vm }`) — no setContextProperty in main.cpp.
class CounterViewModel : public QObject {
	Q_OBJECT
	QML_ELEMENT
	Q_PROPERTY(int count READ count NOTIFY countChanged)
	Q_PROPERTY(QString label READ label NOTIFY countChanged)

  public:
	explicit CounterViewModel(QObject *parent = nullptr);

	[[nodiscard]] auto count() const -> int;
	[[nodiscard]] auto label() const -> QString;

	Q_INVOKABLE void increment();
	Q_INVOKABLE void reset();

  signals:
	void countChanged();

  private:
	core::Counter counter_;
};
