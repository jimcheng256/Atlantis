#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface AtlantisProfile : NSObject
@property (nonatomic, readonly, copy) NSString *directory;
@property (nonatomic, readonly, copy) NSString *suiteName;
@property (nonatomic, readonly, retain) NSUserDefaults *defaults;
- (instancetype)init NS_UNAVAILABLE;
- (nullable instancetype)initWithDirectory:(NSString *)directory error:(NSError **)error;
- (NSString *)storagePath:(NSString *)component;
@end

BOOL RDConfigureAtlantisProfile(NSArray<NSString *> *arguments, NSError **error);
NSUserDefaults *RDAtlantisDefaults(void);
NSString *RDAtlantisStoragePath(NSString *component);
NSString *RDAtlantisDefaultLogDirectory(void);
BOOL RDAtlantisHasProfile(void);

NS_ASSUME_NONNULL_END
