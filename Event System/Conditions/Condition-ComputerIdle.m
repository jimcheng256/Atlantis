//
//  Condition-ComputerIdle.m
//  Atlantis
//
//  Created by Rachel Blackman on 4/10/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "Condition-ComputerIdle.h"
#import "HIDIdleTime.h"

@implementation Condition_ComputerIdle

+ (NSString *) conditionName
{
    // TODO: Localize
    return @"Computer: System has been idle for at least ...";
}

+ (NSString *) conditionDescription
{
    // TODO: Localize
    return @"Execute this event when the computer has been idle and unused for the given number of seconds.";
}

- (NSString *) conditionDescription
{
    NSString *string = [[NSString stringWithFormat:@"Computer has been idle %@ seconds.", @(_rdInterval)] retain];
    
    return [string autorelease];
}

- (id) init
{
    self = [super init];
    if (self) {
        _rdInterval = 600;
    }
    return self;
}

- (id) initWithCoder:(NSCoder *) coder
{
    self = [super initWithCoder:coder];
    if (self) {
        _rdInterval = [coder decodeDoubleForKey:@"idle.interval"];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
    [super encodeWithCoder:coder];
    [coder encodeDouble:_rdInterval forKey:@"idle.interval"];
}

#pragma mark Execution

- (BOOL) isTrueForState:(AtlantisState *) state
{
    HIDIdleTime *reader = [[HIDIdleTime alloc] init];
    uint64_t nanoseconds = 0;
    BOOL read = [reader readIdleTime:&nanoseconds];
    [reader release];

    return read && nanoseconds / 1000000000.0 >= _rdInterval;
}

#pragma mark Configuration

- (void) controlTextDidEndEditing:(NSNotification *) notification
{
    _rdInterval = [_rdActualText doubleValue];
}


- (NSView *) conditionConfigurationView
{
    if (!_rdInternalConfigurationView) {
        [NSBundle loadNibNamed:@"CondConf_ComputerIdle" owner:self];
    }

    [_rdActualText setDelegate:self];
    [_rdActualText setDoubleValue:_rdInterval];
    
    return _rdInternalConfigurationView;
}

@end
