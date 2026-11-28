//
//  StackedCommand.m
//  Atlantis
//
//  Created by Rachel Blackman on 4/5/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "StackedCommand.h"
#import "AtlantisState.h"
#import "RDAtlantisWorldInstance.h"
#include <limits.h>

static int AppendStackedCommandDigit(int repeats, int digit)
{
    if (repeats > (INT_MAX - digit) / 10)
        return INT_MAX;
    return repeats * 10 + digit;
}

@implementation StackedCommand

- (NSString *) checkOptionsForState:(AtlantisState *) state
{
    NSDictionary *commandParams = [state extraDataForKey:@"RDCommandParams"];
    
    NSString *target = [commandParams objectForKey:@"RDOptsMainData"];
    
    if (!target) {
        return @"StackedCommand expects a parameter!";
    }
    else if ([commandParams count] > 2) {
        return @"StackedCommand expects only one parameter!";
    }
    
    return nil;
}

- (void) executeForState:(AtlantisState *) state
{
    NSDictionary *commandParams = [state extraDataForKey:@"RDCommandParams"];    
    NSString *stack = [commandParams objectForKey:@"RDOptsMainData"];

    [[state world] outputStatus:[NSString stringWithFormat:@"Executing stacked command: %@", stack] toSpawn:[state spawnPath]];

    NSUInteger position = 0;
    NSUInteger lastmark = 0;
    int repeats = 0;
    BOOL inCommand = NO;
    NSString *command;
    NSUInteger length = [stack length];
    NSCharacterSet *digitSet = [NSCharacterSet characterSetWithCharactersInString:@"1234567890"];
    
    while (position < length) {
    
        unichar curChar = [stack characterAtIndex:position];
    
        if (!inCommand) {
            if ([digitSet characterIsMember:curChar]) {
                repeats = AppendStackedCommandDigit(repeats, curChar - '0');
            }
            else {
                lastmark = position;
                inCommand = YES;
            }
        }
        else {
            if ([digitSet characterIsMember:curChar]) {
                command = [stack substringWithRange:NSMakeRange(lastmark,position - lastmark)];

                int loop = 0;
                for (loop = 0; loop < repeats; loop++)
                    [[state world] sendString:command];
                    
                repeats = [[NSString stringWithCharacters:&curChar length:1] intValue];
                inCommand = NO;
            }
        }
    
        position++;
    }
    
    if (inCommand) {
        command = [stack substringWithRange:NSMakeRange(lastmark,position - lastmark)];
        
        int loop = 0;
        for (loop = 0; loop < repeats; loop++)
            [[state world] sendString:command];
        
    }
    
}


@end
