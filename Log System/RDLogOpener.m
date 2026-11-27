#import "../Core/AtlantisProfile.h"
//
//  RDLogOpener.m
//  Atlantis
//
//  Created by Rachel Blackman on 2/15/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "RDLogOpener.h"
#import "RDAtlantisMainController.h"
#import "RDLogType.h"
#import "RDAtlantisSpawn.h"
#import "AtlantisProgressSheet.h"
#import <objc/runtime.h>
#import <objc/message.h>

@implementation RDLogOpener

- (id) initWithState:(AtlantisState *) state
{
    self = [super init];
    if (self) {
        _rdState = [state retain];
        _rdSavePanel = nil;
    }
    return self;
}

- (id) initWithHotkeyState:(RDHotkeyState *)state
{
    NSLog(@"Eeek!");
    return nil;
}

- (void) dealloc
{
    [_rdSavePanel release];
    [_rdCurrentOptions release];
    [_rdState release];
    [super dealloc];
}

NSInteger scrollbackSort(id obj1, id obj2, void * __nullable context)
{
    NSAttributedString *st1 = (NSAttributedString *)obj1;
    NSAttributedString *st2 = (NSAttributedString *)obj2;
    
    NSRange tempRange;
    NSDate *d1 = nil;
    NSDate *d2 = nil;

    if ([st1 length]) {
        NSDictionary *dict1 = [st1 attributesAtIndex:0 effectiveRange:&tempRange];
        d1 = [dict1 objectForKey:@"RDTimeStamp"];
    }
    if ([st2 length]) {
        NSDictionary *dict2 = [st2 attributesAtIndex:0 effectiveRange:&tempRange];
        d2 = [dict2 objectForKey:@"RDTimeStamp"];
    }
    
    if (d1 && !d2) {
        return NSOrderedDescending;
    }
    else if (!d1 && d2) {
        return NSOrderedAscending;
    }
    else {
        return [d1 compare:d2];
    }    
}

static BOOL RDLogModeForAlertResponse(NSModalResponse response, BOOL canAppend, RDLogSaveMode *mode)
{
    switch (response) {
        case NSAlertFirstButtonReturn:
            *mode = RDLogSaveModeReplace;
            return YES;
        case NSAlertThirdButtonReturn:
            if (canAppend) {
                *mode = RDLogSaveModeAppend;
                return YES;
            }
            return NO;
        default:
            return NO;
    }
}

- (void)showLogOpenError:(NSError *)error
{
    if (!error)
        error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteUnknownError userInfo:nil];
    NSAlert *alert = [NSAlert alertWithError:error];
    if ([NSApp keyWindow])
        [alert beginSheetModalForWindow:[NSApp keyWindow] completionHandler:nil];
    else
        [alert runModal];
}

