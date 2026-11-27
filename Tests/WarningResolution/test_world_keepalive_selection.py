"""Exercise Keepalive popup saves and restoration at AppKit index widths."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Preferences/World/WorldMainEditor.m"

PROBE = r'''
#import <AppKit/AppKit.h>

@interface Probe : NSObject
@property NSInteger indexOfSelectedItem;
@property(retain) NSNumber *saved;
@end
@implementation Probe
- (NSInteger)numberOfItems { return 4; }
- (void)selectItemAtIndex:(NSInteger)index { self.indexOfSelectedItem = index; }
- (id)preferences { return self; }
- (id)character { return @"test character"; }
- (void)setPreference:(NSNumber *)value forKey:(NSString *)key withCharacter:(NSString *)character {
    NSCAssert([key isEqual:@"atlantis.network.keepalive"] && [character isEqual:@"test character"], @"preference target");
    self.saved = value;
}
- (id)preferenceForKey:(NSString *)key withCharacter:(id)character fallback:(BOOL)fallback {
    return self.saved;
}
CHANGE
- (void)commit:(id)_rdKeepaliveLogic {
    COMMIT
}
- (void)restore:(id)_rdKeepaliveLogic {
    NSNumber *numResult;
    RESTORE
}
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        for (NSNumber *input in @[@0, @1, @2, @3, @(-1), @4, @4294967297LL]) {
            probe.saved = @2;
            probe.indexOfSelectedItem = input.integerValue;
            [probe keepaliveChanged:probe];
            printf("change %ld\n", (long)probe.saved.integerValue);
            probe.saved = @2;
            probe.indexOfSelectedItem = input.integerValue;
            [probe commit:probe];
            printf("commit %ld\n", (long)probe.saved.integerValue);
            probe.saved = input;
            [probe restore:probe];
            printf("restore %ld\n", (long)probe.indexOfSelectedItem);
        }
        probe.saved = nil;
        [probe restore:probe];
        printf("default %ld\n", (long)probe.indexOfSelectedItem);
        [probe release];
    }
}
'''


class WorldKeepaliveSelectionTests(unittest.TestCase):
    def test_selection_and_legacy_preferences(self):
        source = SOURCE.read_text()
        change = re.search(r"^- \(void\) keepaliveChanged:.*?^}", source, re.M | re.S)[0]
        change = change.replace("(id) sender", "(id) _rdKeepaliveLogic")
        final_commit = re.search(r"^- \(void\) finalCommit.*?^}", source, re.M | re.S)[0]
        commit = re.search(
            r'removePreferenceForKey:@"atlantis.world.ssl".*?^    }\n(.*?)'
            r'^    result = \[_rdCharacterName stringValue\];',
            final_commit, re.M | re.S,
        )[1]
        commit = commit.replace("keepaliveChanged:nil", "keepaliveChanged:_rdKeepaliveLogic")
        restore = re.search(
            r'^    numResult = [^\n]*atlantis.network.keepalive.*?'
            r'(?=^    result = .*?atlantis.world.name)',
            source, re.M | re.S,
        )[0]
        probe = PROBE.replace("CHANGE", change).replace("COMMIT", commit).replace("RESTORE", restore)
        with tempfile.TemporaryDirectory(prefix="atlantis-keepalive.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)],
                check=True,
            )
            observed = subprocess.check_output([binary], text=True).splitlines()
        expected = []
        for index in range(4):
            expected.extend([f"change {index}", f"commit {index}", f"restore {index}"])
        expected.extend(["change 2", "commit 2", "restore 0"] * 3)
        self.assertEqual(observed, expected + ["default 0"])


if __name__ == "__main__":
    unittest.main()
