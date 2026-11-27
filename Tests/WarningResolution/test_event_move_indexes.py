"""Exercise both production Event Editor reordering actions with synthetic indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest

SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"

FIXTURES = r'''
#import <AppKit/AppKit.h>
#import "EventCollection.h"
#import "EventDataProtocol.h"

@interface RDAtlantisConditionItem : NSObject
@end
@implementation RDAtlantisConditionItem
- (id)itemCondition { return self; }
@end

@interface RDAtlantisActionItem : NSObject
@end
@implementation RDAtlantisActionItem
- (id)itemAction { return self; }
@end

static NSInteger row;
static NSUInteger indexValue;
static NSUInteger count;

@interface Fixture : NSObject
@end
@implementation Fixture
- (NSInteger)selectedRow { return row; }
- (NSInteger)eventsCount { return 2; }
- (id)eventAtIndex:(NSUInteger)index {
    printf("event %lu\n", (unsigned long)index);
    return index < 2 ? self : nil;
}
- (NSArray *)eventConditions { return (NSArray *)self; }
- (NSArray *)eventActions { return (NSArray *)self; }
- (NSUInteger)indexOfObject:(id)item { return indexValue; }
- (NSUInteger)count { return count; }
- (void)eventMoveCondition:(id)item toPosition:(int)position {
    printf("condition %d\n", position);
}
- (void)eventMoveAction:(id)item toPosition:(int)position {
    printf("action %d\n", position);
}
- (void)moveItem:(id)item toPosition:(int)position {
    printf("view %d\n", position);
}
@end

@interface Probe : NSObject {
@public
    NSTableView *_rdTableView;
    EventCollection *_rdEventData;
    Fixture *_rdConditionChainView;
    Fixture *_rdActionChainView;
}
@end

@implementation Probe
'''

DRIVER = r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        row = strtoll(argv[1], NULL, 10);
        indexValue = strcmp(argv[2], "missing") == 0 ? NSNotFound : strtoull(argv[2], NULL, 10);
        count = strtoull(argv[3], NULL, 10);
        Fixture *fixture = [Fixture new];
        Probe *probe = [Probe new];
        probe->_rdEventData = (EventCollection *)fixture;
        probe->_rdTableView = (NSTableView *)fixture;
        probe->_rdConditionChainView = probe->_rdActionChainView = fixture;
        id item = strcmp(argv[4], "condition") == 0
            ? [RDAtlantisConditionItem new] : [RDAtlantisActionItem new];
        if (strcmp(argv[5], "up") == 0)
            [probe moveUp:item];
        else
            [probe moveDown:item];
    }
}
'''


class EventMoveIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temp = tempfile.TemporaryDirectory(prefix="atlantis-event-moves.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        methods = re.findall(r"^- \(void\) move(?:Up|Down):.*?^}", SOURCE.read_text(), re.M | re.S)
        if len(methods) != 2:
            raise ValueError("Expected both Event Editor move actions")
        source.write_text(FIXTURES + "\n".join(methods) + DRIVER)
        cls.probe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-I", str(SOURCE.parent), "-framework", "Cocoa",
                        str(source), "-o", str(cls.probe)], check=True)

    def check_move(self, direction, row, index, count, destination=None):
        for kind in ("condition", "action"):
            with self.subTest(kind=kind, direction=direction, row=row, index=index):
                expected = f"event {row}\n" if 0 <= row < 2 else ""
                if destination is not None:
                    expected += f"{kind} {destination}\nview {destination}\n"
                actual = subprocess.check_output(
                    [self.probe, str(row), str(index), str(count), kind, direction], text=True
                )
                self.assertEqual(actual, expected)

    def test_ordinary_moves_and_endpoints(self):
        self.check_move("up", 1, 1, 3, 0)
        self.check_move("down", 1, 1, 3, 2)
        self.check_move("up", 1, 0, 3)
        self.check_move("down", 1, 2, 3)

    def test_invalid_rows_and_missing_items(self):
        for direction in ("up", "down"):
            for row in (-1, 2, 2**32 + 1, 2**63 - 1):
                self.check_move(direction, row, 1, 3)
            self.check_move(direction, 1, "missing", 3)

    def test_signed_position_boundary(self):
        limit = 2**31 - 1
        self.check_move("up", 1, limit, limit + 2, limit - 1)
        self.check_move("down", 1, limit - 1, limit + 2, limit)
        self.check_move("up", 1, limit + 1, limit + 2)
        self.check_move("down", 1, limit, limit + 2)
        self.check_move("up", 1, 2**32 + 1, 2**32 + 3)
        self.check_move("down", 1, 2**32 + 1, 2**32 + 3)


if __name__ == "__main__":
    unittest.main()
