"""Exercise the Event Editor's tab restoration with AppKit's missing index."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"

FIXTURE = r'''

#import <AppKit/AppKit.h>
#import "EventDataProtocol.h"
@interface Event : NSObject
@property BOOL supportsConditions;
@end
@implementation Event
- (BOOL)eventSupportsConditions { return self.supportsConditions; }
@end
@interface Editor : NSObject {
@public NSTabView *_rdTabView;
        NSTabViewItem *_rdCondItem;
        NSTableView *_rdTableView;
}
@end
@implementation Editor
'''

DRIVER = r'''
@end
int main(void) {
    @autoreleasepool {
        Editor *editor = [Editor new];
        NSTabView *tabs = [[NSTabView alloc] initWithFrame:NSZeroRect];
        NSTabViewItem *conditions = [[NSTabViewItem alloc] initWithIdentifier:@"eventConds"];
        [tabs addTabViewItem:conditions];
        editor->_rdTabView = tabs;
        editor->_rdCondItem = conditions;
        Event *event = [Event new];
        [editor setForEventType:(id)event];
        printf("%ld %d\n", (long)tabs.numberOfTabViewItems, tabs.tabViewType == NSNoTabsNoBorder);
        event.supportsConditions = YES;
        [editor setForEventType:(id)event];
        printf("%ld %d\n", (long)tabs.numberOfTabViewItems, tabs.tabViewType == NSTopTabsBezelBorder);
    }
}
'''


class EventTabIndexTests(unittest.TestCase):
    def test_tab_returns_when_event_supports_conditions(self):
        method = re.search(
            r"^- \(void\) setForEventType:.*?^}", SOURCE.read_text(), re.M | re.S
        )
        if method is None:
            self.fail("Could not find the Event Editor's event type setter")
        with tempfile.TemporaryDirectory(prefix="atlantis-event-tabs.") as temp:
            source = Path(temp) / "probe.m"
            source.write_text(FIXTURE + method[0] + DRIVER)
            executable = source.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-framework", "AppKit", "-I", str(SOURCE.parent),
                 str(source), "-o", str(executable)],
                check=True,
            )
            self.assertEqual(subprocess.check_output([executable], text=True), "0 1\n1 1\n")


if __name__ == "__main__":
    unittest.main()
