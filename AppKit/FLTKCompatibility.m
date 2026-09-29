/*
 * FLTK Compatibility Shim for Darling AppKit
 *
 * This module provides runtime compatibility shims for macOS binaries built with FLTK
 * running under Darling X11/Wayland backends.
 */

#import <Foundation/NSNotification.h>
#import <Foundation/NSString.h>
#import <AppKit/NSEvent.h>
#import <objc/runtime.h>

static void (*orig_flWindowDidMove)(id self, SEL _cmd, NSNotification *notif) = NULL;
static void (*orig_flViewProcessKeyDown)(id self, SEL _cmd, NSEvent *event) = NULL;

static void safe_flWindowDidMove(id self, SEL _cmd, NSNotification *notif) {
    id win = [notif object];
    if (win != nil && [win respondsToSelector:@selector(getFl_Window)]) {
        typedef void *(*GetFlWindowFn)(id, SEL);
        GetFlWindowFn fn = (GetFlWindowFn)[win methodForSelector:@selector(getFl_Window)];
        void *flw = fn ? fn(win, @selector(getFl_Window)) : NULL;
        if (flw == NULL) {
            return;
        }
    } else {
        return;
    }
    if (orig_flWindowDidMove != NULL) {
        orig_flWindowDidMove(self, _cmd, notif);
    }
}

static void flViewProcessKeyDownFixed(id self, SEL _cmd, NSEvent *event) {
    if (orig_flViewProcessKeyDown != NULL) {
        orig_flViewProcessKeyDown(self, _cmd, event);
    }

    NSString *characters = [event characters];
    if (characters == nil || [characters length] == 0) {
        characters = [event charactersIgnoringModifiers];
    }

    BOOL needHandle = NO;
    NSEventModifierFlags mods = [event modifierFlags];
    if ((mods & (NSCommandKeyMask | NSControlKeyMask)) != 0) {
        needHandle = YES;
    }

    if (characters != nil && [characters length] > 0) {
        unichar c = [characters characterAtIndex:0];
        if (c == 0x08 || c == 0x7F || c == '\r' || c == '\n' || c == '\t' || c == 0x1B) {
            needHandle = YES;
        } else if (c >= 0xF700 && c <= 0xF8FF) {
            needHandle = YES;
        }
    } else {
        needHandle = YES;
    }

    if (needHandle) {
        Ivar ivar = class_getInstanceVariable([self class], "need_handle");
        if (ivar != NULL) {
            *(char *)((char *)self + ivar_getOffset(ivar)) = 1;
        }
    }
}

static BOOL flViewResolutionChangeFixed(id self, SEL _cmd) {
    return NO;
}

static BOOL flViewAcceptsFirstMouseFixed(id self, SEL _cmd, NSEvent *event) {
    return YES;
}

__attribute__((constructor))
static void applyFLTKCompatibilityShims(void) {
    Class delClass = objc_lookUpClass("FLWindowDelegate");
    if (delClass) {
        SEL sel = sel_registerName("windowDidMove:");
        Method m = class_getInstanceMethod(delClass, sel);
        if (m) {
            orig_flWindowDidMove = (void (*)(id, SEL, NSNotification *))method_getImplementation(m);
            method_setImplementation(m, (IMP)safe_flWindowDidMove);
        }
    }

    Class viewClass = objc_lookUpClass("FLView");
    if (viewClass) {
        SEL selPK = sel_registerName("process_keydown:");
        Method mPK = class_getInstanceMethod(viewClass, selPK);
        if (mPK) {
            orig_flViewProcessKeyDown = (void (*)(id, SEL, NSEvent *))method_getImplementation(mPK);
            method_setImplementation(mPK, (IMP)flViewProcessKeyDownFixed);
        }
        SEL selAFM = sel_registerName("acceptsFirstMouse:");
        Method mAFM = class_getInstanceMethod(viewClass, selAFM);
        if (mAFM) {
            method_setImplementation(mAFM, (IMP)flViewAcceptsFirstMouseFixed);
        }
        SEL selRC = sel_registerName("did_view_resolution_change");
        Method mRC = class_getInstanceMethod(viewClass, selRC);
        if (mRC) {
            method_setImplementation(mRC, (IMP)flViewResolutionChangeFixed);
        }
    }
}
