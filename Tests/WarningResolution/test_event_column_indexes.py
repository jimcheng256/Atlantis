"""Verify extra-data column moves with AppKit's signed indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"

FIXTURE = r'''
#import <AppKit/AppKit.h>

static NSInteger column;
static NSInteger count;
@interface Fixture : NSObject
@end
@implementation Fixture
- (NSInteger)columnWithIdentifier:(NSString *)identifier { return column; }
- (NSInteger)numberOfColumns { return count; }
- (void)moveColumn:(NSInteger)oldIndex toColumn:(NSInteger)newIndex {
    printf("move %ld %ld\n", (long)oldIndex, (long)newIndex);
}
@end

@interface Probe : NSObject {
@public
    NSTableView *_rdTableView;
}
@end
@implementation Probe
- (void)addExtraDataColumn:(NSString *)identifier withTitle:(NSString *)title andCell:(NSCell *)cell {
    puts("install");
}
'''

DRIVER = r'''
@end
int main(int argc, char **argv) {
    @autoreleasepool {
        column = strtoll(argv[1], NULL, 10);
        count = strtoll(argv[2], NULL, 10);
        Probe *probe = [Probe new];
        probe->_rdTableView = (NSTableView *)[Fixture new];
        [probe addExtraDataColumn:@"fixture" withTitle:@"Fixture" andCell:nil atIndex:atoi(argv[3])];
    }
}
'''


class EventColumnIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        method = re.search(
            r"^- \(void\) addExtraDataColumn:[^\n]*atIndex:[^\n]*\n\{.*?^}",
            SOURCE.read_text(), re.M | re.S,
        )
        if method is None:
            raise ValueError("Expected the positioned extra-data column method")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-event-columns.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + method[0] + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-framework", "AppKit",
                        str(source), "-o", str(cls.exe)], check=True)

    def check_move(self, column, count, destination, expected):
        actual = subprocess.check_output(
            [self.exe, str(column), str(count), str(destination)], text=True
        )
        self.assertEqual(actual, "install\n" + expected)

    def test_ordinary_and_full_width_columns(self):
        self.check_move(2, 3, 1, "move 2 1\n")
        wide = 2**32 + 1
        self.check_move(wide, wide + 1, 1, f"move {wide} 1\n")

    def test_missing_and_out_of_range_indexes(self):
        for column, count, destination in ((-1, 2, 1), (2, 2, 1),
                                           (1, 2, -1), (1, 2, 2)):
            with self.subTest(column=column, count=count, destination=destination):
                self.check_move(column, count, destination, "")


if __name__ == "__main__":
    unittest.main()
