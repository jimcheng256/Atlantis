"""Check Foundation range widths in the email link filter."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Filter System/RDEmailFilter.m"


class EmailSearchRangeTests(unittest.TestCase):
    def test_initial_range_and_match_advancement(self):
        source = SOURCE.read_text()
        initial = re.search(r"\w+ searchLength = \[searchString length\];\s*searchRange = [^;]+;", source)[0]
        advance = re.search(r"\w+ newPos = [^;]+;\s*searchRange = [^;]+;", source)[0]
        probe = r'''
#import <Foundation/Foundation.h>

@interface SearchText : NSObject
@property NSUInteger length;
@end
@implementation SearchText
@end

static void check(SearchText *searchString, NSRange foundUrlRange) {
    NSRange searchRange;
    INITIAL
    printf("%lu %lu\n", (unsigned long)searchRange.location, (unsigned long)searchRange.length);
    ADVANCE
    printf("%lu %lu\n", (unsigned long)searchRange.location, (unsigned long)searchRange.length);
}

int main(void) {
    @autoreleasepool {
        SearchText *text = [SearchText new];
        text.length = 40;
        check(text, NSMakeRange(4, 15));
        check(text, NSMakeRange(25, 15));
        text.length = (1ULL << 32) + 40;
        check(text, NSMakeRange((1ULL << 32) + 4, 15));
        check(text, NSMakeRange(4, 15));
        [text release];
    }
}
'''.replace("INITIAL", initial).replace("ADVANCE", advance)
        with tempfile.TemporaryDirectory(prefix="atlantis-email-ranges.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, [
            "0 40", "19 21", "0 40", "40 0",
            "0 4294967336", "4294967315 21", "0 4294967336", "19 4294967317",
        ])


if __name__ == "__main__":
    unittest.main()
