"""Verify description branches use the full action count."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


ROOT = Path(__file__).resolve().parents[2]
PROBE = r'''
#import <Foundation/Foundation.h>

@protocol EventActionProtocol
- (NSString *)actionDescription;
@end

@interface Action : NSObject <EventActionProtocol>
@property (copy) NSString *actionDescription;
@end
@implementation Action
@end

@interface Actions : NSObject
@property NSUInteger count;
@property (retain) NSArray *items;
@end
@implementation Actions
- (id)objectAtIndex:(NSUInteger)index { return [self.items objectAtIndex:index]; }
- (NSEnumerator *)objectEnumerator { return [self.items objectEnumerator]; }
@end

@interface Probe : NSObject {
@public
    Actions *_rdActions;
}
@end
@implementation Probe
METHOD
@end

int main(void) {
    @autoreleasepool {
        Probe *probe = [Probe new];
        Actions *actions = [Actions new];
        Action *first = [Action new], *second = [Action new];
        first.actionDescription = @"First.";
        second.actionDescription = @"Second.";
        probe->_rdActions = actions;
        actions.items = @[first, second];
        for (NSNumber *count in @[@0, @1, @2, @4294967296ULL, @4294967297ULL]) {
            actions.count = count.unsignedIntegerValue;
            puts([[probe eventDescription] UTF8String]);
        }
        [first release];
        [second release];
        [actions release];
        [probe release];
    }
}
'''


class EventDescriptionCountTests(unittest.TestCase):
    def test_empty_single_and_multi_action_descriptions(self):
        for filename in ("Command System/AliasEvent.m", "Hotkey System/HotkeyEvent.m"):
            with self.subTest(filename=filename), tempfile.TemporaryDirectory(prefix="atlantis-event-description.") as temp:
                source = (ROOT / filename).read_text()
                method = re.search(r"^- \(NSString \*\) eventDescription\n\{.*?^}", source, re.M | re.S)[0]
                path = Path(temp) / "probe.m"
                path.write_text(PROBE.replace("METHOD", method))
                binary = path.with_suffix("")
                subprocess.run(["xcrun", "clang", "-framework", "Foundation", str(path), "-o", str(binary)], check=True)
                lines = subprocess.check_output([binary], text=True).splitlines()
                self.assertEqual(lines, ["<< No Actions Set >>", "First."] + ["First, then Second."] * 3)


if __name__ == "__main__":
    unittest.main()
