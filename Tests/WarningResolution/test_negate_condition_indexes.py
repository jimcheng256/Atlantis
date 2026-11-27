"""Exercise restoration and forwarding of Negated Condition class indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event System/Conditions/Condition-Negate.m"

PROBE = r'''

#import <AppKit/AppKit.h>
static NSInteger popupSelection;
static NSUInteger classIndex;
@interface Fixture : NSObject
@end
@implementation Fixture
- (NSInteger)indexOfSelectedItem { return popupSelection; }
- (NSUInteger)indexOfObject:(id)item { return classIndex; }
- (void)selectItemAtIndex:(NSInteger)index { printf("restored %ld\n", (long)index); }
@end
@interface Probe : NSObject {
@public NSPopUpButton *_rdConditionPicker;
NSObject *_rdChildCondition;
}
@end
@implementation Probe
- (void)setChildConditionClass:(NSInteger)index { printf("requested %ld\n", (long)index); }
CALLBACK
- (void)restore:(NSArray *)conditionClasses {
LOOKUP
}
@end
int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        Fixture *fixture = [Fixture new];
        probe->_rdConditionPicker = (NSPopUpButton *)fixture;
        for (NSNumber *value in @[@1, @4294967297LL, @(NSNotFound)]) {
            classIndex = value.unsignedLongLongValue;
            popupSelection = value.longLongValue;
            printf("input %lu\n", (unsigned long)classIndex);
            [probe restore:(NSArray *)fixture];
            [probe conditionTypeChanged:nil];
        }
    }
}
'''


class NegateConditionIndexTests(unittest.TestCase):
    def test_wide_and_missing_class_indexes(self):
        source = SOURCE.read_text()
        callback = re.search(r"^- \(void\) conditionTypeChanged:.*?^}", source, re.M | re.S)[0]
        lookup = re.search(r"^    (?:int|NSUInteger) conditionIndex = .*?^    }", source, re.M | re.S)[0]
        argument = re.search(r"setChildConditionClass:\((int|NSInteger)\)", source)[1]
        probe = PROBE.replace("CALLBACK", callback).replace("LOOKUP", lookup)
        probe = probe.replace("setChildConditionClass:(NSInteger)", f"setChildConditionClass:({argument})")
        with tempfile.TemporaryDirectory(prefix="atlantis-negate-condition.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            self.assertEqual(subprocess.check_output([binary], text=True).splitlines(), [
                "input 1", "restored 1", "requested 1",
                "input 4294967297", "restored 4294967297", "requested 4294967297",
                "input 9223372036854775807", "requested 9223372036854775807",
            ])


if __name__ == "__main__":
    unittest.main()
