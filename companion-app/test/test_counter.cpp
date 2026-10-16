#include "core/counter.hpp"

#include <gtest/gtest.h>

TEST(CounterTest, StartsAtZero) {
	const core::Counter counter;
	EXPECT_EQ(counter.count(), 0);
	EXPECT_EQ(counter.label(), "Not clicked yet");
}

TEST(CounterTest, IncrementUpdatesCountAndLabel) {
	core::Counter counter;
	counter.increment();
	EXPECT_EQ(counter.label(), "Clicked once");
	counter.increment();
	counter.increment();
	EXPECT_EQ(counter.count(), 3);
	EXPECT_EQ(counter.label(), "Clicked 3 times");
}

TEST(CounterTest, ResetGoesBackToZero) {
	core::Counter counter;
	counter.increment();
	counter.reset();
	EXPECT_EQ(counter.count(), 0);
}
