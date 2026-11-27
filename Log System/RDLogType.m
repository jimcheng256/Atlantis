//
//  RDLogType.m
//  Atlantis
//
//  Created by Rachel Blackman on 2/14/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import "RDLogType.h"
#import "AtlantisState.h"
#include <errno.h>
#include <fcntl.h>
#include <stdio.h>
#include <sys/file.h>
#include <sys/stat.h>
#include <unistd.h>

@implementation RDLogType {
    BOOL _openingSavePanelFile;
}

+ (NSString *) logtypeName
{
    // TODO: Localize
    return @"Base Logfile (this should not be here!)";
}

+ (BOOL) canAppendToLog
{
    return NO;
}

+ (BOOL) supportsOptions
{
    return NO;
}

+ (NSString *) shortTypeName
{
    return @"baselog";
}

- (NSDictionary *) configureOptions:(NSDictionary *)oldOptions
{
    return nil;
}

- (id) initWithFilename:(NSString *)filename forSpawn:(NSString *)spawnPath inWorld:(RDAtlantisWorldInstance *)world
{
    return [self initWithFilename:filename forSpawn:spawnPath inWorld:world withOptions:nil];
}

- (id) initWithFilename:(NSString *)filename forSpawn:(NSString *)spawnPath inWorld:(RDAtlantisWorldInstance *)world withOptions:(NSDictionary *)options
{
    self = [super init];
    if (self) {
        _rdFilename = [[[filename stringByExpandingTildeInPath] stringByStandardizingPath] retain];

        if (spawnPath)
            _rdSpawnPath = [[NSString stringWithString:spawnPath] retain];
        else
            _rdSpawnPath = nil;

        if (world)
            _rdWorld = [world retain];
        else
            _rdWorld = nil;

        if (options) 
            _rdOptions = [[NSDictionary dictionaryWithDictionary:options] retain];
        else
            _rdOptions = [[self defaultOptions] retain];
            
        _rdLogfile = nil;
        _rdTimestamps = NO;
    }
    return self;
}

- (void) dealloc
{
    [self closeFile];
    [_rdOptions release];
    [_rdLogfile release];
    [_rdFilename release];
    [_rdSpawnPath release];
    [_rdWorld release];
    [super dealloc];
}

- (void) setWriteTimestamps:(BOOL) timestamps
{
    _rdTimestamps = timestamps;
}

- (BOOL) writeTimestamps
{
    return _rdTimestamps;
}

- (NSString *) shortTypeName
{
    return [[self class] shortTypeName];
}

- (NSString *) description
{
    // TODO: Localize
    NSString *baseLine = @"%@ (%@%@)";
    NSString *spawnLine = @"%@ only";
    
    NSString *spawnData = nil;
    if ([self spawnPath]) {
        spawnData = [NSString stringWithFormat:spawnLine, [self spawnPath]];
    }

    NSString *fileonly = [[self filename] lastPathComponent];

    return [NSString stringWithFormat:baseLine, fileonly, [self shortTypeName], spawnData ? spawnData : @""];    
}

- (NSDictionary *) options
{
    return _rdOptions;
}

- (NSDictionary *) defaultOptions
{
    return nil;
}

- (BOOL) createDirectoriesToFile
{
    NSArray *pathComponents = [[[self filename] stringByDeletingLastPathComponent] pathComponents];
    
    NSString *currentPath = @"";
    NSFileManager *fileman = [NSFileManager defaultManager];
    BOOL isDirectory;
    
    NSEnumerator *pathEnum = [pathComponents objectEnumerator];
    NSString *pathFragment = @"/";
    
    do {
        currentPath = [currentPath stringByAppendingPathComponent:pathFragment];
        if ([fileman fileExistsAtPath:currentPath isDirectory:&isDirectory]) {
            if (!isDirectory)
                return NO;
        }
        else {
            if (![fileman createDirectoryAtPath:currentPath attributes:nil])
                return NO;
        }
    } while (pathFragment = [pathEnum nextObject]);

    return YES;
}

