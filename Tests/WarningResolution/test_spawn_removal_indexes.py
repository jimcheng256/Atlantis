"""Exercise the Spawn editor's selection across its removal sheet callback."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Preferences/World/WorldSpawnEditor.m"


def probe_source():
    editor = SOURCE.read_text().split("@implementation WorldSpawnEditor", 1)[1]
    methods = re.findall(
        r"^- \([^)]+\)\s*(?:removeSpawn|handleRemoveResult):[^\n]*\n\{.*?^\}",
        editor, re.M | re.S,
    )
    if len(methods) != 2:
        raise ValueError(f"Expected the removal action and callback in {SOURCE}")
    return r'''
#import <AppKit/AppKit.h>

@interface WindowFixture : NSObject
- (BOOL)makeFirstResponder:(id)responder;
@end
@implementation WindowFixture
- (BOOL)makeFirstResponder:(id)responder { return YES; }
@end

@interface OutlineFixture : NSObject
@property (retain) WindowFixture *window;
@property NSInteger selectedRow, lookedUpRow, deselectedRow;
@property NSUInteger reloads;
@end
@implementation OutlineFixture
- (id)itemAtRow:(NSInteger)row {
    self.lookedUpRow = row;
    return self;
}
- (void)deselectRow:(NSInteger)row { self.deselectedRow = row; }
- (void)reloadData { self.reloads++; }
@end

typedef NSObject WorldSpawnRecord;

@interface SpawnRemovalProbe : NSObject {
@public
    OutlineFixture *_rdSpawnList;
    void *savedContext;
    SEL savedCallback;
    NSUInteger removals;
}
- (void)removeSpawn:(id)sender;
@end
@implementation SpawnRemovalProbe
- (void)askQuestion:(NSString *)question info:(NSString *)info action:(SEL)callback context:(void *)context {
    savedContext = context;
    savedCallback = callback;
}
- (void)traverseAndRemove:(WorldSpawnRecord *)record { removals++; }
''' + "\n".join(methods) + r'''
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        SpawnRemovalProbe *probe = [[[SpawnRemovalProbe alloc] init] autorelease];
        OutlineFixture *outline = [[[OutlineFixture alloc] init] autorelease];
        outline.selectedRow = strtoll(argv[1], NULL, 10);
        outline.lookedUpRow = outline.deselectedRow = -2;
        if (atoi(argv[3])) {
            outline.window = [[[WindowFixture alloc] init] autorelease];
        }
        probe->_rdSpawnList = outline;

        @autoreleasepool {
            [probe removeSpawn:nil];
        }
        if (!probe->savedContext) {
            puts("no sheet");
            return 0;
        }

        NSInteger savedRow = [(NSNumber *)probe->savedContext integerValue];
        IMP callback = [probe methodForSelector:probe->savedCallback];
        ((void (*)(id, SEL, NSAlert *, int, void *))callback)(
            probe, probe->savedCallback, nil, atoi(argv[2]), probe->savedContext);
        printf("%ld %ld %ld %lu %lu\n", (long)savedRow, (long)outline.lookedUpRow,
               (long)outline.deselectedRow, (unsigned long)probe->removals, (unsigned long)outline.reloads);
    }
}
'''


class SpawnRemovalIndexTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        temporary = tempfile.TemporaryDirectory(prefix="atlantis-spawn-removal-indexes.")
        cls.addClassCleanup(temporary.cleanup)
        source = Path(temporary.name) / "probe.m"
        cls.executable = source.with_suffix("")
        source.write_text(probe_source())
        subprocess.run(
            ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "Cocoa",
             str(source), "-o", str(cls.executable)],
            check=True,
        )

    def run_probe(self, row, confirmed, *, window=True):
        return subprocess.check_output(
            [self.executable, str(row), str(int(confirmed)), str(int(window))], text=True,
        ).strip()

    def test_confirm_uses_original_row_at_full_width(self):
        for row in (2, 2**32 + 2, 2**62 + 2):
            with self.subTest(row=row):
                self.assertEqual(self.run_probe(row, True), f"{row} {row} {row} 1 1")

    def test_cancel_and_missing_selection_do_not_remove_a_row(self):
        self.assertEqual(self.run_probe(2, False), "2 -2 -2 0 0")
        self.assertEqual(self.run_probe(-1, True), "-1 -2 -2 0 0")

    def test_detached_editor_does_not_start_a_sheet(self):
        self.assertEqual(self.run_probe(2, True, window=False), "no sheet")


if __name__ == "__main__":
    unittest.main()
