//
//  RDMultibyteFilter.m
//  Atlantis
//
//  Created by Jim Cheng on 6/23/26.
//

#import "RDMultibyteFilter.h"

@implementation RDMultibyteFilter

- (id) initWithWorld:(RDAtlantisWorldInstance *)world
{
    self = [super initWithWorld:world];
    if (self) {
        _rdHoldoverBuffer = nil;
    }
    return self;
}

- (void) dealloc
{
    [_rdHoldoverBuffer release];
    [super dealloc];
}

- (void) addBytesToHoldover:(NSData *)dataBytes
{
    if (!_rdHoldoverBuffer)
        _rdHoldoverBuffer = [[NSMutableData data] retain];
        
    [_rdHoldoverBuffer appendData:dataBytes];
}

- (void) filterInput:(id) object
{
    if ([object isKindOfClass:[NSMutableData class]]) {
        
        NSStringEncoding encoding = [_rdWorld stringEncoding];

        // We're only handling UTF-8 multibyte for now...
        if (encoding == NSUTF8StringEncoding) {
            
            NSMutableData *mutableData = (NSMutableData *)object;
            
            if (_rdHoldoverBuffer.length > 0) {
                [_rdHoldoverBuffer appendData:mutableData];
                [mutableData setLength:0];
                [mutableData setData:_rdHoldoverBuffer];
                [_rdHoldoverBuffer setLength:0];
            }
            
            const unsigned char *bytes = [mutableData bytes];
            unsigned long count = [mutableData length];
            unsigned long bytesToHold = 0;
            unsigned char byte = bytes[count - 1];
            
            while (count > 0 && byte >= 0x80) {
                /*
                if (byte <= 0xBF) {
                    // Continuation byte
                }
                else if (byte == 0xC0 || byte == 0xC1) {
                    // Unused
                }
                else if (byte <= 0xF4) {
                    // First byte of a code unit sequence
                }
                else if (byte >= 0xF5) {
                    // Unused
                }
                */
                bytesToHold++;
                byte = bytes[--count];
            }
            
            if (bytesToHold > 0) {
                [self addBytesToHoldover:[mutableData subdataWithRange:NSMakeRange([mutableData length] - bytesToHold, bytesToHold)]];
                mutableData.length = [mutableData length] - bytesToHold;
            }
            
        }
    }
}

@end