- (void) findGoodFilename
{
    NSString *extension = [[self filename] pathExtension];
    NSString *baseline;
    if (extension && [extension length])
        baseline = [[self filename] substringWithRange:NSMakeRange(0,[[self filename] length] - ([extension length] + 1))];
    else
        baseline = [self filename];
        
    int counter = 1;
    NSString *testFilename;
    
    if (extension && [extension length])
        testFilename = [NSString stringWithFormat:@"%@-%d.%@", baseline, counter, extension];
    else
        testFilename = [NSString stringWithFormat:@"%@-%d", baseline, counter];

    NSFileManager *fileman = [NSFileManager defaultManager];
    
    while ([fileman fileExistsAtPath:testFilename]) {
        counter++;
        if (extension && [extension length])
            testFilename = [NSString stringWithFormat:@"%@-%d.%@", baseline, counter, extension];
        else
            testFilename = [NSString stringWithFormat:@"%@-%d", baseline, counter];
    }
    
    [_rdFilename release];
    _rdFilename = [testFilename retain];    
}

static BOOL RDSameLogIdentity(NSDictionary *expected, NSDictionary *actual)
{
    return [expected[NSFileType] isEqual:NSFileTypeRegular] &&
           [actual[NSFileType] isEqual:NSFileTypeRegular] &&
           [expected[NSFileSystemNumber] isEqual:actual[NSFileSystemNumber]] &&
           [expected[NSFileSystemFileNumber] isEqual:actual[NSFileSystemFileNumber]];
}

static BOOL RDSameLogFile(NSDictionary *expected, NSDictionary *actual)
{
    return RDSameLogIdentity(expected, actual) &&
           [expected[NSFileSize] isEqual:actual[NSFileSize]] &&
           [expected[NSFileModificationDate] isEqual:actual[NSFileModificationDate]];
}

static BOOL RDLogFileMatchesDescriptor(NSDictionary *file, int descriptor)
{
    struct stat info;
    return fstat(descriptor, &info) == 0 && S_ISREG(info.st_mode) &&
           [file[NSFileSystemFileNumber] isEqual:@(info.st_ino)] &&
           [file[NSFileSystemNumber] isEqual:@(info.st_dev)];
}

