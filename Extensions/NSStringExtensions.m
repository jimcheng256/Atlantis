//
//  NSStringExtensions.m
//  Atlantis
//
//  Created by Rachel Blackman on 2/14/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "NSStringExtensions.h"
#import "RDAtlantisMainController.h"

@implementation NSString (RDStringSubstitution)

#define optionParseNone             0
#define optionParseArgName          1
#define optionParseArgVal           2
#define optionParseMain             3

- (NSDictionary *) optionsFromString
{
    NSMutableDictionary *options = [[NSMutableDictionary alloc] init];
    
    unsigned position = 0;
    int state = optionParseNone;
    BOOL inQuote = NO;
    BOOL cantQuote = NO;
    unsigned lastMarker = 0;
    NSString *argName = nil;
    
    [options setObject:self forKey:@"RDOptsFullString"];
    
    while (position < [self length]) {
        unichar curChar = [self characterAtIndex:position];
        
        switch (state) {

            case optionParseNone:
                if (curChar == '-') {
                    lastMarker = position;
                    state = optionParseArgName;
                }
                else if (!isspace(curChar)) {
                    state = optionParseMain;
                    lastMarker = position;
                }
                break;
                
            case optionParseArgName:
                if (curChar == '-') {
                    lastMarker = position;
                }
                else if (isspace(curChar) || (curChar == '=')) {
                    argName = [self substringWithRange:NSMakeRange(lastMarker + 1,position - lastMarker - 1)];
                    state = optionParseArgVal;
                    cantQuote = NO;
                }
                break;
                
            case optionParseArgVal:
                if (!cantQuote) {
                    if (curChar == '"') {
                        inQuote = YES;
                        cantQuote = YES;
                        lastMarker = position;
                    }
                    else if (curChar == '-') {
                        [options setObject:@"" forKey:argName];
                        state = optionParseArgName;
                        lastMarker = position;
                    }
                    else if (!isspace(curChar)) {
                        cantQuote = YES;
                        lastMarker = position;
                    }
                }
                else {
                    if ((!inQuote && isspace(curChar)) || (inQuote && (curChar == '"'))) {
                        NSString *argTemp;
                        
                        if (inQuote)
                            argTemp = [self substringWithRange:NSMakeRange(lastMarker + 1,position - lastMarker - 1)];
                        else
                            argTemp = [self substringWithRange:NSMakeRange(lastMarker,position - lastMarker)];
                        
                        [options setObject:argTemp forKey:argName];
                        state = optionParseNone;
                    }
                }
                break;
        }
        
        position++;        
    }
    
    if (state == optionParseArgVal) {
        NSString *argTemp = [self substringWithRange:NSMakeRange(lastMarker,position - lastMarker)];
        [options setObject:argTemp forKey:argName];
    }
    else if (state == optionParseMain) {
        NSString *argTemp = [self substringWithRange:NSMakeRange(lastMarker,position - lastMarker)];
        [options setObject:argTemp forKey:@"RDOptsMainData"];    
    }
    
    return [options autorelease]; 
}

// No known production callers in Atlantis or Lemuria. Only the warning-resolution test exercises this method.
- (NSUInteger) lineCount
{
    NSUInteger count = 1;
    NSUInteger length = [self length];
    // Ignore a newline in the final position.
    for (NSUInteger index = 1; index < length; index++) {
        if ([self characterAtIndex:index - 1] == '\n')
            count++;
    }
    return count;
}

