#import <Cocoa/Cocoa.h>
#import <Lemuria/Lemuria.h>
#import <Lemuria/RBSplitView.h>
#import "../RDAtlantisWorldInstance.h"
#import "../ImageBackgroundView.h"
#import "../../Core/RDAtlantisMainController.h"
#import "../../Misc/RDAtlantisTextInputView.h"

NS_ASSUME_NONNULL_BEGIN

BOOL RDSpawnStatusBarAtBottom(void);
RDNestedViewManager *RDSpawnViewManager(void);
NSArray *RDSpawnScrollback(RDTextView *output);
void RDSpawnSortDescriptors(NSMutableArray *descriptors);
void RDSpawnConfigureDivider(RBSplitView *split, NSImage * _Nullable dimple, NSImage * _Nullable background);

NS_ASSUME_NONNULL_END
