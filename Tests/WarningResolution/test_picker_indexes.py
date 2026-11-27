"""Exercise the action and condition sheet callbacks with synthetic menu indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def picker_callback(kind):
    source = (ROOT / "Event System" / f"{kind}Picker.m").read_text()
    match = re.search(r"^- \(void\)_sheetDidEnd:[^\n]+\n\{.*?^\}", source, re.M | re.S)
    if not match:
        raise ValueError(f"Missing sheet callback in {kind}Picker")
    return match[0]


def probe_source():
    source = r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

typedef NSObject BaseAction;
typedef NSObject BaseCondition;

@interface MenuFixture : NSObject
@property NSInteger index;
@end
@implementation MenuFixture
- (NSMenuItem *)selectedItem { return nil; }
- (NSInteger)indexOfItem:(NSMenuItem *)item { return self.index; }
- (NSInteger)indexOfSelectedItem { return self.index; }
@end

@interface ClassesFixture : NSObject
@property NSUInteger count;
@property NSUInteger lookedUpIndex;
@property NSUInteger lookups;
@end
@implementation ClassesFixture
- (Class)objectAtIndex:(NSUInteger)index {
    self.lookedUpIndex = index;
    self.lookups++;
    return [NSObject class];
}
@end

@interface DelegateFixture : NSObject
@property NSUInteger calls;
@end
@implementation DelegateFixture
- (void)newActionPicked:(BaseAction *)action context:(void *)context {
    self.calls++;
    [action release];
}
- (void)newConditionPicked:(BaseCondition *)condition context:(void *)context {
    self.calls++;
    [condition release];
}
@end
'''
    for kind in ("Action", "Condition"):
        source += f'''
@interface {kind}Probe : NSObject {{
    MenuFixture *_rd{kind}List;
    ClassesFixture *_rd{kind}Classes;
    DelegateFixture *_rdDelegate;
    void *_rdContext;
    NSWindow *_rd{kind}Picker;
}}
+ (void)runIndex:(NSInteger)index count:(NSUInteger)count;
@end

@implementation {kind}Probe
{picker_callback(kind)}

+ (void)runIndex:(NSInteger)index count:(NSUInteger)count {{
    {kind}Probe *picker = [[self alloc] init];
    MenuFixture *menu = [[MenuFixture alloc] init];
    ClassesFixture *classes = [[ClassesFixture alloc] init];
    DelegateFixture *delegate = [[DelegateFixture alloc] init];
    menu.index = index;
    classes.count = count;
    picker->_rd{kind}List = menu;
    picker->_rd{kind}Classes = [classes retain];
    picker->_rdDelegate = delegate;
    [picker _sheetDidEnd:nil returnCode:NSModalResponseOK contextInfo:NULL];
    printf("%lu %lu %lu\\n", (unsigned long)classes.lookups,
           (unsigned long)classes.lookedUpIndex, (unsigned long)delegate.calls);
    [delegate release];
    [classes release];
    [menu release];
    [picker release];
}}
@end
'''
    return source + r'''
int main(int argc, char **argv) {
    @autoreleasepool {
        NSInteger index = strtoll(argv[2], NULL, 10);
        NSUInteger count = strtoull(argv[3], NULL, 10);
        if (strcmp(argv[1], "Action") == 0) {
            [ActionProbe runIndex:index count:count];
        } else {
            [ConditionProbe runIndex:index count:count];
        }
    }
}
'''


class PickerIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-picker-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-framework", "Cocoa", str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check_index(self, index, count, expected):
        for kind in ("Action", "Condition"):
            with self.subTest(picker=kind, index=index, count=count):
                result = subprocess.check_output(
                    [self.executable, kind, str(index), str(count)],
                )
                self.assertEqual(tuple(map(int, result.split())), expected)

    def test_valid_selection_dispatches(self):
        self.check_index(1, 2, (1, 1, 1))

    def test_large_selection_keeps_full_index(self):
        index = 2**32 + 1
        self.check_index(index, index + 1, (1, index, 1))

    def test_no_selection_does_not_dispatch(self):
        self.check_index(-1, 2, (0, 0, 0))
        self.check_index(2**63 - 1, 2, (0, 0, 0))

    def test_out_of_range_selection_does_not_dispatch(self):
        self.check_index(0, 0, (0, 0, 0))
        self.check_index(2, 2, (0, 0, 0))


if __name__ == "__main__":
    unittest.main()
