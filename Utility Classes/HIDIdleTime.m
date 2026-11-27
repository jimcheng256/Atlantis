#import "HIDIdleTime.h"

#include <math.h>

@implementation HIDIdleTime

- (id)init
{
    self = [super init];
    if (self) {
        io_iterator_t iterator = IO_OBJECT_NULL;
        kern_return_t result = IOServiceGetMatchingServices(
            kIOMainPortDefault, IOServiceMatching("IOHIDSystem"), &iterator);
        if (result == KERN_SUCCESS && iterator != IO_OBJECT_NULL) {
            _hidEntry = IOIteratorNext(iterator);
        }
        if (iterator != IO_OBJECT_NULL) {
            IOObjectRelease(iterator);
        }
        if (_hidEntry == IO_OBJECT_NULL) {
            [self release];
            return nil;
        }
    }
    return self;
}

- (void)dealloc
{
    if (_hidEntry != IO_OBJECT_NULL) {
        IOObjectRelease(_hidEntry);
    }
    [super dealloc];
}

- (BOOL)readIdleTime:(uint64_t *)nanoseconds
{
    CFMutableDictionaryRef properties = NULL;
    kern_return_t result = IORegistryEntryCreateCFProperties(
        _hidEntry, &properties, kCFAllocatorDefault, 0);
    if (properties == NULL) {
        return NO;
    }

    BOOL valid = NO;
    if (result == KERN_SUCCESS) {
        id value = [(NSDictionary *)properties objectForKey:@"HIDIdleTime"];
        if ([value isKindOfClass:[NSData class]] && [value length] == sizeof(*nanoseconds)) {
            [value getBytes:nanoseconds length:sizeof(*nanoseconds)];
            valid = YES;
        } else if ([value isKindOfClass:[NSNumber class]]) {
            NSNumber *number = value;
            if (isfinite(number.doubleValue) && [number compare:@0] != NSOrderedAscending) {
                uint64_t integer = number.unsignedLongLongValue;
                if ([number isEqualToNumber:@(integer)]) {
                    *nanoseconds = integer;
                    valid = YES;
                }
            }
        }
    }
    CFRelease(properties);
    return valid;
}

@end
