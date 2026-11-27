#import "Core/AtlantisProfile.h"
#import "Worlds/AddressBook.h"
#import "Worlds/WorldCollection.h"
#import "Worlds/RDAtlantisWorldPreferences.h"

// Objective-C APIs used by the Swift spawn implementation.
#import "Worlds/Spawn/RDAtlantisSpawnInterop.h"

#import "Preferences/Application/AtlantisPreferencePane.h"
#import "Core/RDAtlantisApplication.h"
#import <Lemuria/RDNestedSourceView.h>
#import <Lemuria/RDNestedTabBarView.h>
#import <Lemuria/RDNestedOutlineView.h>
#import "Preferences/World/WorldConfigurationEditor.h"
#import "Preferences/World/WorldFormattingEditor.h"
#import "Preferences/World/WorldHighlightEditor.h"
#import "Preferences/World/WorldUserconfEditor.h"

// The zero-argument legacy initializer is distinct from NSObject's init.
static inline WorldConfigurationEditor *RDCreateGlobalWorldConfigurationEditor(void) NS_RETURNS_RETAINED;
static inline WorldConfigurationEditor *RDCreateGlobalWorldConfigurationEditor(void)
{
    return [[WorldConfigurationEditor alloc] initWithGlobalWorld];
}

#import "Event Configuration Kit/EventEditor.h"
#import "Event System/ActionPicker.h"
#import "Event System/ActionClasses.h"
#import "Hotkey System/HotkeyCollection.h"
#import "Hotkey System/HotkeyEvent.h"
#import "Support/PTHotKeysLib/PTKeyComboPanel.h"
#import "Toolbar System/ToolbarCollection.h"

// Preserve the application singleton even though Swift imports +controller as init.
static inline RDAtlantisMainController * _Nullable RDPreferenceMainController(void)
{
    return [RDAtlantisMainController controller];
}
#import "Event System/ConditionClasses.h"
#import "Toolbar System/ToolbarUserEvent.h"

#import "Event System/Actions/Action-Notification.h"
#import "Event System/WorldEvent.h"
#import "Event System/AtlantisState.h"

#import "Scripting/ScriptingEngine.h"
#import "Scripting/LuaScriptingEngine.h"
#import "Scripting/ScriptBridge.h"
#import "Filter System/RDAnsiFilter.h"
#import "Filter System/RDTelnetFilter.h"
#import "Log System/RDHTMLLog.h"
#import "Log System/RDPlainText.h"
#import "Log System/RDFormattedText.h"