- (void)savePanelDidEnd:(NSSavePanel *)sheet response:(NSModalResponse)response
{
    if (response == NSModalResponseOK) {
        NSArray *logtypes = [[RDAtlantisMainController controller] logTypes];
        NSString *filename = [[sheet URL] path];
        NSInteger selected = [_rdLogTypes indexOfSelectedItem];
        if (!filename || selected < 0 || (NSUInteger)selected >= [logtypes count])
            return;
        Class logClass = [logtypes objectAtIndex:(NSUInteger)selected];

        NSError *fileError = nil;
        NSDictionary *existingFile = [[NSFileManager defaultManager] attributesOfItemAtPath:filename
                                                                                       error:&fileError];
        RDLogSaveMode mode = RDLogSaveModeCreate;
        if (existingFile) {
            if (![existingFile[NSFileType] isEqual:NSFileTypeRegular]) {
                [self showLogOpenError:[NSError errorWithDomain:NSCocoaErrorDomain
                                                          code:NSFileWriteInvalidFileNameError
                                                      userInfo:@{NSFilePathErrorKey: filename}]];
                return;
            }
            BOOL canAppend = [logClass canAppendToLog];
            NSAlert *alert = [[[NSAlert alloc] init] autorelease];
            [alert setMessageText:@"A log file already exists"];
            [alert setInformativeText:[NSString stringWithFormat:@"Choose how to open %@.",
                                                                     [filename lastPathComponent]]];
            [alert addButtonWithTitle:@"Replace"];
            NSButton *cancelButton = [alert addButtonWithTitle:@"Cancel"];
            if (canAppend)
                [alert addButtonWithTitle:@"Append"];
            // Keep the destructive action on an explicit button click.
            [[[alert buttons] objectAtIndex:0] setKeyEquivalent:@""];
            [cancelButton setKeyEquivalent:@"\r"];
            if (!RDLogModeForAlertResponse([alert runModal], canAppend, &mode))
                return;
        }
        else if (![[fileError domain] isEqualToString:NSCocoaErrorDomain] ||
                 ([fileError code] != NSFileReadNoSuchFileError && [fileError code] != NSFileNoSuchFileError)) {
            [self showLogOpenError:fileError];
            return;
        }

        NSString* (*SendReturningString)(id, SEL) = (NSString* (*)(id, SEL))objc_msgSend;
        
        NSString *logtype = SendReturningString(logClass,@selector(logtypeName));
        
        if (logtype) {
            [RDAtlantisDefaults() setObject:logtype forKey:@"atlantis.logsave.type"];
        }
        [RDAtlantisDefaults() setObject:[filename stringByDeletingLastPathComponent] forKey:@"atlantis.logsave.directory"];

        NSString *spawnPath = nil;
        if ([_rdSpawnOnlyButton state] == NSControlStateValueOn) {
            spawnPath = [[_rdState spawn] internalPath];
        }

        BOOL showTimestamps = NO;
        if ([_rdTimestampButton state] == NSControlStateValueOn) {
            showTimestamps = YES;
        }
        [RDAtlantisDefaults() setBool:([_rdTimestampButton state] == NSControlStateValueOn) forKey:@"atlantis.logsave.timestamps"];
        
        RDLogType *logger = [[[logClass alloc] initWithFilename:filename forSpawn:spawnPath
                                                       inWorld:[_rdState world] withOptions:_rdCurrentOptions] autorelease];
        [logger setWriteTimestamps:showTimestamps];
        NSError *openError = nil;
        if ([logger openFileForSavePanelWithMode:mode existingFile:existingFile error:&openError]) {
            [[_rdState world] addLogfile:logger];
            
            if ([_rdScrollbackButton state] == NSControlStateValueOn) {
                
                NSMutableArray *scrollbackData = nil; 
                AtlantisProgressSheet *progressSheet = [[AtlantisProgressSheet alloc] init];
                
                [progressSheet openPanel:@"Preparing log..." withMaxValue:-1];
                BOOL cancelled = NO;                
                
                if (([[_rdState world] countOpenSpawns] != 1) && ([_rdSpawnOnlyButton state] == NSControlStateValueOff)) {
                    // Generate combined scrollback
                    scrollbackData = [[NSMutableArray alloc] init];

                    NSEnumerator *spawnEnum = [[_rdState world] spawnEnumerator];
                    RDAtlantisSpawn *spawnWalk;
                    
                    while (spawnWalk = [spawnEnum nextObject]) {
                        [progressSheet setLabel:[NSString stringWithFormat:@"Adding %@ to scrollback...", [spawnWalk viewName]]];
                        cancelled = [progressSheet modalRun];
                        if (cancelled) {
                            [logger closeFile];
                            [[_rdState world] removeLogfile:logger];
                            [scrollbackData release];
                            [progressSheet closePanel];
                            [progressSheet release];                
                            return;                        
                        }
                        [scrollbackData addObjectsFromArray:[spawnWalk scrollbackData]];
                    }
                    
                    [progressSheet setLabel:@"Sorting combined scrollback..."];
                    [scrollbackData sortUsingFunction:scrollbackSort context:nil];
                }
                else {
                    scrollbackData = [[[_rdState spawn] scrollbackData] mutableCopy];                
                }
                
                // Write out lines
                if (scrollbackData) {
                    NSEnumerator *scrollbackEnum = [scrollbackData objectEnumerator];
                    NSAttributedString *stringWalk;
                    
                    NSUInteger totalLines = [scrollbackData count];
                    
                    [progressSheet setLabel:[NSString stringWithFormat:@"Writing %lu lines...", (unsigned long)totalLines]];
                    [progressSheet setMaxValue:(double)totalLines];
                    
                    double progress = 0;
                    [progressSheet setProgress:0];
                    
                    while (stringWalk = [scrollbackEnum nextObject]) {
                        NSRange effRange;
                        NSDictionary *attrs = nil;
                        
                        if ([stringWalk length])
                            attrs = [stringWalk attributesAtIndex:0 effectiveRange:&effRange];
                        
                        progress++;
                        NSString *lineClass = [attrs objectForKey:@"RDLineClass"];
                        [progressSheet setProgress:progress];
                        cancelled = [progressSheet modalRun];
                        if (cancelled) {
                            [logger closeFile];
                            [[_rdState world] removeLogfile:logger];
                            [scrollbackData release];
                            [progressSheet closePanel];
                            [progressSheet autorelease];                
                            return;
                        }
                        
                        if (!(lineClass && [lineClass isEqualToString:@"console"])) {
                            if ([attrs objectForKey:@"RDOmitSpan"]) {
                                [logger writeString:[stringWalk attributedSubstringFromRange:NSMakeRange(effRange.length,[stringWalk length] - effRange.length)] withState:_rdState];
                            }
                            else
                                [logger writeString:stringWalk withState:_rdState];
                        }
                    }
                    [scrollbackData release];
                }
                [progressSheet closePanel];
                [progressSheet autorelease];                
            }            
        }
        else {
            [self showLogOpenError:openError];
        }
        
    }
}

