"""Verify the MUSH format tag at restore, save, and export boundaries."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Misc/MUSHTextEditor.m"
PROBE = r'''
#import <AppKit/AppKit.h>

static NSUserDefaults *defaults;
static NSUserDefaults *RDAtlantisDefaults(void) { return defaults; }

@interface Probe : NSObject {
@public
    id _rdAnsiTypePicker;
    id _rdEditorView;
    NSInteger _tag;
    NSInteger _restoredTag;
    NSAttributedString *_storage;
}
- (NSString *)editorAsMUSHText;
@end

@implementation Probe
- (id)textStorage { return _storage; }
- (id)selectedCell { return self; }
- (NSInteger)tag { return _tag; }
- (BOOL)selectCellWithTag:(NSInteger)tag { _restoredTag = tag; return YES; }
- (NSInteger)idForColor:(NSColor *)color { return NSNotFound; }
- (BOOL)isHighlightedInAttributes:(NSDictionary *)attrs { return NO; }
- (BOOL)isInvertedInAttributes:(NSDictionary *)attrs { return NO; }
- (BOOL)isUnderlinedInAttributes:(NSDictionary *)attrs { return NO; }
- (NSString *)fgColorForAttributes:(NSDictionary *)attrs { return @"r"; }
- (NSString *)bgColorForAttributes:(NSDictionary *)attrs { return nil; }

- (void)restore {
    RESTORE
}
SAVE
EXPORT
@end

int main(void) {
    @autoreleasepool {
        NSString *suite = [@"Atlantis.MUSHFormatTags." stringByAppendingString:NSUUID.UUID.UUIDString];
        defaults = [[NSUserDefaults alloc] initWithSuiteName:suite];
        NSString *key = @"atlantis.mushEdit.ansiType";
        Probe *probe = [Probe new];
        probe->_rdAnsiTypePicker = probe;
        probe->_rdEditorView = probe;
        probe->_storage = [[NSAttributedString alloc] initWithString:@"AB"
            attributes:@{@"RDAnsiForegroundColor": @1}];
        for (NSNumber *tag in @[@0, @1, @2, @3, @(-1), @4294967298LL]) {
            probe->_tag = tag.integerValue;
            [defaults setInteger:probe->_tag forKey:key];
            [probe restore];
            [defaults removeObjectForKey:key];
            [probe ansiPicked:nil];
            printf("%ld %ld %s\n", (long)probe->_restoredTag,
                (long)[defaults integerForKey:key], [[probe editorAsMUSHText] UTF8String]);
        }
        [defaults removePersistentDomainForName:suite];
        [defaults release];
        [probe->_storage release];
        [probe release];
    }
}
'''


class MUSHFormatTagTests(unittest.TestCase):
    def test_restore_save_and_export_use_the_full_tag(self):
        source = SOURCE.read_text()
        restore = re.search(r'^    \w+ ansiType = .*?\n    \[_rdAnsiTypePicker selectCellWithTag:ansiType\];',
                            source, re.M)[0]
        save = re.search(r"^- \(void\) ansiPicked:.*?^}", source, re.M | re.S)[0]
        export = re.search(r"^- \(NSString \*\) editorAsMUSHText\n\{.*?^}", source, re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-mush-tags.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("RESTORE", restore).replace("SAVE", save).replace("EXPORT", export))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, [
            "0 0 %cn%crAB%cn",
            "1 1 %xn%xrAB%xn",
            "2 2 [ansi(r,AB)]",
            "3 3 AB",
            "-1 -1 ",
            "4294967298 4294967298 ",
        ])


if __name__ == "__main__":
    unittest.main()
