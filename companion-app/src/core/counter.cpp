#include "core/counter.hpp"

#include <fmt/format.h>

namespace core {

void Counter::increment() {
	++count_;
}

void Counter::reset() {
	count_ = 0;
}

auto Counter::count() const -> int {
	return count_;
}

auto Counter::label() const -> std::string {
	switch (count_) {
	case 0:
		return "Not clicked yet";
	case 1:
		return "Clicked once";
	default:
		return fmt::format("Clicked {} times", count_);
	}
}

} // namespace core
