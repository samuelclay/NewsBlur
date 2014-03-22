//
//  OSKKeychainUtility.m
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//
// Based on code by Michael Mayo at http://overhrd.com/?p=208
//

#import "OSKKeychainUtility.h"

#import <Security/Security.h>
#import "OSKLogger.h"

@implementation OSKKeychainUtility

+ (void)saveString:(NSString *)inputString forKey:(NSString	*)key {
	NSAssert(key != nil, @"Invalid key");
	NSAssert(inputString != nil, @"Invalid string");
    
    // Always delete the prior key first, updating existing keys
    // fails irrecoverably under certain conditions.
    [OSKKeychainUtility deleteStringForKey:key];
	
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
	query[(__bridge id)kSecAttrAccount] = key;
	query[(__bridge id)kSecAttrAccessible] = (__bridge id)kSecAttrAccessibleAlways;
	query[(__bridge id)kSecValueData] = [inputString dataUsingEncoding:NSUTF8StringEncoding];
		
    OSStatus error = SecItemAdd((__bridge CFDictionaryRef)query, NULL);
    
    if (error == errSecSuccess) {
        OSKLog(@"Successfully added item to Keychain for key: %@", key);
    } else {
        OSKLog(@"FAILED to add item to Keychain for key: %@", key);
    }
}

+ (NSString *)getStringForKey:(NSString *)key {
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
	query[(__bridge id)kSecAttrAccount] = key;
	query[(__bridge id)kSecReturnData] = (__bridge id)kCFBooleanTrue;
    
	CFDataRef dataFromKeychain = nil;
    
	OSStatus error = SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&dataFromKeychain);
	
	NSString *stringToReturn = nil;
	if (error == errSecSuccess) {
        NSData *data = (__bridge NSData *)dataFromKeychain;
		stringToReturn = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	}
	
	return stringToReturn;
}

+ (void)deleteStringForKey:(NSString *)key {
	NSMutableDictionary *query = [NSMutableDictionary dictionary];
	query[(__bridge id)kSecClass] = (__bridge id)kSecClassGenericPassword;
	query[(__bridge id)kSecAttrAccount] = key;
    
	OSStatus status = SecItemDelete((__bridge CFDictionaryRef)query);
    
	if (status != errSecSuccess) {
		OSKLog(@"SecItemDelete failed: %d", (int)status);
	}
}

@end