- (BOOL)openFileForSavePanelWithMode:(RDLogSaveMode)mode
                     existingFile:(NSDictionary *)existingFile
                            error:(NSError **)error
{
    NSFileManager *manager = [NSFileManager defaultManager];
    NSString *destination = [self filename];
    const char *destinationPath = [destination fileSystemRepresentation];
    NSString *staging = nil;
    NSDictionary *cleanupIdentity = nil;
    BOOL opened = NO;
    int failure = EIO;
    int descriptor = -1;
    int originalDescriptor = -1;
    NSString *recoveryPath = nil;

    if ([self isOpen] ||
        (mode != RDLogSaveModeCreate && mode != RDLogSaveModeReplace && mode != RDLogSaveModeAppend) ||
        (mode == RDLogSaveModeAppend && ![[self class] canAppendToLog])) {
        failure = EINVAL;
    }
    else if (mode != RDLogSaveModeCreate &&
             !RDSameLogFile(existingFile, [manager attributesOfItemAtPath:destination error:NULL])) {
        failure = ESTALE;
    }
    else if (mode == RDLogSaveModeAppend) {
        descriptor = open(destinationPath, O_WRONLY | O_APPEND | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
        if (descriptor < 0) {
            failure = errno;
        }
        else if (!RDLogFileMatchesDescriptor(existingFile, descriptor)) {
            close(descriptor);
            descriptor = -1;
            failure = ESTALE;
        }
    }
    else {
        if (mode == RDLogSaveModeReplace) {
            originalDescriptor = open(destinationPath, O_RDONLY | O_NOFOLLOW | O_NONBLOCK | O_CLOEXEC);
            if (originalDescriptor < 0)
                failure = errno;
            else if (!RDLogFileMatchesDescriptor(existingFile, originalDescriptor))
                failure = ESTALE;
            else if (flock(originalDescriptor, LOCK_EX | LOCK_NB) != 0)
                failure = errno;
            else
                failure = 0;
        }
        else {
            failure = 0;
        }
    }

    if (failure == 0 && mode != RDLogSaveModeAppend) {
        NSString *pattern = [[destination stringByDeletingLastPathComponent]
            stringByAppendingPathComponent:@".atlantis-log.XXXXXX"];
        char *buffer = strdup([pattern fileSystemRepresentation]);
        if (buffer != NULL) {
            descriptor = mkstemp(buffer);
            failure = descriptor < 0 ? errno : EIO;
            if (descriptor >= 0) {
                staging = [manager stringWithFileSystemRepresentation:buffer length:strlen(buffer)];
                NSDictionary *file = [manager attributesOfItemAtPath:staging error:NULL];
                if (RDLogFileMatchesDescriptor(file, descriptor))
                    cleanupIdentity = file;
            }
            free(buffer);
        }
        else {
            failure = ENOMEM;
        }
    }

    if (descriptor >= 0 && flock(descriptor, LOCK_EX | LOCK_NB) != 0) {
        failure = errno;
        close(descriptor);
        descriptor = -1;
    }
    if (descriptor >= 0) {
        _rdLogfile = [[NSFileHandle alloc] initWithFileDescriptor:descriptor closeOnDealloc:YES];
        _openingSavePanelFile = YES;
        @try {
            opened = [self openFile] && [self isOpen];
            if (opened && staging)
                opened = [_rdLogfile synchronizeAndReturnError:NULL];
        }
        @catch (NSException *exception) {
            opened = NO;
        }
        @finally {
            _openingSavePanelFile = NO;
        }
    }

    if (opened && staging) {
        const char *stagingPath = [staging fileSystemRepresentation];
        NSDictionary *preparedFile = [manager attributesOfItemAtPath:staging error:NULL];
        if (!RDLogFileMatchesDescriptor(preparedFile, descriptor)) {
            // The staging name no longer refers to our open file.
            staging = nil;
            failure = ESTALE;
            opened = NO;
        }
        else if (mode == RDLogSaveModeReplace &&
            !RDSameLogFile(existingFile, [manager attributesOfItemAtPath:destination error:NULL])) {
            failure = ESTALE;
            opened = NO;
        }
        else if (renamex_np(stagingPath, destinationPath,
                            mode == RDLogSaveModeReplace ? RENAME_SWAP : RENAME_EXCL) != 0) {
            failure = errno;
            opened = NO;
        }
        else if (mode == RDLogSaveModeCreate) {
            staging = nil;
        }
        else if (!RDSameLogFile(existingFile, [manager attributesOfItemAtPath:staging error:NULL])) {
            // Preserve the displaced file if another process changed the destination.
            if (!RDSameLogFile(preparedFile, [manager attributesOfItemAtPath:destination error:NULL]) ||
                renamex_np(stagingPath, destinationPath, RENAME_SWAP) != 0) {
                recoveryPath = staging;
                staging = nil;
            }
            failure = ESTALE;
            opened = NO;
        }
        else {
            cleanupIdentity = existingFile;
        }
    }

    if (staging && RDSameLogIdentity(cleanupIdentity, [manager attributesOfItemAtPath:staging error:NULL]))
        unlink([staging fileSystemRepresentation]);
    if (originalDescriptor >= 0)
        close(originalDescriptor);

    if (!opened) {
        if (descriptor >= 0) {
            [_rdLogfile release];
            _rdLogfile = nil;
        }
        if (error) {
            NSMutableDictionary *details = [NSMutableDictionary dictionaryWithObject:destination
                                                                                forKey:NSFilePathErrorKey];
            if (recoveryPath) {
                details[NSLocalizedRecoverySuggestionErrorKey] =
                    [NSString stringWithFormat:@"The previous file is available at %@.", recoveryPath];
            }
            *error = [NSError errorWithDomain:NSPOSIXErrorDomain code:failure userInfo:details];
        }
        return NO;
    }

    [_rdWorld outputStatus:[NSString stringWithFormat:@"Began logging to file: %@", destination]
                   toSpawn:[self spawnPath]];
    return YES;
}

- (BOOL) openFile
{
    if (_openingSavePanelFile)
        return YES;
    NSFileManager *manager = [NSFileManager defaultManager];
    BOOL isDirectory = NO;
    BOOL exists = [manager fileExistsAtPath:[self filename] isDirectory:&isDirectory];
    if (isDirectory)
        return NO;

    BOOL creating = !exists || ![[self class] canAppendToLog];
    if (exists && creating)
        [self findGoodFilename];
    if (creating && ![self createDirectoriesToFile])
        return NO;

    int flags = O_WRONLY | O_APPEND | O_NONBLOCK | O_CLOEXEC;
    if (creating)
        flags |= O_CREAT | O_EXCL;
    int descriptor = open([[self filename] fileSystemRepresentation], flags, 0666);
    if (descriptor < 0)
        return NO;

    struct stat info;
    if (fstat(descriptor, &info) != 0 || !S_ISREG(info.st_mode) ||
        flock(descriptor, LOCK_SH | LOCK_NB) != 0) {
        close(descriptor);
        return NO;
    }

    _rdLogfile = [[NSFileHandle alloc] initWithFileDescriptor:descriptor closeOnDealloc:YES];
    [_rdLogfile seekToEndOfFile];
    [_rdWorld outputStatus:[NSString stringWithFormat:@"Began logging to file: %@", [self filename]]
                   toSpawn:[self spawnPath]];
    return YES;
}

- (BOOL) closeFile
{
    if (_rdLogfile) {
        [_rdLogfile closeFile];
        [_rdLogfile release];
        _rdLogfile = nil;

        // TODO: Localize
        NSString *outputString = @"Closed logfile: %@";        
        [_rdWorld outputStatus:[NSString stringWithFormat:outputString,[self filename]] toSpawn:[self spawnPath]];
    }
    return YES;
}

- (BOOL) isOpen
{
    if (_rdLogfile) {
        return YES;
    }
    
    return NO;
}

- (NSString *) filename
{
    return _rdFilename;
}

- (NSString *) spawnPath
{
    return _rdSpawnPath;
}

- (NSFileHandle *) fileHandle
{
    return _rdLogfile;
}

- (RDAtlantisWorldInstance *) world
{
    return _rdWorld;
}

- (BOOL) shouldWriteForState:(AtlantisState *)state
{
    if (_rdSpawnPath) {
        NSString *viewPath = [state spawnPath];
        if (viewPath) {
            if ([viewPath isEqualToString:_rdSpawnPath])
                return YES;
        }
        
        return NO;
    }
    
    return YES;
}

- (void) writeStringToFile:(NSString *)string
{
    if ([self isOpen]) {
        NSData *data = [string dataUsingEncoding:NSUTF8StringEncoding];
        [[self fileHandle] writeData:data];
    }
}

- (void) writeString:(NSAttributedString *)string withState:(AtlantisState *)state
{
    // Nothing
}

/* Template

+ (NSString *) logtypeName
{
    // TODO: Localize
    return @"typename here";
}

+ (BOOL) canAppendToLog;

- (id) initWithFilename:(NSString *)filename forSpawn:(NSString *)spawnPath inWorld:(RDAtlantisWorldInstance *)world
{
    self = [super initWithFilename:filename forSpawn:spawnPath inWorld:world];
    if (self) {
    
    }
    return self;
}

- (void) dealloc
{
    [super dealloc];
}

- (NSString *) shortTypeName
{
    // TODO: Localize
    return @"type";
}

- (BOOL) openFile 
{
    if ([super openFile]) {
        // Any initial file header stuff here
    }
}

- (BOOL) closeFile
{
    if ([self isOpen]) {
        // Any final footer stuff here
    }
    return [super closeFile];
}

- (void) writeString:(NSAttributedString *)string withState:(AtlantisState *)state
{
    // If this line is marked 'omit from logs,' we, well, omit it from logs.
    NSRange effRange;
    NSDictionary *attrs = [string attributesAtIndex:0 effectiveRange:&effRange];
    if ([attrs objectForKey:@"RDLogOmitLine"])
        return;

    // Alter this as appropriate.
}


 */

@end
