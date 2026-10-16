#import <AppKit/AppKit.h>
#include <dbus/dbus.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

@interface NSObject (LayoutUpdatedBackend)
- (BOOL) isAvailable;
@end

int main(void) {
    NSAutoreleasePool *pool = [NSAutoreleasePool new];
    NSMenu *menus[2] = {nil, nil};
    DBusConnection *emitter = NULL, *receiver = NULL;
    DBusMessage *message = NULL;
    DBusError error;
    const char *sender = NULL, *receiverName = NULL;
    const char *address = getenv("DBUS_SESSION_BUS_ADDRESS");
    char match[512];
    struct timespec start, now;
    unsigned int received = 0;
    int result = 1;
    dbus_error_init(&error);

    if (!address || !*address) {
        fprintf(stderr, "FAIL: require an isolated DBUS_SESSION_BUS_ADDRESS\n");
        goto cleanup;
    }
    emitter = dbus_bus_get(DBUS_BUS_SESSION, &error);
    if (!emitter || dbus_error_is_set(&error)) {
        fprintf(stderr, "FAIL: cached emitter connection: %s\n",
                error.message ? error.message : "no connection");
        goto cleanup;
    }
    sender = dbus_bus_get_unique_name(emitter);
    if (!sender || !*sender) {
        fprintf(stderr, "FAIL: cached emitter has no unique name\n");
        goto cleanup;
    }
    receiver = dbus_bus_get_private(DBUS_BUS_SESSION, &error);
    if (!receiver || dbus_error_is_set(&error)) {
        fprintf(stderr, "FAIL: private receiver connection: %s\n",
                error.message ? error.message : "no connection");
        goto cleanup;
    }
    dbus_connection_set_exit_on_disconnect(receiver, FALSE);
    receiverName = dbus_bus_get_unique_name(receiver);
    if (!receiverName || !*receiverName || receiver == emitter ||
        strcmp(receiverName, sender) == 0) {
        fprintf(stderr, "FAIL: receiver must have a distinct connection identity\n");
        goto cleanup;
    }
    int length = snprintf(match, sizeof(match),
            "type='signal',sender='%s',path='/MenuBar',"
            "interface='com.canonical.dbusmenu',member='LayoutUpdated'", sender);
    if (length < 0 || (size_t)length >= sizeof(match)) {
        fprintf(stderr, "FAIL: subscription rule does not fit\n");
        goto cleanup;
    }
    // A non-NULL error waits for AddMatch acknowledgement before either update.
    dbus_bus_add_match(receiver, match, &error);
    if (dbus_error_is_set(&error)) {
        fprintf(stderr, "FAIL: AddMatch: %s\n", error.message);
        goto cleanup;
    }

    [NSApplication sharedApplication];
    Class globalMenuClass = NSClassFromString(@"X11GlobalMenu");
    if (!globalMenuClass ||
        ![globalMenuClass respondsToSelector: @selector(sharedGlobalMenu)]) {
        fprintf(stderr, "FAIL: X11GlobalMenu backend is not loaded\n");
        goto cleanup;
    }
    id globalMenu = [globalMenuClass performSelector: @selector(sharedGlobalMenu)];
    if (!globalMenu || ![globalMenu isAvailable]) {
        fprintf(stderr, "FAIL: X11GlobalMenu singleton is unavailable\n");
        goto cleanup;
    }
    menus[0] = [[NSMenu alloc] initWithTitle: @"First"];
    menus[1] = [[NSMenu alloc] initWithTitle: @"Second"];
    if (!menus[0] || !menus[1]) {
        fprintf(stderr, "FAIL: could not allocate the controlled menus\n");
        goto cleanup;
    }
    if (clock_gettime(CLOCK_MONOTONIC, &start) != 0) {
        perror("FAIL: monotonic clock");
        goto cleanup;
    }
    for (unsigned int index = 0; index < 2; index++) {
        [NSApp setMainMenu: menus[index]];
        dbus_connection_flush(emitter);
        if (!dbus_connection_get_is_connected(emitter)) {
            fprintf(stderr, "FAIL: emitter disconnected during update\n");
            goto cleanup;
        }
    }

    while (received < 2) {
        if (clock_gettime(CLOCK_MONOTONIC, &now) != 0) {
            perror("FAIL: monotonic clock");
            goto cleanup;
        }
        double elapsed = (double)(now.tv_sec - start.tv_sec) +
                (double)(now.tv_nsec - start.tv_nsec) / 1000000000.0;
        if (elapsed >= 5.0) {
            fprintf(stderr, "FAIL: deadline waiting for LayoutUpdated %u of 2\n",
                    received + 1);
            goto cleanup;
        }
        if (!dbus_connection_read_write(receiver, 50)) {
            fprintf(stderr, "FAIL: receiver disconnected while reading\n");
            goto cleanup;
        }
        message = dbus_connection_pop_message(receiver);
        if (!message)
            continue;
        const char *actualSender = dbus_message_get_sender(message);
        const char *path = dbus_message_get_path(message);
        const char *interface = dbus_message_get_interface(message);
        const char *member = dbus_message_get_member(message);
        if (actualSender && strcmp(actualSender, DBUS_SERVICE_DBUS) == 0 &&
            path && strcmp(path, DBUS_PATH_DBUS) == 0 &&
            interface && strcmp(interface, DBUS_INTERFACE_DBUS) == 0) {
            dbus_message_unref(message);
            message = NULL;
            continue;
        }
        if (dbus_message_get_type(message) != DBUS_MESSAGE_TYPE_SIGNAL ||
            !actualSender || strcmp(actualSender, sender) != 0 ||
            !path || strcmp(path, "/MenuBar") != 0 ||
            !interface || strcmp(interface, "com.canonical.dbusmenu") != 0 ||
            !member || strcmp(member, "LayoutUpdated") != 0) {
            fprintf(stderr, "FAIL: unexpected message identity for update %u\n",
                    received + 1);
            goto cleanup;
        }
        const char *signature = dbus_message_get_signature(message);
        if (!signature || strcmp(signature, "ui") != 0) {
            fprintf(stderr, "FAIL: update %u signature '%s', expected 'ui'\n",
                    received + 1, signature ? signature : "(missing)");
            goto cleanup;
        }
        DBusMessageIter iter;
        dbus_uint32_t revision;
        dbus_int32_t parent;
        if (!dbus_message_iter_init(message, &iter) ||
            dbus_message_iter_get_arg_type(&iter) != DBUS_TYPE_UINT32) {
            fprintf(stderr, "FAIL: update %u missing UINT32 revision\n", received + 1);
            goto cleanup;
        }
        dbus_message_iter_get_basic(&iter, &revision);
        if (!dbus_message_iter_next(&iter) ||
            dbus_message_iter_get_arg_type(&iter) != DBUS_TYPE_INT32) {
            fprintf(stderr, "FAIL: update %u missing INT32 parent\n", received + 1);
            goto cleanup;
        }
        dbus_message_iter_get_basic(&iter, &parent);
        if (dbus_message_iter_next(&iter)) {
            fprintf(stderr, "FAIL: update %u has an extra argument\n", received + 1);
            goto cleanup;
        }
        if (revision != received + 2 || parent != 0) {
            fprintf(stderr, "FAIL: update %u got revision=%u parent=%d, expected %u/0\n",
                    received + 1, (unsigned int)revision, (int)parent, received + 2);
            goto cleanup;
        }
        received++;
        dbus_message_unref(message);
        message = NULL;
    }
    puts("PASS: LayoutUpdated ui 2/0 then ui 3/0 from cached emitter");
    if (fflush(stdout) != 0) {
        perror("FAIL: writing PASS marker");
        goto cleanup;
    }
    result = 0;

cleanup:
    if (message)
        dbus_message_unref(message);
    [menus[0] release];
    [menus[1] release];
    if (receiver) {
        dbus_connection_close(receiver);
        dbus_connection_unref(receiver);
    }
    if (emitter)
        dbus_connection_unref(emitter);
    dbus_error_free(&error);
    [pool drain];
    return result;
}
