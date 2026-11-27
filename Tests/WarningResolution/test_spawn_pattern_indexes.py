"""Exercise the Spawn editor's pattern and exception table indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "Preferences/World/WorldSpawnEditor.m"
NOT_FOUND = 2**63 - 1


def probe_source():
    source = SOURCE.read_text()

    def extract(names, count):
        methods = re.findall(
            r"^- \([^)]+\)\s*(?:" + names + r"):[^\n]*\n\{.*?^\}", source, re.M | re.S,
        )
        if len(methods) != count:
            raise ValueError(f"Expected {count} methods matching {names} in {SOURCE}")
        return "\n".join(methods)

    data_source = extract("numberOfRowsInTableView|tableView", 3)
    actions = extract("addPattern|removePattern|addException|removeException", 4)
    return r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "RDStringPattern.h"

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
@implementation RDStringPattern
+ (RDStringPattern *)patternWithString:(NSString *)pattern type:(int)type {
    RDStringPattern *result = [[[self alloc] init] autorelease];
    result->_rdPattern = pattern;
    result->_rdPatternType = type;
    return result;
}
- (int)type { return _rdPatternType; }
- (NSString *)pattern { return _rdPattern; }
@end
#pragma clang diagnostic pop

@interface RowsFixture : NSMutableArray
@property (retain) RDStringPattern *pattern;
@property NSUInteger countOverride, lookupRow, replacementRow, removalRow, reportedIndex;
@property NSUInteger size;
@end
@implementation RowsFixture
- (NSUInteger)count { return self.countOverride ?: self.size; }
- (id)objectAtIndex:(NSUInteger)row {
    self.lookupRow = row;
    return self.pattern;
}
- (void)replaceObjectAtIndex:(NSUInteger)row withObject:(id)object {
    self.replacementRow = row;
    self.pattern = object;
}
- (void)insertObject:(id)object atIndex:(NSUInteger)row {
    self.pattern = object;
    self.size++;
}
- (void)removeObjectAtIndex:(NSUInteger)row {
    self.removalRow = row;
    self.size--;
}
- (NSUInteger)indexOfObject:(id)object { return self.reportedIndex; }
- (id)mutableCopyWithZone:(NSZone *)zone { return [self retain]; }
@end

@interface TableFixture : NSObject
@property NSInteger tag, selectedRow, requestedRow, editedRow;
@end
@implementation TableFixture
- (void)reloadData {}
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend { self.requestedRow = row; }
- (void)editColumn:(NSInteger)column row:(NSInteger)row withEvent:(NSEvent *)event select:(BOOL)select {
    self.editedRow = row;
}
@end

@interface WorldSpawnRecord : NSObject <NSTableViewDataSource> {
@public
    NSMutableArray *_rdPatterns, *_rdExceptions;
    NSUInteger savedPatterns, savedExceptions;
}
- (NSArray *)patterns;
- (NSArray *)exceptions;
- (void)setPatterns:(NSArray *)patterns;
- (void)setExceptions:(NSArray *)exceptions;
@end
@implementation WorldSpawnRecord
- (NSArray *)patterns { return _rdPatterns; }
- (NSArray *)exceptions { return _rdExceptions; }
- (void)setPatterns:(NSArray *)patterns { savedPatterns = patterns.count; }
- (void)setExceptions:(NSArray *)exceptions { savedExceptions = exceptions.count; }
''' + data_source + r'''
@end

@interface SpawnTableProbe : NSObject {
@public
    NSView *_rdSpawnList;
    TableFixture *_rdPatternList, *_rdExceptionList;
    WorldSpawnRecord *record;
}
- (void)addPattern:(id)sender;
- (void)removePattern:(id)sender;
- (void)addException:(id)sender;
- (void)removeException:(id)sender;
@end
@implementation SpawnTableProbe
- (WorldSpawnRecord *)currentSelectedSpawn { return record; }
''' + actions + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        if (strcmp(argv[1], "signatures") == 0) {
            Class cls = [WorldSpawnRecord class];
            char countType[8], readType[8], writeType[8];
            method_getReturnType(class_getInstanceMethod(cls, @selector(numberOfRowsInTableView:)),
                                 countType, sizeof(countType));
            method_getArgumentType(class_getInstanceMethod(cls, @selector(tableView:objectValueForTableColumn:row:)),
                                   4, readType, sizeof(readType));
            method_getArgumentType(class_getInstanceMethod(cls, @selector(tableView:setObjectValue:forTableColumn:row:)),
                                   5, writeType, sizeof(writeType));
            printf("%d %d %d\n", strcmp(countType, @encode(NSInteger)) == 0,
                   strcmp(readType, @encode(NSInteger)) == 0, strcmp(writeType, @encode(NSInteger)) == 0);
            return 0;
        }

        NSInteger row = strtoll(argv[3], NULL, 10);
        BOOL isPattern = atoi(argv[2]) == 1;
        RowsFixture *rows = [[[RowsFixture alloc] init] autorelease];
        rows.pattern = [RDStringPattern patternWithString:@"original" type:RDPatternContains];
        rows.size = 2;
        rows.lookupRow = rows.replacementRow = rows.removalRow = NSNotFound;
        WorldSpawnRecord *record = [[[WorldSpawnRecord alloc] init] autorelease];
        if (isPattern) {
            record->_rdPatterns = rows;
        } else {
            record->_rdExceptions = rows;
        }
        TableFixture *table = [[[TableFixture alloc] init] autorelease];
        table.tag = atoi(argv[2]);
        table.selectedRow = row;
        table.requestedRow = table.editedRow = -2;

        if (strcmp(argv[1], "data") == 0) {
            rows.countOverride = strtoull(argv[4], NULL, 10);
            id<NSTableViewDataSource> dataSource = record;
            NSTableView *view = (NSTableView *)table;
            NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"matchPattern"] autorelease];
            NSString *value = [dataSource tableView:view objectValueForTableColumn:column row:row];
            [dataSource tableView:view setObjectValue:@"changed" forTableColumn:column row:row];
            printf("%ld %s %lu %lu %s %d\n", (long)[dataSource numberOfRowsInTableView:view],
                   value ? value.UTF8String : "nil", (unsigned long)rows.lookupRow,
                   (unsigned long)rows.replacementRow, rows.pattern.pattern.UTF8String, rows.pattern.type);
        } else {
            SpawnTableProbe *probe = [[[SpawnTableProbe alloc] init] autorelease];
            probe->_rdPatternList = table;
            probe->_rdExceptionList = table;
            probe->record = record;
            rows.reportedIndex = strtoull(argv[4], NULL, 10);
            if (isPattern) {
                [probe removePattern:nil];
            } else {
                [probe removeException:nil];
            }
            printf("%lu %lu %lu\n", (unsigned long)rows.removalRow, (unsigned long)rows.size,
                   (unsigned long)(isPattern ? record->savedPatterns : record->savedExceptions));
            if (isPattern) {
                [probe addPattern:nil];
            } else {
                [probe addException:nil];
            }
            printf("%ld %ld %lu\n", (long)table.requestedRow, (long)table.editedRow,
                   (unsigned long)(isPattern ? record->savedPatterns : record->savedExceptions));
        }
    }
}
'''


class SpawnPatternIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-spawn-pattern-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations", "-I", str(ROOT / "Utility Classes"),
             "-framework", "Cocoa", str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check_both_tables(self, command, row, extra, expected):
        for tag in (1, 2):
            with self.subTest(tag=tag, row=row):
                result = subprocess.check_output(
                    [self.executable, command, str(tag), str(row), str(extra)], text=True,
                )
                self.assertEqual(result.splitlines(), expected)

    def test_data_source_signatures(self):
        self.assertEqual(subprocess.check_output([self.executable, "signatures"]), b"1 1 1\n")

    def test_data_source_reads_and_edits_ordinary_and_wide_rows(self):
        for row in (1, 2**32 + 1):
            self.check_both_tables("data", row, row + 1, [f"{row + 1} original {row} {row} changed 2"])

    def test_data_source_rejects_missing_and_out_of_range_rows(self):
        for row in (-1, 2, 2**32 + 1):
            self.check_both_tables("data", row, 2, [f"2 nil {NOT_FOUND} {NOT_FOUND} original 2"])

    def test_add_and_remove_ordinary_row(self):
        self.check_both_tables("actions", 1, 1, ["1 1 1", "1 1 2"])

    def test_add_preserves_wide_index_and_remove_rejects_wide_row(self):
        row = 2**32 + 1
        self.check_both_tables("actions", row, row, [f"{NOT_FOUND} 2 0", f"{row} {row} 3"])

    def test_missing_selection_and_missing_added_index(self):
        self.check_both_tables("actions", -1, NOT_FOUND, [f"{NOT_FOUND} 2 0", "-2 -2 3"])


if __name__ == "__main__":
    unittest.main()
