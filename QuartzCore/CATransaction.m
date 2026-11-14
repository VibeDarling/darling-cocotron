#import "CATransactionGroup.h"
#import "CATransactionInternal.h"
#import <Foundation/NSArray.h>
#import <Foundation/NSNumber.h>
#import <Foundation/NSString.h>
#import <QuartzCore/CALayerContext.h>
#import <QuartzCore/CATransaction.h>

NSString *const kCATransactionAnimationDuration =
        @"kCATransactionAnimationDuration";
NSString *const kCATransactionDisableActions = @"kCATransactionDisableActions";
NSString *const kCATransactionAnimationTimingFunction =
        @"kCATransactionAnimationTimingFunction";
NSString *const kCATransactionCompletionBlock =
        @"kCATransactionCompletionBlock";

@implementation CATransaction

static NSMutableArray *transactionStack() {
    NSMutableDictionary *shared = [NSCurrentThread() sharedDictionary];
    id stack = [shared objectForKey: @"CATransactionStack"];

    if (stack == nil) {
        stack = [NSMutableArray array];
        [shared setObject: stack forKey: @"CATransactionStack"];
    }

    return stack;
}

static CATransactionGroup *currentTransactionGroup() {
    id stack = transactionStack();

    CATransactionGroup *result = [stack lastObject];

    return result;
}

static CATransactionGroup *createImplicitTransactionGroupIfNeeded() {
    CATransactionGroup *check = currentTransactionGroup();

    if (check == nil) {
        check = [[CATransactionGroup alloc] init];

        [transactionStack() addObject: check];
        [check release]; // The stack owns the active transaction.
        [[NSRunLoop currentRunLoop]
                performSelector: @selector(commit)
                         target: [CATransaction class]
                       argument: nil
                          order: 0
                          modes: [NSArray arrayWithObject:
                                                  NSDefaultRunLoopMode]];
    }

    return check;
}

+ (BOOL) disableActions {
    return [[self valueForKey: kCATransactionDisableActions] boolValue];
}

+ (CFTimeInterval) animationDuration {
    return [[self valueForKey: kCATransactionAnimationDuration] doubleValue];
}

+ (CAMediaTimingFunction *) animationTimingFunction {
    return [self valueForKey: kCATransactionAnimationTimingFunction];
}

//+(void (^)(void))completionBlock;

+ valueForKey: (NSString *) key {
    CATransactionGroup *group = createImplicitTransactionGroupIfNeeded();

    return [group valueForKey: key];
}

+ (void) setAnimationDuration: (CFTimeInterval) value {
    [self setValue: [NSNumber numberWithDouble: value]
            forKey: kCATransactionAnimationDuration];
}

+ (void) setAnimationTimingFunction: (CAMediaTimingFunction *) value {
    [self setValue: value forKey: kCATransactionAnimationTimingFunction];
}

//+(void)setCompletionBlock:(void (^)(void))value;
+ (void) setDisableActions: (BOOL) value {
    [self setValue: [NSNumber numberWithBool: value]
            forKey: kCATransactionDisableActions];
}

+ (void) setValue: value forKey: (NSString *) key {
    CATransactionGroup *group = createImplicitTransactionGroupIfNeeded();

    [group setValue: value forKey: key];
}

+ (void) begin {
    CATransactionGroup *group = [[CATransactionGroup alloc] init];

    [group setExplicitlyBegan: YES];
    [transactionStack() addObject: group];
    [group release];
}

+ (BOOL) hasOpenTransaction {
    CATransactionGroup *group = currentTransactionGroup();

    return group != nil && [group isExplicitlyBegan];
}

+ (void) commit {
    [transactionStack() removeLastObject];
}

// Private, required by Mac Catalyst frameworks and not documented. The name
// asks for the state of the current transaction. Cocotron's transaction state
// is its CATransactionGroup, so this answers the innermost open group, or nil
// when no transaction is open. It never opens an implicit transaction, unlike
// reading a transaction property. The result is not retained: a caller that
// keeps it past +commit holds a freed object.
+ (id) currentState {
    return currentTransactionGroup();
}

// Private, sent to the class by Mac Catalyst frameworks and not documented. The
// name asks for a handler to run when an implicit transaction begins. The
// block's signature is not known (GUESS), and calling a block with the wrong
// arguments could corrupt state, so the block is kept (a new one replaces the
// old one, nil clears it) and deliberately never called, even though Cocotron
// does have implicit transactions (createImplicitTransactionGroupIfNeeded).
// Work that Catalyst schedules from this handler never runs. Transactions
// behave exactly as before.
static id implicitTransactionDidBeginHandler;

+ (void) setImplicitTransactionDidBeginHandler: (id) handler {
    if (handler != nil)
        NSLog(@"CATransaction setImplicitTransactionDidBeginHandler: handler stored, never called");

    @synchronized([CATransaction class]) {
        id previous = implicitTransactionDidBeginHandler;
        implicitTransactionDidBeginHandler = [handler copy];
        [previous release];
    }
}

// Private, sent to the class by Mac Catalyst frameworks and not documented. The
// name asks to stop a run loop observer from committing transactions (GUESS: the
// argument is a BOOL, YES disables). Nothing in Cocotron has run loop observer
// commits (an implicit transaction is committed from a run loop perform), so the
// value is accepted and ignored.
+ (void) setDisableRunLoopObserverCommits: (BOOL) value {
}

+ (void) flush {
}

+ (void) lock {
}

+ (void) unlock {
}

@end
