//
//  RDStringPattern.h
//  Atlantis
//
//  Created by Rachel Blackman on Thu Jul 08 2004.
//  Copyright (c) 2004 Riverdark Studios. All rights reserved.
//

#import <Foundation/Foundation.h>

enum {
    RDPatternBeginsWith,
    RDPatternIs,
    RDPatternContains,
    RDPatternRegexp
};

@interface RDStringPattern : NSObject <NSCopying, NSCoding> {

    int             _rdPatternType;
    NSString *      _rdPattern;
    
    NSString *      _rdMatchMe;
    NSUInteger      _rdMatchPosition;
    
}

+ (RDStringPattern *) patternWithString:(NSString *)pattern type:(int)type;

// Tests the match condition. RDPatternIs requires equality with the entire input.
- (BOOL) patternMatchesString:(NSString *)match;
- (BOOL) stringContainsPattern:(NSString *)match;

// Iterates highlight ranges. RDPatternIs highlights each literal occurrence,
// and RDPatternContains highlights the whole input when it contains the pattern.
// Pass the input to start and nil to advance. A zero-length range ends iteration.
- (NSRange) stringMatch:(NSString *)match;

- (int) type;
- (NSString *) pattern;

- (id) copyWithZone:(NSZone *)zone;

- (void) encodeWithCoder:(NSCoder *)coder;
- (id) initWithCoder:(NSCoder *)coder;

@end
