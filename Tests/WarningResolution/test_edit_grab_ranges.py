"""Check Grab and FugueEdit range arithmetic at the native string width."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Worlds/RDAtlantisWorldInstance.m"
PROBE = r'''
#import <Foundation/Foundation.h>

@interface LengthFixture : NSObject
@property NSUInteger length;
@end
@implementation LengthFixture
@end

FUNCTIONS

static void exercise(NSRange (*rangeFor)(LengthFixture *, LengthFixture *)) {
    LengthFixture *prefix = [LengthFixture new];
    LengthFixture *line = [LengthFixture new];
    for (NSNumber *width in @[@12, @4294967308ULL]) {
        prefix.length = width.unsignedIntegerValue;
        for (NSNumber *tail in @[@12, @11, @0]) {
            line.length = prefix.length + tail.unsignedIntegerValue;
            NSRange range = rangeFor(prefix, line);
            printf("%lu %lu\n", (unsigned long)range.location, (unsigned long)range.length);
        }
    }
    [prefix release];
    [line release];
}

int main(void) {
    @autoreleasepool {
        exercise(grabRange);
        exercise(fugueRange);
    }
}
'''


class EditGrabRangeTests(unittest.TestCase):
    def test_both_ranges_preserve_payload_rules_and_wide_offsets(self):
        source = SOURCE.read_text()
        functions = []
        for pattern, name in (("rdGrabPattern", "grabRange"), ("rdFuguePattern", "fugueRange")):
            prefix = f"[[_{pattern} pattern] length]"
            match = re.search(
                rf"\w+ patternLength = {re.escape(prefix)};\s*NSRange tempRange = [^;]+;", source
            )[0]
            body = match.replace(prefix, "[prefix length]")
            functions.append(
                f"static NSRange {name}(LengthFixture *prefix, LengthFixture *compareString) {{\n"
                f"    {body}\n"
                "    return tempRange;\n}"
            )
        with tempfile.TemporaryDirectory(prefix="atlantis-edit-grab-range.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("FUNCTIONS", "\n\n".join(functions)))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        expected = [
            "12 11", "12 10", "12 18446744073709551615",
            "4294967308 11", "4294967308 10", "4294967308 18446744073709551615",
        ]
        self.assertEqual(lines, expected * 2)


if __name__ == "__main__":
    unittest.main()
