"""Check that quitting with connected worlds requires explicit confirmation."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Core/RDAtlantisMainController.m"

PROBE = r'''
#import <AppKit/AppKit.h>

static NSModalResponse response;
static NSString *cancelKey;
static int modalRuns;

@interface FakeAlert : NSObject
+ (instancetype)alertWithMessageText:(id)title defaultButton:(id)accept
                    alternateButton:(id)cancel otherButton:(id)other
          informativeTextWithFormat:(id)message;
@end
@implementation FakeAlert
+ (instancetype)alertWithMessageText:(id)title defaultButton:(id)accept
                    alternateButton:(id)cancel otherButton:(id)other
          informativeTextWithFormat:(id)message {
    NSCAssert([accept isEqual:@"Quit"] && [cancel isEqual:@"Don't Quit"], @"legacy button order");
    return [[[self alloc] init] autorelease];
}
- (NSArray *)buttons { return @[self, self]; }
- (void)setKeyEquivalent:(NSString *)key { cancelKey = key; }
- (NSModalResponse)runModal { modalRuns++; return response; }
@end

@interface Probe : NSObject
@property BOOL connected;
@property int saves;
@property int disconnects;
@end
static Probe *controller;

#define NSAlert FakeAlert
#define RDAtlantisMainController Probe
@implementation Probe
+ (instancetype)controller { return controller; }
- (BOOL)worldsAreConnected { return self.connected; }
- (void)saveAllData { self.saves++; }
- (void)disconnectAllWorlds { self.disconnects++; }
METHOD
@end

int main(void) {
    @autoreleasepool {
        controller = [Probe new];
        for (NSNumber *connected in @[@NO, @YES]) {
            for (NSNumber *result in @[@(NSAlertDefaultReturn), @(NSAlertAlternateReturn),
                                        @(NSAlertErrorReturn), @(NSModalResponseAbort),
                                        @4294967297LL, @4294967296LL]) {
                response = result.integerValue;
                modalRuns = 0;
                controller.connected = connected.boolValue;
                controller.saves = 0;
                controller.disconnects = 0;
                NSApplicationTerminateReply reply = [controller applicationShouldTerminate:nil];
                printf("%d %d %d %d\n", reply == NSTerminateNow,
                       controller.saves, controller.disconnects, modalRuns);
            }
        }
        NSCAssert([cancelKey isEqual:@"\e"], @"Escape cancels");
        [controller release];
    }
}
'''


class QuitConfirmationTests(unittest.TestCase):
    def test_only_explicit_quit_disconnects_worlds(self):
        method = re.search(
            r"^- \(NSApplicationTerminateReply\)applicationShouldTerminate:.*?^}",
            SOURCE.read_text(), re.M | re.S,
        )[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-quit-probe.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "AppKit",
                 str(path), "-o", str(binary)],
                check=True,
            )
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["1 1 0 0"] * 6 + ["1 1 1 1"] + ["0 1 0 1"] * 5)


if __name__ == "__main__":
    unittest.main()
