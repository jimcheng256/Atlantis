"""Verify highlight ranges and native-width cursor advancement."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Utility Classes/RDStringPattern.m"
PROBE = r'''
@interface NSString (Regex)
- (NSRange)rangeOfRegularExpressionString:(NSString *)pattern;
- (NSRange)rangeOfRegularExpressionString:(NSString *)pattern
    options:(NSUInteger)options range:(NSRange)range;
@end

@interface WideText : NSObject
@end
@implementation WideText
- (NSUInteger)length { return (1ULL << 32) + 5; }
- (NSString *)substringToIndex:(NSUInteger)index { return @"cat"; }
- (NSRange)rangeOfString:(NSString *)pattern options:(NSUInteger)options range:(NSRange)range {
    if (range.location == 0)
        return NSMakeRange(1ULL << 32, 3);
    NSCAssert(range.location == (1ULL << 32) + 3 && range.length == 2, @"wide cursor");
    return NSMakeRange(NSNotFound, 0);
}
- (NSRange)rangeOfRegularExpressionString:(NSString *)pattern options:(NSUInteger)options range:(NSRange)range {
    return [self rangeOfString:pattern options:options range:range];
}
@end

@implementation RDStringPattern
METHODS
@end

@interface Probe : RDStringPattern
- (void)configure:(int)type wide:(BOOL)wide;
@end
@implementation Probe
- (void)configure:(int)type wide:(BOOL)wide {
    [_rdMatchMe release];
    _rdMatchMe = wide ? (NSString *)[WideText new] : nil;
    _rdPatternType = type;
    _rdPattern = @"cat";
    _rdMatchPosition = 0;
}
@end

static void Check(NSRange actual, NSUInteger location, NSUInteger length) {
    NSCAssert(NSEqualRanges(actual, NSMakeRange(location, length)), @"range %@", NSStringFromRange(actual));
}

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        [probe configure:RDPatternIs wide:NO];
        NSCAssert([probe patternMatchesString:@"cat"], @"exact predicate");
        NSCAssert(![probe patternMatchesString:@"bobcat cat"], @"reject substring in predicate");
        Check([probe stringMatch:@"bobcat cat"], 3, 3);
        Check([probe stringMatch:nil], 7, 3);
        Check([probe stringMatch:nil], NSNotFound, 0);

        [probe configure:RDPatternContains wide:NO];
        Check([probe stringMatch:@"bobcat cat"], 0, 10);
        Check([probe stringMatch:nil], 0, 0);

        [probe configure:RDPatternBeginsWith wide:YES];
        Check([probe stringMatch:nil], 0, (1ULL << 32) + 5);
        Check([probe stringMatch:nil], 0, 0);

        for (NSNumber *type in @[@(RDPatternIs), @(RDPatternRegexp)]) {
            [probe configure:type.intValue wide:YES];
            Check([probe stringMatch:nil], 1ULL << 32, 3);
            Check([probe stringMatch:nil], NSNotFound, 0);
        }
        [probe configure:RDPatternIs wide:NO];
        [probe release];
    }
}
'''


class PatternCursorTests(unittest.TestCase):
    def test_matching_contract_and_wide_cursor(self):
        source = SOURCE.read_text()
        methods = [
            re.search(pattern, source, re.M | re.S)[0]
            for pattern in (r"^- \(BOOL\) patternMatchesString:.*?^}", r"^- \(NSRange\) stringMatch:.*?^}")
        ]
        with tempfile.TemporaryDirectory(prefix="atlantis-pattern-cursor.") as temp:
            path = Path(temp) / "probe.m"
            header = SOURCE.with_suffix(".h").read_text()
            path.write_text(header + PROBE.replace("METHODS", "\n".join(methods)))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", "-Wno-incomplete-implementation",
                            "-Wno-protocol", str(path), "-o", str(binary)], check=True)
            result = subprocess.run([binary], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)


if __name__ == "__main__":
    unittest.main()
