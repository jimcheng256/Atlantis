"""Exercise Text Spawn range creation and copy/move menu selection."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event System/Actions/Action-TextSpawn.m"

PROBE = r'''
#import <AppKit/AppKit.h>
#import <assert.h>

@interface NSString (Expansion)
- (NSString *)expandWithDataIn:(id)data;
@end

@interface Fixture : NSObject
@property NSUInteger length;
@property NSInteger selection;
@property NSUInteger writes;
@end
@implementation Fixture
- (id)stringData { return self; }
- (id)data { return nil; }
- (NSString *)expandWithDataIn:(id)data { return @"destination"; }
- (NSInteger)indexOfSelectedItem { return self.selection; }
- (NSDictionary *)attributesAtIndex:(NSUInteger)index effectiveRange:(NSRange *)range {
    assert(index == 0);
    return @{};
}
- (void)addAttribute:(NSString *)name value:(id)value range:(NSRange)range {
    if ([name isEqualToString:@"RDExtraSpawns"]) {
        assert([value isEqual:@[@"destination"]]);
    } else {
        assert([name isEqualToString:@"RDExtraSpawnMove"]);
        assert([value isEqual:@(self.length > 8)]);
    }
    printf("%s %lu %lu\n", name.UTF8String, (unsigned long)range.location,
           (unsigned long)range.length);
    self.writes++;
}
@end

@interface Probe : NSObject {
@public
    NSString *_rdSpawnPath;
    NSPopUpButton *_rdCopyTextButton;
    BOOL _rdCopyText;
}
@end
@implementation Probe
EXECUTE
CHANGE
@end

int main(void) {
    @autoreleasepool {
        Fixture *fixture = [Fixture new];
        Probe *probe = [Probe new];
        probe->_rdSpawnPath = (NSString *)fixture;
        probe->_rdCopyTextButton = (NSPopUpButton *)fixture;
        for (NSNumber *selection in @[@0, @1, @(-1), @4294967296LL]) {
            fixture.selection = selection.integerValue;
            [probe copyMoveChanged:nil];
            printf("copy %d\n", probe->_rdCopyText);
        }
        for (NSNumber *length in @[@0, @8, @4294967297LL]) {
            fixture.length = length.unsignedIntegerValue;
            probe->_rdCopyText = fixture.length <= 8;
            [probe executeForState:fixture];
        }
        assert(fixture.writes == 4);
    }
}
'''


class TextSpawnIndexTests(unittest.TestCase):
    def test_copy_move_selection_and_attribute_ranges(self):
        source = SOURCE.read_text()
        execute = re.search(r"^- \(BOOL\) executeForState:.*?^}", source, re.M | re.S)[0]
        change = re.search(r"^- \(void\) copyMoveChanged:.*?^}", source, re.M | re.S)[0]
        probe = PROBE.replace("EXECUTE", execute.replace("AtlantisState *", "Fixture *"))
        probe = probe.replace("CHANGE", change)
        with tempfile.TemporaryDirectory(prefix="atlantis-text-spawn.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            self.assertEqual(subprocess.check_output([binary], text=True).splitlines(), [
                "copy 1", "copy 0", "copy 0", "copy 0",
                "RDExtraSpawns 0 8", "RDExtraSpawnMove 0 8",
                "RDExtraSpawns 0 4294967297", "RDExtraSpawnMove 0 4294967297",
            ])


if __name__ == "__main__":
    unittest.main()
