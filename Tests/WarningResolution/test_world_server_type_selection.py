"""Check Server Type popup saves, restoration, and the MUD scrollback default."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Preferences/World/WorldMainEditor.m"

PROBE = r'''
#import <AppKit/AppKit.h>

@interface Probe : NSObject {
@public
    id _rdServerType;
}
@property NSInteger selection;
@property(retain) NSNumber *saved;
@property(retain) NSNumber *lines;
@property(copy) NSString *character;
@end
@implementation Probe
- (id)preferences { return self; }
- (id)selectedItem { return self; }
- (NSInteger)indexOfItem:(id)item { return self.selection; }
- (NSInteger)numberOfItems { return 3; }
- (void)selectItemAtIndex:(NSInteger)index { self.selection = index; }
- (void)setPreference:(NSNumber *)value forKey:(NSString *)key withCharacter:(id)character {
    NSCAssert(!character, @"world preference");
    if ([key isEqual:@"atlantis.world.codebase"])
        self.saved = value;
    else if ([key isEqual:@"atlantis.mainview.lines"])
        self.lines = value;
}
- (id)preferenceForKey:(NSString *)key withCharacter:(id)character fallback:(BOOL)fallback {
    return [key isEqual:@"atlantis.world.codebase"] ? self.saved : self.lines;
}
HELPER
CHANGE
- (void)commit {
    COMMIT
}
- (void)restore {
    NSNumber *numResult;
    RESTORE
}
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        probe->_rdServerType = probe;
        for (NSNumber *input in @[@0, @1, @2, @(-1), @3, @4294967297LL]) {
            probe.saved = @2;
            probe.lines = nil;
            probe.selection = input.integerValue;
            [probe serverTypeChanged:nil];
            printf("change %ld %ld\n", (long)probe.saved.integerValue, (long)probe.lines.integerValue);
            probe.saved = @2;
            probe.lines = nil;
            probe.selection = input.integerValue;
            [probe commit];
            printf("commit %ld %ld\n", (long)probe.saved.integerValue, (long)probe.lines.integerValue);
            probe.saved = input;
            [probe restore];
            printf("restore %ld\n", (long)probe.selection);
        }
        probe.saved = nil;
        [probe restore];
        printf("default %ld\n", (long)probe.selection);

        probe.saved = @2;
        probe.lines = @900;
        probe.selection = 1;
        [probe serverTypeChanged:nil];
        printf("existing lines %ld %ld\n", (long)probe.saved.integerValue, (long)probe.lines.integerValue);

        probe.character = @"character";
        probe.saved = @2;
        probe.lines = nil;
        [probe serverTypeChanged:nil];
        [probe commit];
        printf("character %ld %ld\n", (long)probe.saved.integerValue, (long)probe.lines.integerValue);
        [probe release];
    }
}
'''


class WorldServerTypeSelectionTests(unittest.TestCase):
    def test_native_selection_persistence_and_mud_default(self):
        source = SOURCE.read_text()
        helper = re.search(r"^- \(NSInteger\) saveServerTypeSelection.*?^}", source, re.M | re.S)
        change = re.search(r"^- \(IBAction\) serverTypeChanged:.*?^}", source, re.M | re.S)[0]
        final_commit = re.search(r"^- \(void\) finalCommit.*?^}", source, re.M | re.S)[0]
        commit = re.search(
            r'(^    if \(!\[self character\]\) \{(?:(?!^    \}).)*?atlantis.world.codebase.*?^    \}'
            r'|^    \[self saveServerTypeSelection\];)\s*^    \[\[self preferences\] endBulk\]',
            final_commit, re.M | re.S,
        )[1]
        restore = re.search(
            r'^    numResult = [^\n]*atlantis.world.codebase.*?(?=^    if \(\[self character\]\))',
            source, re.M | re.S,
        )[0]
        probe = PROBE.replace("HELPER", helper[0] if helper else "")
        probe = probe.replace("CHANGE", change).replace("COMMIT", commit).replace("RESTORE", restore)
        with tempfile.TemporaryDirectory(prefix="atlantis-server-type.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            observed = subprocess.check_output([binary], text=True).splitlines()
        expected = []
        for index in range(3):
            expected.extend([f"change {index} {500 if index == 1 else 0}", f"commit {index} 0", f"restore {index}"])
        expected.extend(["change 2 0", "commit 2 0", "restore 0"] * 3)
        self.assertEqual(observed, expected + ["default 0", "existing lines 1 900", "character 2 0"])


if __name__ == "__main__":
    unittest.main()
