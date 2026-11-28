"""Check the native-width count contracts for both event class registries."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]


class RegistryCountTests(unittest.TestCase):
    def test_registry_counts_preserve_collection_width(self):
        for registry, selector in (
            ("ActionClasses", "actionClassCount"),
            ("ConditionClasses", "conditionClassCount"),
        ):
            with self.subTest(registry=registry):
                source = ROOT / "Event System" / f"{registry}.m"
                method = re.search(
                    rf"^- \(\w+\) {selector}.*?^}}", source.read_text(), re.M | re.S
                )[0]
                probe = f'''
#import <Foundation/Foundation.h>
#import "{registry}.h"
#import <objc/runtime.h>

@interface SyntheticCollection : NSObject
@property NSUInteger count;
@end
@implementation SyntheticCollection
@end

@implementation {registry}
{method}
@end

int main(void) {{
    @autoreleasepool {{
        {registry} *registry = [{registry} new];
        SyntheticCollection *collection = [SyntheticCollection new];
        object_setIvar(registry, class_getInstanceVariable([{registry} class], "_rdClasses"), collection);
        NSMethodSignature *signature = [registry methodSignatureForSelector:@selector({selector})];
        printf("%zu\\n", signature.methodReturnLength);
        for (NSNumber *value in @[@0, @7, @4294967297ULL]) {{
            collection.count = value.unsignedIntegerValue;
            printf("%lu\\n", (unsigned long)[registry {selector}]);
        }}
        object_setIvar(registry, class_getInstanceVariable([{registry} class], "_rdClasses"), nil);
        [collection release];
        [registry release];
    }}
}}
'''
                with tempfile.TemporaryDirectory(prefix="atlantis-registry-count.") as temp:
                    path = Path(temp) / "probe.m"
                    path.write_text(probe)
                    binary = path.with_suffix("")
                    subprocess.run(
                        ["xcrun", "clang", "-Wno-incomplete-implementation", "-framework", "Foundation",
                         "-I", str(source.parent), "-I", str(ROOT / "Event Configuration Kit"), str(path), "-o", str(binary)],
                        check=True,
                    )
                    observed = subprocess.check_output([binary], text=True).splitlines()
                self.assertEqual(observed, ["8", "0", "7", "4294967297"])


if __name__ == "__main__":
    unittest.main()
