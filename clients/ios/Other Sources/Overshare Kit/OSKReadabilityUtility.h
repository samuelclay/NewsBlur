//
//  OSKReadabilityUtility.h
//  Overshare
//
//  Created by Jared Sinclair on 10/20/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@class OSKApplicationCredential;
@class OSKManagedAccount;
@class OSKManagedAccountCredential;

@interface OSKReadabilityUtility : NSObject

+ (void)signIn:(NSString *)username password:(NSString *)password appCredential:(OSKApplicationCredential *)appCredential completion:(void(^)(OSKManagedAccount *account, NSError *error))completion;

+ (void)saveURL:(NSURL *)URL withAccountCredential:(OSKManagedAccountCredential *)accountCredential appCredential:(OSKApplicationCredential *)appCredential completion:(void(^)(BOOL success, NSError *error))completion;

@end
