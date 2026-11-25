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

// These legacy outlet ivars have no public setters.
void RDSpawnSetEditorRouting(RDAtlantisTextInputView *input, RDTextView *output, BOOL enabled)
{
    [input setValue:(enabled ? output : nil) forKey:@"passInputsTo"];
    [output setValue:(enabled ? input : nil) forKey:@"_rdRedirectFocusOnKeyTo"];
}

void RDSpawnConfigureDivider(RBSplitView *split, NSImage *dimple, NSImage *background)
{
    [split setDivider:dimple];
    [background setFlipped:YES];
    [split setDividerBackground:background];
    [split setDividerThickness:8];
}
