"""Verify the open-spawn count includes the main spawn at native width."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Worlds/RDAtlantisWorldInstance.m"
PROBE = r'''
#import <Foundation/Foundation.h>

@interface SpawnCollection : NSObject
@property NSUInteger count;
@end
@implementation SpawnCollection
@end

@interface Probe : NSObject {
@public
    SpawnCollection *_rdSpawns;
}
DECLARATION
@end
@implementation Probe
METHOD
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        SpawnCollection *spawns = [SpawnCollection new];
        probe->_rdSpawns = spawns;
        for (NSNumber *count in @[@0, @3, @4294967295ULL, @4294967296ULL]) {
            spawns.count = count.unsignedIntegerValue;
            printf("%lu\n", (unsigned long)[probe countOpenSpawns]);
        }
        [spawns release];
        [probe release];
    }
}
'''


class OpenSpawnCountTests(unittest.TestCase):
    def test_count_includes_main_spawn_without_truncating(self):
        signature = r"^- \([^\n]+\) countOpenSpawns"
        declaration = re.search(signature + r";", SOURCE.with_suffix(".h").read_text(), re.M)[0]
        method = re.search(signature + r"\n\{.*?^}", SOURCE.read_text(), re.M | re.S)[0]
        with tempfile.TemporaryDirectory(prefix="atlantis-open-spawn-count.") as temp:
            path = Path(temp) / "probe.m"
            path.write_text(PROBE.replace("DECLARATION", declaration).replace("METHOD", method))
            binary = path.with_suffix("")
            subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(path), "-o", str(binary)], check=True)
            lines = subprocess.check_output([binary], text=True).splitlines()
        self.assertEqual(lines, ["1", "4", "4294967296", "4294967297"])


if __name__ == "__main__":
    unittest.main()
