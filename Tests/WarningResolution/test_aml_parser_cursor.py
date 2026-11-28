"""Check valid AML output and native-width cursor advancement."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Extensions/NSAttributedStringAdditions.m"
PROBE = r'''
#import <AppKit/AppKit.h>
#include <stdbool.h>

@interface RDAtlantisWorldInstance : NSObject
@end
@implementation RDAtlantisWorldInstance
- (id)preferenceForKey:(NSString *)key { return @[[NSColor blackColor]]; }
- (NSParagraphStyle *)formattingParagraphStyle { return nil; }
@end

@interface NSColor (Probe)
+ (NSColor *)colorWithWebCode:(NSString *)code;
@end

@interface WideAML : NSObject
@end
@implementation WideAML {
    NSUInteger _searches;
}
- (NSUInteger)length { return (1ULL << 32) + 7; }
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set options:(NSStringCompareOptions)options range:(NSRange)range {
    if (++_searches == 1)
        return NSMakeRange(0, 1);
    if (_searches == 2)
        return NSMakeRange((1ULL << 32) + 2, 1);
    NSCAssert(_searches == 3 && range.location == (1ULL << 32) + 3 &&
        range.length == 4, @"wide AML search range %@", NSStringFromRange(range));
    return NSMakeRange(NSNotFound, 0);
}
- (NSString *)substringWithRange:(NSRange)range {
    if (range.location == 1)
        return @"b";
    NSCAssert(range.location == (1ULL << 32) + 3 && range.length == 4,
        @"wide AML tail range %@", NSStringFromRange(range));
    return @"café";
}
@end

@implementation NSAttributedString (Probe)
METHOD
@end

int main(void) {
    @autoreleasepool {
        RDAtlantisWorldInstance *world = [RDAtlantisWorldInstance new];
        WideAML *wide = [WideAML new];
        for (id text in @[@"hello <b>world</b> &lt; café", wide]) {
            NSAttributedString *result = [[NSAttributedString alloc] initWithAML:text
                forWorld:world withFont:[NSFont systemFontOfSize:12]
                withDefaultFG:[NSColor blackColor] withDefaultBG:nil];
            puts(result.string.UTF8String);
            [result release];
        }
        [wide release];
        [world release];
    }
}
'''


class AMLParserCursorTests(unittest.TestCase):
    def test_valid_text_and_wide_tag_end(self):
        method = re.search(r"^- \(id\) initWithAML:[^\n]*withFont:.*?^}",
                           SOURCE.read_text(), re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-aml-cursor.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit",
                            "-Wno-deprecated-declarations", str(path), "-o", str(binary)], check=True)
            result = subprocess.run([binary], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["hello world < café", "café"])


if __name__ == "__main__":
    unittest.main()
