//
//  OSKFacebookSharing.h
//  Overshare
//
//  Created by Jared on 3/20/14.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKFacebookContentItem;

#import "OSKSyntaxHighlighting.h"

@protocol OSKFacebookSharing <NSObject>

@property (assign, nonatomic) NSInteger remainingCharacterCount;

- (NSInteger)maximumCharacterCount;
- (NSInteger)maximumImageCount;
- (NSInteger)maximumUsernameLength;
- (NSInteger)updateRemainingCharacterCount:(OSKFacebookContentItem *)contentItem urlEntities:(NSArray *)urlEntities;
- (OSKSyntaxHighlighting)syntaxHighlighting;

@optional

- (BOOL)allowLinkShortening; // OSK assumes YES.

@end
