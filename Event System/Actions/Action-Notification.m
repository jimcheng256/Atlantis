//
//  Action-Notification.m
//  Atlantis
//
//  Created by Rachel Blackman on 3/5/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "Action-Notification.h"
#import "Atlantis-Swift.h"
#import "NSStringExtensions.h"
#import "AtlantisState.h"
#import "RDAtlantisSpawn.h"

@implementation Action_Notification

+ (void)load
{
    // NB: Backward compatibility for legacy Growl actions; now uses native macOS.
    [NSKeyedUnarchiver setClass:self forClassName:@"Action_Growl"];
}

#pragma mark Initialization

- (id) init
{
    self = [super init];
    if (self) {
        _rdNotificationBody = nil;
        _rdNotificationTitle = nil;
    }
    return self;
}

- (id) initWithString:(NSString *) string title:(NSString *)title;
{
    self = [self init];
    if (self) {
        _rdNotificationBody = [[string copyWithZone:nil] retain];
        _rdNotificationTitle = [[title copyWithZone:nil] retain];
    }
    return self;
}

- (void) dealloc
{
    [_rdNotificationBody release];
    [_rdNotificationTitle release];
    [super dealloc];
}

- (id) initWithCoder:(NSCoder *) coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _rdNotificationBody = [[coder decodeObjectForKey:@"action.growlText"] retain];
        _rdNotificationTitle = [[coder decodeObjectForKey:@"action.growlTitle"] retain];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *) coder;
{
    [super encodeWithCoder:coder];
    if (_rdNotificationBody)
        [coder encodeObject:_rdNotificationBody forKey:@"action.growlText"];
    if (_rdNotificationTitle)
        [coder encodeObject:_rdNotificationTitle forKey:@"action.growlTitle"];
}


#pragma mark Action Implementation

+ (NSString *) actionName
{
    // TODO: Localize
    return @"Atlantis: Display Notification";
}

+ (NSString *) actionDescription
{
    // TODO: Localize
    return @"Display text to the user in Notification Center.";
}

- (NSString *) actionDescription
{
    // TODO: Localize
    NSString *result = [NSString stringWithFormat:@"Display '%@' in Notification Center.",
                        _rdNotificationBody ? _rdNotificationBody : @""];

    return result;
}

+ (NSNumber *) validForType:(AtlantisEventType) type
{
    if (type == AtlantisTypeEvent)
        return [NSNumber numberWithBool:YES];

    return [NSNumber numberWithBool:NO];
}

- (BOOL) executeForState:(AtlantisState *) state
{
    NSString *realTitle = [_rdNotificationTitle expandWithDataIn:[state data]];
    NSString *realText = [_rdNotificationBody expandWithDataIn:[state data]];

    [AtlantisNotifications postWithTitle:realTitle
                                   body:realText
                              spawnPath:[[state spawn] viewPath]];

    return NO;
}

#pragma mark Configuration Glue

- (NSView *) actionConfigurationView
{
    if (!_rdInternalConfigurationView) {
        [NSBundle loadNibNamed:@"ActionConf_Notification" owner:self];
    }

    [_rdActualText setDelegate:self];
    [_rdTitleText setDelegate:self];

    if (_rdNotificationBody)
        [_rdActualText setStringValue:_rdNotificationBody];
    else
        [_rdActualText setStringValue:@""];

    if (_rdNotificationTitle)
        [_rdTitleText setStringValue:_rdNotificationTitle];
    else
        [_rdTitleText setStringValue:@""];


    return _rdInternalConfigurationView;
}

- (void) controlTextDidEndEditing:(NSNotification *) notification
{
    if ([notification object] == _rdActualText) {
        [_rdNotificationBody release];
        _rdNotificationBody = [[_rdActualText stringValue] retain];
    }
    else if ([notification object] == _rdTitleText) {
        [_rdNotificationTitle release];
        _rdNotificationTitle = [[_rdTitleText stringValue] retain];
    }
}

@end
