// Sanitizer verification as GoogleTest *death tests*.
//
// A sanitizer aborts the whole process, so it can't be caught in-process — gtest's death
// tests fork a child, run the statement, and assert the child died with the matching
// diagnostic on stderr. Each test compiles only when its sanitizer is active (the
// SANITIZER_* defines come from test/CMakeLists.txt), and they run under ctest via
// gtest_discover_tests, just like the rest of the suite.
#include <gtest/gtest.h>

#include <cstdlib>

#if defined(SANITIZER_UBSAN)
#include <climits>
TEST(SanitizerDeathTest, UndefinedBehavior) {
	EXPECT_DEATH(
		{
			volatile int x = INT_MAX;
			volatile int one = 1;
			volatile int z = x + one; // signed overflow -> UBSan (fatal via -fno-sanitize-recover)
			(void)z;
		},
		"runtime error"); // single token: gtest's Windows regex treats '|' as a literal
}
#endif

#if defined(SANITIZER_ASAN)
TEST(SanitizerDeathTest, AddressSanitizer) {
	EXPECT_DEATH(
		{
			int *a = new int[3];
			volatile int idx = 5;
			volatile int v = a[idx]; // OOB read, observed via volatile so it survives optimization
			(void)v;
			delete[] a;
		},
		"AddressSanitizer");
}
#endif

#if defined(SANITIZER_LSAN)
#include <sanitizer/lsan_interface.h>
#if defined(__GNUC__) || defined(__clang__)
__attribute__((noinline))
#endif
static void
leak_now() {
	volatile int *p = new int[64]; // leaked; the only pointer is gone once this returns
	p[0] = 1;
}
TEST(SanitizerDeathTest, LeakSanitizer) {
	// gtest death-test children _exit() (skipping the atexit leak scan), so force the check.
	EXPECT_DEATH(
		{
			leak_now();
			if (__lsan_do_recoverable_leak_check() != 0) {
				std::abort();
			}
		},
		"LeakSanitizer");
}
#endif

#if defined(SANITIZER_TSAN)
#include <thread>
TEST(SanitizerDeathTest, ThreadSanitizer) {
	EXPECT_DEATH(
		{
			int shared = 0;
			auto bump = [&] {
				for (int i = 0; i < 100000; ++i) {
					++shared; // unsynchronized concurrent write
				}
			};
			std::thread t1(bump);
			std::thread t2(bump);
			t1.join();
			t2.join();
		},
		"ThreadSanitizer");
}
#endif
