#import "AtlantisProfile.h"
#import <CommonCrypto/CommonDigest.h>

@implementation AtlantisProfile

- (instancetype)initWithDirectory:(NSString *)directory error:(NSError **)error
{
    self = [super init];
    if (!self) return nil;

    NSString *path = directory.stringByExpandingTildeInPath;
    NSFileManager *files = [NSFileManager defaultManager];
    if (![path isAbsolutePath]) {
        path = [files.currentDirectoryPath stringByAppendingPathComponent:path];
    }

    if (![files createDirectoryAtPath:path withIntermediateDirectories:YES attributes:nil error:error]) {
        [self release];
        return nil;
    }

    _directory = [path.stringByResolvingSymlinksInPath.stringByStandardizingPath copy];
    if (![files isWritableFileAtPath:_directory] ||
        [self.directory isEqualToString:[@"~/Library/Application Support/Atlantis" stringByExpandingTildeInPath].stringByResolvingSymlinksInPath]) {
        if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError
                                            userInfo:@{NSFilePathErrorKey: _directory}];
        [self release];
        return nil;
    }

    for (NSString *component in @[@"worlds", @"Logs"]) {
        NSString *child = [self storagePath:component];
        if (![files createDirectoryAtPath:child withIntermediateDirectories:YES attributes:nil error:error]) {
            [self release];
            return nil;
        }
    }

    NSData *bytes = [_directory dataUsingEncoding:NSUTF8StringEncoding];
    unsigned char digest[CC_SHA256_DIGEST_LENGTH];
    CC_SHA256(bytes.bytes, (CC_LONG)bytes.length, digest);
    NSMutableString *name = [NSMutableString stringWithString:@"net.riverdark.Atlantis.profile."];
    for (NSUInteger index = 0; index < sizeof(digest); index++) {
        [name appendFormat:@"%02x", (unsigned int)digest[index]];
    }
    _suiteName = [name copy];
    _defaults = [[NSUserDefaults alloc] initWithSuiteName:_suiteName];
    return self;
}

- (void)dealloc
{
    [_directory release];
    [_suiteName release];
    [_defaults release];
    [super dealloc];
}

- (NSString *)storagePath:(NSString *)component
{
    return [self.directory stringByAppendingPathComponent:component];
}

@end

static AtlantisProfile *profile;

BOOL RDConfigureAtlantisProfile(NSArray<NSString *> *arguments, NSError **error)
{
    NSString *directory = nil;
    for (NSUInteger index = 1; index < arguments.count; index++) {
        if (![arguments[index] isEqualToString:@"--profile-directory"]) continue;
        if (directory || index + 1 == arguments.count ||
            [arguments[index + 1] length] == 0 || [arguments[index + 1] hasPrefix:@"-"]) {
            if (error) *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteInvalidFileNameError
                                                userInfo:@{NSLocalizedDescriptionKey: @"Specify --profile-directory once, followed by a directory path."}];
            return NO;
        }
        directory = arguments[++index];
    }
    if (!directory) return YES;

    profile = [[AtlantisProfile alloc] initWithDirectory:directory error:error];
    if (!profile) return NO;

    NSLog(@"Atlantis profile: preferences suite %@, storage directory %@", profile.suiteName, profile.directory);
    return YES;
}

BOOL RDAtlantisHasProfile(void)
{
    return profile != nil;
}

NSUserDefaults *RDAtlantisDefaults(void)
{
    return profile ? profile.defaults : [NSUserDefaults standardUserDefaults];
}

NSString *RDAtlantisStoragePath(NSString *component)
{
    if (profile) return [profile storagePath:component];
    return [[@"~/Library/Application Support/Atlantis" stringByExpandingTildeInPath]
        stringByAppendingPathComponent:component];
}

NSString *RDAtlantisDefaultLogDirectory(void)
{
    if (profile) return [profile storagePath:@"Logs"];
    return @"~/Documents";
}
