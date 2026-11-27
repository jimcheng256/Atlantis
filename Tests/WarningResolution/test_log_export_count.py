"""Exercise the log export progress count and label at Cocoa widths."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Log System/RDLogOpener.m"

PROBE = r'''
#import <Foundation/Foundation.h>
#import <assert.h>

@interface Progress : NSObject
@property(copy) NSString *label;
@property double maxValue;
@end
@implementation Progress
@end

@interface Scrollback : NSObject
@property NSUInteger count;
@end
@implementation Scrollback
@end

int main(void) {
    @autoreleasepool {
        Scrollback *scrollbackData = [Scrollback new];
        Progress *progressSheet = [Progress new];
        for (NSNumber *count in @[@0, @42, @2147483648LL, @4294967297LL]) {
            scrollbackData.count = count.unsignedIntegerValue;
            CONFIGURE_PROGRESS
            assert(([progressSheet.label isEqualToString:
                    [NSString stringWithFormat:@"Writing %@ lines...", count]]));
            assert(progressSheet.maxValue == count.doubleValue);
        }
    }
}
'''


class LogExportCountTests(unittest.TestCase):
    def test_progress_label_and_maximum(self):
        progress = re.search(
            r"^[^\n]*\btotalLines = \[scrollbackData count\];.*?"
            r"^[^\n]*\[progressSheet setMaxValue:\(double\)totalLines\];",
            SOURCE.read_text(), re.M | re.S,
        )
        self.assertIsNotNone(progress)
        with tempfile.TemporaryDirectory(prefix="atlantis-log-export.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("CONFIGURE_PROGRESS", progress[0]))
            binary = path.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-framework", "Foundation", str(path), "-o", str(binary)],
                check=True,
            )
            subprocess.run([binary], check=True)


if __name__ == "__main__":
    unittest.main()
