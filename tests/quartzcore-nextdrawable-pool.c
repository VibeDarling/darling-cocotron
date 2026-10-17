// Host MODEL of the nextDrawable pool protocol in QuartzCore/CAMetalLayer.mm and
// CALayerContext.m. QuartzCore cannot be compiled on the host (it needs Vulkan, GL
// and the Darling runtime), so this is a C state machine with the same rules, not the
// Objective-C itself. It pins the design:
//   1. A slot returns to the pool only inside a render pass (the presented handler).
//   2. nextDrawable on the main thread runs a pass itself when presents are queued.
//   3. Only the main thread reads the unretained context pointer.
//   4. A pass never nests, whichever entry point asks for it.
//   5. If a pass takes no present, the caller waits instead of looping.
// Build and run with tests/quartzcore-nextdrawable-pool.sh.
#include <stdbool.h>
#include <stdio.h>

#define POOL 3

static int failures;
#define CHECK(c, msg) do { if (!(c)) { failures++; printf("FAIL line %d: %s\n", __LINE__, msg); } } while (0)

typedef struct {
    int usable;        // free slots
    int queued;        // presented, waiting for a pass to hand them back
    bool context;      // the unretained layer->context pointer is valid
    bool hasWindow;    // renderLayer can attach (else it returns early)
    bool inProgress;   // CALayerContext._renderInProgress
    int depth, maxDepth;
    int passes;
    bool badContextRead;
    bool nestedFromHandler; // the presented handler calls nextDrawable again
    bool nestedRender;      // app code in the pass causes a display pass (NSView path)
    int waits;
} Model;

static int nextDrawable(Model *m, bool mainThread);

// CALayerContext -renderLayer: with the guard. Taking a queued present frees its slot.
static void renderLayer(Model *m) {
#ifndef MUT_NO_GUARD
    if (m->inProgress)
        return;
#endif
    m->inProgress = true;
    m->depth++;
    if (m->depth > m->maxDepth)
        m->maxDepth = m->depth;
    if (m->hasWindow && m->queued > 0) {
        m->passes++;
        m->queued--;
        if (m->nestedFromHandler) { // app code inside the pass
            m->nestedFromHandler = false;
            nextDrawable(m, true);
        }
        if (m->nestedRender) {
            m->nestedRender = false;
            renderLayer(m);
        }
        m->usable++;
    }
    m->depth--;
    m->inProgress = false;
}

static bool renderPendingPresents(Model *m, bool mainThread) {
    if (m->inProgress || !mainThread)
        return false;
    renderLayer(m);
    return true;
}

// Returns the number of times the caller had to wait; -1 for the 1 s timeout.
static int nextDrawable(Model *m, bool mainThread) {
    int waited = 0;
    while (m->usable == 0) {
#ifndef MUT_NO_MAIN_CHECK
        if (mainThread && m->queued > 0) {
#else
        if (m->queued > 0) {
#endif
            if (!m->context)
                m->badContextRead = true; // would message freed memory
            int before = m->queued;
            bool rendered = renderPendingPresents(m, mainThread);
            if (rendered && m->queued < before)
                continue;
        }
        // The real code blocks on the condition; the timer pass on the main thread
        // would free a slot. The model has one thread, so it counts the wait and ends it.
        waited++;
        m->waits++;
        return -1;
    }
    m->usable--;
    return waited;
}

static Model fresh(void) {
    Model m = {0};
    m.context = true;
    m.hasWindow = true;
    return m;
}

int main(void) {
    // 1+2: the whole pool is presented; the main thread finds a slot without waiting.
    Model m = fresh();
    m.queued = POOL;
    CHECK(nextDrawable(&m, true) == 0, "main thread frees a slot by running a pass");
    CHECK(m.passes == 1, "exactly one pass for one slot");

    // Each pass takes one present, so POOL calls drain POOL presents and no more.
    m = fresh(); m.queued = POOL;
    for (int i = 0; i < POOL; i++)
        CHECK(nextDrawable(&m, true) == 0, "drains the pool one pass per call");
    CHECK(m.queued == 0 && m.usable == 0, "pool fully handed out");

    // 3: another thread does not touch the context, even if it has been freed.
    m = fresh(); m.queued = POOL; m.context = false;
    CHECK(nextDrawable(&m, false) == -1, "worker thread waits for the main thread timer");
    CHECK(!m.badContextRead, "worker thread never reads the context");

    // 4: app code in the presented handler asks for a drawable again.
    m = fresh(); m.queued = POOL; m.nestedFromHandler = true;
    nextDrawable(&m, true);
    CHECK(m.maxDepth == 1, "a pass never nests");

    // Layout or a delegate inside the pass triggers a display pass (NSView.m path).
    m = fresh(); m.queued = POOL; m.nestedRender = true;
    nextDrawable(&m, true);
    CHECK(m.maxDepth == 1, "a direct render inside a pass does not nest");

    // A pass already running (the NSView display path) refuses a second one.
    m = fresh(); m.queued = POOL; m.inProgress = true;
    CHECK(nextDrawable(&m, true) == -1, "refused while a pass runs: waits");
    CHECK(m.depth == 0 && m.passes == 0, "no pass started inside a pass");

    // 5: no window yet: the pass takes nothing, so the caller waits instead of spinning.
    m = fresh(); m.queued = POOL; m.hasWindow = false;
    CHECK(nextDrawable(&m, true) == -1, "pass took nothing: falls through to the wait");
    CHECK(m.passes == 0, "no pass without a window");

    // Nothing queued and the app holds the whole pool: wait, as on macOS.
    m = fresh();
    CHECK(nextDrawable(&m, true) == -1, "nothing queued: waits");

    if (failures)
        return 1;
    printf("PASS\n");
    return 0;
}
