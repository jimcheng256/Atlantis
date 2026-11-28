"""Verify the existing codepage preference contract across the three save paths."""

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
@property NSInteger tag;
@property BOOL hasSelection;
@property NSControlStateValue state;
@property (retain) NSNumber *saved;
@end
@implementation Probe
- (id)preferences { return self; }
- (id)character { return @"Example"; }
- (id)selectedItem { return self.hasSelection ? self : nil; }
- (void)setEnabled:(BOOL)enabled {}
- (NSInteger)indexOfSelectedItem { return 1; }
- (void)setPreference:(NSNumber *)value forKey:(NSString *)key withCharacter:(id)character {
    NSCAssert([character isEqual:@"Example"], @"preserve character scope");
    if ([key isEqual:@"atlantis.encoding"])
        self.saved = value;
}
- (void)removePreferenceForKey:(NSString *)key withCharacter:(id)character {
    [self setPreference:nil forKey:key withCharacter:character];
}
HELPER
ACTION
- (void)commit:(id)sender {
    FINAL
}
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
            for (id tag in @[@0, @(NSUTF8StringEncoding), @(NSUTF16BigEndianStringEncoding),
                              @4294967297ULL, @(-1), [NSNull null]]) {
                probe.hasSelection = tag != [NSNull null];
                probe.tag = probe.hasSelection ? [tag integerValue] : 77;
                for (SEL selector : (SEL[]){@selector(commit:), @selector(chooseCodepage:), @selector(toggle:)}) {
                    probe.saved = @99;
                    [probe performSelector:selector withObject:nil];
                    puts(probe.saved.stringValue.UTF8String ?: "removed");
                }
            }
        }
        probe.saved = nil;
        [probe release];
    }
}
'''


class CodepageSaveTests(unittest.TestCase):
    def test_all_saves_preserve_the_unsigned_32_bit_contract(self):
        source = SOURCE.read_text()
        helper = re.search(r"^- \(void\) saveSelectedCodepage.*?^}", source, re.M | re.S)
        action = re.search(r"^- \(IBAction\) chooseCodepage:.*?^}", source, re.M | re.S)[0]
        final = re.search(
            r"^    if \(\[_rdCodepageDefault state\].*?(?=^    if \(\[_rdGrabpassDefault state\])",
            source, re.M | re.S,
        )[0]
        toggle = re.search(
            r"^    else (if \(sender == _rdCodepageDefault\).*?)(?=^    else if \(sender == _rdGrabpassDefault\))",
            source, re.M | re.S,
        )[1]
        probe = PROBE.replace("HELPER", helper[0] if helper else "")
        probe = probe.replace("ACTION", action).replace("FINAL", final).replace("TOGGLE", toggle)
        with tempfile.TemporaryDirectory(prefix="atlantis-codepage-save.") as temp:
            path = Path(temp) / "probe.mm"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang++", "-std=c++17", "-framework", "AppKit",
                            str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        expected = [value for value in ("0", "4", "2415919360", "1", "4294967295", "0") for _ in range(3)]
        self.assertEqual(lines, expected + ["removed"] * 18)


if __name__ == "__main__":
    unittest.main()
