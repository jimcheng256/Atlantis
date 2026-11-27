"""Verify that event models preserve their source indexes during exchanges."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event System/BaseEvent.m"

FIXTURE = r'''
#import <Foundation/Foundation.h>
@protocol EventConditionProtocol;
@protocol EventActionProtocol;

static NSUInteger position, count;

@interface Store : NSObject
@end
@implementation Store
- (BOOL)containsObject:(id)item { return position != NSNotFound; }
- (NSUInteger)indexOfObject:(id)item { return position; }
- (NSUInteger)count { return count; }
- (void)exchangeObjectAtIndex:(NSUInteger)source withObjectAtIndex:(NSUInteger)destination {
    printf("%lu %lu\n", (unsigned long)source, (unsigned long)destination);
}
@end

@interface Probe : NSObject {
@public
    Store *_rdConditions, *_rdActions;
}
@end
@implementation Probe
'''

DRIVER = r'''
@end
int main(int argc, char **argv) {
    @autoreleasepool {
        position = strcmp(argv[1], "missing") == 0 ? NSNotFound : strtoull(argv[1], NULL, 10);
        count = strtoull(argv[2], NULL, 10);
        int destination = atoi(argv[3]);
        Probe *probe = [Probe new];
        probe->_rdConditions = probe->_rdActions = [Store new];
        id item = [NSObject new];
        [probe eventMoveCondition:item toPosition:destination];
        [probe eventMoveAction:item toPosition:destination];
    }
}
'''


class BaseEventMoveIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        methods = re.findall(r"^- \(void\) eventMove(?:Condition|Action):.*?^}",
                             SOURCE.read_text(), re.M | re.S)
        if len(methods) != 2:
            raise ValueError("Expected both event model move methods")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-base-event-moves.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + "\n".join(methods) + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(source),
                        "-o", str(cls.exe)], check=True)

    def check_move(self, source, count, destination, expected):
        actual = subprocess.check_output(
            [self.exe, str(source), str(count), str(destination)], text=True
        )
        self.assertEqual(actual, expected)

    def test_ordinary_and_wide_sources(self):
        for source, destination in ((1, 0), (2**31, 2**31 - 1), (2**32 + 1, 1)):
            with self.subTest(source=source):
                self.check_move(source, source + 1, destination, f"{source} {destination}\n" * 2)

    def test_missing_item_and_invalid_or_unchanged_destination(self):
        for source, destination in (("missing", 0), (1, -1), (1, 2), (1, 1)):
            with self.subTest(source=source, destination=destination):
                self.check_move(source, 2, destination, "")


if __name__ == "__main__":
    unittest.main()
