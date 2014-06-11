//
//  OSKMicrobloggingActivity.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

#import "OSKSyntaxHighlighting.h"

@class OSKMicroblogPostContentItem;

@protocol OSKMicrobloggingActivity <NSObject>

@property (assign, nonatomic) NSInteger remainingCharacterCount;

- (NSInteger)maximumCharacterCount;
- (NSInteger)maximumImageCount;
- (NSInteger)maximumUsernameLength;
- (NSInteger)updateRemainingCharacterCount:(OSKMicroblogPostContentItem *)contentItem urlEntities:(NSArray *)urlEntities;
- (OSKSyntaxHighlighting)syntaxHighlighting;

@optional

- (BOOL)allowLinkShortening; // OSK assumes YES.

@end
