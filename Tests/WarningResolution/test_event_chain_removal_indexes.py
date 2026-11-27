"""Exercise condition and action removal at the AppKit and Lemuria boundaries."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"

FIXTURE = r'''
#import <AppKit/AppKit.h>
#import <limits.h>
#import "EventCollection.h"
#import "EventDataProtocol.h"
typedef NSObject RDChainedListItem;

static NSInteger row;
static unsigned position;
static BOOL active;

@interface Fixture : NSObject
@property (copy) NSString *label;
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
- (NSUInteger)count { return 2; }
- (id)objectAtIndex:(NSUInteger)index {
    printf("item %lu\n", (unsigned long)index);
    if (index >= self.count)
        [NSException raise:NSRangeException format:@"Invalid chain index %lu", (unsigned long)index];
    return self;
}
- (RDChainedListItem *)currentActiveItem { return active ? self : nil; }
- (unsigned)positionOfItem:(RDChainedListItem *)item { return position; }
- (NSWindow *)window { return (NSWindow *)self; }
- (BOOL)makeFirstResponder:(NSResponder *)responder { puts("focus"); return YES; }
- (void)eventRemoveCondition:(id)item { puts("remove condition"); }
- (void)eventRemoveAction:(id)item { puts("remove action"); }
- (void)removeItem:(RDChainedListItem *)item { printf("remove view %s\n", self.label.UTF8String); }
- (void)setNeedsDisplay:(BOOL)flag { printf("redraw %s\n", self.label.UTF8String); }
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
        position = (unsigned)strtoul(argv[2], NULL, 10);
        active = atoi(argv[3]) != 0;
        Fixture *fixture = [Fixture new];
        Probe *probe = [Probe new];
        probe->_rdTableView = (NSTableView *)fixture;
        probe->_rdEventData = (EventCollection *)fixture;
        probe->_rdConditionChainView = [Fixture new];
        probe->_rdConditionChainView.label = @"condition";
        probe->_rdActionChainView = [Fixture new];
        probe->_rdActionChainView.label = @"action";
        @try {
            if (strcmp(argv[4], "condition") == 0)
                [probe removeCondition:nil];
            else
                [probe removeAction:nil];
        } @catch (NSException *exception) {
            printf("%s\n", exception.name.UTF8String);
        }
    }
}
'''


class EventChainRemovalIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        methods = re.findall(r"^- \(void\) remove(?:Condition|Action):[^\n]*\n\{.*?^}",
                             SOURCE.read_text(), re.M | re.S)
        if len(methods) != 2:
            raise ValueError("Expected the condition and action removal methods")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-event-chain-removal.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + "\n".join(methods) + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(["xcrun", "clang", "-framework", "AppKit", "-I", str(SOURCE.parent),
                        str(source), "-o", str(cls.exe)], check=True)

    def check_removal(self, kind, row, position, expected, *, active=True):
        output = subprocess.check_output(
            [self.exe, str(row), str(position), str(int(active)), kind], text=True
        )
        self.assertEqual(output, expected)

    def test_removes_model_item_and_redraws_its_chain(self):
        for kind in ("condition", "action"):
            with self.subTest(kind=kind):
                self.check_removal(kind, 1, 0,
                                   f"event 1\nitem 0\nfocus\nremove {kind}\nremove view {kind}\nredraw {kind}\n")

    def test_invalid_rows_are_ignored(self):
        for kind in ("condition", "action"):
            for row in (-1, 2, 2**32 + 1, 2**63 - 1):
                with self.subTest(kind=kind, row=row):
                    self.check_removal(kind, row, 0, "")

    def test_missing_or_out_of_range_chain_items_are_ignored(self):
        for kind in ("condition", "action"):
            self.check_removal(kind, 1, 0, "event 1\n", active=False)
            for position in (2, 2**32 - 1):
                with self.subTest(kind=kind, position=position):
                    self.check_removal(kind, 1, position, "event 1\n")


if __name__ == "__main__":
    unittest.main()
