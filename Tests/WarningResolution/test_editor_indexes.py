"""Exercise the production World Configuration and Open Log selection methods."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


def method(path, signature):
    text = (ROOT / path).read_text()
    match = re.search(rf"^{re.escape(signature)}[^\n]*\n\{{.*?^\}}", text, re.M | re.S)
    if not match:
        raise ValueError(f"Missing {signature} in {path}")
    return match[0]


def probe_source():
    world = method("Preferences/World/WorldConfigurationEditor.m", "- (BOOL)tabView:")
    log_path = "Event System/Actions/Action-OpenLog.m"
    change = method(log_path, "- (void) logTypeChanged:")
    configure = method(log_path, "- (NSView *) actionConfigurationView")
    return r'''
#import <AppKit/AppKit.h>
#import <objc/message.h>

@interface WorldConfigurationTab : NSObject
@property NSUInteger commits;
@end
@implementation WorldConfigurationTab
- (void)finalCommit { self.commits++; }
@end

@interface LogFormat : NSObject
+ (NSString *)logtypeName;
+ (NSString *)shortTypeName;
+ (BOOL)supportsOptions;
@end
@implementation LogFormat
+ (NSString *)logtypeName { return @"Formatted"; }
+ (NSString *)shortTypeName { return @"Formatted"; }
+ (BOOL)supportsOptions { return YES; }
@end

@interface Selection : NSObject
@property NSInteger index;
@property NSInteger restoredIndex;
@end
@implementation Selection
- (NSTabViewItem *)selectedTabViewItem {
    if (self.index == -1) {
        return nil;
    }
    return [[[NSTabViewItem alloc] initWithIdentifier:@(self.index)] autorelease];
}
- (NSInteger)indexOfTabViewItem:(NSTabViewItem *)item { return self.index; }
- (NSInteger)indexOfSelectedItem { return self.index; }
- (NSInteger)indexOfItemWithTitle:(NSString *)title { return self.index; }
- (void)removeAllItems {}
- (void)addItemWithTitle:(NSString *)title {}
- (void)selectItemAtIndex:(NSInteger)index { self.restoredIndex = index; }
@end

@interface IndexedCollection : NSObject
@property NSUInteger count;
@property NSUInteger lookups;
@property NSUInteger lastIndex;
@property (retain) id entry;
@end
@implementation IndexedCollection
- (id)objectAtIndex:(NSUInteger)index {
    self.lookups++;
    self.lastIndex = index;
    return self.entry;
}
- (NSEnumerator *)objectEnumerator {
    return [@[self.entry] objectEnumerator];
}
@end

@interface RDAtlantisMainController : NSObject
+ (instancetype)controller;
- (NSArray *)logTypes;
@end
static IndexedCollection *formats;
@implementation RDAtlantisMainController
+ (instancetype)controller { return [[[self alloc] init] autorelease]; }
- (NSArray *)logTypes { return (NSArray *)formats; }
@end

@interface EditorProbe : NSObject <NSTextFieldDelegate> {
@public
    Selection *_rdConfigTabView;
    IndexedCollection *_rdConfigPages;
    Selection *_rdLogTypes;
    NSString *_rdLogType;
    NSString *_rdPath;
    NSString *_rdSpawnPath;
    NSDictionary *_rdOptions;
    NSButton *_rdOptionsButton, *_rdSpawnEnabled, *_rdLogScrollback, *_rdTimestampsEnabled;
    NSTextField *_rdFilename, *_rdSpawnTextfield;
    BOOL _rdScrollback, _rdTimestamps;
    NSView *_rdInternalConfigurationView;
}
@end
@implementation EditorProbe
''' + "\n".join((world, change, configure)) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        NSString *mode = @(argv[1]);
        Selection *selection = [[[Selection alloc] init] autorelease];
        IndexedCollection *collection = [[[IndexedCollection alloc] init] autorelease];
        EditorProbe *probe = [[[EditorProbe alloc] init] autorelease];
        selection.index = strtoll(argv[2], NULL, 10);
        collection.count = strtoull(argv[3], NULL, 10);
        if ([mode isEqualToString:@"world"]) {
            WorldConfigurationTab *tab = [[[WorldConfigurationTab alloc] init] autorelease];
            collection.entry = tab;
            probe->_rdConfigTabView = selection;
            probe->_rdConfigPages = collection;
            BOOL allowed = [probe tabView:nil shouldSelectTabViewItem:nil];
            printf("%lu %lu %lu %d\n", (unsigned long)collection.lookups,
                   (unsigned long)collection.lastIndex, (unsigned long)tab.commits, allowed);
        } else {
            formats = collection;
            collection.entry = [LogFormat class];
            probe->_rdLogTypes = selection;
            if ([mode isEqualToString:@"change"]) {
                probe->_rdLogType = [@"Plain" retain];
                [probe logTypeChanged:nil];
                printf("%lu %lu %s\n", (unsigned long)collection.lookups,
                       (unsigned long)collection.lastIndex, probe->_rdLogType.UTF8String);
                [probe->_rdLogType release];
            } else {
                probe->_rdLogType = @"Formatted";
                probe->_rdInternalConfigurationView = [[[NSView alloc] init] autorelease];
                [probe actionConfigurationView];
                printf("%ld\n", (long)selection.restoredIndex);
            }
        }
        collection.entry = nil;
    }
}
'''


class EditorIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-editor-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def check(self, mode, index, count, expected):
        with self.subTest(mode=mode, index=index, count=count):
            result = subprocess.check_output([self.executable, mode, str(index), str(count)])
            self.assertEqual(result.decode().strip(), expected)

    def test_tab_commit_uses_full_index(self):
        for index in (1, 2**32 + 1):
            self.check("world", index, index + 1, f"1 {index} 1 1")

    def test_tab_skips_commit_without_a_valid_current_selection(self):
        for index, count in ((-1, 2), (2**63 - 1, 2), (0, 0), (2, 2)):
            self.check("world", index, count, "0 0 0 1")

    def test_log_type_change_uses_full_index(self):
        for index in (1, 2**32 + 1):
            self.check("change", index, index + 1, f"1 {index} Formatted")

    def test_log_type_change_ignores_invalid_selection(self):
        for index, count in ((-1, 2), (2**63 - 1, 2), (0, 0), (2, 2)):
            self.check("change", index, count, "0 0 Plain")

    def test_log_format_restore_uses_full_index(self):
        for index in (1, 2**32 + 1):
            self.check("restore", index, index + 1, str(index))


if __name__ == "__main__":
    unittest.main()
