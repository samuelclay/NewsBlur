//
//  OSKFileManager.h
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//
//  Based on code by Jamin Guy for Riposte http://alpha.app.net/jaminguy
//

@import UIKit; 

@interface OSKFileManager : NSObject

+ (id)sharedInstance;

- (void)saveObject:(id <NSSecureCoding, NSCopying>)object forKey:(NSString *)key completion:(void(^)(void))completion completionQueue:(dispatch_queue_t)queue;
- (id)loadSavedObjectForKey:(NSString *)key;
- (void)deleteSavedObjectForKey:(NSString *)key completion:(void (^)(void))completion completionQueue:(dispatch_queue_t)queue;

@end
