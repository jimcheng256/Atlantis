"""Check stacked-command offsets and bounded decimal accumulation."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Command System/StackedCommand.m"
PROBE = r'''
#import <Foundation/Foundation.h>
#include <limits.h>

ACCUMULATOR

@interface WideString : NSObject
@end
@implementation WideString
- (NSUInteger)length { return (NSUInteger)UINT_MAX + 1; }
- (unichar)characterAtIndex:(NSUInteger)index {
    NSCAssert(index == 0, @"first character");
    @throw [NSException exceptionWithName:@"WideScan" reason:nil userInfo:nil];
}
@end

@interface AtlantisState : NSObject
@property (retain) id input;
@property (retain) NSMutableArray *sent;
@end
@implementation AtlantisState
- (id)extraDataForKey:(NSString *)key { return @{@"RDOptsMainData": self.input}; }
- (id)world { return self; }
- (id)spawnPath { return nil; }
- (void)outputStatus:(NSString *)status toSpawn:(NSString *)spawn {}
- (void)sendString:(NSString *)command { [self.sent addObject:command]; }
@end

@interface Probe : NSObject
@end
@implementation Probe
METHOD
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        AtlantisState *state = [AtlantisState new];
        state.sent = [NSMutableArray array];
        state.input = @"2look0wait1café1score";
        [probe executeForState:state];
        puts([[state.sent componentsJoinedByString:@","] UTF8String]);
        [state.sent removeAllObjects];
        state.input = @"1look99999999999999999999999999";
        [probe executeForState:state];
        puts([[state.sent componentsJoinedByString:@","] UTF8String]);
        state.input = [[[WideString alloc] init] autorelease];
        @try {
            [probe executeForState:state];
            puts("skipped wide scan");
        } @catch (NSException *exception) {
            if (![exception.name isEqualToString:@"WideScan"]) @throw;
            puts("started wide scan");
        }
        printf("%d %d %d %d\n", APPEND(214748364, 6), APPEND(214748364, 7),
            APPEND(214748364, 8), APPEND(INT_MAX, 0));
        [state release];
        [probe release];
    }
}
'''


class StackedCommandCountTests(unittest.TestCase):
    def test_command_order_and_integer_boundaries(self):
        source = SOURCE.read_text()
        method = re.search(r"^- \(void\) executeForState:.*?^}", source, re.M | re.S)[0]
        accumulator = re.search(r"^static int AppendStackedCommandDigit.*?^}", source, re.M | re.S)
        if accumulator:
            implementation = accumulator[0] + "\n#define APPEND AppendStackedCommandDigit"
        else:
            implementation = "#define APPEND(count, digit) ((count) * 10 + (digit))"
        with tempfile.TemporaryDirectory(prefix="atlantis-stacked-count.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method).replace("ACCUMULATOR", implementation))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation",
                            "-fsanitize=signed-integer-overflow", "-fno-sanitize-recover=signed-integer-overflow",
                            str(path), "-o", str(binary)], check=True)
            result = subprocess.run([binary], capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.splitlines(), ["look,look,café,score", "look", "started wide scan",
                         "2147483646 2147483647 2147483647 2147483647"])


if __name__ == "__main__":
    unittest.main()
