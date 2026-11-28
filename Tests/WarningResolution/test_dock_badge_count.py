"""Check the Dock badge label with synthetic active-view counts."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Core/RDAtlantisMainController.m"

PROBE = r'''
#import <AppKit/AppKit.h>

@interface Probe : NSObject
@property NSUInteger count;
@property BOOL inactiveOnly;
@property BOOL visibleOnly;
@property BOOL active;
@property BOOL visible;
@property BOOL miniaturized;
@property (copy) NSString *label;
@end
static Probe *probe;

#undef NSApp
#define NSApp probe
#define RDNestedViewManager Probe
static Probe *RDAtlantisDefaults(void) { return probe; }

@implementation Probe
+ (id)manager { return probe; }
- (id)activeViews { return self; }
- (id)dockTile { return self; }
- (id)windows { return @[self]; }
- (BOOL)isActive { return self.active; }
- (BOOL)isVisible { return self.visible; }
- (BOOL)isMiniaturized { return self.miniaturized; }
- (void)setBadgeLabel:(NSString *)label { self.label = label; }
- (BOOL)boolForKey:(NSString *)key {
    return [key isEqual:@"atlantis.badge.inactive"] ? self.inactiveOnly : self.visibleOnly;
}
METHOD
@end

int main(void) {
    @autoreleasepool {
        probe = [Probe new];
        for (NSNumber *count in @[@0, @7, @99, @100, @2147483648ULL, @4294967296ULL, @4294967297ULL]) {
            probe.count = count.unsignedIntegerValue;
            [probe refreshBadge];
            puts(probe.label.UTF8String ?: "hidden");
        }
        probe.inactiveOnly = YES;
        probe.active = YES;
        [probe refreshBadge];
        puts(probe.label.UTF8String ?: "hidden");
        probe.active = NO;
        probe.visibleOnly = YES;
        probe.visible = YES;
        probe.miniaturized = YES;
        [probe refreshBadge];
        puts(probe.label.UTF8String ?: "hidden");
        probe.miniaturized = NO;
        [probe refreshBadge];
        puts(probe.label.UTF8String ?: "hidden");
        probe.label = nil;
        [probe release];
    }
}
'''


class DockBadgeCountTests(unittest.TestCase):
    def test_full_width_badge_and_visibility_rules(self):
        method = re.search(r"^- \(void\) refreshBadge.*?^}", SOURCE.read_text(), re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-dock-badge.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["hidden", "7", "99", "99+", "99+", "99+", "99+",
                                 "hidden", "hidden", "99+"])


if __name__ == "__main__":
    unittest.main()
