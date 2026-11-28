"""Check SSL checkbox saves and disabled-control inheritance."""

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
    id _rdHostSSL;
}
@property NSControlStateValue state;
@property (getter=isEnabled) BOOL enabled;
@property (retain) NSNumber *saved;
@end

@implementation Probe
- (id)preferences { return self; }
- (id)character { return @"Character"; }
- (void)setPreference:(NSNumber *)value forKey:(NSString *)key withCharacter:(id)character {
    NSCAssert([key isEqual:@"atlantis.world.ssl"] && [character isEqual:@"Character"], @"SSL scope");
    self.saved = value;
}
- (void)removePreferenceForKey:(NSString *)key withCharacter:(id)character {
    [self setPreference:nil forKey:key withCharacter:character];
}
ACTION
- (void)commit {
    COMMIT
}
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        probe->_rdHostSSL = probe;
        for (NSNumber *state in @[@0, @1, @(-1), @4294967297LL]) {
            probe.state = state.integerValue;
            probe.enabled = YES;
            [probe hostSSLChanged:nil];
            printf("%d ", probe.saved.intValue);
            probe.saved = nil;
            [probe commit];
            printf("%d ", probe.saved ? probe.saved.intValue : -1);
            probe.enabled = NO;
            probe.saved = @YES;
            [probe commit];
            printf("%d\n", probe.saved ? probe.saved.intValue : -1);
        }
        probe.saved = nil;
        [probe release];
    }
}
'''


class WorldSSLSelectionTests(unittest.TestCase):
    def test_only_native_on_saves_true_and_disabled_clears_override(self):
        source = SOURCE.read_text()
        action = re.search(r"^- \(void\) hostSSLChanged:.*?^}", source, re.M | re.S)[0]
        final_commit = re.search(r"^- \(void\) finalCommit.*?^}", source, re.M | re.S)[0]
        commit = re.search(
            r"^(?:    numResult = \[_rdHostSSL state\];\n)?"
            r"    if \(\[_rdHostSSL isEnabled\]\) \{.*?(?=^    \[self keepaliveChanged:nil\];)",
            final_commit, re.M | re.S,
        )[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-ssl-probe.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("ACTION", action).replace("COMMIT", "int numResult;\n" + commit))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["0 0 -1", "1 1 -1", "0 0 -1", "0 0 -1"])


if __name__ == "__main__":
    unittest.main()
