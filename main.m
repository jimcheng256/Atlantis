//
//  main.m
//  Atlantis
//
//  Created by Rachel Blackman on 2/8/06.
//  Copyright Riverdark Studios 2006. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "Core/AtlantisProfile.h"

int main(int argc, char *argv[])
{
    @autoreleasepool {
        NSError *error = nil;
        if (!RDConfigureAtlantisProfile([[NSProcessInfo processInfo] arguments], &error)) {
            fprintf(stderr, "Atlantis: %s\n", error.localizedDescription.UTF8String);
            return EXIT_FAILURE;
        }
    }

    int result = NSApplicationMain(argc,  (const char **) argv);
    
    return result;
}
