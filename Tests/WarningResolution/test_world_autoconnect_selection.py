"""Exercise startup preference writes with native-width AppKit values."""

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
    id _rdAutoconnect;
    id _rdAutopicker;
}
@property NSControlStateValue state;
@property NSInteger selection;
@property BOOL enabled;
@property BOOL open;
@property BOOL connect;
@property NSInteger bulkDepth;
@end

@implementation Probe
- (id)preferences { return self; }
- (id)character { return @"Test Character"; }
- (void)beginBulk { self.bulkDepth++; }
- (void)endBulk { self.bulkDepth--; }
- (id)selectedItem { return self; }
- (NSInteger)indexOfItem:(id)item { return self.selection; }
- (NSInteger)indexOfSelectedItem { return self.selection; }
- (void)setPreference:(NSNumber *)value forKey:(NSString *)key withCharacter:(id)character {
    NSCAssert([character isEqual:@"Test Character"], @"preserve character scope");
    NSCAssert(self.bulkDepth > 0, @"batch preference writes");
    if ([key isEqual:@"atlantis.world.autoopen"])
        self.open = value.boolValue;
    else if ([key isEqual:@"atlantis.world.autoconnect"])
        self.connect = value.boolValue;
    else
        NSCAssert(NO, @"unexpected preference");
}
HELPER
TYPE_ACTION
CHECKBOX_ACTION
- (void)commit {
    [self beginBulk];
    int numResult;
    COMMIT
    [self endBulk];
}
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        probe->_rdAutoconnect = probe;
        probe->_rdAutopicker = probe;
        for (NSNumber *state in @[@1, @0, @(-1), @4294967297LL]) {
            for (NSNumber *selection in @[@0, @1, @(-1), @2, @(NSNotFound), @4294967297LL]) {
                for (NSString *action in @[@"popup", @"checkbox", @"commit"]) {
                    probe.state = state.integerValue;
                    probe.selection = selection.integerValue;
                    probe.open = YES;
                    probe.connect = NO;
                    probe.enabled = YES;
                    if ([action isEqual:@"popup"])
                        [probe autoconnectTypeChanged:nil];
                    else if ([action isEqual:@"checkbox"])
                        [probe autoconnectChanged:nil];
                    else
                        [probe commit];
                    printf("%s %ld %ld %d %d %d\n", action.UTF8String, (long)probe.state,
                           (long)probe.selection, probe.open, probe.connect, probe.enabled);
                    NSCAssert(probe.bulkDepth == 0, @"balanced bulk writes");
                }
            }
        }
        [probe release];
    }
}
'''


class WorldAutoconnectSelectionTests(unittest.TestCase):
    def test_actions_and_final_save(self):
        source = SOURCE.read_text()
        helper = re.search(r"^- \(void\) saveAutoconnectSelection.*?^}", source, re.M | re.S)
        popup = re.search(r"^- \(void\) autoconnectTypeChanged:.*?^}", source, re.M | re.S)[0]
        checkbox = re.search(r"^- \(void\) autoconnectChanged:.*?^}", source, re.M | re.S)[0]
        final_commit = re.search(r"^- \(void\) finalCommit.*?^}", source, re.M | re.S)[0]
        commit = re.search(
            r"^    (?:numResult = \[_rdAutoconnect state\];|\[self saveAutoconnectSelection\];)"
            r".*?(?=^    \[self saveServerTypeSelection\];)",
            final_commit, re.M | re.S,
        )[0]
        probe = PROBE.replace("HELPER", helper[0] if helper else "")
        probe = probe.replace("TYPE_ACTION", popup).replace("CHECKBOX_ACTION", checkbox).replace("COMMIT", commit)
        with tempfile.TemporaryDirectory(prefix="atlantis-autoconnect-probe.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(len(lines), 72)
        for line in lines:
            action, state, selection, opened, connected, enabled = line.split()
            with self.subTest(action=action, state=state, selection=selection):
                on = state == "1"
                expected_open = on or action == "popup"
                expected_connect = on and selection == "1"
                expected_enabled = on or action != "checkbox"
                self.assertEqual(
                    (int(opened), int(connected), int(enabled)),
                    (expected_open, expected_connect, expected_enabled),
                )


if __name__ == "__main__":
    unittest.main()
