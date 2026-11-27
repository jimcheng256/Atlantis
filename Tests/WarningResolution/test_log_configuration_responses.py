"""Check log configuration modal responses at their native AppKit width."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


LOG_SYSTEM = Path(__file__).resolve().parents[2] / "Log System"
PROBE = r'''
#import <AppKit/AppKit.h>

@interface Modal : NSObject
@property NSModalResponse response;
- (NSModalResponse)runModalForWindow:(NSWindow *)window;
@end
@implementation Modal
- (NSModalResponse)runModalForWindow:(NSWindow *)window { return self.response; }
@end

#undef NSApp
#define NSApp modal
static Modal *modal;

@interface Probe : NSObject {
    NSWindow *_rdConfigWindow;
    NSTextField *_rdIndentField, *_rdCharactersField;
    NSButton *_rdWordWrap, *_rdSkipLines, *_rdCondenseLines;
}
@end

@implementation Probe
- (NSDictionary *)currentConfigurationState { return @{@"html": @YES}; }
- (NSDictionary *)formatted:(NSDictionary *)oldOptions {
    NSNumber *indentBy, *wrapAt, *wordWrap, *skipLines, *condenseLines;
    FORMATTED
}
- (NSDictionary *)html:(NSDictionary *)oldOptions {
    HTML
}
@end

int main(void) {
    @autoreleasepool {
        modal = [[[Modal alloc] init] autorelease];
        Probe *probe = [[[Probe alloc] init] autorelease];
        NSDictionary *oldOptions = @{@"old": @YES};
        for (NSNumber *rawResponse in @[@1, @0, @(-1001), @4294967297LL, @(-4294967295LL)]) {
            modal.response = rawResponse.integerValue;
            printf("%d %d\n", [probe formatted:oldOptions] != oldOptions,
                   [probe html:oldOptions] != oldOptions);
        }
    }
}
'''


class LogConfigurationResponseTests(unittest.TestCase):
    def test_only_exact_accept_response_replaces_options(self):
        probe = PROBE
        for token, filename in (("FORMATTED", "RDFormattedText.m"), ("HTML", "RDHTMLLog.m")):
            code = re.search(
                r"^[^\n]*result = \[NSApp runModalForWindow:_rdConfigWindow\];.*?return results;",
                (LOG_SYSTEM / filename).read_text(), re.M | re.S,
            )
            self.assertIsNotNone(code)
            probe = probe.replace(token, code[0])
        with tempfile.TemporaryDirectory(prefix="atlantis-log-modal.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(probe)
            binary = path.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-framework", "AppKit", str(path), "-o", str(binary)],
                check=True,
            )
            observed = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(observed, ["1 1", "0 0", "0 0", "0 0", "0 0"])


if __name__ == "__main__":
    unittest.main()
