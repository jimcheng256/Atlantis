"""Exercise selected-row bounds and condition mode in the Event Editor."""

from pathlib import Path
import re
import subprocess
import tempfile
import unittest


SOURCE = Path(__file__).resolve().parents[2] / "Event Configuration Kit/EventEditor.m"

FIXTURE = r'''
#import <AppKit/AppKit.h>
#import <objc/runtime.h>
#import "EventCollection.h"
#import "EventDataProtocol.h"

typedef NSObject BaseAction;
typedef NSObject BaseCondition;
static NSImage *s_upArrow, *s_downArrow;

@interface RDAtlantisConditionItem : NSView
@end
@implementation RDAtlantisConditionItem
@end
@interface RDAtlantisActionItem : NSView
@end
@implementation RDAtlantisActionItem
@end
@interface RDChainedListButton : NSObject
@end
@implementation RDChainedListButton
@end
@interface RemovalConfirmation : NSObject
+ (void)presentForWindow:(NSWindow *)window itemType:(NSString *)type
                itemName:(NSString *)name onConfirm:(void (^)(void))confirm;
@end

static NSInteger row, mode;

@interface Fixture : NSObject
@end
@implementation Fixture
- (NSInteger)selectedRow { return row; }
- (NSInteger)indexOfSelectedItem { return mode; }
- (NSInteger)eventsCount { return 2; }
- (id)eventAtIndex:(NSUInteger)index {
    printf("event %lu\n", (unsigned long)index);
    return index < 2 ? self : nil;
}
- (BOOL)eventSupportsConditions { return YES; }
- (BOOL)eventConditionsAnded { return YES; }
- (void)eventSetConditionsAnded:(BOOL)anded { printf("anded %d\n", (int)anded); }
- (NSArray *)eventConditions { return nil; }
- (NSArray *)eventActions { return nil; }
- (void)newConditionPicked:(id)item context:(id)event { puts("add condition"); [item release]; }
- (void)newActionPicked:(id)item context:(id)event { puts("add action"); [item release]; }
- (void)removeEvent:(id)event { puts("remove"); }
- (void)removeAllItems { puts("clear"); }
- (void)setNeedsDisplay:(BOOL)display {}
- (void)selectItemAtIndex:(NSInteger)index {}
- (NSWindow *)window { return nil; }
- (void)reloadData {}
@end

@interface Probe : NSObject {
@public
    NSTableView *_rdTableView;
    EventCollection *_rdEventData;
    NSPopUpButton *_rdConditionType;
    id _rdDelegate, _rdConditionChainView, _rdActionChainView;
    NSTabView *_rdTabView;
    NSTabViewItem *_rdCondItem;
    NSControl *_rdRemoveActionButton, *_rdRemoveConditionButton;
}
@property BOOL confirmsEventRemoval;
- (void)moveUp:(id)sender;
- (void)moveDown:(id)sender;
@end
@implementation Probe
- (void)moveUp:(id)sender {}
- (void)moveDown:(id)sender {}
'''

DRIVER = r'''
@end
@implementation RemovalConfirmation
+ (void)presentForWindow:(NSWindow *)window itemType:(NSString *)type
                itemName:(NSString *)name onConfirm:(void (^)(void))confirm {}
@end

int main(int argc, char **argv) {
    @autoreleasepool {
        row = strtoll(argv[1], NULL, 10);
        mode = strtoll(argv[2], NULL, 10);
        Fixture *fixture = [Fixture new];
        Probe *probe = [Probe new];
        probe->_rdTableView = (NSTableView *)fixture;
        probe->_rdEventData = (EventCollection *)fixture;
        probe->_rdConditionType = (NSPopUpButton *)fixture;
        probe->_rdDelegate = fixture;
        probe->_rdConditionChainView = probe->_rdActionChainView = fixture;
        NSMenuItem *menu = [NSMenuItem new];
        menu.representedObject = [NSObject class];
        NSString *command = [NSString stringWithUTF8String:argv[3]];
        if ([command isEqualToString:@"refresh"])
            [probe resynchChainedView];
        else
            [probe performSelector:NSSelectorFromString(command) withObject:menu];
    }
}
'''


class EventSelectedRowTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        methods = re.findall(
            r"^- \(void\)\s*(?:resynchChainedView|removeEvent:|changeConditionsAnded:|addCondition:|addAction:)"
            r"[^\n]*\n\{.*?^}", SOURCE.read_text(), re.M | re.S,
        )
        if len(methods) != 5:
            raise ValueError("Expected the five Event Editor methods under test")
        temp = tempfile.TemporaryDirectory(prefix="atlantis-event-selected-rows.")
        cls.addClassCleanup(temp.cleanup)
        source = Path(temp.name) / "probe.m"
        source.write_text(FIXTURE + "\n".join(methods) + DRIVER)
        cls.exe = source.with_suffix("")
        subprocess.run(
            ["xcrun", "clang", "-Wno-objc-method-access", "-framework", "AppKit", "-I",
             str(SOURCE.parent), str(source), "-o", str(cls.exe)], check=True,
        )

    def check(self, command, row, expected, *, mode=1):
        actual = subprocess.check_output([self.exe, str(row), str(mode), command], text=True)
        self.assertEqual(actual, expected)

    def test_ordinary_selected_row(self):
        for command, result in (("addAction:", "add action"), ("addCondition:", "add condition"),
                                ("removeEvent:", "remove")):
            self.check(command, 1, f"event 1\n{result}\n")
        self.check("refresh", 1, "clear\nclear\nevent 1\n")

    def test_invalid_rows_do_not_look_up_an_event(self):
        for command in ("refresh", "removeEvent:", "changeConditionsAnded:", "addAction:", "addCondition:"):
            for row in (-1, 2, 2**32 + 1, 2**63 - 1):
                with self.subTest(command=command, row=row):
                    self.check(command, row, "clear\nclear\n" if command == "refresh" else "")

    def test_condition_mode_only_accepts_any_or_all(self):
        for mode in (0, 1, -1, 2, 2**32 + 1):
            with self.subTest(mode=mode):
                expected = f"anded {mode}\n" if mode in (0, 1) else ""
                self.check("changeConditionsAnded:", 1, f"event 1\n{expected}", mode=mode)


if __name__ == "__main__":
    unittest.main()
