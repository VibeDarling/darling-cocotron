// CTSwapLineBreakEpsilon: GUESS (rung 6) stand-in. Sets the line-break epsilon and returns the previous value.
// Checks the initial value, set and return-previous, and that concurrent swaps neither lose nor invent a value.
#import <Foundation/Foundation.h>
#import <CoreText/CoreText.h>
#include <pthread.h>
#include <stdio.h>
#include <string.h>

// Private name, not in the installed headers: GUESS (rung 6) prototype, as in KTCoreTextInternal.h.
extern CGFloat CTSwapLineBreakEpsilon(CGFloat newEpsilon);

static int failures;
#define CHECK(cond, ...) do { if (cond) printf("PASS "); else { printf("FAIL "); ++failures; } printf(__VA_ARGS__); printf("\n"); } while (0)

enum { kThreads = 8, kSwaps = 2000 };
static double returned[kThreads][kSwaps];

static void *worker(void *arg)
{
    long t = (long)arg;
    for (int i = 0; i < kSwaps; ++i) returned[t][i] = CTSwapLineBreakEpsilon((double)(t * kSwaps + i + 1));
    return NULL;
}

int main(void) { @autoreleasepool {
    CHECK(CTSwapLineBreakEpsilon(0.25) == 0.0, "the initial epsilon is 0");
    CHECK(CTSwapLineBreakEpsilon(1.5) == 0.25, "a swap returns the previous value");
    CHECK(CTSwapLineBreakEpsilon(1.5) == 1.5, "swapping the same value returns it");
    CHECK(CTSwapLineBreakEpsilon(0.0) == 1.5, "a swap back to 0 returns the value stored last");
    CHECK(CTSwapLineBreakEpsilon(0.0) == 0.0, "0 is stored as 0");

    // Every thread stores values nobody else stores. Each stored value (plus the initial 0) must come back exactly once,
    // except the final one, which is still stored: no lost update, no torn or invented value.
    pthread_t threads[kThreads];
    for (long t = 0; t < kThreads; ++t) pthread_create(&threads[t], NULL, worker, (void *)t);
    for (int t = 0; t < kThreads; ++t) pthread_join(threads[t], NULL);

    static unsigned char seen[kThreads * kSwaps + 1];
    int invented = 0, duplicated = 0;
    for (int t = 0; t < kThreads; ++t)
        for (int i = 0; i < kSwaps; ++i) {
            double v = returned[t][i];
            long k = (long)v;
            if (v != (double)k || k < 0 || k > kThreads * kSwaps) { ++invented; continue; }
            if (seen[k]++) ++duplicated;
        }
    double last = CTSwapLineBreakEpsilon(0.0);
    long lastKey = (long)last;
    CHECK(last == (double)lastKey && lastKey >= 1 && lastKey <= kThreads * kSwaps, "the value left stored is one a thread stored");
    if (lastKey >= 1 && lastKey <= kThreads * kSwaps) ++seen[lastKey];
    int missing = 0;
    for (long k = 0; k <= kThreads * kSwaps; ++k) if (seen[k] != 1) ++missing;
    CHECK(invented == 0, "no returned value was invented or torn (%d)", invented);
    CHECK(duplicated == 0, "no value was returned twice (%d)", duplicated);
    CHECK(missing == 0, "every stored value, and the initial 0, was returned exactly once (%d off)", missing);
    printf("RESULT failures=%d\n", failures);
    return failures ? 1 : 0;
} }
