#import <AppKit/AppKit.h>
#include <assert.h>

#define CHECK_ALIAS(OLD, NEW) do { \
    _Static_assert(__builtin_types_compatible_p(__typeof__(OLD), __typeof__(NEW)), "alias type"); \
    assert((OLD) == (NEW)); \
} while (0)

int main(void) {
    @autoreleasepool {
        CHECK_ALIAS(NSOnState, NSControlStateValueOn);
        CHECK_ALIAS(NSOffState, NSControlStateValueOff);
        assert(NSOKButton == NSModalResponseOK);
        assert(NSCancelButton == NSModalResponseCancel);
        CHECK_ALIAS(NSLeftMouseDraggedMask, NSEventMaskLeftMouseDragged);
        CHECK_ALIAS(NSLeftMouseUpMask, NSEventMaskLeftMouseUp);
        CHECK_ALIAS(NSLeftMouseDragged, NSEventTypeLeftMouseDragged);
        CHECK_ALIAS(NSLeftMouseUp, NSEventTypeLeftMouseUp);
        CHECK_ALIAS(NSShiftKeyMask, NSEventModifierFlagShift);
        CHECK_ALIAS(NSCommandKeyMask, NSEventModifierFlagCommand);
        CHECK_ALIAS(NSAlternateKeyMask, NSEventModifierFlagOption);
        CHECK_ALIAS(NSControlKeyMask, NSEventModifierFlagControl);
        CHECK_ALIAS(NSFunctionKeyMask, NSEventModifierFlagFunction);
        CHECK_ALIAS(NSKeyDown, NSEventTypeKeyDown);
        CHECK_ALIAS(NSSmallControlSize, NSControlSizeSmall);

        printf("15 numeric aliases match in value\n");
    }
}
