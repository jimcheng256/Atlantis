"""Verify the Carbon modifier mask passed to the hotkey dispatchers."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Core/RDAtlantisApplication.m"
PROBE = r'''
#import <AppKit/AppKit.h>
#import <Carbon/Carbon.h>

@interface Probe : NSObject
- (int)modifiersForEvent:(NSEvent *)theEvent;
@end

@implementation Probe
CONVERSION
- (int)modifiersForEvent:(NSEvent *)theEvent {
    CALL
    return modifiers;
}
@end

int main(void) {
    @autoreleasepool {
        const NSEventModifierFlags flags[] = {
            NSEventModifierFlagCommand, NSEventModifierFlagOption,
            NSEventModifierFlagControl, NSEventModifierFlagShift,
            NSEventModifierFlagFunction
        };
        const int masks[] = {cmdKey, optionKey, controlKey, shiftKey, rightControlKey};
        Probe *probe = [Probe new];
        for (unsigned combination = 0; combination < 32; ++combination) {
            int expected = 0;
            NSEventModifierFlags enabled = 0;
            for (unsigned i = 0; i < 5; ++i) {
                if (combination & (1U << i)) {
                    enabled |= flags[i];
                    expected |= masks[i];
                }
            }
            for (NSNumber *extra in @[@0, @(NSEventModifierFlagCapsLock |
                                            NSEventModifierFlagNumericPad |
                                            NSEventModifierFlagHelp)]) {
                NSEvent *event = [NSEvent keyEventWithType:NSEventTypeKeyDown location:NSZeroPoint
                    modifierFlags:enabled | extra.unsignedIntegerValue timestamp:0 windowNumber:0
                    context:nil characters:@"a" charactersIgnoringModifiers:@"a" isARepeat:NO keyCode:0];
                NSCAssert([probe modifiersForEvent:event] == expected, @"Carbon mask mismatch");
            }
        }
        [probe release];
    }
}
'''


class ApplicationModifierMaskTests(unittest.TestCase):
    def test_every_modifier_combination_keeps_its_carbon_mask(self):
        source = SOURCE.read_text()
        conversion = re.search(r"^- \(long\)cocoaModifiersAsCarbonModifiers:.*?^}", source, re.M | re.S)[0]
        call = re.search(r"int modifiers = .*?\[self cocoaModifiersAsCarbonModifiers:.*?;", source)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-application-modifiers.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("CONVERSION", conversion).replace("CALL", call))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            subprocess.run([binary], check=True)


if __name__ == "__main__":
    unittest.main()
