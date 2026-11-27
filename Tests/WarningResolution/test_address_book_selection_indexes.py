"""Exercise Address Book selection and tab restoration with synthetic indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Worlds/AddressBook.m"
NOT_FOUND = 2**63 - 1


def probe_source():
    methods = re.findall(
        r"^- \([^)]+\)\s*(?:reloadKeepingSelection|currentSelection|"
        r"outlineView:[^\n]*shouldSelectItem:[^\n]*|outlineViewSelectionDidChange:[^\n]*)\n\{.*?^\}",
        SOURCE.read_text(), re.M | re.S,
    )
    if len(methods) != 4:
        raise ValueError(f"Expected four Address Book selection methods in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>

@interface AddressBookRecord : NSObject
@end
@implementation AddressBookRecord
- (NSString *)uuid { return @"fixture"; }
- (BOOL)isCharacter { return YES; }
@end

@interface WorldConfigurationEditor : NSObject
@property NSUInteger commits;
@end
@implementation WorldConfigurationEditor
- (void)commitAll { self.commits++; }
@end

@interface OutlineFixture : NSObject
@property NSInteger selectedRow, resolvedRow, lookedUpRow, requestedRow;
@property NSUInteger reloads;
@property (retain) AddressBookRecord *item;
@end
@implementation OutlineFixture
- (AddressBookRecord *)itemAtRow:(NSInteger)row {
    self.lookedUpRow = row;
    return self.item;
}
- (NSInteger)rowForItem:(AddressBookRecord *)item { return self.resolvedRow; }
- (void)reloadData { self.reloads++; }
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend { self.requestedRow = row; }
@end

@interface TabsFixture : NSTabView
@property NSInteger sourceIndex, count, requestedIndex;
@property BOOL hasSelectedTab;
@end
@implementation TabsFixture
- (NSInteger)indexOfTabViewItem:(NSTabViewItem *)item { return self.sourceIndex; }
- (NSInteger)numberOfTabViewItems { return self.count; }
- (NSTabViewItem *)selectedTabViewItem {
    return self.hasSelectedTab ? [[[NSTabViewItem alloc] initWithIdentifier:@"tab"] autorelease] : nil;
}
- (void)selectTabViewItemAtIndex:(NSInteger)index { self.requestedIndex = index; }
@end

@interface ContainerFixture : NSObject
@property (retain) NSTabViewItem *selectedTabViewItem;
@property (retain) NSTabViewItem *destination;
@property NSUInteger switches;
@end
@implementation ContainerFixture
- (void)selectTabViewItemWithIdentifier:(NSString *)identifier {
    if ([identifier isEqualToString:@"fixture"]) {
        self.switches++;
        self.selectedTabViewItem = self.destination;
    }
}
@end

@interface AddressBookProbe : NSObject {
@public
    OutlineFixture *_rdWorldList;
    ContainerFixture *_rdConfigContent;
    NSDictionary *_rdWorldPreferenceViews;
    NSButton *_rdRemoveWorldButton, *_rdAddCharacterButton, *_rdRemoveCharacterButton;
    NSButton *_rdConnectButton, *_rdShortcutButton;
}
- (AddressBookRecord *)currentSelection;
- (void)outlineViewSelectionDidChange:(NSNotification *)notification;
@end
@implementation AddressBookProbe
- (void)saveExpands {}
''' + "\n".join(methods) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        OutlineFixture *outline = [[[OutlineFixture alloc] init] autorelease];
        outline.selectedRow = strtoll(argv[1], NULL, 10);
        outline.resolvedRow = strtoll(argv[2], NULL, 10);
        outline.lookedUpRow = outline.requestedRow = -2;
        outline.item = [[[AddressBookRecord alloc] init] autorelease];

        TabsFixture *source = [[[TabsFixture alloc] initWithFrame:NSZeroRect] autorelease];
        source.sourceIndex = strtoll(argv[3], NULL, 10);
        source.hasSelectedTab = atoi(argv[5]);
        TabsFixture *destination = [[[TabsFixture alloc] initWithFrame:NSZeroRect] autorelease];
        destination.count = strtoll(argv[4], NULL, 10);
        destination.requestedIndex = -2;
        ContainerFixture *config = [[[ContainerFixture alloc] init] autorelease];
        config.selectedTabViewItem = [[[NSTabViewItem alloc] initWithIdentifier:@"source"] autorelease];
        config.selectedTabViewItem.view = source;
        config.destination = [[[NSTabViewItem alloc] initWithIdentifier:@"destination"] autorelease];
        config.destination.view = destination;

        AddressBookProbe *probe = [[[AddressBookProbe alloc] init] autorelease];
        WorldConfigurationEditor *editor = [[[WorldConfigurationEditor alloc] init] autorelease];
        probe->_rdWorldList = outline;
        probe->_rdConfigContent = config;
        probe->_rdWorldPreferenceViews = @{@"fixture": editor};

        BOOL selected = [probe currentSelection] == outline.item;
        printf("%d %ld\n", selected, (long)outline.lookedUpRow);
        outline.lookedUpRow = -2;
        [probe reloadKeepingSelection];
        printf("%ld %ld %lu\n", (long)outline.lookedUpRow, (long)outline.requestedRow, (unsigned long)outline.reloads);
        outline.lookedUpRow = -2;
        BOOL shouldSelect = [probe outlineView:nil shouldSelectItem:outline.item];
        printf("%d %ld %lu\n", shouldSelect, (long)outline.lookedUpRow, (unsigned long)editor.commits);
        outline.lookedUpRow = -2;
        [probe outlineViewSelectionDidChange:nil];
        printf("%ld %lu %ld\n", (long)outline.lookedUpRow, (unsigned long)config.switches,
               (long)destination.requestedIndex);
    }
}
'''


class AddressBookSelectionIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-address-book-selection.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def run_probe(self, row, resolved, tab, count, *, has_tab=True):
        return subprocess.check_output(
            [self.executable, str(row), str(resolved), str(tab), str(count), str(int(has_tab))], text=True,
        ).splitlines()

    def test_ordinary_and_wide_selection_and_restoration(self):
        for row in (1, 2**32 + 1):
            with self.subTest(row=row):
                resolved, tab = row + 2, row + 3
                self.assertEqual(
                    self.run_probe(row, resolved, tab, tab + 1),
                    [f"1 {row}", f"{row} {resolved} 1", f"1 {row} 1", f"{row} 1 {tab}"],
                )

    def test_missing_selection_and_unresolved_row(self):
        self.assertEqual(self.run_probe(-1, -1, 1, 2), ["0 -2", "-2 -2 1", "1 -2 0", "-2 0 -2"])
        self.assertEqual(self.run_probe(1, -1, 1, 2)[1], "1 -2 1")

    def test_does_not_restore_tab_outside_destination(self):
        for tab, has_tab in ((1, False), (-1, True), (NOT_FOUND, True), (2, True), (2**32 + 1, True)):
            with self.subTest(tab=tab, has_tab=has_tab):
                self.assertEqual(self.run_probe(1, 1, tab, 2, has_tab=has_tab)[-1], "1 1 -2")


if __name__ == "__main__":
    unittest.main()
