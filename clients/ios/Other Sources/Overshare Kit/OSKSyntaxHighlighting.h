//
//  OSKSyntaxHighlighting.h
//  Overshare
//
//  Created by Jared on 3/20/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

@import Foundation;

typedef NS_ENUM(NSInteger, OSKSyntaxHighlighting) {
    OSKSyntaxHighlighting_None =        0,
    OSKSyntaxHighlighting_Links =       1 << 1,
    OSKSyntaxHighlighting_Usernames =   1 << 2,
    OSKSyntaxHighlighting_Hashtags =    1 << 3,
};
