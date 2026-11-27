#import <Foundation/Foundation.h>
#import <IOKit/IOKitLib.h>

@interface HIDIdleTime : NSObject {
    io_registry_entry_t _hidEntry;
}

- (BOOL)readIdleTime:(uint64_t *)nanoseconds;

@end
