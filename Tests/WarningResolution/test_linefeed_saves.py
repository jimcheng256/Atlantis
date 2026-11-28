"""Verify linefeed preference saves from the popup and defaults toggle."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Preferences/World/WorldFormattingEditor.m"
PROBE = r'''
#import <AppKit/AppKit.h>

@interface Probe : NSObject {
@public
    id _rdCodepage;
    id _rdCodepageDefault;
    id _rdLinefeedType;
}
@property NSInteger selection;
@property NSControlStateValue state;
@property (retain) NSNumber *saved;
@end
@implementation Probe
- (id)preferences { return self; }
- (id)character { return @"Example"; }
- (void)saveSelectedCodepage {}
- (void)setEnabled:(BOOL)enabled {}
- (NSInteger)indexOfSelectedItem { return self.selection; }
- (void)setPreference:(NSNumber *)value forKey:(NSString *)key withCharacter:(id)character {
    NSCAssert([character isEqual:@"Example"], @"preserve character scope");
    if ([key isEqual:@"atlantis.text.linefeed"])
        self.saved = value;
}
- (void)removePreferenceForKey:(NSString *)key withCharacter:(id)character {
    [self setPreference:nil forKey:key withCharacter:character];
}
HELPER
ACTION
- (void)toggle:(id)unused {
    BOOL enabled = self.state == NSControlStateValueOn;
    id sender = _rdCodepageDefault;
    TOGGLE
}
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        probe->_rdCodepage = probe;
        probe->_rdCodepageDefault = probe;
        probe->_rdLinefeedType = probe;
        for (NSNumber *defaultState in @[@0, @1]) {
            probe.state = defaultState.integerValue;
            for (NSNumber *selection in @[@0, @1, @(-1), @2, @(NSNotFound),
                                           @4294967296LL, @4294967297LL]) {
                probe.selection = selection.integerValue;
                probe.saved = @99;
                [probe chooseLinefeed:probe];
                puts(probe.saved.stringValue.UTF8String ?: "removed");
                probe.saved = @99;
                [probe toggle:nil];
                puts(probe.saved.stringValue.UTF8String ?: "removed");
            }
        }
        probe.saved = nil;
        [probe release];
    }
}
'''


class LinefeedSaveTests(unittest.TestCase):
    def test_both_paths_save_only_valid_rows_or_remove_the_override(self):
        source = SOURCE.read_text()
        helper = re.search(r"^- \(void\) saveSelectedLinefeed:.*?^}", source, re.M | re.S)
        action = re.search(r"^- \(IBAction\) chooseLinefeed:.*?^}", source, re.M | re.S)[0]
        toggle = re.search(
            r"^    else (if \(sender == _rdCodepageDefault\).*?)(?=^    else if \(sender == _rdGrabpassDefault\))",
            source, re.M | re.S,
        )[1]
        probe = PROBE.replace("HELPER", helper[0] if helper else "")
        probe = probe.replace("ACTION", action).replace("TOGGLE", toggle)
        with tempfile.TemporaryDirectory(prefix="atlantis-linefeed-save.") as temp:
            path = Path(temp) / "probe.mm"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang++", "-std=c++17", "-framework", "AppKit",
                            str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["0", "0", "1", "1"] + ["99"] * 10 + ["removed"] * 14)


if __name__ == "__main__":
    unittest.main()
