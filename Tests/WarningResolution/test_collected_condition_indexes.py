"""Exercise mode selection and removal in the collected-conditions editor."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event System/Conditions/Condition-CollectedConditions.m"

FIXTURE = r'''
#import <AppKit/AppKit.h>
#include <limits.h>
typedef NSObject RDChainedListItem;
static NSInteger mode;
static unsigned position;
static NSUInteger count;
static BOOL active;

@interface Store : NSObject
@end
@implementation Store
- (id)selectedItem { return mode < 0 ? nil : self; }
- (NSInteger)indexOfItem:(id)item { return mode; }
- (NSInteger)indexOfSelectedItem { return mode; }
- (NSUInteger)count { return count; }
- (void)removeObjectAtIndex:(NSUInteger)index { printf("remove %lu\n", (unsigned long)index); }
- (id)currentActiveItem { return active ? self : nil; }
- (unsigned)positionOfItem:(id)item { return position; }
- (void)removeItem:(id)item { puts("remove view"); }
@end

@interface Probe : NSObject {
@public
    Store *_rdConditions, *_rdConditionsChain, *_rdConditionsAndedPicker;
    BOOL _rdConditionsAnded;
}
@end
@implementation Probe
'''

DRIVER = r'''
@end
int main(int argc, char **argv) {
    @autoreleasepool {
        mode = strtoll(argv[1], NULL, 10);
        position = (unsigned)strtoul(argv[2], NULL, 10);
        count = strtoull(argv[3], NULL, 10);
        active = atoi(argv[4]) != 0;
        Probe *probe = [Probe new];
        probe->_rdConditions = probe->_rdConditionsChain = probe->_rdConditionsAndedPicker = [Store new];
        probe->_rdConditionsAnded = atoi(argv[5]) != 0;
        [probe conditionAndedChanged:nil];
        printf("mode %d\n", (int)probe->_rdConditionsAnded);
        [probe removeSubCondition:nil];
    }
}
'''


class CollectedConditionIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        methods = re.findall(r"^- \(void\) (?:conditionAndedChanged|removeSubCondition):[^\n]*\n\{.*?^}",
                             SOURCE.read_text(), re.M | re.S)
        if len(methods) != 2:
            raise ValueError("Expected both collected-condition handlers")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-collected-condition.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + "\n".join(methods) + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(source),
                        "-o", str(cls.exe)], check=True)

    def check(self, mode, position, count, expected, *, active=True, anded=False):
        actual = subprocess.check_output(
            [self.exe, str(mode), str(position), str(count), str(int(active)), str(int(anded))], text=True
        )
        self.assertEqual(actual, expected)

    def test_valid_modes_and_positions(self):
        self.check(0, 1, 2, "mode 0\nremove 1\nremove view\n", anded=True)
        wide = 2**31 + 1
        self.check(1, wide, wide + 1, f"mode 1\nremove {wide}\nremove view\n")

    def test_invalid_modes_preserve_current_setting(self):
        for mode in (-1, 2, 2**32, 2**32 + 1):
            for anded in (False, True):
                with self.subTest(mode=mode, anded=anded):
                    self.check(mode, 0, 2, f"mode {int(anded)}\n", active=False, anded=anded)

    def test_missing_and_out_of_range_positions(self):
        for position in (2, 2**32 - 1):
            with self.subTest(position=position):
                self.check(1, position, 2, "mode 1\n")


if __name__ == "__main__":
    unittest.main()
