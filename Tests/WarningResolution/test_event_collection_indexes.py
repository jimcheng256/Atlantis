"""Exercise the collection and editor together with synthetic wide indexes."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


KIT = Path(__file__).resolve().parents[2] / "Event Configuration Kit"

PROBE = r'''

#import <AppKit/AppKit.h>
#import <limits.h>
#import "EventDataProtocol.h"
static NSUInteger size, itemIndex;

@interface Store : NSObject
@end
@implementation Store
- (NSUInteger)count { return size; }
- (NSUInteger)indexOfObject:(id)item { return itemIndex; }
- (BOOL)containsObject:(id)item { return itemIndex != NSNotFound; }
- (id)objectAtIndex:(NSUInteger)index {
    printf("table lookup: %lu\n", (unsigned long)index);
    return nil;
}
- (void)exchangeObjectAtIndex:(NSUInteger)destination withObjectAtIndex:(NSUInteger)source {
    printf("move source: %lu destination: %lu\n", (unsigned long)source, (unsigned long)destination);
}
- (void)selectRow:(NSInteger)row byExtendingSelection:(BOOL)extend {
    printf("select: %ld\n", (long)row);
}
@end

@interface ProbeEventCollection : NSObject {
@public Store *_rdEvents;
}
@end
@implementation ProbeEventCollection
COLLECTION_METHODS
@end

@interface Editor : NSObject {
@public ProbeEventCollection *_rdEventData;
        NSTableView *_rdTableView;
}
@end
@implementation Editor
EDITOR_METHODS
@end

int main(void) {
    @autoreleasepool {
        Store *store = [Store new];
        ProbeEventCollection *collection = [ProbeEventCollection new];
        collection->_rdEvents = store;
        Editor *editor = [Editor new];
        editor->_rdEventData = collection;
        editor->_rdTableView = (NSTableView *)store;
        size = (NSUInteger)INT_MAX + 1;
        printf("count at INT_MAX + 1: %ld\n", (long)[collection eventsCount]);
        size = 2;
        itemIndex = 1;
        [editor selectEvent:nil];
        itemIndex = NSNotFound;
        [editor selectEvent:nil];
        size = (NSUInteger)UINT_MAX + 3;
        itemIndex = (NSUInteger)UINT_MAX + 2;
        [editor selectEvent:nil];
        [collection moveEvent:nil toIndex:0];
        itemIndex = 1;
        [collection moveEvent:nil toIndex:(NSUInteger)UINT_MAX + 2];
        itemIndex = (NSUInteger)UINT_MAX + 2;
        printf("requested row: %lu\n", (unsigned long)itemIndex);
        [editor tableView:editor->_rdTableView objectValueForTableColumn:nil row:(NSInteger)itemIndex];
    }
}
'''


def methods(filename, patterns):
    source = (KIT / filename).read_text()
    return "\n".join(re.search(pattern, source, re.M | re.S)[0] for pattern in patterns)


class EventCollectionIndexTests(unittest.TestCase):
    def test_collection_and_editor_preserve_wide_indexes_and_missing_events(self):
        collection = "\n".join(re.findall(
            r"^- \([^)]+\) (?:eventsCount|indexOfEvent:|moveEvent:|eventAtIndex:)[^\n]*\n\{.*?^}",
            (KIT / "EventCollection.m").read_text(), re.M | re.S,
        ))
        editor = methods("EventEditor.m", [
            r"^- \(void\) selectEvent:[^\n]*\n\{.*?^}",
            r"^- \(id\)tableView:[^\n]*objectValueForTableColumn:[^\n]*\n\{.*?^}",
        ])
        with tempfile.TemporaryDirectory(prefix="atlantis-event-collection.") as temp:
            source = Path(temp) / "probe.m"
            source.write_text(PROBE.replace("COLLECTION_METHODS", collection).replace("EDITOR_METHODS", editor))
            executable = source.with_suffix("")
            subprocess.run(
                ["xcrun", "clang", "-Wno-deprecated-declarations", "-framework", "AppKit",
                 "-I", str(KIT), str(source), "-o", str(executable)], check=True,
            )
            self.assertEqual(subprocess.check_output([executable], text=True).splitlines(), [
                "count at INT_MAX + 1: 2147483648",
                "select: 1",
                "select: 4294967297",
                "move source: 4294967297 destination: 0",
                "move source: 1 destination: 4294967297",
                "requested row: 4294967297",
                "table lookup: 4294967297",
            ])


if __name__ == "__main__":
    unittest.main()
