"""Check formatted-log output using the production writer and a capture sink."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Log System/RDFormattedText.m"
PROBE = r'''
#import <Foundation/Foundation.h>
typedef NSObject AtlantisState;

@interface Probe : NSObject
@property(retain) NSDictionary *options;
@property BOOL writeTimestamps;
@end

@implementation Probe
- (void)writeStringToFile:(NSString *)string {
    NSData *bytes = [string dataUsingEncoding:NSUTF8StringEncoding];
    if (!bytes) exit(2);
    fwrite(bytes.bytes, 1, bytes.length, stdout);
}
WRITER
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        Probe *probe = [[[Probe alloc] init] autorelease];
        probe.options = @{@"wrap": @YES, @"wrapchars": @(atoi(argv[1])),
                          @"indent": @(atoi(argv[2]))};
        probe.writeTimestamps = atoi(argv[3]) != 0;
        [NSTimeZone setDefaultTimeZone:[NSTimeZone timeZoneForSecondsFromGMT:0]];
        NSDictionary *attributes = probe.writeTimestamps
            ? @{@"RDTimeStamp": [NSDate dateWithTimeIntervalSince1970:0]} : nil;
        NSAttributedString *line = [[[NSAttributedString alloc]
            initWithString:[NSString stringWithUTF8String:argv[4]]
            attributes:attributes] autorelease];
        @try {
            [probe writeString:line withState:nil];
        } @catch (NSException *exception) {
            fprintf(stderr, "%s\n", exception.name.UTF8String);
            return 3;
        }
    }
}
'''


class FormattedLogWrapTests(unittest.TestCase):
    def test_exact_utf8_output(self):
        writer = re.search(
            r"^- \(void\) writeString:\(NSAttributedString \*\)string withState:.*?^}",
            SOURCE.read_text(), re.M | re.S,
        )
        self.assertIsNotNone(writer)
        cases = [
            ("soft wrap", 5, 2, 0, "one two", "one\n  two\n"),
            ("hard wrap", 4, 2, 0, "abcdef", "abc-\n  d-\n  ef\n"),
            ("zero continuation width", 4, 4, 0, "abcdef", "abc-\ndef\n"),
            ("zero first-line width", 11, 2, 1, "abcdef", "[00:00:00] abcdef\n"),
            ("timestamp width", 14, 2, 1, "abcdef", "[00:00:00] ab-\n  cdef\n"),
            ("negative margin", -1, 2, 0, "abcdef", "abcdef\n"),
            ("one column", 1, 0, 0, "ab", "a\nb\n"),
            ("surrogate pair", 2, 0, 0, "😀ab", "😀\nab\n"),
            ("combining mark", 2, 0, 0, "e\u0301ab", "e\u0301\nab\n"),
            ("joined emoji", 1, 0, 0, "👩‍💻a", "👩‍💻\na\n"),
            ("UTF-16 margin", 3, 0, 0, "😀abc", "😀-\nabc\n"),
        ]
        with tempfile.TemporaryDirectory(prefix="atlantis-formatted-log.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("WRITER", writer[0]))
            binary = path.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework",
                 "Foundation", str(path), "-o", str(binary)],
                capture_output=True, check=True,
            )
            for name, margin, indent, timestamps, line, expected in cases:
                with self.subTest(name=name):
                    result = subprocess.run(
                        [binary, str(margin), str(indent), str(timestamps), line],
                        capture_output=True, timeout=5,
                    )
                    self.assertEqual(result.returncode, 0, result.stderr)
                    self.assertEqual(result.stdout, expected.encode("utf-8"))


if __name__ == "__main__":
    unittest.main()