- (void) resyncButton
{
    NSArray *logtypes = [[RDAtlantisMainController controller] logTypes];
    Class logClass = [logtypes objectAtIndex:[_rdLogTypes indexOfSelectedItem]];

    BOOL (*SendReturningBool)(id, SEL) = (BOOL (*)(id, SEL))objc_msgSend;
    
    if(SendReturningBool(logClass,@selector(supportsOptions))) {
        [_rdOptionsButton setEnabled:YES];
    }
    else {
        [_rdOptionsButton setEnabled:NO];    
    }
}

- (void) logTypeChanged:(id) sender
{
    [_rdCurrentOptions release];
    _rdCurrentOptions = nil;
    [self resyncButton];
}

- (void) logTypeOptions:(id) sender
{
    NSArray *logtypes = [[RDAtlantisMainController controller] logTypes];
    Class logClass = [logtypes objectAtIndex:[_rdLogTypes indexOfSelectedItem]];

    RDLogType *tempLog = (RDLogType *)class_createInstance(logClass,0);
    [tempLog init];

    NSDictionary *newOptions = [tempLog configureOptions:_rdCurrentOptions];
    
    if (newOptions != _rdCurrentOptions) {
        [_rdCurrentOptions release];
        _rdCurrentOptions = [newOptions retain];
    }        
}

- (BOOL) openPanel
{
    if (_rdSavePanel)
        return NO;
    if ([NSBundle loadNibNamed:@"LogOptionPanel" owner:self])
    {
        [_rdSpawnOnlyButton setState:NSControlStateValueOff];
        [_rdScrollbackButton setState:NSControlStateValueOff];
        [_rdTimestampButton setState:NSControlStateValueOff];
        [_rdLogTypes removeAllItems];
        _rdCurrentOptions = nil;
        
        NSEnumerator *logtypeEnum = [[[RDAtlantisMainController controller] logTypes] objectEnumerator];
        Class logWalk;
        
        NSString *lastType = 
            [RDAtlantisDefaults() objectForKey:@"atlantis.logsave.type"];

        NSString* (*SendReturningString)(id, SEL) = (NSString* (*)(id, SEL))objc_msgSend;
        
        while (logWalk = [logtypeEnum nextObject]) {
            if (logWalk) {
                NSString *result = SendReturningString(logWalk,@selector(logtypeName));
                
                if (!result) {
                    result = @"<unknown log type>";
                }
                
                [_rdLogTypes addItemWithTitle:result];
            }            
         }
         
        if (lastType) {
            [_rdLogTypes selectItemWithTitle:lastType];
        }
        [self resyncButton];        
        
        BOOL lastTimestamp = [RDAtlantisDefaults() boolForKey:@"atlantis.logsave.timestamps"];
        if (lastTimestamp) {
            [_rdTimestampButton setState:NSControlStateValueOn];
        }
        
        NSWindow *window = [NSApp keyWindow];
        
        _rdSavePanel = [[NSSavePanel savePanel] retain];
        [_rdSavePanel setAccessoryView:_rdOptionsView];
        NSString *lastDirectory = [RDAtlantisDefaults() objectForKey:@"atlantis.logsave.directory"];
        if (!lastDirectory)
            lastDirectory = RDAtlantisDefaultLogDirectory();
        [_rdSavePanel setDirectoryURL:[NSURL fileURLWithPath:lastDirectory isDirectory:YES]];
        void (^completion)(NSModalResponse) = ^(NSModalResponse result) {
            [_rdSavePanel orderOut:self];
            [self savePanelDidEnd:_rdSavePanel response:result];
            [_rdSavePanel release];
            _rdSavePanel = nil;
            [_rdCurrentOptions release];
            _rdCurrentOptions = nil;
        };
        if (window)
            [_rdSavePanel beginSheetModalForWindow:window completionHandler:completion];
        else
            [_rdSavePanel beginWithCompletionHandler:completion];
        return YES;
    }
    else
        return NO;
    
}

@end
