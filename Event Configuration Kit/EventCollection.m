//
//  EventCollection.m
//  LemuriaTestbed
//
//  Created by Rachel Blackman on 2/25/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "EventCollection.h"


@implementation EventCollection

- (id) init
{
    self = [super init];
    if (self) {
        _rdEvents = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) dealloc
{
    [_rdEvents release];
    [super dealloc];
}

- (id) initWithCoder:(NSCoder *) coder
{
    self = [super init];
    _rdEvents = [[coder decodeObjectForKey:@"events"] mutableCopy];
    if (!_rdEvents) {
        _rdEvents = [[NSMutableArray alloc] init];
    }
    return self;
}

- (void) encodeWithCoder:(NSCoder *) coder
{
    [coder encodeObject:_rdEvents forKey:@"events"];
}

- (void) addEvent:(id <EventDataProtocol>) event
{
    if (![_rdEvents containsObject:event]) {
        [_rdEvents addObject:event];
    }
}

- (void) removeEvent:(id <EventDataProtocol>) event
{
    if ([_rdEvents containsObject:event]) {
        [_rdEvents removeObject:event];
    }
}

- (id <EventDataProtocol>) eventAtIndex:(NSUInteger) index
{
    if (index < [_rdEvents count]) {
        return [_rdEvents objectAtIndex:index];
    }
    
    return nil;
}

- (void) moveEvent:(id <EventDataProtocol>)event toIndex:(NSUInteger) index
{
    NSUInteger oldIndex = [_rdEvents indexOfObject:event];
    if (oldIndex != NSNotFound && index < [_rdEvents count] && index != oldIndex) {
        [_rdEvents exchangeObjectAtIndex:index withObjectAtIndex:oldIndex];
    }
}

- (NSUInteger) indexOfEvent:(id <EventDataProtocol>) event
{
    return [_rdEvents indexOfObject:event];
}

- (NSInteger) eventsCount
{
    return (NSInteger)[_rdEvents count];
}

- (NSArray *) events
{
    return [NSArray arrayWithArray:_rdEvents];
}


@end
