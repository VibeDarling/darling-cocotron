// SPDX-License-Identifier: GPL-3.0-only
// Ancillary test code, GPL-3.0; the patched cocotron sources keep their own licence.
// Checks NSCellUndoManager (AppKit/NSCellUndoManager.m, compiled in under the name
// AKTestCellUndoManager) against a plain NSUndoManager as the "next" manager: a new cell
// registration must discard the next manager's redo stack and change nothing else.
// NSDocument comes from the AppKit being linked. Built and run by tests/appkit-cell-undo.sh.
#import <AppKit/NSDocument.h>
#import <Foundation/Foundation.h>
#import "NSCellUndoManager.h"
#include <stdio.h>
#include <stdlib.h>

#define CHECK(cond, ...)                                                       \
    do {                                                                       \
        if (!(cond)) {                                                         \
            fprintf(stderr, "FAIL %s: ", currentCase);                         \
            fprintf(stderr, __VA_ARGS__);                                      \
            fprintf(stderr, "\n");                                             \
            exit(1);                                                           \
        }                                                                      \
    } while (0)

static const char *currentCase;

// A document-like model whose edits register their own inverse with the undo manager that is
// current while they run, like a real document does.
@interface Model : NSObject {
@public
    int value;
    NSUndoManager *manager;
}
- (void) setValue: (NSNumber *) number;
- (void) noop: (id) unused;
@end

@implementation Model
- (void) setValue: (NSNumber *) number {
    [manager registerUndoWithTarget: self selector: @selector(setValue:) object: [NSNumber numberWithInt: value]];
    value = [number intValue];
}
- (void) noop: (id) unused {
}
@end

static NSUndoManager *newNext(BOOL groupsByEvent) {
    NSUndoManager *next = [NSUndoManager new];
    [next setGroupsByEvent: groupsByEvent];
    return next;
}

static void edit(Model *m, int to) {
    if (![m->manager groupsByEvent])
        [m->manager beginUndoGrouping];
    [m setValue: [NSNumber numberWithInt: to]];
    if (![m->manager groupsByEvent])
        [m->manager endUndoGrouping];
}

static void turn(void) {
    [[NSRunLoop currentRunLoop] runUntilDate: [NSDate dateWithTimeIntervalSinceNow: 0.05]];
}

// The cell registers one undo action of its own on the manager under test.
static void cellRegisters(NSUndoManager *cell, Model *target) {
    BOOL explicit = ![cell groupsByEvent];
    if (explicit)
        [cell beginUndoGrouping];
    [cell registerUndoWithTarget: target selector: @selector(noop:) object: nil];
    if (explicit)
        [cell endUndoGrouping];
}

static NSUndoManager *newCell(NSUndoManager *next, BOOL groupsByEvent) {
    AKTestCellUndoManager *cell = [AKTestCellUndoManager new];
    [cell setGroupsByEvent: groupsByEvent];
    [cell setNextUndoManager: next];
    return cell;
}

// next: A then B, B undone (redo available); the cell then registers C.
static void staleRedoIsCleared(void) {
    currentCase = "stale redo cleared";
    NSUndoManager *next = newNext(NO), *cell = newCell(next, NO);
    Model *doc = [Model new];
    doc->manager = next;
    edit(doc, 1);
    edit(doc, 2);
    [next undo];
    CHECK(doc->value == 1 && [next canRedo], "setup: value %d, canRedo %d", doc->value, [next canRedo]);
    NSInteger level = [next groupingLevel];

    cellRegisters(cell, doc);

    CHECK(![next canRedo], "next still has a stale redo");
    CHECK(![cell canRedo], "cell can redo");
    CHECK([next groupingLevel] == level, "next group level %d, was %d", (int) [next groupingLevel], (int) level);
    CHECK(doc->value == 1, "value changed to %d", doc->value);
    CHECK([cell canUndo], "cell lost its own action");
    [cell undo]; // the cell's own action first (a no-op on the model)
    CHECK(doc->value == 1, "cell undo touched the model: %d", doc->value);
    [cell undo]; // then the next manager: A, not an empty group
    CHECK(doc->value == 0, "first undo after the sequence left value %d, wanted 0", doc->value);
    CHECK(![next canUndo], "next has more to undo than A");
}

static void nothingChangesWithoutRedo(void) {
    currentCase = "no redo, nothing registered on next";
    NSUndoManager *next = newNext(NO), *cell = newCell(next, NO);
    Model *doc = [Model new];
    doc->manager = next;
    cellRegisters(cell, doc);
    CHECK(![next canUndo] && ![next canRedo] && [next groupingLevel] == 0, "empty next changed");

    edit(doc, 5);
    CHECK([next canUndo], "setup");
    cellRegisters(cell, doc);
    [next undo];
    CHECK(doc->value == 0 && ![next canUndo], "undo after a cell registration: value %d", doc->value);
}

