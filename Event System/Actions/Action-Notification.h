//
//  Action-Notification.h
//  Atlantis
//
//  Created by Rachel Blackman on 3/5/06.
//  Copyright 2006 Riverdark Studios. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "BaseAction.h"

@interface Action_Notification : BaseAction <NSTextFieldDelegate> {

    NSString                    *_rdNotificationTitle;
    NSString                    *_rdNotificationBody;
    
    IBOutlet NSView         *_rdInternalConfigurationView;
    IBOutlet NSTextField    *_rdActualText;
    IBOutlet NSTextField    *_rdTitleText;

}

- (id) initWithString:(NSString *) string title:(NSString *)title;

@end
