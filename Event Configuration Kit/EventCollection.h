//
//  EventCollection.h
//  LemuriaTestbed
//
//  Created by Rachel Blackman on 2/25/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@protocol EventDataProtocol;

@interface EventCollection : NSObject <NSCoding> {

    NSMutableArray                  *_rdEvents;

}

- (void) addEvent:(id <EventDataProtocol>) event;
- (void) removeEvent:(id <EventDataProtocol>) event;
- (void) moveEvent:(id <EventDataProtocol>)event toIndex:(NSUInteger) index;


- (NSInteger) eventsCount;
- (NSArray *) events;

- (id <EventDataProtocol>) eventAtIndex:(NSUInteger) index;
- (NSUInteger) indexOfEvent:(id <EventDataProtocol>) event;

@end
