"""Exercise the whole-event move actions at the table and collection boundary."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"

FIXTURE = r'''
#import <AppKit/AppKit.h>
#import "EventCollection.h"

static NSInteger selectedRow;
static int eventCount;
static BOOL missingEvent;

@interface Probe : NSObject {
@public
    NSTableView *_rdTableView;
    EventCollection *_rdEventData;
    BOOL _rdNoRedraw;
}
@end

@interface Fixture : NSObject
@property (assign) Probe *probe;
@end
@implementation Fixture
- (NSInteger)selectedRow { return selectedRow; }
- (NSWindow *)window { return (NSWindow *)self; }
- (BOOL)makeFirstResponder:(NSResponder *)responder { puts("focus"); return YES; }
- (int)eventsCount { return eventCount; }
- (id)eventAtIndex:(unsigned)index {
    printf("event %u\n", index);
    return index < (unsigned)eventCount && !missingEvent ? self : nil;
}
- (void)moveEvent:(id)event toIndex:(unsigned)index { printf("move %u\n", index); }
- (void)reloadData { puts("reload"); }
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend {
    printf("select %ld %d %d\n", (long)row, extend, self.probe->_rdNoRedraw);
}
@end

@implementation Probe
'''

DRIVER = r'''
@end
int main(int argc, char **argv) {
    @autoreleasepool {
        selectedRow = strtoll(argv[1], NULL, 10);
        eventCount = atoi(argv[2]);
        missingEvent = atoi(argv[3]) != 0;
        Fixture *fixture = [Fixture new];
        Probe *probe = [Probe new];
        fixture.probe = probe;
        probe->_rdTableView = (NSTableView *)fixture;
        probe->_rdEventData = (EventCollection *)fixture;
        if (strcmp(argv[4], "up") == 0)
            [probe moveEventUp:nil];
        else
            [probe moveEventDown:nil];
        printf("redraw %d\n", probe->_rdNoRedraw);
    }
}
'''


class EventReorderIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        methods = re.findall(r"^- \(void\) moveEvent(?:Up|Down):.*?^}", SOURCE.read_text(), re.M | re.S)
        if len(methods) != 2:
            raise ValueError("Expected both whole-event move actions")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-event-reorder.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + "\n".join(methods) + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-framework", "AppKit", "-I", str(SOURCE.parent),
                        str(source), "-o", str(cls.exe)], check=True)

    def check_move(self, direction, row, count, expected, *, missing=False):
        output = subprocess.check_output(
            [self.exe, str(row), str(count), str(int(missing)), direction], text=True
        )
        self.assertEqual(output, f"focus\n{expected}redraw 0\n")

    def test_moves_and_reselects_the_same_destination(self):
        self.check_move("up", 1, 3, "event 1\nmove 0\nreload\nselect 0 0 1\n")
        self.check_move("down", 1, 3, "event 1\nmove 2\nreload\nselect 2 0 1\n")
        row = 2**31 - 3
        self.check_move("down", row, row + 2, f"event {row}\nmove {row + 1}\nreload\nselect {row + 1} 0 1\n")

    def test_endpoints_and_missing_event(self):
        self.check_move("up", 0, 3, "event 0\n")
        self.check_move("down", 2, 3, "event 2\n")
        self.check_move("up", 1, 3, "event 1\n", missing=True)

    def test_invalid_rows_do_not_look_up_events(self):
        for direction in ("up", "down"):
            for row in (-1, -2, 3, 2**32 + 1, 2**63 - 1):
                with self.subTest(direction=direction, row=row):
                    self.check_move(direction, row, 3, "")


if __name__ == "__main__":
    unittest.main()
