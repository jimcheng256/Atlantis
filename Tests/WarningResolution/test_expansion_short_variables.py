"""Exercise temporary-variable fallback and length limits in the expansion method."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Extensions/NSStringExtensions.m"
PROBE = r'''
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
@interface RDAtlantisMainController : NSObject
+ (id)controller;
- (id)tempStateVarForKey:(NSString *)key;
@end
@implementation RDAtlantisMainController
+ (id)controller { return [[[self alloc] init] autorelease]; }
- (id)tempStateVarForKey:(NSString *)key {
    return @{@"x": @"temporary", @"four": @"four-value", @"longer": @"explicit"}[key];
}
@end
@implementation NSString (ExpansionProbe)
METHOD
@end

static const NSUInteger wideOffset = 4294967296ULL;

@interface WideTemplate : NSObject
@end

@implementation WideTemplate
- (NSUInteger)length { return wideOffset + 11; }
- (NSRange)rangeOfString:(NSString *)needle options:(NSStringCompareOptions)options range:(NSRange)range {
    if ([needle isEqual:@"}"])
        return NSMakeRange(wideOffset + 9, 1);
    return range.location == 0 ? NSMakeRange(wideOffset, 2) : NSMakeRange(NSNotFound, 0);
}
- (NSRange)rangeOfCharacterFromSet:(NSCharacterSet *)set options:(NSStringCompareOptions)options range:(NSRange)range {
    return NSMakeRange(wideOffset + 7, 1);
}
- (unichar)characterAtIndex:(NSUInteger)index { return ':'; }
- (NSString *)substringWithRange:(NSRange)range {
    if (NSEqualRanges(range, NSMakeRange(0, wideOffset)))
        return @"prefix ";
    if (NSEqualRanges(range, NSMakeRange(wideOffset + 2, 5)))
        return @"value";
    if (NSEqualRanges(range, NSMakeRange(wideOffset + 8, 1)))
        return @"1";
    if (NSEqualRanges(range, NSMakeRange(wideOffset + 10, 1)))
        return @"!";
    return @"unexpected range";
}
@end

int main(void) {
    @autoreleasepool {
        for (NSString *input in @[@"%{x}", @"%{four}", @"%{temp.x}", @"%{temp.longer}",
                                  @"%{longer}", @"%{z}", @"%{}", @"%{temp.z}"]) {
            puts([input expandWithDataIn:@{}].UTF8String);
        }
        puts([@"%{x}" expandWithDataIn:@{@"x": @"event data"}].UTF8String);
        for (NSString *input in @[@"%{value:-1}", @"%{value:-2147483648}", @"%{value:0}", @"%{value:3}"]) {
            puts([input expandWithDataIn:@{@"value": @"abcdef"}].UTF8String);
        }
        NSDictionary *unicode = @{@"emoji": @"😀x", @"accent": @"e\u0301x",
                                  @"flag": @"🇨🇦x", @"joined": @"👩‍💻x"};
        for (NSString *input in @[@"%{emoji:1}", @"%{accent:1}", @"%{flag:1}",
                                  @"%{joined:1}", @"%{joined:2}"]) {
            puts([input expandWithDataIn:unicode].UTF8String ?: "invalid UTF-8");
        }
        SEL selector = @selector(expandWithDataIn:);
        Method method = class_getInstanceMethod([NSString class], selector);
        class_addMethod([WideTemplate class], selector, method_getImplementation(method), method_getTypeEncoding(method));
        WideTemplate *wide = [[[WideTemplate alloc] init] autorelease];
        puts([(id)wide expandWithDataIn:@{@"value": @"😀x"}].UTF8String);
    }
}
'''


class ExpansionShortVariablesTests(unittest.TestCase):
    def test_lookup_and_length_limits(self):
        method = re.search(r"^- \(NSString \*\) expandWithDataIn:.*?^}",
                           SOURCE.read_text(), re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-expansion.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "Foundation",
                            str(path), "-o", str(binary)],
                           check=True)
            result = subprocess.run([binary], capture_output=True, text=True, check=True)
        lines = result.stdout.splitlines()
        self.assertEqual(
            [line.split("Atlantis warning: ", 1)[1] for line in result.stderr.splitlines()
             if "Atlantis warning: " in line],
            ["Variable 'x' was not found in the supplied data. Using 'temp.x'.",
             "Variable 'four' was not found in the supplied data. Using 'temp.four'.",
             "Negative length limit '-1' for variable 'value'. Truncation is disabled.",
             "Negative length limit '-2147483648' for variable 'value'. Truncation is disabled."],
        )
        self.assertEqual(lines, ["temporary", "four-value", "temporary", "explicit",
                                 "<Unknown Variable: 'longer'>", "<Unknown Variable: 'z'>",
                                 "<Unknown Variable: ''>", "<Unknown Variable: 'temp.z'>", "event data",
                                 "abcdef", "abcdef", "abcdef", "abc...",
                                 "😀...", "e\u0301...", "🇨🇦...", "👩‍💻...", "👩‍💻x",
                                 "prefix 😀...!"])


if __name__ == "__main__":
    unittest.main()
