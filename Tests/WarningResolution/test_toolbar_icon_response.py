"""Verify the toolbar icon picker accepts only the exact AppKit OK response."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Toolbar System/ToolbarUserEvent.m"
PROBE = r'''
#import <AppKit/AppKit.h>

static NSModalResponse response;
static NSMutableDictionary *settings;
static NSMutableDictionary *RDAtlantisDefaults(void) { return settings; }

@interface Panel : NSObject
@end
@implementation Panel
+ (instancetype)openPanel { return [[[self alloc] init] autorelease]; }
- (void)setAllowsMultipleSelection:(BOOL)allowsMultiple {}
- (NSInteger)runModalForDirectory:(NSString *)path file:(NSString *)name { return response; }
- (NSString *)directory { return @"/selected"; }
- (NSString *)filename { return @"/selected/icon.png"; }
@end

@interface Image : NSObject
- (instancetype)initByReferencingFile:(NSString *)filename;
@end
@implementation Image
- (instancetype)initByReferencingFile:(NSString *)filename {
    NSCAssert([filename isEqualToString:@"/selected/icon.png"], @"selected path");
    return [super init];
}
@end

#define NSOpenPanel Panel
#define NSImage Image
@interface Probe : NSObject {
@public
    NSImage *_rdToolbarIcon;
    BOOL _rdDirty;
}
@end
@implementation Probe
METHOD
@end

int main(void) {
    @autoreleasepool {
        settings = [NSMutableDictionary dictionary];
        Probe *probe = [[[Probe alloc] init] autorelease];
        NSString *key = @"atlantis.image.path";
        for (NSNumber *value in @[@(NSModalResponseOK), @(NSModalResponseCancel), @(-1001),
                                  @4294967297LL, @(-4294967295LL)]) {
            response = value.integerValue;
            [settings setObject:@"/previous" forKey:key];
            [probe eventEditExtraDataHook:@"eventIcon"];
            printf("%s %d\n", [[settings objectForKey:key] UTF8String], probe->_rdToolbarIcon != nil);
            [probe->_rdToolbarIcon release];
            probe->_rdToolbarIcon = nil;
        }
    }
}
'''


class ToolbarIconResponseTests(unittest.TestCase):
    def test_only_appkit_ok_changes_the_icon_and_last_directory(self):
        method = re.search(r"^- \(void\) eventEditExtraDataHook:.*?^}", SOURCE.read_text(), re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-toolbar-icon.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["/selected 1"] + ["/previous 0"] * 4)


if __name__ == "__main__":
    unittest.main()
