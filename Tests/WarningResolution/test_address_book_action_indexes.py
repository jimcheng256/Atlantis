"""Exercise the Address Book actions that select a world or character."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Worlds/AddressBook.m"


def probe_source():
    methods = re.findall(
        r"^- \([^)]+\)\s*(?:addWorld|addCharacter|focusWorld):[^\n]*\n\{.*?^\}",
        SOURCE.read_text().split("@implementation AddressBook\n", 1)[1], re.M | re.S,
    )
    if len(methods) != 3:
        raise ValueError(f"Expected three Address Book actions in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>

@interface RDAtlantisWorldPreferences : NSObject
@end
@implementation RDAtlantisWorldPreferences
- (void)setPreference:(id)value forKey:(NSString *)key withCharacter:(NSString *)character {}
- (BOOL)hasCharacter:(NSString *)name { return NO; }
- (void)addCharacter:(NSString *)name {}
@end

@interface AddressBookRecord : NSObject
@property (retain) RDAtlantisWorldPreferences *world;
@property (retain) AddressBookRecord *character;
@end
@implementation AddressBookRecord
- (id)initWithWorld:(RDAtlantisWorldPreferences *)world forCharacter:(NSString *)character {
    self = [super init];
    if (self) self.world = world;
    return self;
}
- (NSComparisonResult)compare:(AddressBookRecord *)record { return NSOrderedSame; }
- (BOOL)isCharacter { return NO; }
- (void)addCharacter:(NSString *)name {}
- (AddressBookRecord *)characterWithName:(NSString *)name { return self.character; }
@end

@interface OutlineFixture : NSObject
@property NSInteger resolvedRow, selectedRow;
@property (retain) AddressBookRecord *lookedUpRecord;
@end
@implementation OutlineFixture
- (NSInteger)rowForItem:(AddressBookRecord *)record {
    self.lookedUpRecord = record;
    return self.resolvedRow;
}
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend { self.selectedRow = row; }
- (void)expandItem:(id)item {}
- (void)expandItem:(id)item expandChildren:(BOOL)expand {}
@end

@interface AddressBookProbe : NSObject {
@public
    OutlineFixture *_rdWorldList;
    NSMutableArray *_rdWorldRecords;
    id _rdWorlds;
    AddressBookRecord *worldRecord;
    NSUInteger displays;
}
@end
@implementation AddressBookProbe
- (AddressBookRecord *)worldByName:(NSString *)name { return nil; }
- (AddressBookRecord *)currentSelection { return worldRecord; }
- (AddressBookRecord *)recordForWorld:(RDAtlantisWorldPreferences *)world { return worldRecord; }
- (void)addEditorForWorldRecord:(AddressBookRecord *)record {}
- (void)resynchAll {}
- (void)reloadKeepingSelection {}
- (void)display { displays++; }
''' + "\n".join(methods) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        AddressBookProbe *probe = [[[AddressBookProbe alloc] init] autorelease];
        OutlineFixture *outline = [[[OutlineFixture alloc] init] autorelease];
        outline.resolvedRow = strtoll(argv[2], NULL, 10);
        outline.selectedRow = -2;
        probe->_rdWorldList = outline;
        probe->_rdWorldRecords = [NSMutableArray array];
        probe->worldRecord = [[[AddressBookRecord alloc] init] autorelease];
        probe->worldRecord.character = [[[AddressBookRecord alloc] init] autorelease];
        AddressBookRecord *expected;
        if (strcmp(argv[1], "add-world") == 0) {
            [probe addWorld:nil];
            expected = [probe->_rdWorldRecords firstObject];
        } else if (strcmp(argv[1], "add-character") == 0) {
            [probe addCharacter:nil];
            expected = probe->worldRecord.character;
        } else {
            BOOL character = strcmp(argv[1], "focus-character") == 0;
            [probe focusWorld:nil forCharacter:character ? @"fixture" : nil];
            expected = character ? probe->worldRecord.character : probe->worldRecord;
        }
        printf("%d %ld %lu\n", expected && outline.lookedUpRecord == expected,
               (long)outline.selectedRow, (unsigned long)probe->displays);
    }
}
'''


class AddressBookActionIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-address-book-actions.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-framework", "Cocoa", str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check_actions(self, row, expected):
        for action in ("add-world", "add-character", "focus-world", "focus-character"):
            with self.subTest(action=action, row=row):
                result = subprocess.check_output([self.executable, action, str(row)], text=True)
                displays = int(action.startswith("focus"))
                self.assertEqual(result, f"1 {expected} {displays}\n")

    def test_ordinary_and_wide_rows(self):
        for row in (1, 2**32 + 1):
            self.check_actions(row, row)

    def test_missing_row_leaves_selection_alone(self):
        self.check_actions(-1, -2)


if __name__ == "__main__":
    unittest.main()
