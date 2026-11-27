"""Exercise the Address Book's connection column and editor tab lookups."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Worlds/AddressBook.m"
NOT_FOUND = 2**63 - 1


def probe_source():
    source = SOURCE.read_text()
    column = re.search(r"^ +\w+ newColIndex = .*?moveColumn:[^\n]*;", source, re.M | re.S)
    editor = re.search(r"^- \(void\) addEditorForWorldRecord:[^\n]*\n\{.*?^\}", source, re.M | re.S)
    if not column or not editor:
        raise ValueError(f"Missing column or editor tab lookup in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>

@interface AddressBookRecord : NSObject
@end
@implementation AddressBookRecord
- (id)world { return nil; }
- (NSString *)character { return nil; }
- (NSString *)uuid { return @"fixture"; }
@end

@interface WorldConfigurationEditor : NSObject
@end
@implementation WorldConfigurationEditor
- (instancetype)initWithWorld:(id)world forCharacter:(NSString *)character { return [super init]; }
- (NSView *)configView {
    return [[[NSView alloc] initWithFrame:NSZeroRect] autorelease];
}
@end

@interface ColumnFixture : NSObject
@property NSUInteger index;
@property NSInteger movedFrom, movedTo;
@end
@implementation ColumnFixture
- (ColumnFixture *)tableColumns { return self; }
- (NSUInteger)indexOfObject:(id)column { return self.index; }
- (void)moveColumn:(NSInteger)oldIndex toColumn:(NSInteger)newIndex {
    self.movedFrom = oldIndex;
    self.movedTo = newIndex;
}
@end

@interface TabFixture : NSObject
@property NSInteger index, loadedIndex;
@property (retain) NSTabViewItem *existing, *added;
@end
@implementation TabFixture
- (NSInteger)indexOfTabViewItemWithIdentifier:(id)identifier { return self.index; }
- (NSTabViewItem *)tabViewItemAtIndex:(NSInteger)index {
    self.loadedIndex = index;
    return self.existing;
}
- (void)addTabViewItem:(NSTabViewItem *)item { self.added = item; }
@end

@interface AddressBookProbe : NSObject {
@public
    ColumnFixture *_rdWorldList;
    TabFixture *_rdConfigContent;
    NSMutableDictionary *_rdWorldPreferenceViews;
}
- (void)moveConnectionColumn:(NSTableColumn *)imageCol;
- (void)addEditorForWorldRecord:(AddressBookRecord *)record;
@end
@implementation AddressBookProbe
- (void)moveConnectionColumn:(NSTableColumn *)imageCol {
''' + column[0] + r'''
}
''' + editor[0] + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        AddressBookProbe *probe = [[[AddressBookProbe alloc] init] autorelease];
        if (strcmp(argv[1], "column") == 0) {
            ColumnFixture *fixture = [[[ColumnFixture alloc] init] autorelease];
            fixture.index = strtoull(argv[2], NULL, 10);
            fixture.movedFrom = fixture.movedTo = -2;
            probe->_rdWorldList = fixture;
            [probe moveConnectionColumn:nil];
            printf("%ld %ld\n", (long)fixture.movedFrom, (long)fixture.movedTo);
        } else {
            TabFixture *fixture = [[[TabFixture alloc] init] autorelease];
            fixture.index = strtoll(argv[2], NULL, 10);
            fixture.loadedIndex = -2;
            fixture.existing = [[[NSTabViewItem alloc] initWithIdentifier:@"fixture"] autorelease];
            NSView *originalView = [[fixture.existing.view retain] autorelease];
            probe->_rdConfigContent = fixture;
            probe->_rdWorldPreferenceViews = [NSMutableDictionary dictionary];
            [probe addEditorForWorldRecord:[[[AddressBookRecord alloc] init] autorelease]];
            printf("%ld %d %d %d\n", (long)fixture.loadedIndex, fixture.existing.view != originalView,
                   fixture.added.view != nil, probe->_rdWorldPreferenceViews[@"fixture"] != nil);
        }
    }
}
'''


class AddressBookLookupIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-address-book-lookups.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-framework", "Cocoa", str(source), "-o", str(cls.executable)],
            check=True,
        )

    def run_probe(self, path, index):
        return subprocess.check_output([self.executable, path, str(index)], text=True).strip()

    def test_ordinary_and_wide_column_indexes(self):
        for index in (1, 2**32 + 1):
            with self.subTest(index=index):
                self.assertEqual(self.run_probe("column", index), f"{index} 0")

    def test_missing_column_is_not_moved(self):
        self.assertEqual(self.run_probe("column", NOT_FOUND), "-2 -2")

    def test_ordinary_and_wide_tab_indexes_replace_the_view(self):
        for index in (1, 2**32 + 1):
            with self.subTest(index=index):
                self.assertEqual(self.run_probe("tab", index), f"{index} 1 0 1")

    def test_missing_tab_gets_a_new_view(self):
        for index in (-1, NOT_FOUND):
            with self.subTest(index=index):
                self.assertEqual(self.run_probe("tab", index), "-2 0 1 1")


if __name__ == "__main__":
    unittest.main()
