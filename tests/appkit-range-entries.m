// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test code, GPL-3.0; the patched cocotron sources keep their own licence.
// Drives AKRangeEntries with random operations and compares every observable result with a naive
// model: one int per character index (0 = no entry). Built and run by tests/appkit-range-entries.sh.
#import <Foundation/Foundation.h>
#import "AKRangeEntries.h"
#include <assert.h>
#include <stdio.h>
#include <stdlib.h>

#define CAP 256

static unsigned long long rngState;
static unsigned rnd(unsigned n) {
    rngState = rngState * 6364136223846793005ULL + 1442695040888963407ULL;
    return (unsigned) (rngState >> 33) % n;
}

#define CHECK(cond, ...)                                                       \
    do {                                                                       \
        if (!(cond)) {                                                         \
            fprintf(stderr, "FAIL seed %llu op %d: ", seed, opNumber);         \
            fprintf(stderr, __VA_ARGS__);                                      \
            fprintf(stderr, "\n");                                             \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

static unsigned long long seed;
static int opNumber;

typedef struct {
    AKRangeEntries *table;
    BOOL objects;
    int model[CAP]; // value (objects) or entry id (pointers) per index, 0 = none
    int length;     // indexes at or beyond this are 0 in the model
} Fixture;

static int valueOf(const Fixture *f, void *p) {
    return f->objects ? [(NSNumber *) p intValue] : *(int *) p;
}

// maximal runs of equal nonzero values in the model
static int runs(const Fixture *f, NSRange out[CAP]) {
    int n = 0;
    for (int i = 0; i < f->length; i++) {
        if (f->model[i] == 0)
            continue;
        if (i > 0 && f->model[i - 1] == f->model[i])
            out[n - 1].length++;
        else
            out[n++] = NSMakeRange(i, 1);
    }
    return n;
}

static void checkAll(Fixture *f) {
    NSRange expect[CAP];
    int n = runs(f, expect);

    CHECK((int) AKCountRangeEntries(f->table) == n, "count %d, model has %d runs",
          (int) AKCountRangeEntries(f->table), n);

    for (int i = 0; i < f->length + 3; i++) {
        int want = i < f->length ? f->model[i] : 0;
        NSRange got = NSMakeRange(777, 777);
        void *p = AKRangeEntryAtIndex(f->table, i, &got);
        if (want) {
            CHECK(p != NULL && valueOf(f, p) == want, "index %d: value %d, want %d", i,
                  p ? valueOf(f, p) : -1, want);
            int s = i, e = i + 1;
            while (s > 0 && f->model[s - 1] == want) s--;
            while (e < f->length && f->model[e] == want) e++;
            CHECK(got.location == s && got.length == e - s,
                  "index %d: run {%lu,%lu}, want {%d,%d}", i, (unsigned long) got.location,
                  (unsigned long) got.length, s, e - s);
        } else if (n == 0) {
            CHECK(p == NULL && got.location == NSNotFound && got.length == 0,
                  "empty table index %d: {%lu,%lu}", i, (unsigned long) got.location,
                  (unsigned long) got.length);
        } else {
            int s = i, e = i + 1;
            while (s > 0 && f->model[s - 1] == 0) s--;
            while (e < f->length && f->model[e] == 0) e++;
            // the gap before the first run starts at 0 and the one after the last is open ended
            CHECK(p == NULL, "index %d: expected no entry", i);
            CHECK(got.location == s, "gap at %d starts at %lu, want %d", i,
                  (unsigned long) got.location, s);
            if (e >= f->length)
                CHECK(got.length == NSNotFound, "open gap at %d has length %lu", i,
                      (unsigned long) got.length);
            else
                CHECK(got.length == e - s, "gap at %d has length %lu, want %d", i,
                      (unsigned long) got.length, e - s);
        }
        void *q = AKRangeEntryAtIndex(f->table, i, NULL);
        CHECK(q == p, "index %d: NULL effectiveRange changed the answer", i);
    }

    AKRangeEnumerator it = AKRangeEntryEnumerator(f->table);
    NSRange r;
    void *v;
    for (int k = 0; k < n; k++) {
        CHECK(AKNextRangeEnumeratorEntry(&it, &r, &v), "enumerator ended at %d of %d", k, n);
        CHECK(NSEqualRanges(r, expect[k]) && valueOf(f, v) == f->model[expect[k].location],
              "enumerator entry %d is {%lu,%lu}", k, (unsigned long) r.location,
              (unsigned long) r.length);
        CHECK(AKRangeEntryAtRange(f->table, expect[k]) == v, "AtRange missed run %d", k);
        if (expect[k].length > 1)
            CHECK(AKRangeEntryAtRange(f->table, NSMakeRange(expect[k].location, expect[k].length - 1)) == NULL,
                  "AtRange matched a strict subrange of run %d", k);
    }
    CHECK(!AKNextRangeEnumeratorEntry(&it, &r, &v), "enumerator has more than %d entries", n);
    CHECK(AKRangeEntryAtRange(f->table, NSMakeRange(f->length + 5, 2)) == NULL,
          "AtRange matched a range past the end");
}

static void setModel(Fixture *f, NSRange r, int value) {
    for (NSUInteger i = r.location; i < NSMaxRange(r); i++)
        f->model[i] = value;
}

static void *makeValue(Fixture *f, int value) {
    if (f->objects)
        return [NSNumber numberWithInt:value];
    int *p = malloc(sizeof(int));
    *p = value;
    return p;
}

static void randomRange(Fixture *f, NSRange *r) {
    r->location = rnd(f->length);
    r->length = 1 + rnd(f->length / 3 + 1);
    if (NSMaxRange(*r) > f->length)
        r->length = f->length - r->location;
}

// A run with at least two indexes, chosen at random; NO if none
static BOOL pickRun(Fixture *f, NSRange *out) {
    NSRange all[CAP];
    int n = runs(f, all), cand[CAP], c = 0;
    for (int i = 0; i < n; i++)
        if (all[i].length >= 2)
            cand[c++] = i;
    if (c == 0)
        return NO;
    *out = all[cand[rnd(c)]];
    return YES;
}

static void run(BOOL objects, unsigned long long s) {
    seed = s;
    rngState = s * 2654435761ULL + 12345;
    Fixture f = {0};
    f.objects = objects;
    f.table = objects ? AKCreateRangeToCopiedObjectEntries(rnd(6))
                      : AKCreateRangeToOwnedPointerEntries(rnd(6));
    f.length = 20 + rnd(30);
    int nextId = 1;

    for (opNumber = 0; opNumber < 60; opNumber++) {
        unsigned op = rnd(100);
        NSRange r, rr;
        if (op < 50) {
            randomRange(&f, &r);
            if (objects) {
                int v = 1 + rnd(3);
                AKRangeEntriesDivideAndConquer(f.table, r);
                AKRangeEntryInsert(f.table, r, makeValue(&f, v));
                setModel(&f, r, v);
            } else {
                BOOL isFree = YES;
                for (NSUInteger i = r.location; i < NSMaxRange(r); i++)
                    if (f.model[i]) isFree = NO;
                if (!isFree)
                    continue;
                AKRangeEntryInsert(f.table, r, makeValue(&f, nextId));
                setModel(&f, r, nextId++);
            }
        } else if (op < 58 && objects) {
            // an empty range only asks for neighbouring equal entries to be joined: no visible change
            AKRangeEntryInsert(f.table, NSMakeRange(rnd(f.length), 0), makeValue(&f, 1 + rnd(3)));
        } else if (op < 68) {
            NSRange all[CAP];
            int n = runs(&f, all);
            if (n == 0)
                continue;
            int k = rnd(n);
            AKRangeEntriesRemoveEntryAtIndex(f.table, k);
            setModel(&f, all[k], 0);
        } else if (op < 84 && objects) {
            // delete characters strictly inside one run: it shrinks, later entries move down
            if (!pickRun(&f, &rr))
                continue;
            NSUInteger len = 1 + rnd(rr.length - 1);
            NSRange del = NSMakeRange(rr.location + rnd(rr.length - len + 1), len);
            AKRangeEntriesExpandAndWipe(f.table, del, -(NSInteger) len);
            for (NSUInteger i = NSMaxRange(del); i < f.length; i++)
                f.model[i - len] = f.model[i];
            for (NSUInteger i = f.length - len; i < f.length; i++)
                f.model[i] = 0;
            f.length -= len;
        } else if (objects) {
            // insert characters strictly inside one run: it grows
            if (!pickRun(&f, &rr) || f.length > CAP - 8)
                continue;
            NSUInteger at = rr.location + 1 + rnd(rr.length - 1);
            int delta = 1 + rnd(3);
            AKRangeEntriesExpandAndWipe(f.table, NSMakeRange(at, 0), delta);
            for (int i = f.length - 1; i >= (int) at; i--)
                f.model[i + delta] = f.model[i];
            for (int i = 0; i < delta; i++)
                f.model[at + i] = f.model[at - 1];
            f.length += delta;
        } else {
            continue;
        }
        checkAll(&f);
    }
    AKResetRangeEntries(f.table);
    CHECK(AKCountRangeEntries(f.table) == 0, "reset left entries");
    AKFreeRangeEntries(f.table);
}

// A removed last entry leaves a stale copy in the slot just past the table; a lookup must not see it.
static void staleSlot(void) {
    seed = 0;
    opNumber = 0;
    AKRangeEntries *t = AKCreateRangeToOwnedPointerEntries(4);
    int *a = malloc(sizeof(int)), *b = malloc(sizeof(int)), *c = malloc(sizeof(int));
    *a = *b = *c = 1;
    AKRangeEntryInsert(t, NSMakeRange(0, 2), a);
    AKRangeEntryInsert(t, NSMakeRange(5, 2), b);
    AKRangeEntryInsert(t, NSMakeRange(9, 2), c);
    AKRangeEntriesRemoveEntryAtIndex(t, 2);
    CHECK(AKRangeEntryAtRange(t, NSMakeRange(9, 2)) == NULL, "AtRange found a removed entry");
    CHECK(AKRangeEntryAtRange(t, NSMakeRange(5, 2)) == b, "AtRange lost a live entry");
    AKFreeRangeEntries(t);
}

int main(void) {
    @autoreleasepool {
        staleSlot();
        for (unsigned long long s = 1; s <= 400; s++) {
            @autoreleasepool { run(YES, s); }
            run(NO, s);
        }
        AKFreeRangeEntries(NULL);
        CHECK(AKCountRangeEntries(NULL) == 0, "NULL table");
    }
    printf("appkit-range-entries: OK\n");
    return 0;
}
