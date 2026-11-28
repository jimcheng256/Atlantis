"""Exercise the startup reset guard with disposable preferences."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Core/RDAtlantisMainController.m"

PROBE = r'''
#import <Foundation/Foundation.h>

static NSUserDefaults *prefs;
static BOOL profile;
static NSUserDefaults *RDAtlantisDefaults(void) { return prefs; }
static BOOL RDAtlantisHasProfile(void) { return profile; }

static BOOL requestsReset(void) {
    GUARD
    return NO;
}

int main(void) {
    @autoreleasepool {
        NSString *suite = [@"atlantis-version-probe." stringByAppendingString:[[NSUUID UUID] UUIDString]];
        prefs = [[NSUserDefaults alloc] initWithSuiteName:suite];
        [prefs setObject:@"present" forKey:@"existing-setting"];
        for (NSNumber *hasProfile in @[@NO, @YES]) {
            profile = hasProfile.boolValue;
            for (id version in @[[NSNull null], @0, @106, @2147483648LL, @4294967296LL]) {
                if (version == [NSNull null])
                    [prefs removeObjectForKey:@"RDAtlantisVersion"];
                else
                    [prefs setInteger:[version integerValue] forKey:@"RDAtlantisVersion"];
                printf("%d\n", requestsReset());
            }
        }
        [prefs removePersistentDomainForName:suite];
        [prefs release];
    }
}
'''


class StartupVersionTests(unittest.TestCase):
    def test_only_zero_in_standard_defaults_requests_reset(self):
        guard = re.search(
            r'^    (?:int|NSInteger) lastVersion = .*?\n'
            r'    if \(lastVersion == 0 && !RDAtlantisHasProfile\(\)\) \{',
            SOURCE.read_text(), re.M,
        )[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-version-probe.") as temp:
            source = Path(temp) / "probe.m"
            source.write_text(PROBE.replace("GUARD", guard + "\n        return YES;\n    }"))
            binary = source.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(source), "-o", str(binary)],
                           check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["1", "1", "0", "0", "0"] + ["0"] * 5)


if __name__ == "__main__":
    unittest.main()
