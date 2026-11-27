"""Exercise the Highlights editor's production methods with synthetic indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
EDITOR = ROOT / "Preferences/World/WorldHighlightEditor.m"


def probe_source():
    names = (
        "tableViewSelectionDidChange", "numberOfRowsInTableView", "tableView",
        "controlTextDidEndEditing", "addHighlight", "toggleForeground",
        "toggleBackground", "changePatternType", "changeColor",
    )
    method_pattern = r"^- \([^)]+\)\s*(?:" + "|".join(names) + r"):[^\n]*\n\{.*?^\}"
    methods = re.findall(method_pattern, EDITOR.read_text(), re.M | re.S)
    if len(methods) != 10:
        raise ValueError(f"Expected ten methods in {EDITOR}")
    return r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "RDStringPattern.h"

static int patternType;
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wincomplete-implementation"
#pragma clang diagnostic ignored "-Wprotocol"
@implementation RDStringPattern
+ (RDStringPattern *)patternWithString:(NSString *)pattern type:(int)type {
    patternType = type;
    return [[[self alloc] init] autorelease];
}
- (int)type { return patternType; }
- (NSString *)pattern { return @"pattern"; }
@end
#pragma clang diagnostic pop

@interface HighlightEvent : NSObject
@property (retain) RDStringPattern *pattern;
@property (retain) NSColor *foreground;
@property (retain) NSColor *background;
@end
@implementation HighlightEvent
@end

@interface HighlightsFixture : NSObject
@property NSUInteger count;
@property NSUInteger lookupRow;
@property NSUInteger addedRow;
@property (retain) HighlightEvent *event;
@end
@implementation HighlightsFixture
- (id)objectAtIndex:(NSUInteger)index {
    self.lookupRow = index;
    return self.event;
}
- (void)addObject:(HighlightEvent *)event { self.event = event; }
- (NSUInteger)indexOfObject:(id)object { return self.addedRow; }
@end

@interface TableFixture : NSObject
@property NSInteger selectedRow;
@property NSInteger selectionRequest;
@end
@implementation TableFixture
- (void)reloadData {}
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend {
    self.selectionRequest = row;
}
@end

@interface PickerFixture : NSObject
@property NSInteger indexOfSelectedItem;
@end
@implementation PickerFixture
- (id)selectedItem { return nil; }
- (NSInteger)indexOfItem:(id)item { return self.indexOfSelectedItem; }
- (void)selectItemAtIndex:(NSInteger)index {}
- (void)setEnabled:(BOOL)enabled {}
@end

@interface HighlightsProbe : NSObject <NSTableViewDataSource> {
@public
    id _rdHighlights;
    TableFixture *_rdHighlightsTable;
    PickerFixture *_rdHighlightTypeButton;
    NSButton *_rdRemoveHighlightButton, *_rdHighlightUseBgButton, *_rdHighlightUseFgButton;
    NSColorWell *_rdForegroundColorWell, *_rdBackgroundColorWell;
    NSTextField *_rdHighlightPattern;
    NSUInteger commits;
}
@end
@implementation HighlightsProbe
- (void)finalCommit { commits++; }
''' + "\n".join(methods) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        HighlightsProbe *probe = [[[HighlightsProbe alloc] init] autorelease];
        if (strcmp(argv[1], "signatures") == 0) {
            SEL reader = @selector(tableView:objectValueForTableColumn:row:);
            SEL writer = @selector(tableView:setObjectValue:forTableColumn:row:);
            SEL counter = @selector(numberOfRowsInTableView:);
            Class cls = [HighlightsProbe class];
            char countType[8], readType[8], writeType[8];
            method_getReturnType(class_getInstanceMethod(cls, counter), countType, sizeof(countType));
            method_getArgumentType(class_getInstanceMethod(cls, reader), 4, readType, sizeof(readType));
            method_getArgumentType(class_getInstanceMethod(cls, writer), 5, writeType, sizeof(writeType));
            printf("%d %d %d\n", strcmp(countType, @encode(NSInteger)) == 0,
                   strcmp(readType, @encode(NSInteger)) == 0, strcmp(writeType, @encode(NSInteger)) == 0);
            return 0;
        }

        NSInteger row = strtoll(argv[1], NULL, 10);
        NSInteger menuIndex = strtoll(argv[2], NULL, 10);
        NSUInteger addedRow = strtoull(argv[3], NULL, 10);
        HighlightsFixture *highlights = [[[HighlightsFixture alloc] init] autorelease];
        highlights.count = row < 0 ? 0 : (NSUInteger)row + 1;
        highlights.addedRow = addedRow;
        highlights.event = [[[HighlightEvent alloc] init] autorelease];
        highlights.event.pattern = [RDStringPattern patternWithString:@"pattern" type:0];
        TableFixture *table = [[[TableFixture alloc] init] autorelease];
        table.selectedRow = row;
        table.selectionRequest = -2;
        PickerFixture *picker = [[[PickerFixture alloc] init] autorelease];
        picker.indexOfSelectedItem = menuIndex;
        probe->_rdHighlights = highlights;
        probe->_rdHighlightsTable = table;
        probe->_rdHighlightTypeButton = picker;

        id<NSTableViewDataSource> dataSource = probe;
        NSTableView *tableView = (NSTableView *)table;
        printf("%ld\n", (long)[dataSource numberOfRowsInTableView:tableView]);
        if (row >= 0) {
            NSTableColumn *column = [[[NSTableColumn alloc] initWithIdentifier:@"highlightType"] autorelease];
            id value = [dataSource tableView:tableView objectValueForTableColumn:column row:row];
            printf("%d %lu\n", [value intValue], (unsigned long)highlights.lookupRow);
            table.selectedRow = -1; // Keep the selection refresh from replacing the recorded lookup.
            [dataSource tableView:tableView setObjectValue:@1 forTableColumn:column row:row];
            printf("%d %lu\n", patternType, (unsigned long)highlights.lookupRow);
            table.selectedRow = row;
        }

        SEL actions[] = {@selector(tableViewSelectionDidChange:), @selector(controlTextDidEndEditing:),
                         @selector(toggleForeground:), @selector(toggleBackground:),
                         @selector(changeColor:), @selector(changePatternType:)};
        for (NSUInteger i = 0; i < sizeof(actions) / sizeof(*actions); i++) {
            highlights.lookupRow = NSNotFound;
            [probe performSelector:actions[i] withObject:nil];
            printf("%s %lu\n", highlights.lookupRow == NSNotFound ? "none" : "row",
                   highlights.lookupRow == NSNotFound ? 0 : (unsigned long)highlights.lookupRow);
        }
        printf("%d %lu\n", patternType, (unsigned long)probe->commits);
        [probe addHighlight:nil];
        printf("%ld\n", (long)table.selectionRequest);
    }
}
'''


class HighlightIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-highlight-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations",
             "-I", str(ROOT / "Utility Classes"), "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def test_data_source_signatures(self):
        self.assertEqual(subprocess.check_output([self.executable, "signatures"]), b"1 1 1\n")

    def run_probe(self, row, menu, added):
        return subprocess.check_output(
            [self.executable, str(row), str(menu), str(added)], text=True,
        ).splitlines()

    def check_row(self, row, menu):
        self.assertEqual(
            self.run_probe(row, menu, row),
            [str(row + 1), f"0 {row}", f"1 {row}", *[f"row {row}"] * 6, f"{menu} 5", str(row)],
        )

    def test_ordinary_row(self):
        for menu in range(4):
            with self.subTest(menu=menu):
                self.check_row(2, menu)

    def test_wide_row(self):
        self.check_row(2**32 + 2, 2)

    def test_missing_table_selection_and_missing_added_row(self):
        self.assertEqual(
            self.run_probe(-1, 2, 2**63 - 1),
            ["0", *["none 0"] * 6, "0 0", "-2"],
        )

    def test_invalid_pattern_menu_selection_preserves_pattern(self):
        for menu in (-1, 4, 2**32 + 2):
            with self.subTest(menu=menu):
                result = self.run_probe(2, menu, 2)
                self.assertEqual(result[-2], "1 4")


if __name__ == "__main__":
    unittest.main()
