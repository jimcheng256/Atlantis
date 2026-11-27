"""Exercise the Address Book outline data source with synthetic child indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Worlds/AddressBook.m"
NOT_FOUND = 2**63 - 1


def probe_source():
    methods = re.findall(
        r"^- \([^)]+\)outlineView:[^\n]*(?:numberOfChildrenOfItem:|child:)[^\n]*\n\{.*?^\}",
        SOURCE.read_text(), re.M | re.S,
    )
    if len(methods) != 2:
        raise ValueError(f"Expected two outline data-source methods in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface ChildrenFixture : NSObject
@property NSUInteger count, index;
@end
@implementation ChildrenFixture
- (id)objectAtIndex:(NSUInteger)index {
    self.index = index;
    return self;
}
@end

@interface AddressBookRecord : NSObject
@property (retain) NSArray *subitems;
@end
@implementation AddressBookRecord
@end

@interface AddressBookProbe : NSObject <NSOutlineViewDataSource> {
@public
    NSArray *_rdWorldRecords;
}
@end
@implementation AddressBookProbe
''' + "\n".join(methods) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        if (strcmp(argv[1], "signatures") == 0) {
            Class cls = [AddressBookProbe class];
            char countType[8], indexType[8];
            method_getReturnType(class_getInstanceMethod(cls, @selector(outlineView:numberOfChildrenOfItem:)),
                                 countType, sizeof(countType));
            method_getArgumentType(class_getInstanceMethod(cls, @selector(outlineView:child:ofItem:)),
                                   3, indexType, sizeof(indexType));
            printf("%d %d\n", strcmp(countType, @encode(NSInteger)) == 0,
                   strcmp(indexType, @encode(NSInteger)) == 0);
            return 0;
        }

        NSInteger index = strtoll(argv[1], NULL, 10);
        NSUInteger count = strtoull(argv[2], NULL, 10);
        ChildrenFixture *worlds = [[[ChildrenFixture alloc] init] autorelease];
        ChildrenFixture *characters = [[[ChildrenFixture alloc] init] autorelease];
        worlds.count = count;
        characters.count = count;
        worlds.index = characters.index = NSNotFound;
        AddressBookProbe *probe = [[[AddressBookProbe alloc] init] autorelease];
        probe->_rdWorldRecords = (NSArray *)worlds;
        AddressBookRecord *world = [[[AddressBookRecord alloc] init] autorelease];
        world.subitems = (NSArray *)characters;
        AddressBookRecord *character = [[[AddressBookRecord alloc] init] autorelease];
        id<NSOutlineViewDataSource> dataSource = probe;
        NSOutlineView *view = [[[NSOutlineView alloc] initWithFrame:NSZeroRect] autorelease];

        id worldChild = [dataSource outlineView:view child:index ofItem:nil];
        id characterChild = [dataSource outlineView:view child:index ofItem:world];
        printf("%ld %d %lu\n", (long)[dataSource outlineView:view numberOfChildrenOfItem:nil],
               worldChild == worlds, (unsigned long)worlds.index);
        printf("%ld %d %lu\n", (long)[dataSource outlineView:view numberOfChildrenOfItem:world],
               characterChild == characters, (unsigned long)characters.index);
        printf("%ld %d\n", (long)[dataSource outlineView:view numberOfChildrenOfItem:character],
               [dataSource outlineView:view child:0 ofItem:character] == nil);
    }
}
'''


class AddressBookOutlineIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-address-book-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-framework", "Cocoa", str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check_children(self, index, count, expected):
        result = subprocess.check_output(
            [self.executable, str(index), str(count)], text=True,
        ).splitlines()
        self.assertEqual(result, [expected, expected, "0 1"])

    def test_data_source_signatures(self):
        self.assertEqual(subprocess.check_output([self.executable, "signatures"]), b"1 1\n")

    def test_ordinary_and_wide_world_and_character_indexes(self):
        for index in (1, 2**32 + 1):
            with self.subTest(index=index):
                self.check_children(index, index + 1, f"{index + 1} 1 {index}")

    def test_empty_missing_and_out_of_range_indexes(self):
        for index, count in ((0, 0), (-1, 2), (2, 2), (2**32 + 1, 2)):
            with self.subTest(index=index, count=count):
                self.check_children(index, count, f"{count} 0 {NOT_FOUND}")


if __name__ == "__main__":
    unittest.main()
