#import "../Core/AtlantisProfile.h"
//
//  RDFormattedText.m
//  Atlantis
//
//  Created by Rachel Blackman on 2/14/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "RDFormattedText.h"
#import "RDAtlantisWorldInstance.h"
#import "AtlantisState.h"

@implementation RDFormattedText

+ (NSString *) logtypeName
{
    // TODO: Localize
    return @"Plain Text (Formatted)";
}

+ (BOOL) canAppendToLog
{
    return YES;
}

+ (BOOL) supportsOptions
{
    return YES;
}

- (id) initWithFilename:(NSString *)filename forSpawn:(NSString *)spawnPath inWorld:(RDAtlantisWorldInstance *)world withOptions:(NSDictionary *)options
{
    self = [super initWithFilename:filename forSpawn:spawnPath inWorld:world withOptions:options];
    if (self) {
            
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

+ (NSString *) shortTypeName
{
    // TODO: Localize
    return @"Formatted Text";
}

- (NSDictionary *) defaultOptions
{
    NSDictionary *myDict;
    
    myDict = [RDAtlantisDefaults() objectForKey:@"log.formatted.defaults"];
    
    if (!myDict) {
        myDict = [NSDictionary dictionaryWithObjectsAndKeys:
                    [NSNumber numberWithInt:2],@"indent",
                    [NSNumber numberWithInt:78],@"wrapchars",
                    [NSNumber numberWithBool:YES],@"skiplines",
                    [NSNumber numberWithBool:NO],@"condenselines",
                    [NSNumber numberWithBool:YES],@"wrap", nil];
    }
    
    return myDict;
}

- (NSDictionary *) configureOptions:(NSDictionary *)oldOptions
{
    if (!_rdConfigWindow) {
        [NSBundle loadNibNamed:@"LogConf_Formatted" owner:self];
    }
    
    NSDictionary *realOptions = oldOptions;
    NSNumber *indentBy = nil;
    NSNumber *wrapAt = nil;
    NSNumber *wordWrap = nil;
    NSNumber *skipLines = nil;
    NSNumber *condenseLines = nil;
    
    if (!realOptions) {
        realOptions = [self defaultOptions]; 
    }

    indentBy = [realOptions objectForKey:@"indent"];
    wrapAt = [realOptions objectForKey:@"wrapchars"];
    wordWrap = [realOptions objectForKey:@"wrap"];
    skipLines = [realOptions objectForKey:@"skiplines"];
    condenseLines = [realOptions objectForKey:@"condenselines"];
    
    if (!indentBy)
        indentBy = [NSNumber numberWithInt:2];
    if (!wrapAt)
        wrapAt = [NSNumber numberWithInt:78];
    if (!wordWrap)
        wordWrap = [NSNumber numberWithBool:YES];
    if (!skipLines)
        skipLines = [NSNumber numberWithBool:YES];
    if (!condenseLines)
        condenseLines = [NSNumber numberWithBool:NO];
        
    if ([skipLines boolValue]) {
        [_rdSkipLines setState:NSControlStateValueOn];
        [_rdCondenseLines setEnabled:YES];
    } 
    else {
        [_rdSkipLines setState:NSControlStateValueOff];
        [_rdCondenseLines setEnabled:NO];
    }

    if ([condenseLines boolValue])
        [_rdCondenseLines setState:NSControlStateValueOn];
    else
        [_rdCondenseLines setState:NSControlStateValueOff];
        
    if ([wordWrap boolValue]) {
        [_rdWordWrap setState:NSControlStateValueOn];
        [_rdIndentField setEnabled:YES];
        [_rdCharactersField setEnabled:YES];
    }
    else {
        [_rdWordWrap setState:NSControlStateValueOff];
        [_rdIndentField setEnabled:NO];
        [_rdCharactersField setEnabled:NO];
    }
    
    [_rdIndentField setIntValue:[indentBy intValue]];
    [_rdCharactersField setIntValue:[wrapAt intValue]];
    
    int result = [NSApp runModalForWindow:_rdConfigWindow];
    
    NSDictionary *results = oldOptions;
    
    if (result == 1) {
        
        indentBy = [NSNumber numberWithInt:[_rdIndentField intValue]];
        wrapAt = [NSNumber numberWithInt:[_rdCharactersField intValue]];
        wordWrap = [NSNumber numberWithBool:([_rdWordWrap state] == NSControlStateValueOn)];
        skipLines = [NSNumber numberWithBool:([_rdSkipLines state] == NSControlStateValueOn)];
        condenseLines = [NSNumber numberWithBool:([_rdCondenseLines state] == NSControlStateValueOn)];

        results = 
            [NSDictionary dictionaryWithObjectsAndKeys:
                indentBy,@"indent",
                wrapAt,@"wrapchars",
                wordWrap,@"wrap",
                skipLines,@"skiplines", 
                condenseLines,@"condenselines",
                nil];
    }
    
    [_rdConfigWindow orderOut:self];
    
    return results;
}

- (void) wrapToggled:(id) sender
{
    if ([_rdWordWrap state] == NSControlStateValueOn) {
        [_rdIndentField setEnabled:YES];
        [_rdCharactersField setEnabled:YES];    
    }
    else {
        [_rdIndentField setEnabled:NO];
        [_rdCharactersField setEnabled:NO];    
    }
}

- (void) skipToggled:(id) sender
{
    if ([_rdSkipLines state] == NSControlStateValueOn) {
        [_rdCondenseLines setEnabled:YES];
    }
    else {
        [_rdCondenseLines setEnabled:NO];
    }
}


- (void) makeDefaults:(id) sender
{

    NSNumber *indentBy = nil;
    NSNumber *wrapAt = nil;
    NSNumber *wordWrap = nil;
    NSNumber *skipLines = nil;
    NSNumber *condenseLines = nil;

    indentBy = [NSNumber numberWithInt:[_rdIndentField intValue]];
    wrapAt = [NSNumber numberWithInt:[_rdCharactersField intValue]];
    wordWrap = [NSNumber numberWithBool:([_rdWordWrap state] == NSControlStateValueOn)];
    skipLines = [NSNumber numberWithBool:([_rdSkipLines state] == NSControlStateValueOn)];
    condenseLines = [NSNumber numberWithBool:([_rdCondenseLines state] == NSControlStateValueOn)];
    
    NSDictionary *result = 
        [NSDictionary dictionaryWithObjectsAndKeys:
            indentBy,@"indent",
            wrapAt,@"wrapchars",
            wordWrap,@"wrap",
            skipLines,@"skiplines", 
            condenseLines,@"condenselines",
            nil];
            
    [RDAtlantisDefaults() setObject:result forKey:@"log.formatted.defaults"];
}

- (void) okButton:(id) sender
{
    [NSApp stopModalWithCode:1];
}

- (void) cancelButton:(id) sender
{
    [NSApp stopModalWithCode:0];
}

- (BOOL) openFile 
{
    if ([super openFile]) {
        NSString *gameName = [[self world] preferenceForKey:@"atlantis.world.name"];
        NSString *characterName = [[self world] preferenceForKey:@"atlantis.world.character"];
        
        NSString *friendlyName = nil;
        
        if (gameName && characterName) {
            friendlyName = [NSString stringWithFormat:@"%@ on %@", characterName, gameName];
        }
        else if (!characterName && gameName) {
            friendlyName = gameName;
        }
        
        // TODO: Localize
        [self writeStringToFile:@"\n"];
        if (friendlyName) {
            [self writeStringToFile:[NSString stringWithFormat:@"    //// Logfile for %@\n", friendlyName]];
        }
        if ([self spawnPath]) {
            [self writeStringToFile:[NSString stringWithFormat:@"    //// Logging spawn: %@\n", [self spawnPath]]];
        }
        [self writeStringToFile:[NSString stringWithFormat:@"    //// Started at %@\n\n", [[NSDate date] description]]];
        return YES;
    }
    return NO;
}

- (BOOL) closeFile
{
    if ([self isOpen]) {
        // TODO: Localize
        [self writeStringToFile:[NSString stringWithFormat:@"    //// Closed at %@\n\n", [[NSDate date] description]]];
    }
    return [super closeFile];
}

- (void) writeString:(NSAttributedString *)string withState:(AtlantisState *)state
{
    // If this line is marked 'omit from logs,' we, well, omit it from logs.
    NSDictionary *attrs = nil;
    if ([string length]) {
        NSRange effRange;
        attrs = [string attributesAtIndex:0 effectiveRange:&effRange];
        if ([attrs objectForKey:@"RDLogOmitLine"])
            return;
    }
    else {
        // dead string aiiie
        return;
    }

    NSString *realString = [NSString stringWithString:[string string]];

    if ([realString length] && ([realString characterAtIndex:[realString length] - 1] == '\n')) {
        realString = [realString substringWithRange:NSMakeRange(0,[realString length] - 1)];
    }

    NSMutableString *newString = [[NSMutableString alloc] init];
    NSInteger indent = 2;
    NSInteger margin = 79;
    BOOL wordWrap = YES;
    BOOL skipLines = YES;
    BOOL condenseLines = NO;
    
    if ([self options]) {
        indent = [[[self options] objectForKey:@"indent"] intValue];
        margin = [[[self options] objectForKey:@"wrapchars"] intValue];
        wordWrap = [[[self options] objectForKey:@"wrap"] boolValue];
        skipLines = [[[self options] objectForKey:@"skiplines"] boolValue];
        condenseLines = [[[self options] objectForKey:@"condenselines"] boolValue];
    }

    if ([self writeTimestamps]) {
        NSDate *timestamp = [attrs objectForKey:@"RDTimeStamp"];
        if (timestamp) {
            [newString appendString:[timestamp descriptionWithCalendarFormat:@"[%H:%M:%S] " timeZone:nil locale:nil]];
        }
    }
    
    BOOL blankLine = NO;
    
    if (![realString length])
        blankLine = YES;
    else {
        NSUInteger pos = 0;
        BOOL allBlank = YES;
        NSCharacterSet *charSet = [NSCharacterSet whitespaceCharacterSet];
        while (allBlank && (pos < [realString length])) {
            if (![charSet characterIsMember:[realString characterAtIndex:pos]]) {
                allBlank = NO;
            }
            pos++;
        }
        
        if (allBlank)
            blankLine = YES;
    }    
    

    if (blankLine) {
        if (!condenseLines && !skipLines)
            [self writeStringToFile:@"\n"];
        if (skipLines && !condenseLines)
            [self writeStringToFile:@"\n"];
        return;
    }

    if (wordWrap) {
        NSUInteger length = [realString length];
        NSUInteger pos = 0;
        NSInteger firstLinePrefix = [self writeTimestamps] ? 11 : 0;
        while (pos < length) {
            NSInteger prefix = pos == 0 ? firstLinePrefix : indent;
            if (prefix < 0 || margin <= prefix) {
                [newString appendString:[realString substringFromIndex:pos]];
                [newString appendString:@"\n"];
                break;
            }

            NSUInteger width = (NSUInteger)(margin - prefix);
            NSUInteger end = length;
            NSUInteger resumeAt = length;
            BOOL hyphenate = NO;
            if (width < length - pos) {
                NSUInteger limit = pos + width;
                end = [realString rangeOfComposedCharacterSequenceAtIndex:limit].location;
                while (end > pos) {
                    NSRange cluster = [realString rangeOfComposedCharacterSequenceAtIndex:end];
                    unichar character = [realString characterAtIndex:end];
                    if (cluster.length == 1 && character < 128 && isspace(character))
                        break;
                    end = [realString rangeOfComposedCharacterSequenceAtIndex:end - 1].location;
                }

                if (end > pos) {
                    resumeAt = end;
                    while (resumeAt < length) {
                        NSRange cluster = [realString rangeOfComposedCharacterSequenceAtIndex:resumeAt];
                        unichar character = [realString characterAtIndex:resumeAt];
                        if (cluster.length != 1 || character >= 128 || !isspace(character))
                            break;
                        resumeAt = NSMaxRange(cluster);
                    }
                }
                else {
                    // Reserve a unit for the hyphen, or emit one whole cluster by itself.
                    end = [realString rangeOfComposedCharacterSequenceAtIndex:limit - 1].location;
                    hyphenate = end > pos;
                    if (!hyphenate)
                        end = NSMaxRange([realString rangeOfComposedCharacterSequenceAtIndex:pos]);
                    resumeAt = end;
                }
            }

            if (pos > 0) {
                for (NSInteger space = 0; space < indent; space++)
                    [newString appendString:@" "];
            }
            [newString appendString:[realString substringWithRange:NSMakeRange(pos, end - pos)]];
            if (hyphenate)
                [newString appendString:@"-"];
            [newString appendString:@"\n"];
            pos = resumeAt;
        }
    }
    else {
        [newString appendString:realString];
        [newString appendString:@"\n"];
    }
    
    if (skipLines)
        [newString appendString:@"\n"];

    [self writeStringToFile:newString];
    [newString release];
}


@end