- (NSString *) expandWithDataIn:(NSDictionary *) data
{
    NSMutableString *workString = [[NSMutableString alloc] init];
    
    NSRange testMe;
    NSUInteger pos = 0;
    NSUInteger selfLength = [self length];
    
    NSCharacterSet *endSet = [NSCharacterSet characterSetWithCharactersInString:@"}:"];
    
    while (pos < selfLength) {
        testMe = [self rangeOfString:@"%{" options:0 range:NSMakeRange(pos,selfLength - pos)];
        if (testMe.length) {
            NSRange endMark = [self rangeOfCharacterFromSet:endSet options:0 range:NSMakeRange(testMe.location,selfLength - testMe.location)];
            if (endMark.location != NSNotFound) {
                NSUInteger startPos = testMe.location + testMe.length;
                NSUInteger endPoint = endMark.location + endMark.length;
                unsigned limitLength = 0;
                NSString *varName = [self substringWithRange:NSMakeRange(startPos,endMark.location - startPos)];
            
                if ([self characterAtIndex:endMark.location] == ':') {
                    NSRange realEnd = [self rangeOfString:@"}" options:0 range:NSMakeRange(endMark.location,selfLength - endMark.location)];
                    if (realEnd.length) {
                        NSString *lengthChar = [self substringWithRange:NSMakeRange(endPoint,realEnd.location - endPoint)];
                        int parsedLimit = [lengthChar intValue];
                        if (parsedLimit < 0) {
                            NSLog(@"Atlantis warning: Negative length limit '%@' for variable '%@'. Truncation is disabled.", lengthChar, varName);
                        }
                        else {
                            limitLength = (unsigned)parsedLimit;
                        }
                        endPoint = realEnd.location + realEnd.length;
                    }
                    else {
                        [workString appendString:[self substringWithRange:NSMakeRange(pos,selfLength - pos)]];
                        return [NSString stringWithString:workString];
                    }
                }
                
                [workString appendString:[self substringWithRange:NSMakeRange(pos,testMe.location - pos)]];
                
                NSObject *keyResult = [data objectForKey:varName];
                if (!keyResult) {
                    // On the fly
                    if (([varName length] > 9) && [[varName substringToIndex:9] isEqualToString:@"datetime."]) {
                                            
                        NSString *restOfString = [varName substringFromIndex:9];
                        NSCalendarDate *rightNow = [NSCalendarDate calendarDate];
                        
                        if ([restOfString isEqualToString:@"year"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%Y"];
                        }
                        else if ([restOfString isEqualToString:@"month"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%m"];
                        }
                        else if ([restOfString isEqualToString:@"day"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%d"];
                        }
                        else if ([restOfString isEqualToString:@"hour"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%H"];
                        }
                        else if ([restOfString isEqualToString:@"minute"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%M"];
                        }
                        else if ([restOfString isEqualToString:@"second"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%S"];
                        }
                        else if ([restOfString isEqualToString:@"weekday"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%A"];
                        }
                        else if ([restOfString isEqualToString:@"weekdayshort"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%a"];                        
                        }
                        else if ([restOfString isEqualToString:@"monthname"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%B"];                        
                        }
                        else if ([restOfString isEqualToString:@"monthnameshort"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%b"];                        
                        }
                        else if ([restOfString isEqualToString:@"date"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%Y-%m-%d"];                        
                        }
                        else if ([restOfString isEqualToString:@"time"]) {
                            keyResult = [rightNow descriptionWithCalendarFormat:@"%H.%M.%S"];                        
                        }                        
                    }
                    else if (([varName length] > 8) && [[varName substringToIndex:8] isEqualToString:@"command."]) {
                        NSDictionary *commandParams = [data objectForKey:@"RDCommandParams"];    
                        NSString *cmdData = [commandParams objectForKey:@"RDOptsMainData"];
                        NSString *cmdFull = [commandParams objectForKey:@"RDOptsFullString"];                                            
                        NSString *restOfString = [varName substringFromIndex:8];
                        
                        if ([restOfString isEqualToString:@"data"]) {
                            keyResult = cmdData ? cmdData : @"";
                        }
                        else if ([restOfString isEqualToString:@"fulltext"]) {
                            keyResult = cmdFull ? cmdFull : @"";
                        }
                        else {
                            keyResult = [commandParams objectForKey:restOfString];
                            if (!keyResult || [[keyResult description] isEqualToString:@""]) {
                                keyResult = @"0";
                            }
                        }                        
                    }
                    else if (([varName length] > 7) && [[varName substringToIndex:7] isEqualToString:@"regexp."]) {
                        NSArray *regExpArray = [data objectForKey:@"RDRegexpMatchData"];
                        
                        if (regExpArray) {
                            NSString *restOfString = [varName substringFromIndex:7];
                            int offset = [restOfString intValue];
                            
                            if (offset < [regExpArray count]) {
                                keyResult = [regExpArray objectAtIndex:offset];
                            }
                        }
                        
                        if (!keyResult)
                            keyResult = @"";
                    }
                    else if ([varName hasPrefix:@"temp."]) {
                        NSString *restOfString = [varName substringFromIndex:5];
                        
                        keyResult = [[RDAtlantisMainController controller] tempStateVarForKey:restOfString];
                    }
                    else if ([varName length] > 0 && [varName length] < 5) {
                        keyResult = [[RDAtlantisMainController controller] tempStateVarForKey:varName];
                        if (keyResult) {
                            NSLog(@"Atlantis warning: Variable '%@' was not found in the supplied data. Using 'temp.%@'.", varName, varName);
                        }
                    }
                }
                
                if (keyResult) {
                    NSString *endResult = [keyResult description];
                    
                    if (limitLength && ([endResult length] > limitLength)) {
                        // The template limit counts grapheme clusters, independent of display width.
                        NSUInteger end = 0;
                        for (NSUInteger count = 0; count < limitLength && end < [endResult length]; count++) {
                            end = NSMaxRange([endResult rangeOfComposedCharacterSequenceAtIndex:end]);
                        }
                        if (end < [endResult length]) {
                            endResult = [NSString stringWithFormat:@"%@...", [endResult substringToIndex:end]];
                        }
                    }
                    [workString appendString:endResult];
                }
                else {
                    [workString appendString:[NSString stringWithFormat:@"<Unknown Variable: '%@'>", varName]];
                }
                pos = endPoint;
            }
            else {
                [workString appendString:[self substringWithRange:NSMakeRange(pos,selfLength - pos)]];
                pos = selfLength;            
            }
        }
        else {
            [workString appendString:[self substringWithRange:NSMakeRange(pos,selfLength - pos)]];
            pos = selfLength;
        }
    }
    
    return workString;
}

- (NSString *) string
{
    return self;
}


- (int) intValueFromHex
{
    int total = 0;
    
    unsigned pos = 0;
    
    const char *tempSet = "0123456789ABCDEF";
    
    while (pos < [self length]) {
        total = total * 16;
        char curchar = [[self uppercaseString] characterAtIndex:pos];
        
        char *tval = index(tempSet,curchar);
        if (tval) {
            int val = (int)(tval - tempSet);
            
            total += val;
        }
        pos++;
    }
    
    return total;
}

@end

