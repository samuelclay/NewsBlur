//
//  OSKInstapaperUtility.h
//  Overshare
//
//  Created by Jared Sinclair on 10/19/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKManagedAccount;
@class OSKManagedAccountCredential;

@interface OSKInstapaperUtility : NSObject

+ (void)createNewAccountWithUsername:(NSString *)username
                            password:(NSString *)password
                          completion:(void(^)(OSKManagedAccount *account, NSError *error))completion;

+ (void)saveURL:(NSURL *)URL
     credential:(OSKManagedAccountCredential *)credential
     completion:(void(^)(BOOL success, NSError *error))completion;

@end