static void canUndoUnchangedWithRedo(void) {
    currentCase = "next canUndo unchanged";
    NSUndoManager *next = newNext(NO), *cell = newCell(next, NO);
    Model *doc = [Model new];
    doc->manager = next;
    edit(doc, 1);
    edit(doc, 2);
    [next undo];
    [next undo];
    CHECK(![next canUndo] && [next canRedo], "setup");
    cellRegisters(cell, doc);
    CHECK(![next canUndo], "dummy registration left something to undo");
    CHECK(![next canRedo], "redo not cleared");
}

static void eventGroupedManagers(void) {
    currentCase = "groups by event";
    NSUndoManager *next = newNext(YES), *cell = newCell(next, YES);
    Model *doc = [Model new];
    doc->manager = next;
    edit(doc, 1);
    turn();
    edit(doc, 2);
    turn();
    [next undo];
    CHECK(doc->value == 1 && [next canRedo] && [next groupingLevel] == 0, "setup");

    cellRegisters(cell, doc);
    turn();

    CHECK(![next canRedo], "stale redo survived the turn");
    CHECK([next groupingLevel] == 0, "next group level %d after the turn", (int) [next groupingLevel]);
    CHECK(doc->value == 1, "value changed to %d", doc->value);
    [cell undo];
    [cell undo];
    CHECK(doc->value == 0, "first next undo left value %d, wanted 0", doc->value);
}

static void invocationPath(void) {
    currentCase = "prepareWithInvocationTarget";
    NSUndoManager *next = newNext(NO), *cell = newCell(next, NO);
    Model *doc = [Model new];
    doc->manager = next;
    edit(doc, 1);
    [next undo];
    CHECK([next canRedo], "setup");
    [cell beginUndoGrouping];
    [(Model *) [cell prepareWithInvocationTarget: doc] noop: nil];
    [cell endUndoGrouping];
    CHECK(![next canRedo], "redo survived an invocation registration");
}

// Block-based registration does not go through the overridden selector-based one; the cell's
// group closing is what must clear the next manager's redo stack.
static void handlerPath(void) {
    currentCase = "registerUndoWithTarget:handler:";
    NSUndoManager *next = newNext(NO), *cell = newCell(next, NO);
    Model *doc = [Model new];
    doc->manager = next;
    edit(doc, 1);
    [next undo];
    CHECK([next canRedo], "setup");
    [cell beginUndoGrouping];
    [cell registerUndoWithTarget: doc handler: ^(Model *m) {
        (void) m;
    }];
    [cell endUndoGrouping];
    CHECK(![next canRedo], "redo survived a handler registration");
    CHECK(![next canUndo], "next has something to undo");
}

// Cocotron's NSDocument ignores group closing (-_undoManagerDidCloseGroup: is empty), so this case
// cannot fail against Cocotron's AppKit; it records what Apple's AppKit must also satisfy.
static void documentChangeCount(void) {
    currentCase = "NSDocument change count";
    NSDocument *document = [NSDocument new];
    NSUndoManager *next = [document undoManager];
    [next setGroupsByEvent: NO];
    NSUndoManager *cell = newCell(next, NO);
    Model *doc = [Model new];
    doc->manager = next;

    [document updateChangeCount: NSChangeDone];
    edit(doc, 1);
    [next undo]; // the document hears DidUndoChange: count back to 0
    CHECK(![document isDocumentEdited] && [next canRedo], "setup: edited %d", [document isDocumentEdited]);

    cellRegisters(cell, doc);

    CHECK(![next canRedo], "stale redo survived");
    CHECK(![document isDocumentEdited], "the document became edited");
}

// Recorded behaviour: while undo registration is disabled on the next manager, a cell
// registration neither raises nor clears its redo stack (the same as registering on it directly).
static void registrationDisabled(void) {
    currentCase = "registration disabled";
    NSUndoManager *next = newNext(NO), *cell = newCell(next, NO);
    Model *doc = [Model new];
    doc->manager = next;
    edit(doc, 1);
    [next undo];
    CHECK([next canRedo], "setup");
    [next disableUndoRegistration];
    cellRegisters(cell, doc);
    CHECK([next canRedo], "redo was cleared although registration was disabled");
    [next enableUndoRegistration];
    CHECK([next groupingLevel] == 0 && ![next canUndo], "next changed");
}

int main(void) {
    @autoreleasepool {
        staleRedoIsCleared();
        nothingChangesWithoutRedo();
        canUndoUnchangedWithRedo();
        eventGroupedManagers();
        invocationPath();
        handlerPath();
        documentChangeCount();
        registrationDisabled();
    }
    printf("appkit-cell-undo: OK\n");
    return 0;
}
