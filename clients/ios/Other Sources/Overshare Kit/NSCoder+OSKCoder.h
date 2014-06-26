//
//  NSCoder+OSKCoder.h
//  Overshare
//
//  Created by Jared Sinclair on 10/11/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@interface NSCoder (OSKCoder)

+ (void)osk_encodeObjectIfNotNil:(id)object forKey:(NSString *)key withCoder:(NSCoder *)anEncoder;

@end
