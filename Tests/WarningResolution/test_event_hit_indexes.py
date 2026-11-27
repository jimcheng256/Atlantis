"""Exercise Event Editor cell actions with ordinary and synthetic hit indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"

FIXTURE = r'''
#import <AppKit/AppKit.h>
#import "EventCollection.h"
#import "EventDataProtocol.h"

static NSInteger hitRow, hitColumn;
static NSString *identifier;

@interface Fixture : NSObject
@end
@implementation Fixture
- (NSWindow *)window { return (NSWindow *)self; }
- (NSPoint)mouseLocationOutsideOfEventStream { return NSZeroPoint; }
- (NSPoint)convertPoint:(NSPoint)point fromView:(NSView *)view { return point; }
- (NSInteger)rowAtPoint:(NSPoint)point { return hitRow; }
- (NSInteger)columnAtPoint:(NSPoint)point { return hitColumn; }
- (NSArray *)tableColumns { return (NSArray *)self; }
- (NSUInteger)count { return 2; }
- (id)objectAtIndex:(NSUInteger)index {
    printf("column %lu\n", (unsigned long)index);
    if (index >= self.count)
        [NSException raise:NSRangeException format:@"Invalid table column %lu", (unsigned long)index];
    return self;
}
- (NSString *)identifier { return identifier; }
- (NSInteger)eventsCount { return 2; }
- (id)eventAtIndex:(NSUInteger)index {
    printf("event %lu\n", (unsigned long)index);
    return index < 2 ? self : nil;
}
- (BOOL)eventCanEditNameSpecial { return YES; }
- (void)eventEditNameHook { puts("name"); }
- (void)eventEditExtraDataHook:(NSString *)key { printf("extra %s\n", key.UTF8String); }
- (BOOL)eventIsEnabled { return YES; }
- (void)eventSetEnabled:(BOOL)enabled { printf("enabled %d\n", enabled); }
- (void)reloadData { puts("reload"); }
- (void)editColumn:(NSInteger)column row:(NSInteger)row withEvent:(NSEvent *)event select:(BOOL)select {
    printf("edit %ld %ld\n", (long)column, (long)row);
}
@end

@interface RDNestedViewManager : NSObject
@end
@implementation RDNestedViewManager
+ (id)manager { return [self new]; }
- (BOOL)isLeopard { return YES; }
@end

@interface Probe : NSObject {
@public
    NSTableView *_rdTableView;
    EventCollection *_rdEventData;
}
@end
@implementation Probe
'''

DRIVER = r'''
@end
int main(int argc, char **argv) {
    @autoreleasepool {
        hitRow = strtoll(argv[1], NULL, 10);
        hitColumn = strtoll(argv[2], NULL, 10);
        identifier = [NSString stringWithUTF8String:argv[3]];
        Fixture *fixture = [Fixture new];
        Probe *probe = [Probe new];
        probe->_rdTableView = (NSTableView *)fixture;
        probe->_rdEventData = (EventCollection *)fixture;
        @try {
            if (strcmp(argv[4], "double") == 0)
                [probe eventDoubleClicked:nil];
            else
                [probe enableEvent:nil];
        } @catch (NSException *exception) {
            printf("%s\n", exception.name.UTF8String);
        }
    }
}
'''


class EventHitIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        methods = re.findall(r"^- \(void\) (?:eventDoubleClicked|enableEvent):[^\n]*\n\{.*?^}",
                             SOURCE.read_text(), re.M | re.S)
        if len(methods) != 2:
            raise ValueError("Expected both Event Editor cell actions")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-event-hits.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + "\n".join(methods) + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-framework", "AppKit", "-I", str(SOURCE.parent),
                        str(source), "-o", str(cls.exe)], check=True)

    def check_hit(self, action, row, col, identifier, expected):
        result = subprocess.check_output([self.exe, str(row), str(col), identifier, action], text=True)
        self.assertEqual(result, expected)

    def test_valid_hit_dispatches_the_expected_action(self):
        for identifier, result in (("eventName", "name"), ("eventDesc", "edit 0 1"),
                                   ("custom", "extra custom")):
            self.check_hit("double", 1, 0, identifier, f"column 0\nevent 1\n{result}\n")
        self.check_hit("enable", 1, 0, "eventActive", "column 0\nevent 1\nenabled 0\nreload\n")
        self.check_hit("enable", 1, 0, "eventName", "column 0\nevent 1\n")

    def test_missing_or_out_of_range_hits_do_not_dispatch(self):
        for action in ("double", "enable"):
            for invalid in (-1, 2, 2**32 + 1, 2**63 - 1):
                for row, col in ((invalid, 0), (0, invalid)):
                    with self.subTest(action=action, row=row, col=col):
                        self.check_hit(action, row, col, "eventActive", "")


if __name__ == "__main__":
    unittest.main()
