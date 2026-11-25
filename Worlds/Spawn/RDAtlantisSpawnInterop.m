#import "RDAtlantisSpawnInterop.h"

extern NSInteger compareViews(id view1, id view2, void *context);

BOOL RDSpawnStatusBarAtBottom(void)
{
    return [[RDAtlantisMainController controller] statusBarBottom];
}

RDNestedViewManager *RDSpawnViewManager(void)
{
    return [RDNestedViewManager manager];
}

NSArray *RDSpawnScrollback(RDTextView *output)
{
    return [[output textStorage] paragraphs];
}

void RDSpawnSortDescriptors(NSMutableArray *descriptors)
{
    [descriptors sortUsingFunction:compareViews context:NULL];
}

void RDSpawnConfigureDivider(RBSplitView *split, NSImage *dimple, NSImage *background)
{
    [split setDivider:dimple];
    [background setFlipped:YES];
    [split setDividerBackground:background];
    [split setDividerThickness:8];
}
