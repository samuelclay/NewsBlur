//
//  DataUtilities.h
//  NewsBlur
//
//  Created by Roy Yang on 7/20/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

@class NewsBlurAppDelegate;

@interface DataUtilities : NSObject

+ (NSArray *)updateUserProfiles:(NSArray *)userProfiles withNewUserProfiles:(NSArray *)newUserProfiles;
+ (NSDictionary *)updateComment:(NSDictionary *)newCommen for:(NewsBlurAppDelegate *)appDelegate;

@end
