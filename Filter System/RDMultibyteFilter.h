//
//  RDMultibyteFilter.h
//  Atlantis
//
//  Created by Jim Cheng on 6/23/26.
//

#import <Cocoa/Cocoa.h>
#import "RDAtlantisFilter.h"

@interface RDMultibyteFilter : RDAtlantisFilter {

    NSMutableData *     _rdHoldoverBuffer;

}

@end
