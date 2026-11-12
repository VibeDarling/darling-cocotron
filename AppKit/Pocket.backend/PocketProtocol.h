/* The wire protocol between AppKit's Pocket backend and a phone host.

 Permission is hereby granted, free of charge, to any person obtaining a copy of
 this software and associated documentation files (the "Software"), to deal in
 the Software without restriction, including without limitation the rights to
 use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
 of the Software, and to permit persons to whom the Software is furnished to do
 so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in all
 copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 SOFTWARE. */

/*
 * Plain C, with no Darwin or Android headers, so that the host (an Android
 * app's native code, or tools/pocket-host on Linux) includes it as is.
 *
 * The host listens on a Unix stream socket; each app connects to it. Every
 * message is a header and then `size` bytes of payload, in the machine's
 * byte order (both ends are the same phone). A POCKET_BUFFER message carries
 * one file descriptor (SCM_RIGHTS), sent with its first byte.
 *
 * Coordinates are the screen's pixels, from its top left. A window's pixels
 * are in a shared memory buffer: rows from the top, POCKET_FORMAT_BGRA
 * (premultiplied alpha, blue in the lowest byte).
 *
 * Frames: after POCKET_PRESENT the app does not touch the buffer until the
 * host answers POCKET_RELEASE for it, so the host may read it in its own time
 * and nothing tears. Then the app may present again.
 */

#ifndef POCKET_PROTOCOL_H
#define POCKET_PROTOCOL_H

#include <stdint.h>

#define POCKET_PROTOCOL_VERSION 1
// Longer messages are a broken peer.
#define POCKET_MAX_MESSAGE 4096

struct pocket_header {
    uint32_t type;
    uint32_t size; // payload bytes after this header
};

enum {
    // App to host.
    POCKET_HELLO = 1,    // struct pocket_hello
    POCKET_WINDOW = 2,   // struct pocket_window: a new window, or its new state
    POCKET_BUFFER = 3,   // struct pocket_buffer, with the buffer's descriptor
    POCKET_PRESENT = 4,  // struct pocket_present
    POCKET_DESTROY = 5,  // struct pocket_window_id
    POCKET_ORDER = 6,    // uint32_t windows[], from the bottom up
    POCKET_KEYBOARD = 7, // struct pocket_keyboard: show or hide the soft keyboard

    // Host to app.
    POCKET_SCREEN = 101,  // struct pocket_screen, first, and again on a change
    POCKET_RELEASE = 102, // struct pocket_window_id
    POCKET_TOUCH = 103,   // struct pocket_touch
    POCKET_KEY = 104,     // struct pocket_key, then the characters (UTF-8)
    POCKET_TEXT = 105,    // UTF-8 text the input method commits
    POCKET_KEYBOARD_FRAME = 106, // struct pocket_keyboard_frame: the soft keyboard came, went or resized
};

enum {
    POCKET_FORMAT_BGRA = 1,
};

enum {
    POCKET_WINDOW_VISIBLE = 1,
    POCKET_WINDOW_OPAQUE = 2,
};

enum {
    POCKET_TOUCH_BEGAN = 0,
    POCKET_TOUCH_MOVED = 1,
    POCKET_TOUCH_ENDED = 3,
    POCKET_TOUCH_CANCELLED = 4,
};

struct pocket_hello {
    uint32_t version;
    uint32_t pid;
};

struct pocket_window_id {
    uint32_t window;
};

struct pocket_window {
    uint32_t window;
    int32_t x, y, width, height;
    uint32_t flags;
    int32_t level; // AppKit's window level; higher is in front
};

struct pocket_buffer {
    uint32_t window;
    uint32_t width, height, stride;
    uint32_t format;
};

struct pocket_present {
    uint32_t window;
    // The part that changed.
    int32_t x, y, width, height;
};

enum {
    POCKET_KEYBOARD_SECURE = 1,    // a password: nothing remembered or suggested
    POCKET_KEYBOARD_MULTILINE = 2, // Return starts a new line
};

// Hosts take the fields after `shown` only when the message is long enough.
struct pocket_keyboard {
    uint32_t shown;
    // The text's UITextInputTraits, with iOS's values.
    uint32_t keyboard_type;      // UIKeyboardType
    uint32_t return_key;         // UIReturnKeyType
    uint32_t autocapitalization; // UITextAutocapitalizationType
    uint32_t autocorrection;     // UITextAutocorrectionType
    uint32_t flags;              // POCKET_KEYBOARD_*
};

struct pocket_keyboard_frame {
    uint32_t height; // pixels the keyboard covers at the bottom; 0 once it is gone
};

struct pocket_screen {
    uint32_t width, height; // pixels
    uint32_t scale_milli;   // pixels per point, times 1000
    // Pixels a notch, a status bar or a navigation bar cover.
    uint32_t inset_top, inset_left, inset_bottom, inset_right;
};

struct pocket_touch {
    uint32_t phase;
    uint32_t finger; // the same while the finger is down, reused afterwards
    float x, y;
    double time; // seconds, any epoch
};

struct pocket_key {
    uint32_t down;
    // A Mac virtual key code (kVK_*), 0xFFFF for none. For Return, Tab,
    // Delete, Escape, the arrows and the like the app knows the characters.
    uint32_t keycode;
    uint32_t modifiers; // NSEventModifierFlags
    uint32_t length;    // bytes of characters that follow
};

#endif
