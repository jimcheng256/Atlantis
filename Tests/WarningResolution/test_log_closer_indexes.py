"""Exercise the log-closing table methods with synthetic row indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Log System" / "RDLogCloser.m"


def method(source, name):
    match = re.search(rf"^- \([^)]+\)\s*{name}[^\n]*\n\{{.*?^\}}", source, re.M | re.S)
    if not match:
        raise ValueError(f"Missing {name} in {SOURCE}")
    return match[0]


def probe_source():
    source = SOURCE.read_text()
    methods = "\n".join(
        method(source, name)
        for name in ("numberOfRowsInTableView:", "tableView:", "closeLogs:")
    )
    return r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface RDLogType : NSObject
@property BOOL closed;
@end
@implementation RDLogType
- (NSString *)filename { return @"/fixture/session.log"; }
- (NSString *)shortTypeName { return @"Text"; }
- (NSString *)spawnPath { return nil; }
- (void)closeFile { self.closed = YES; }
@end

@interface LogsFixture : NSObject
@property NSUInteger count;
@property NSUInteger lastIndex;
@property (assign) RDLogType *log;
@end
@implementation LogsFixture
- (id)objectAtIndex:(NSUInteger)index {
    self.lastIndex = index;
    return self.log;
}
@end

@interface StateFixture : NSObject
@property NSUInteger removals;
@end
@implementation StateFixture
- (StateFixture *)world { return self; }
- (void)removeLogfile:(RDLogType *)log {
    if (log.closed) {
        self.removals++;
    }
}
@end

@interface TableFixture : NSObject
@property (retain) NSIndexSet *selectedRowIndexes;
@end
@implementation TableFixture
- (void)dealloc {
    [_selectedRowIndexes release];
    [super dealloc];
}
@end

@interface CloserProbe : NSObject <NSTableViewDataSource> {
@public
    LogsFixture *_rdLogfiles;
    TableFixture *_rdTableView;
    StateFixture *_rdState;
    NSPanel *_rdCloserView;
}
- (void)closeLogs:(id)sender;
@end
@implementation CloserProbe
''' + methods + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        if (strcmp(argv[1], "signatures") == 0) {
            Method countMethod = class_getInstanceMethod([CloserProbe class], @selector(numberOfRowsInTableView:));
            Method rowMethod = class_getInstanceMethod([CloserProbe class], @selector(tableView:objectValueForTableColumn:row:));
            char countType[8], rowType[8];
            method_getReturnType(countMethod, countType, sizeof(countType));
            method_getArgumentType(rowMethod, 4, rowType, sizeof(rowType));
            printf("%d %d\n", strcmp(countType, @encode(NSInteger)) == 0,
                   strcmp(rowType, @encode(NSInteger)) == 0);
            return 0;
        }
        NSUInteger row = strtoull(argv[1], NULL, 10);
        NSUInteger count = strtoull(argv[2], NULL, 10);
        CloserProbe *probe = [[[CloserProbe alloc] init] autorelease];
        LogsFixture *logs = [[[LogsFixture alloc] init] autorelease];
        RDLogType *log = [[[RDLogType alloc] init] autorelease];
        logs.count = count;
        logs.log = log;
        probe->_rdLogfiles = logs;
        id<NSTableViewDataSource> dataSource = probe;
        printf("%ld\n", (long)[dataSource numberOfRowsInTableView:nil]);
        if (count == 0) {
            return 0;
        }

        for (NSString *identifier in @[@"logNum", @"logName", @"logType", @"logSpawn"]) {
            NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:identifier] autorelease];
            NSString *value = [dataSource tableView:nil objectValueForTableColumn:column row:(NSInteger)row];
            printf("%s\n", value.UTF8String);
        }
        printf("%lu\n", (unsigned long)logs.lastIndex);

        TableFixture *table = [[[TableFixture alloc] init] autorelease];
        StateFixture *state = [[[StateFixture alloc] init] autorelease];
        table.selectedRowIndexes = [NSIndexSet indexSetWithIndex:row];
        probe->_rdTableView = table;
        probe->_rdState = state;
        [probe closeLogs:nil];
        printf("%lu %lu\n", (unsigned long)logs.lastIndex, (unsigned long)state.removals);
    }
}
'''


class LogCloserIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-log-closer-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check_row(self, row, count):
        result = subprocess.check_output([self.executable, str(row), str(count)], text=True)
        self.assertEqual(
            result.splitlines(),
            [str(count), str(row), "session.log", "Text", "", str(row), f"{row} 1"],
        )

    def test_empty_table(self):
        self.assertEqual(subprocess.check_output([self.executable, "0", "0"]), b"0\n")

    def test_data_source_signatures_match_appkit(self):
        self.assertEqual(subprocess.check_output([self.executable, "signatures"]), b"1 1\n")

    def test_ordinary_row(self):
        self.check_row(1, 3)

    def test_full_width_count_label_and_lookup(self):
        self.check_row(2**32 + 1, 2**32 + 2)


if __name__ == "__main__":
    unittest.main()
