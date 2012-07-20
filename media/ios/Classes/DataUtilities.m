//
//  DataUtilities.m
//  NewsBlur
//
//  Created by Roy Yang on 7/20/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "DataUtilities.h"
#import "NewsBlurAppDelegate.h"

@implementation DataUtilities

+ (NSArray *)updateUserProfiles:(NSArray *)userProfiles withNewUserProfiles:(NSArray *)newUserProfiles {

    NSMutableArray *updatedUserProfiles = [userProfiles mutableCopy];
    
    for (int i = 0; i < newUserProfiles.count; i++) {
        BOOL isInUserProfiles = NO;
        NSDictionary *newUser = [newUserProfiles objectAtIndex:i];
        NSString *newUserIdStr = [NSString stringWithFormat:@"%@", [newUser objectForKey:@"user_id"]];
        
        for (int j = 0; j < userProfiles.count; j++) {
            NSDictionary *user = [userProfiles objectAtIndex:i];
            NSString *userIdStr = [NSString stringWithFormat:@"%@", [user objectForKey:@"user_id"]];
            if ([newUserIdStr isEqualToString:userIdStr]) {
                isInUserProfiles = YES;
                break;
            }
        }
        
        if (!isInUserProfiles) {
            [updatedUserProfiles addObject:newUser];
        }
    }
    return updatedUserProfiles;
}

@end
