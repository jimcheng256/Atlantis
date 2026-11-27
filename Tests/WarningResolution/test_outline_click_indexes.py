"""Exercise the blocking outline view's production mouse handling."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Utility Classes/RDBlockingOutlineView.m"


def probe_source():
    source = SOURCE.read_text()
    method = re.search(r"^- \(void\) mouseDown:[^\n]*\n\{.*?^\}", source, re.M | re.S)
    if not method:
        raise ValueError(f"Missing mouseDown: in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>

@interface MouseQueue : NSObject
@property (retain) NSEvent *nextEvent;
@end
@implementation MouseQueue
- (NSEvent *)nextEventMatchingMask:(NSEventMask)mask untilDate:(NSDate *)deadline
                           inMode:(NSString *)mode dequeue:(BOOL)dequeue {
    return self.nextEvent;
}
@end

static MouseQueue *queue;
#undef NSApp
#define NSApp queue

@interface ColumnFixture : NSObject
@property NSUInteger index;
@property BOOL lookedUp;
@end
@implementation ColumnFixture
- (id)objectAtIndex:(NSUInteger)index {
    self.index = index;
    self.lookedUp = YES;
    return self;
}
@end

@interface OutlineFixture : NSObject
@property NSUInteger fallbackClicks;
@end
@implementation OutlineFixture
- (void)mouseDown:(NSEvent *)event { self.fallbackClicks++; }
@end

@interface OutlineProbe : OutlineFixture
@property NSInteger row;
@property NSInteger column;
@property NSInteger itemRow;
@property BOOL blocksClick;
@property NSUInteger delegateCalls;
@property (retain) ColumnFixture *columns;
- (void)mouseDown:(NSEvent *)event;
@end

@implementation OutlineProbe
- (NSPoint)convertPoint:(NSPoint)point fromView:(NSView *)view { return point; }
- (NSInteger)rowAtPoint:(NSPoint)point { return self.row; }
- (NSInteger)columnAtPoint:(NSPoint)point { return self.column; }
- (id)delegate { return self; }
- (id)itemAtRow:(NSInteger)row {
    self.itemRow = row;
    return self;
}
- (ColumnFixture *)tableColumns { return self.columns; }
- (BOOL)outlineView:(OutlineProbe *)outline clickedItem:(id)item inColumn:(ColumnFixture *)column {
    self.delegateCalls++;
    return self.blocksClick;
}
''' + method[0] + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        OutlineProbe *probe = [[[OutlineProbe alloc] init] autorelease];
        probe.row = strtoll(argv[1], NULL, 10);
        probe.column = strtoll(argv[2], NULL, 10);
        probe.blocksClick = atoi(argv[3]);
        probe.columns = [[[ColumnFixture alloc] init] autorelease];
        NSEventType eventType = atoi(argv[4]) ? NSEventTypeLeftMouseDragged : NSEventTypeLeftMouseUp;
        queue = [[[MouseQueue alloc] init] autorelease];
        queue.nextEvent = [NSEvent mouseEventWithType:eventType location:NSZeroPoint modifierFlags:0 timestamp:0
                                       windowNumber:0 context:nil eventNumber:0 clickCount:1 pressure:0];
        [probe mouseDown:nil];

        printf("%lu %lu\n", (unsigned long)probe.delegateCalls, (unsigned long)probe.fallbackClicks);
        if (probe.columns.lookedUp) {
            printf("%ld %lu\n", (long)probe.itemRow, (unsigned long)probe.columns.index);
        }
    }
}
'''


class OutlineClickIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-outline-click-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-framework", "Cocoa", str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check_click(self, row, column, expected, *, block=True, drag=False):
        result = subprocess.check_output(
            [self.executable, str(row), str(column), str(int(block)), str(int(drag))], text=True,
        )
        self.assertEqual(result.splitlines(), expected)

    def test_ordinary_click_can_block_or_forward(self):
        self.check_click(2, 1, ["1 0", "2 1"])
        self.check_click(2, 1, ["1 1", "2 1"], block=False)

    def test_wide_indexes_reach_the_delegate(self):
        row, column = 2**32 + 2, 2**32 + 1
        self.check_click(row, column, ["1 0", f"{row} {column}"])

    def test_missing_row_or_column_forwards_without_lookup(self):
        for row, column in ((-1, 1), (2, -1)):
            with self.subTest(row=row, column=column):
                self.check_click(row, column, ["0 1"])

    def test_drag_forwards_without_lookup(self):
        self.check_click(2, 1, ["0 1"], drag=True)


if __name__ == "__main__":
    unittest.main()
