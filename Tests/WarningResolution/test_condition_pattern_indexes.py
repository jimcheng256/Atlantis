"""Exercise both condition pattern popups at the AppKit index boundary."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
CONDITIONS = ROOT / "Event System/Conditions"
UTILITY = ROOT / "Utility Classes"

FIXTURE = r'''
#import <AppKit/AppKit.h>
#import "RDStringPattern.h"

static NSInteger selection;

@implementation RDStringPattern
+ (RDStringPattern *)patternWithString:(NSString *)pattern type:(int)type {
    RDStringPattern *value = [[[self alloc] init] autorelease];
    value->_rdPattern = [pattern copy];
    value->_rdPatternType = type;
    return value;
}
- (NSString *)pattern { return _rdPattern; }
- (int)type { return _rdPatternType; }
- (void)dealloc { [_rdPattern release]; [super dealloc]; }
@end

@interface Popup : NSObject
@end
@implementation Popup
- (id)selectedItem { return self; }
- (NSInteger)indexOfItem:(id)item { return selection; }
- (NSInteger)indexOfSelectedItem { return selection; }
@end

@interface Probe : NSObject {
@public
    NSPopUpButton *_rdPatternType;
    RDStringPattern *_rdPattern;
}
- (void)patternTypeChanged:(id)sender;
@end
@implementation Probe
@end
'''

DRIVER = r'''
int main(int argc, char **argv) {
    @autoreleasepool {
        selection = strtoll(argv[2], NULL, 10);
        Probe *probe = [[[NSClassFromString([NSString stringWithUTF8String:argv[1]]) alloc] init] autorelease];
        probe->_rdPatternType = (NSPopUpButton *)[Popup new];
        probe->_rdPattern = [[RDStringPattern patternWithString:@"match me" type:RDPatternContains] retain];
        RDStringPattern *original = [[probe->_rdPattern retain] autorelease];
        [probe patternTypeChanged:nil];
        printf("%d %d %s\n", original == probe->_rdPattern,
               [probe->_rdPattern type], [probe->_rdPattern pattern].UTF8String);
    }
}
'''


class ConditionPatternIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        implementations = []
        for name in ("StringMatch", "VariableMatch"):
            source = (CONDITIONS / f"Condition-{name}.m").read_text()
            match = re.search(r"^- \(void\) patternTypeChanged:.*?^}", source, re.M | re.S)
            if match is None:
                raise ValueError(f"Expected the pattern callback in {name}")
            implementations.append(f"@interface {name} : Probe\n@end\n@implementation {name}\n{match[0]}\n@end")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-condition-patterns.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + "\n".join(implementations) + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-Wno-incomplete-implementation", "-Wno-protocol",
                        "-framework", "AppKit", "-I", str(UTILITY), str(source),
                        "-o", str(cls.exe)], check=True)

    def check_selection(self, index, expected):
        for name in ("StringMatch", "VariableMatch"):
            with self.subTest(condition=name, index=index):
                output = subprocess.check_output([self.exe, name, str(index)], text=True)
                self.assertEqual(output, expected)

    def test_valid_choices_preserve_pattern_text(self):
        for index in range(4):
            self.check_selection(index, f"0 {index} match me\n")

    def test_invalid_choices_preserve_the_existing_pattern(self):
        for index in (-1, 4, 2**32 + 1, 2**63 - 1):
            self.check_selection(index, "1 2 match me\n")


if __name__ == "__main__":
    unittest.main()
