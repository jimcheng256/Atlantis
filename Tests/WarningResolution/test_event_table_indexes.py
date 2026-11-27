"""Exercise the Event Editor table callbacks at the AppKit index boundary."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"


def probe_source():
    methods = re.findall(
        r"^- \([^)]+\)\s*(?:numberOfRowsInTableView|tableView):[^\n]*\n\{.*?^\}",
        SOURCE.read_text(), re.M | re.S,
    )
    if len(methods) != 3:
        raise ValueError(f"Expected three table methods in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "EventDataProtocol.h"
#import "EventCollection.h"

@interface Probe : NSObject <NSTableViewDataSource> {
@public
    EventCollection *_rdEventData;
    NSTableView *_rdTableView;
}
@end
@implementation Probe
''' + "\n".join(methods) + r'''
@end

@interface EventFixture : NSObject
@property (copy) NSString *eventName;
@end
@implementation EventFixture
- (BOOL)eventCanEditName { return YES; }
- (void)eventSetName:(NSString *)name { self.eventName = name; }
@end

@interface CollectionFixture : NSObject
@property NSUInteger lookups;
@property NSUInteger lastIndex;
@property (retain) EventFixture *event;
@end
@implementation CollectionFixture
- (NSInteger)eventsCount { return 2; }
- (id)eventAtIndex:(NSUInteger)index {
    self.lookups++;
    self.lastIndex = index;
    return index < 2 ? self.event : nil;
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        if (strcmp(argv[1], "signatures") == 0) {
            Class cls = [Probe class];
            char count[8], read[8], write[8];
            method_getReturnType(class_getInstanceMethod(cls, @selector(numberOfRowsInTableView:)), count, sizeof(count));
            method_getArgumentType(class_getInstanceMethod(cls, @selector(tableView:objectValueForTableColumn:row:)),
                                   4, read, sizeof(read));
            method_getArgumentType(class_getInstanceMethod(cls, @selector(tableView:setObjectValue:forTableColumn:row:)),
                                   5, write, sizeof(write));
            printf("%d %d %d\n", strcmp(count, @encode(NSInteger)) == 0,
                   strcmp(read, @encode(NSInteger)) == 0, strcmp(write, @encode(NSInteger)) == 0);
            return 0;
        }

        Probe *probe = [[[Probe alloc] init] autorelease];
        CollectionFixture *collection = [[[CollectionFixture alloc] init] autorelease];
        collection.event = [[[EventFixture alloc] init] autorelease];
        collection.event.eventName = @"original";
        probe->_rdEventData = (EventCollection *)collection;
        NSObject *table = [[[NSObject alloc] init] autorelease];
        probe->_rdTableView = (NSTableView *)table;
        NSTableView *caller = (NSTableView *)(atoi(argv[2]) ? table : [[[NSObject alloc] init] autorelease]);
        NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"eventName"] autorelease];
        NSInteger row = strtoll(argv[1], NULL, 10);
        id<NSTableViewDataSource> dataSource = probe;
        NSString *value = [dataSource tableView:caller objectValueForTableColumn:column row:row];
        [dataSource tableView:caller setObjectValue:@"edited" forTableColumn:column row:row];
        printf("%ld %s\n%lu %lu %s\n", (long)[dataSource numberOfRowsInTableView:caller], value.UTF8String,
               (unsigned long)collection.lookups, (unsigned long)collection.lastIndex, collection.event.eventName.UTF8String);
    }
}
'''


class EventTableIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-event-table-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-I", str(SOURCE.parent), "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check_row(self, row, expected, *, active=True):
        self.assertEqual(
            subprocess.check_output([self.executable, str(row), str(int(active))], text=True), expected
        )

    def test_data_source_signatures(self):
        self.assertEqual(subprocess.check_output([self.executable, "signatures"]), b"1 1 1\n")

    def test_ordinary_row(self):
        self.check_row(1, "2 original\n2 1 edited\n")

    def test_missing_and_out_of_range_rows_are_ignored(self):
        for row in (-1, 2, 2**32 + 1, 2**63 - 1):
            with self.subTest(row=row):
                self.check_row(row, "2 \n0 0 original\n")

    def test_unrelated_table_is_ignored(self):
        self.check_row(1, "0 \n0 0 original\n", active=False)


if __name__ == "__main__":
    unittest.main()
