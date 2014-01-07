//
//  OSKPinboardUtility.h
//  Overshare
//
//  Created by Jared Sinclair on 10/21/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKApplicationCredential;
@class OSKLinkBookmarkContentItem;
@class OSKManagedAccount;
@class OSKManagedAccountCredential;

@interface OSKPinboardUtility : NSObject

+ (void)signIn:(NSString *)username password:(NSString *)password completion:(void(^)(OSKManagedAccount *account, NSError *error))completion;

+ (void)addBookmark:(OSKLinkBookmarkContentItem *)linkItem withAccountCredential:(OSKManagedAccountCredential *)accountCredential completion:(void(^)(BOOL success, NSError *error))completion;

@end
