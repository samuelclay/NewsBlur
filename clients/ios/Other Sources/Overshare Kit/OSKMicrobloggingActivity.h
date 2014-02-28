//
//  OSKMicrobloggingActivity.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKMicroblogPostContentItem;

typedef NS_ENUM(NSInteger, OSKMicroblogSyntaxHighlightingStyle) {
    OSKMicroblogSyntaxHighlightingStyle_Twitter,
    OSKMicroblogSyntaxHighlightingStyle_LinksOnly,
};

@protocol OSKMicrobloggingActivity <NSObject>

@property (assign, nonatomic) NSInteger remainingCharacterCount;

- (NSInteger)maximumCharacterCount;
- (NSInteger)maximumImageCount;
- (NSInteger)maximumUsernameLength;
- (NSInteger)updateRemainingCharacterCount:(OSKMicroblogPostContentItem *)contentItem urlEntities:(NSArray *)urlEntities;
- (OSKMicroblogSyntaxHighlightingStyle)syntaxHighlightingStyle;

@optional

- (BOOL)allowLinkShortening; // OSK assumes YES.

@end
