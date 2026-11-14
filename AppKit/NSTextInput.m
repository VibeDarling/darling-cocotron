#import <AppKit/NSEvent.h>
#import <Foundation/NSString.h>
#import <Foundation/NSValue.h>
#import <objc/runtime.h>
#include <AppKit/NSTextInput.h>
#include <AppKit/NSTextInput_Internal.h>

NSString *const NSTextInputContextKeyboardSelectionDidChangeNotification = @"NSTextInputContextKeyboardSelectionDidChangeNotification";

NSString *const NSTextInputReplacementRangeAttributeName = @"NSTextInputReplacementRangeAttributeName";

@implementation NSTextInputContext

// Private class methods that Mac Catalyst (UIKit-for-Mac) clients send. Both are
// accepted and ignored (GUESS, no public header or doc names them): the first
// says whether UIKeyCommand events are routed through the text input context,
// the second whether the event being dispatched is a UIKeyCommand event.
// Nothing in Cocotron consumes either value. Deliberately not declared in any
// header. NEEDS-REAL-MAC to confirm the semantics.
+ (void)setHandleUIKeyCommandEvent:(BOOL)flag {
}

+ (void)setIsUIKeyCommandEvent:(BOOL)flag {
}

+ (NSTextInputContext *)currentInputContext {
    static NSTextInputContext *current = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        current = [[NSTextInputContext alloc] init];
    });
    return current;
}

- (instancetype)initWithClient:(id)client {
    self = [super init];
    if (self) {
        _client = client;
    }
    return self;
}

- (id)client {
    return _client;
}

- (BOOL)handleEvent:(NSEvent *)event {
    if (event == nil || _client == nil)
        return NO;

    if ([event type] == NSKeyDown) {
        NSEventModifierFlags mods = [event modifierFlags];
        BOOL hasCmdOrCtrl = (mods & (NSCommandKeyMask | NSControlKeyMask)) != 0;

        // Shortcuts involving Command or Control (e.g. Cmd+A, Cmd+C, Cmd+V, Cmd+X, Cmd+Z)
        if (hasCmdOrCtrl) {
            Ivar ivar = class_getInstanceVariable([_client class], "need_handle");
            if (ivar != NULL) {
                *(char *)((char *)_client + ivar_getOffset(ivar)) = 1;
            }
            return NO;
        }

        NSString *characters = [event characters];
        if (characters == nil || [characters length] == 0) {
            characters = [event charactersIgnoringModifiers];
        }
        if (characters != nil && [characters length] > 0) {
            unichar c = [characters characterAtIndex:0];

            // Functional, editing and navigation control keys:
            // Backspace, Delete, Enter, Tab, Escape, Home, End, Arrows, PageUp/Down
            BOOL isFunctionOrControlKey = NO;
            if (c == 0x08 || c == 0x7F || c == '\r' || c == '\n' || c == '\t' || c == 0x1B) {
                isFunctionOrControlKey = YES;
            } else if (c >= 0xF700 && c <= 0xF8FF) {
                isFunctionOrControlKey = YES;
            }

            if (isFunctionOrControlKey) {
                Ivar ivar = class_getInstanceVariable([_client class], "need_handle");
                if (ivar != NULL) {
                    *(char *)((char *)_client + ivar_getOffset(ivar)) = 1;
                }
                return NO;
            }

            // Standard printable text characters
            if (c >= 0x20) {
                SEL selRange = sel_registerName("insertText:replacementRange:");
                if ([_client respondsToSelector:selRange]) {
                    typedef void (*InsertTextRangeFn)(id, SEL, id, NSRange);
                    InsertTextRangeFn fn = (InsertTextRangeFn)[_client methodForSelector:selRange];
                    if (fn) {
                        fn(_client, selRange, characters, NSMakeRange(NSNotFound, 0));
                        return YES;
                    }
                } else {
                    SEL sel = sel_registerName("insertText:");
                    if ([_client respondsToSelector:sel]) {
                        typedef void (*InsertTextFn)(id, SEL, id);
                        InsertTextFn fn = (InsertTextFn)[_client methodForSelector:sel];
                        if (fn) {
                            fn(_client, sel, characters);
                            return YES;
                        }
                    }
                }
            }
        }
    }
    return NO;
}

- (void)activate {
}

- (void)deactivate {
}

- (void)discardMarkedText {
}

- (void)invalidateCharacterCoordinates {
}

+ (NSString *)localizedNameForInputSource:(NSTextInputSourceIdentifier)inputSourceIdentifier {
    return @"U.S.";
}

- (NSTextInputSourceIdentifier)selectedKeyboardInputSource {
    return @"com.apple.keylayout.US";
}

- (void)setSelectedKeyboardInputSource:(NSTextInputSourceIdentifier)inputSourceIdentifier {
}

- (NSArray *)keyboardInputSources {
    return [NSArray arrayWithObject: @"com.apple.keylayout.US"];
}

@end
