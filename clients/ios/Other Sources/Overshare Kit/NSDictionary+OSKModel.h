//
//  NSDictionary+OSKModel.h
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@interface NSDictionary (OSKModel)

- (NSString *)osk_nonNullStringIDForKey:(NSString *)key;
- (id)osk_nonNullObjectForKey:(NSString *)key;

@end
