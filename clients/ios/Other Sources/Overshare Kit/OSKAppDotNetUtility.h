//
//  OSKAppDotNetUtility.h
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKApplicationCredential;
@class OSKManagedAccount;
@class OSKManagedAccountCredential;
@class OSKMicroblogPostContentItem;

static NSString * OSKAppDotNetUtility_UserInfoKey_username = @"username";
static NSString * OSKAppDotNetUtility_UserInfoKey_name = @"name";
static NSString * OSKAppDotNetUtility_UserInfoKey_accountID = @"accountID";
static NSString * OSKAppDotNetUtility_UserInfoKey_avatarURL = @"avatarURL";

@interface OSKAppDotNetUtility : NSObject

+ (void)postContentItem:(OSKMicroblogPostContentItem *)item
         withCredential:(OSKManagedAccountCredential *)credential
          appCredential:(OSKApplicationCredential *)appCredential
             completion:(void(^)(BOOL success, NSError *error))completion; // called on main queue

+ (void)fetchUserDataWithCredential:(OSKManagedAccountCredential *)credential
                      appCredential:(OSKApplicationCredential *)appCredential
                         completion:(void(^)(NSDictionary *userDictionary, NSError *error))completion; // called on main queue

+ (void)createNewUserWithAccessToken:(NSString *)token
                       appCredential:(OSKApplicationCredential *)appCredential
                          completion:(void(^)(OSKManagedAccount *account, NSError *error))completion;

+ (void)uploadImage:(UIImage *)image
  accountCredential:(OSKManagedAccountCredential *)credential
      appCredential:(OSKApplicationCredential *)appCredential
         completion:(void (^)(NSDictionary *, NSError *))completion;

@end



