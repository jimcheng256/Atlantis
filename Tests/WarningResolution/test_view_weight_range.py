"""Exercise view-path splitting and preserve existing weight lookup behavior."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Core/RDAtlantisMainController.m"

PROBE = r'''
#import <Foundation/Foundation.h>

@interface WidePath : NSObject
@end
@implementation WidePath
- (NSRange)rangeOfString:(NSString *)separator { return NSMakeRange(4294967296ULL, 1); }
- (NSUInteger)length { return 4294967301ULL; }
- (NSString *)substringWithRange:(NSRange)range {
    if (NSEqualRanges(range, NSMakeRange(0, 4294967296ULL)))
        return @"Example";
    if (NSEqualRanges(range, NSMakeRange(4294967297ULL, 4)))
        return @"Chat";
    return @"incorrect range";
}
@end

#define RDAtlantisWorldInstance Probe
#define RDSpawnConfigRecord Probe
#define RDAtlantisWorldPreferences Probe
@interface Probe : NSObject {
@public
    id _rdWorlds;
}
@property BOOL hasInstance;
@property NSUInteger savedLookups;
@end
@implementation Probe
- (id)connectedWorld:(NSString *)name {
    return self.hasInstance && [name isEqual:@"Example"] ? self : nil;
}
- (id)configForSpawn:(NSString *)path {
    return [@[@"", @"Chat", @"Chat:Guild"] containsObject:path] ? self : nil;
}
- (unsigned)weight { return 7; }
- (id)worldForName:(NSString *)name { self.savedLookups++; return self; }
- (id)preferenceForKey:(NSString *)key withCharacter:(id)character fallback:(BOOL)fallback { return @9; }
METHOD
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        probe->_rdWorlds = probe;
        WidePath *wide = [[[WidePath alloc] init] autorelease];
        for (NSNumber *hasInstance in @[@NO, @YES]) {
            probe.hasInstance = hasInstance.boolValue;
            for (id path in @[@"Example", @"Example:Chat", @"Example:Chat:Guild", @"Example:Missing", wide])
                printf("%u\n", [probe weightForView:path]);
        }
        printf("%lu\n", (unsigned long)probe.savedLookups);
        [probe release];
    }
}
'''


class ViewWeightRangeTests(unittest.TestCase):
    def test_existing_weight_choices_and_full_width_path_split(self):
        method = re.search(
            r"^- \(unsigned\) weightForView:.*?^}", SOURCE.read_text(), re.M | re.S
        )[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-view-weight.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["0"] * 5 + ["7", "7", "7", "0", "7", "0"])


if __name__ == "__main__":
    unittest.main()
