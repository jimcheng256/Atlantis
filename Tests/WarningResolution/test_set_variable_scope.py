"""Exercise Set Variable scope selection and keyed archive compatibility."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event System/Actions/Action-SetTempVar.m"

FIXTURE = r'''
#import <AppKit/AppKit.h>

@interface Popup : NSObject
@property NSInteger selection;
@end
@implementation Popup
- (NSInteger)indexOfSelectedItem { return self.selection; }
- (void)selectItemAtIndex:(NSInteger)index { self.selection = index; }
- (void)setTarget:(id)target {}
- (void)setAction:(SEL)action {}
@end

@interface ActionFixture : NSObject <NSCoding>
@end
@implementation ActionFixture
- (id)initWithCoder:(NSCoder *)coder { return [super init]; }
- (void)encodeWithCoder:(NSCoder *)coder {}
@end

@interface Probe : ActionFixture <NSTextFieldDelegate> {
@public
    NSPopUpButton *_rdVariableTypeField;
    NSTextField *_rdVariableNameField;
    NSTextField *_rdVariableValueField;
    NSView *_rdInternalConfigurationView;
    NSNumber *_rdVariableType;
    NSString *_rdVariableName;
    NSString *_rdVariableValue;
}
- (void)variableTypeChanged:(id)sender;
- (NSView *)actionConfigurationView;
@end
@implementation Probe
METHODS
@end

static Probe *decode(NSData *data, Popup *popup) {
    NSKeyedUnarchiver *reader = [[NSKeyedUnarchiver alloc] initForReadingFromData:data error:NULL];
    reader.requiresSecureCoding = NO;
    Probe *probe = [[Probe alloc] initWithCoder:reader];
    [reader finishDecoding];
    [reader release];
    probe->_rdVariableTypeField = (NSPopUpButton *)popup;
    probe->_rdInternalConfigurationView = (NSView *)popup;
    return [probe autorelease];
}

int main(int argc, char **argv) {
    @autoreleasepool {
        Popup *popup = [[[Popup alloc] init] autorelease];
        NSKeyedArchiver *legacy = [[[NSKeyedArchiver alloc] initRequiringSecureCoding:NO] autorelease];
        if (argv[1][0] != 'm') {
            [legacy encodeObject:[NSNumber numberWithInt:atoi(argv[1])] forKey:@"action.variableType"];
        }
        Probe *probe = decode(legacy.encodedData, popup);
        [probe actionConfigurationView];
        printf("%ld ", (long)popup.selection);

        popup.selection = strtoll(argv[2], NULL, 10);
        [probe variableTypeChanged:nil];

        NSKeyedArchiver *writer = [[[NSKeyedArchiver alloc] initRequiringSecureCoding:NO] autorelease];
        [probe encodeWithCoder:writer];
        Probe *reopened = decode(writer.encodedData, popup);
        [reopened actionConfigurationView];
        printf("%ld\n", (long)popup.selection);
    }
}
'''


class SetVariableScopeTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        source = SOURCE.read_text()
        methods = []
        for signature in ("dealloc", "initWithCoder:", "encodeWithCoder:", "variableTypeChanged:",
                          "actionConfigurationView"):
            methods.append(re.search(rf"^- \([^)]*\) {signature}.*?^}}", source, re.M | re.S)[0])
        temp = tempfile.TemporaryDirectory(prefix="atlantis-set-variable-scope.")
        cls.addClassCleanup(temp.cleanup)
        path = Path(temp.name) / "probe.m"
        path.write_text(FIXTURE.replace("METHODS", "\n".join(methods)))
        cls.binary = path.with_suffix("")
        subprocess.run(["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "AppKit",
                        str(path), "-o", str(cls.binary)], check=True)

    def test_legacy_scopes_and_new_choices_round_trip(self):
        for old, selection in ((0, 1), (1, 2), (2, 0), (-1, 0), ("missing", 0)):
            with self.subTest(old=old, selection=selection):
                output = subprocess.check_output([self.binary, str(old), str(selection)], text=True)
                expected_old = 0 if old == "missing" else old
                self.assertEqual(output, f"{expected_old} {selection}\n")

    def test_invalid_choices_preserve_saved_scope(self):
        for selection in (-1, 3, 2**32 + 1):
            with self.subTest(selection=selection):
                output = subprocess.check_output([self.binary, "2", str(selection)], text=True)
                self.assertEqual(output, "2 2\n")


if __name__ == "__main__":
    unittest.main()
