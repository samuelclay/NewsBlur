//
//  OSKKeychainUtility.h
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@interface OSKKeychainUtility : NSObject

+ (void)saveString:(NSString *)inputString forKey:(NSString *)key;
+ (NSString *)getStringForKey:(NSString *)key;
+ (void)deleteStringForKey:(NSString *)key;

@end






