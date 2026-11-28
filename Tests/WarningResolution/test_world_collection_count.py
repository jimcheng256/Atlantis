"""Verify the world collection count and its startup empty check."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Worlds/WorldCollection.m"
PROBE = r'''
@interface SyntheticWorlds : NSObject
@property NSUInteger count;
@end
@implementation SyntheticWorlds
@end

static BOOL seeded;
@implementation WorldCollection
- (void)sortWorlds {}
- (void)addDefaultWorlds { seeded = YES; }
METHODS
@end

@interface Probe : WorldCollection
- (void)setWorlds:(SyntheticWorlds *)worlds path:(NSString *)path;
@end
@implementation Probe
- (void)setWorlds:(SyntheticWorlds *)worlds path:(NSString *)path {
    _rdWorlds = (NSMutableArray *)worlds;
    _worldDirectory = path;
}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        SyntheticWorlds *worlds = [SyntheticWorlds new];
        [probe setWorlds:worlds path:[NSString stringWithUTF8String:argv[1]]];
        NSMethodSignature *signature = [probe methodSignatureForSelector:@selector(count)];
        printf("%zu\n", signature.methodReturnLength);
        for (NSNumber *count in @[@0, @7, @4294967296ULL, @4294967297ULL]) {
            worlds.count = count.unsignedIntegerValue;
            seeded = NO;
            [probe loadAllWorlds];
            printf("%lu %d\n", (unsigned long)[probe count], seeded);
        }
        [worlds release];
        [probe release];
    }
}
'''


class WorldCollectionCountTests(unittest.TestCase):
    def test_count_and_default_seeding_use_native_width(self):
        source = SOURCE.read_text()
        methods = [
            re.search(pattern, source, re.M | re.S)[0]
            for pattern in (r"^- \(\w+\) count\n\{.*?^}", r"^- \(void\) loadAllWorlds\n\{.*?^}")
        ]
        with tempfile.TemporaryDirectory(prefix="atlantis-world-count.") as temp:
            path = Path(temp) / "probe.m"
            worlds = Path(temp) / "worlds"
            worlds.mkdir()
            path.write_text(SOURCE.with_suffix(".h").read_text() + PROBE.replace("METHODS", "\n".join(methods)))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", "-Wno-incomplete-implementation",
                            "-Wno-deprecated-declarations", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary, worlds], text=True).splitlines()
        self.assertEqual(lines, ["8", "0 1", "7 0", "4294967296 0", "4294967297 0"])


if __name__ == "__main__":
    unittest.main()
