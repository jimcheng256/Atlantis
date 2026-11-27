"""Exercise the User Variables table methods with synthetic row indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Preferences/World/WorldUserconfEditor.m"


def probe_source():
    methods = re.findall(
        r"^- \([^)]+\)\s*(?:numberOfRowsInTableView|tableView|addButton):[^\n]*\n\{.*?^\}",
        SOURCE.read_text(), re.M | re.S,
    )
    if len(methods) != 4:
        raise ValueError(f"Expected four table and Add methods in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface KeysFixture : NSObject
@property NSUInteger count;
@property NSUInteger lookupRow;
@property NSUInteger replacementRow;
@property (copy) NSString *key;
@end

@implementation KeysFixture
- (NSString *)objectAtIndex:(NSUInteger)row {
    self.lookupRow = row;
    return self.key;
}
- (void)replaceObjectAtIndex:(NSUInteger)row withObject:(NSString *)key {
    self.replacementRow = row;
    self.key = key;
}
- (void)addObject:(NSString *)key {
    self.count++;
    self.key = key;
}
@end

@interface TableFixture : NSObject
@property NSInteger selectedRow;
@property NSInteger editedRow;
@end

@implementation TableFixture
- (void)reloadData {}
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend {
    self.selectedRow = row;
}
- (void)editColumn:(NSInteger)column row:(NSInteger)row withEvent:(NSEvent *)event select:(BOOL)select {
    self.editedRow = row;
}
@end

@interface UserVariablesProbe : NSObject <NSTableViewDataSource> {
@public
    KeysFixture *_rdUserConfKeys;
    NSMutableDictionary *_rdUserConf;
    TableFixture *_rdUserConfTable;
    NSView *_rdConfigView;
}
- (void)addButton:(id)sender;
@end
@implementation UserVariablesProbe
''' + "\n".join(methods) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        if (strcmp(argv[1], "signatures") == 0) {
            Class cls = [UserVariablesProbe class];
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

        NSUInteger count = strtoull(argv[1], NULL, 10);
        UserVariablesProbe *probe = [[[UserVariablesProbe alloc] init] autorelease];
        KeysFixture *keys = [[[KeysFixture alloc] init] autorelease];
        TableFixture *table = [[[TableFixture alloc] init] autorelease];
        keys.count = count;
        keys.key = @"original";
        probe->_rdUserConfKeys = keys;
        probe->_rdUserConfTable = table;
        NSMutableDictionary *values = [@{@"original": @"value"} mutableCopy];
        probe->_rdUserConf = [values autorelease];
        id<NSTableViewDataSource> dataSource = probe;

        printf("%ld\n", (long)[dataSource numberOfRowsInTableView:nil]);
        if (count > 0) {
            NSInteger row = (NSInteger)(count - 1);
            NSTableColumn *keyColumn = [[[NSTableColumn alloc] initWithIdentifier:@"userconfKey"] autorelease];
            NSTableColumn *valueColumn = [[[NSTableColumn alloc] initWithIdentifier:@"userconfValue"] autorelease];
            NSString *key = [dataSource tableView:nil objectValueForTableColumn:keyColumn row:row];
            NSString *value = [dataSource tableView:nil objectValueForTableColumn:valueColumn row:row];
            printf("%s %s %lu\n", key.UTF8String, value.UTF8String, (unsigned long)keys.lookupRow);
            [dataSource tableView:nil setObjectValue:@"renamed" forTableColumn:keyColumn row:row];
            [dataSource tableView:nil setObjectValue:@"edited" forTableColumn:valueColumn row:row];
            printf("%s %d %lu\n", [values[@"renamed"] UTF8String], values[@"original"] == nil,
                   (unsigned long)keys.replacementRow);
        }

        [probe addButton:nil];
        printf("%ld %ld %s %s\n", (long)table.selectedRow, (long)table.editedRow,
               keys.key.UTF8String, [values[keys.key] UTF8String]);
    }
}
'''


class UserVariableIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-user-variable-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def test_data_source_signatures_match_appkit(self):
        self.assertEqual(subprocess.check_output([self.executable, "signatures"]), b"1 1 1\n")

    def test_add_to_empty_table(self):
        self.assertEqual(subprocess.check_output([self.executable, "0"]), b"0\n0 0 <name> <value>\n")

    def check_rows(self, count):
        result = subprocess.check_output([self.executable, str(count)], text=True)
        self.assertEqual(
            result.splitlines(),
            [str(count), f"original value {count - 1}", f"edited 1 {count - 1}",
             f"{count} {count} <name> <value>"],
        )

    def test_ordinary_rows(self):
        self.check_rows(3)

    def test_full_width_count_lookup_edit_and_selection(self):
        self.check_rows(2**32 + 2)


if __name__ == "__main__":
    unittest.main()
