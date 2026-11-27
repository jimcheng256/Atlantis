"""Exercise the Spawn editor's outline data source and selection methods."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Preferences/World/WorldSpawnEditor.m"


def probe_source():
    methods = re.findall(
        r"^- \([^)]+\)\s*(?:outlineView:[^\n]*(?:numberOfChildrenOfItem:|child:)[^\n]*"
        r"|reloadKeepingSelection|currentSelectedSpawn|outlineViewSelectionDidChange:[^\n]*"
        r"|addSpawn:[^\n]*)\n\{.*?^\}",
        SOURCE.read_text().split("@implementation WorldSpawnEditor", 1)[1], re.M | re.S,
    )
    if len(methods) != 6:
        raise ValueError(f"Expected six outline methods in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>

@interface ChildrenFixture : NSObject
@property NSUInteger count;
@property NSUInteger lookedUpIndex;
@end
@implementation ChildrenFixture
- (id)objectAtIndex:(NSUInteger)index {
    self.lookedUpIndex = index;
    return self;
}
@end

@interface WorldSpawnRecord : NSObject <NSTableViewDataSource>
@property (retain) NSArray *subSpawns;
@property (retain) NSString *name;
@property int weight;
@property unsigned lines;
@property (retain) NSString *prefix;
@property BOOL activity;
@property BOOL statusBar;
- (WorldSpawnRecord *)spawnByName:(NSString *)name;
- (void)addSpawn:(WorldSpawnRecord *)spawn;
@end
@implementation WorldSpawnRecord
- (WorldSpawnRecord *)spawnByName:(NSString *)name { return nil; }
- (void)addSpawn:(WorldSpawnRecord *)spawn {}
@end

@interface OutlineFixture : NSObject
@property NSInteger selectedRow, resolvedRow, addedRow;
@property NSInteger lookedUpRow, requestedRow, editedRow;
@property (retain) WorldSpawnRecord *item;
@end
@implementation OutlineFixture
- (WorldSpawnRecord *)itemAtRow:(NSInteger)row {
    self.lookedUpRow = row;
    return self.item;
}
- (NSInteger)rowForItem:(WorldSpawnRecord *)item {
    return item.name ? self.addedRow : self.resolvedRow;
}
- (void)reloadData {}
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend { self.requestedRow = row; }
- (void)editColumn:(NSInteger)column row:(NSInteger)row withEvent:(NSEvent *)event select:(BOOL)select {
    self.editedRow = row;
}
- (NSWindow *)window { return nil; }
- (void)expandItem:(id)item {}
@end

@interface SpawnOutlineProbe : NSObject <NSOutlineViewDataSource> {
@public
    WorldSpawnRecord *_rdRootSpawn;
    OutlineFixture *_rdSpawnList;
    NSTableView *_rdPatternList, *_rdExceptionList;
    NSButton *_rdAddSpawn, *_rdRemoveSpawn, *_rdAddPattern, *_rdRemovePattern, *_rdAddException, *_rdRemoveException;
    NSButton *_rdActivityButton, *_rdStatusbarButton;
    NSTextField *_rdPriority, *_rdLineField, *_rdPrefixField;
    NSStepper *_rdPriorityStepper;
}
- (void)outlineViewSelectionDidChange:(NSNotification *)notification;
@end

@implementation SpawnOutlineProbe
''' + "\n".join(methods) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        if (strcmp(argv[1], "signatures") == 0) {
            Class cls = [SpawnOutlineProbe class];
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
        SpawnOutlineProbe *probe = [[[SpawnOutlineProbe alloc] init] autorelease];
        WorldSpawnRecord *root = [[[WorldSpawnRecord alloc] init] autorelease];
        WorldSpawnRecord *branch = [[[WorldSpawnRecord alloc] init] autorelease];
        ChildrenFixture *children = [[[ChildrenFixture alloc] init] autorelease];
        children.count = count;
        children.lookedUpIndex = NSNotFound;
        branch.subSpawns = (NSArray *)children;
        probe->_rdRootSpawn = root;

        OutlineFixture *outline = [[[OutlineFixture alloc] init] autorelease];
        outline.item = branch;
        outline.selectedRow = index;
        outline.resolvedRow = strtoll(argv[3], NULL, 10);
        outline.addedRow = strtoll(argv[4], NULL, 10);
        outline.lookedUpRow = -2;
        outline.requestedRow = -2;
        outline.editedRow = -2;
        probe->_rdSpawnList = outline;
        NSOutlineView *view = (NSOutlineView *)outline;
        id<NSOutlineViewDataSource> dataSource = probe;

        printf("%ld %d %ld\n", (long)[dataSource outlineView:view numberOfChildrenOfItem:nil],
               [dataSource outlineView:view child:0 ofItem:nil] == root,
               (long)[dataSource outlineView:view numberOfChildrenOfItem:branch]);
        id child = [dataSource outlineView:view child:index ofItem:branch];
        printf("%d %lu\n", child == children, (unsigned long)children.lookedUpIndex);

        BOOL foundSelection = [probe currentSelectedSpawn] == branch;
        printf("%d %ld\n", foundSelection, (long)outline.lookedUpRow);
        outline.lookedUpRow = -2;
        [probe reloadKeepingSelection];
        printf("%ld %ld\n", (long)outline.lookedUpRow, (long)outline.requestedRow);
        outline.requestedRow = -2;
        [probe addSpawn:nil];
        printf("%ld %ld\n", (long)outline.requestedRow, (long)outline.editedRow);
    }
}
'''


class SpawnOutlineIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-spawn-outline-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def run_probe(self, row, count, resolved, added):
        return subprocess.check_output(
            [self.executable, str(row), str(count), str(resolved), str(added)], text=True,
        ).splitlines()

    def test_data_source_signatures(self):
        self.assertEqual(subprocess.check_output([self.executable, "signatures"]), b"1 1\n")

    def test_ordinary_and_wide_rows(self):
        for row in (1, 2**32 + 1):
            with self.subTest(row=row):
                resolved, added = row + 2, row + 3
                self.assertEqual(
                    self.run_probe(row, row + 1, resolved, added),
                    [f"1 1 {row + 1}", f"1 {row}", f"1 {row}", f"{row} {resolved}", f"{added} {added}"],
                )

    def test_missing_selection_and_row_lookup(self):
        self.assertEqual(
            self.run_probe(-1, 2, -1, -1),
            ["1 1 2", f"0 {2**63 - 1}", "0 -2", "-2 -2", "-2 -2"],
        )

    def test_reload_can_select_root_when_no_item_was_selected(self):
        self.assertEqual(self.run_probe(-1, 2, 0, -1)[3], "-2 0")

    def test_child_at_count_is_rejected(self):
        self.assertEqual(self.run_probe(2, 2, -1, -1)[1], f"0 {2**63 - 1}")


if __name__ == "__main__":
    unittest.main()
