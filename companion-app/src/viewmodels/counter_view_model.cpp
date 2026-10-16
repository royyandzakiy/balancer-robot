#include "counter_view_model.hpp"

CounterViewModel::CounterViewModel(QObject *parent) : QObject(parent) {
}

auto CounterViewModel::count() const -> int {
	return counter_.count();
}

auto CounterViewModel::label() const -> QString {
	return QString::fromStdString(counter_.label());
}

void CounterViewModel::increment() {
	counter_.increment();
	emit countChanged();
}

void CounterViewModel::reset() {
	if (counter_.count() == 0) {
		return;
	}
	counter_.reset();
	emit countChanged();
}
