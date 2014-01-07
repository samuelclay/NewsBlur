//
//  OSKMicrobloggingActivity.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

typedef NS_ENUM(NSInteger, OSKMicroblogSyntaxHighlightingStyle) {
    OSKMicroblogSyntaxHighlightingStyle_Twitter,
    OSKMicroblogSyntaxHighlightingStyle_LinksOnly,
};

@protocol OSKMicrobloggingActivity <NSObject>

- (NSInteger)maximumCharacterCount;
- (NSInteger)maximumImageCount;
- (OSKMicroblogSyntaxHighlightingStyle)syntaxHighlightingStyle;
- (NSInteger)maximumUsernameLength;

@end
