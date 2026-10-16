#pragma once
#include <string>

namespace core {

// Plain C++ app logic, no Qt. The QML side reaches it only through CounterViewModel, so this
// stays unit-testable with GTest alone (test/test_counter.cpp).
class Counter {
  public:
	void increment();
	void reset();

	[[nodiscard]] auto count() const -> int;
	[[nodiscard]] auto label() const -> std::string;

  private:
	int count_ = 0;
};

} // namespace core
