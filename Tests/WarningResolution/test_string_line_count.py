"""Check line counting and its native-width string limit."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2] / "Extensions"
PROBE = r'''
#import <Foundation/Foundation.h>
#import <objc/runtime.h>
#import "NSStringExtensions.h"

@implementation NSString (LineCountProbe)
METHOD
@end

@interface WideString : NSObject
@end
@implementation WideString
- (NSUInteger)length { return 4294967296ULL; }
- (unichar)characterAtIndex:(NSUInteger)index {
    NSCAssert(index == 0, @"counting starts at zero");
    @throw [NSException exceptionWithName:@"WideStringVisited" reason:nil userInfo:nil];
}
@end

int main(void) {
    @autoreleasepool {
        for (NSString *value in @[@"", @"abc", @"a\n", @"\n", @"a\nb",
                                  @"\n\n", @"a\r\nb", @"😀\nx"]) {
            printf("%lu\n", (unsigned long)[value lineCount]);
        }
        printf("%zu\n", [@"example" methodSignatureForSelector:@selector(lineCount)].methodReturnLength);
        Method method = class_getInstanceMethod([NSString class], @selector(lineCount));
        class_addMethod([WideString class], @selector(lineCount),
                        method_getImplementation(method), method_getTypeEncoding(method));
        id wide = [[[WideString alloc] init] autorelease];
        @try {
            [wide lineCount];
            puts("not visited");
        } @catch (NSException *exception) {
            puts(exception.name.UTF8String);
        }
    }
}
'''


class StringLineCountTests(unittest.TestCase):
    def test_line_counts_and_wide_loop_limit(self):
        source = (ROOT / "NSStringExtensions.m").read_text()
        method = re.search(r"^- \(\w+\) lineCount.*?^}", source, re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-line-count.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-framework", "Foundation", "-I", str(ROOT), str(path), "-o", str(binary)],
                check=True,
            )
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["1", "1", "1", "1", "2", "2", "2", "2", "8", "WideStringVisited"])


if __name__ == "__main__":
    unittest.main()
