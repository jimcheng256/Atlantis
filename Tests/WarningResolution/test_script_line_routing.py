"""Verify scripted destinations, copy order, and full-width attribute ranges."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Scripting/ScriptBridge.m"
PROBE = r'''
#import <Foundation/Foundation.h>
@interface AtlantisState : NSObject
@property (retain) NSMutableAttributedString *stringData;
@end
@implementation AtlantisState
- (id)extraDataForKey:(NSString *)key { return nil; }
@end
static AtlantisState *state;
@interface RDAtlantisMainController : NSObject
@end
@implementation RDAtlantisMainController
+ (id)controller { return self; }
+ (id)stateForSession:(NSString *)session { return state; }
@end
@interface Probe : NSObject
@end
@implementation Probe
METHOD
@end

@interface WideLine : NSObject
@end
@implementation WideLine
- (NSUInteger)length { return (1ULL << 32) + 9; }
- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRange *)range { return @{}; }
- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range {
    printf("%s %lu %lu\n", name.UTF8String, (unsigned long)range.location, (unsigned long)range.length);
}
@end

int main(void) {
    @autoreleasepool {
        state = [AtlantisState new];
        Probe *probe = [Probe new];
        for (NSArray *flags in @[@[@"0", @"1"], @[@"1", @"0"]]) {
            state.stringData = [[[NSMutableAttributedString alloc] initWithString:@"line"] autorelease];
            [probe setLineSpawn:@"first" copy:flags[0] inSession:@"session"];
            [probe setLineSpawn:@"second" copy:flags[1] inSession:@"session"];
            NSDictionary *attrs = [state.stringData attributesAtIndex:0 effectiveRange:NULL];
            printf("%s, %s: %s; original spawn %s\n",
                [flags[0] UTF8String], [flags[1] UTF8String],
                [[attrs[@"RDExtraSpawns"] componentsJoinedByString:@","] UTF8String],
                [attrs[@"RDExtraSpawnMove"] boolValue] ? "suppressed" : "retained");
        }
        WideLine *line = [WideLine new];
        state.stringData = (NSMutableAttributedString *)line;
        [probe setLineSpawn:@"wide" copy:@"1" inSession:@"session"];
        [line release];
        [probe release];
        [state release];
    }
}
'''


class ScriptLineRoutingTests(unittest.TestCase):
    def test_preserves_destination_order_and_full_range(self):
        method = re.search(r"^- \(void\) setLineSpawn:.*?^}", SOURCE.read_text(), re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-script-line-routing.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, [
            "0, 1: first,second; original spawn retained",
            "1, 0: first,second; original spawn suppressed",
            "RDExtraSpawns 0 4294967305",
            "RDExtraSpawnMove 0 4294967305",
        ])


if __name__ == "__main__":
    unittest.main()
