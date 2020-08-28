//
//  DataUtilities.m
//  NewsBlur
//
//  Created by Roy Yang on 7/20/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "DataUtilities.h"
#import "NewsBlurAppDelegate.h"
#import "StoriesCollection.h"
#import "NewsBlur-Swift.h"

@implementation DataUtilities

+ (NSArray *)updateUserProfiles:(NSArray *)userProfiles withNewUserProfiles:(NSArray *)newUserProfiles {

    NSMutableArray *updatedUserProfiles = [userProfiles mutableCopy];
    
    for (int i = 0; i < newUserProfiles.count; i++) {
        BOOL isInUserProfiles = NO;
        NSDictionary *newUser = [newUserProfiles objectAtIndex:i];
        NSString *newUserIdStr = [NSString stringWithFormat:@"%@", [newUser objectForKey:@"user_id"]];
        
        for (int j = 0; j < userProfiles.count; j++) {
            NSDictionary *user = [userProfiles objectAtIndex:j];
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

+ (NSDictionary *)updateComment:(NSDictionary *)newComment for:(NewsBlurAppDelegate *)appDelegate {
    NSDictionary *comment = [newComment objectForKey:@"comment"];
    NSArray *userProfiles = [newComment objectForKey:@"user_profiles"];
    
    appDelegate.storiesCollection.activeFeedUserProfiles = [DataUtilities
                                                            updateUserProfiles:appDelegate.storiesCollection.activeFeedUserProfiles
                                                            withNewUserProfiles:userProfiles];
    
    NSString *commentUserId = [NSString stringWithFormat:@"%@", [comment objectForKey:@"user_id"]];
    BOOL foundComment = NO;
    
    NSArray *friendComments = [appDelegate.activeStory objectForKey:@"friend_comments"];
    NSMutableArray *newFriendsComments = [[NSMutableArray alloc] init];
    for (int i = 0; i < friendComments.count; i++) {
        NSString *userId = [NSString stringWithFormat:@"%@", 
                            [[friendComments objectAtIndex:i] objectForKey:@"user_id"]];
        if([userId isEqualToString:commentUserId]){
            [newFriendsComments addObject:comment];
            foundComment = YES;
        } else {
            [newFriendsComments addObject:[friendComments objectAtIndex:i]];
        }
    }
    
    BOOL foundShare = NO;
    NSArray *friendShares = [appDelegate.activeStory objectForKey:@"friend_shares"];
    NSMutableArray *newFriendsShares = [[NSMutableArray alloc] init];
    for (int i = 0; i < friendShares.count; i++) {
        NSString *userId = [NSString stringWithFormat:@"%@",
                            [[friendShares objectAtIndex:i] objectForKey:@"user_id"]];
        if([userId isEqualToString:commentUserId]){
            [newFriendsShares addObject:comment];
            foundShare = YES;
        } else {
            [newFriendsShares addObject:[friendShares objectAtIndex:i]];
        }
    }
    
    // make mutable copy
    NSMutableDictionary *newActiveStory = [appDelegate.activeStory mutableCopy];
    
    if (!foundComment && !foundShare) {
        NSArray *publicComments = [appDelegate.activeStory objectForKey:@"public_comments"];
        NSMutableArray *newPublicComments = [[NSMutableArray alloc] init];
        for (int i = 0; i < publicComments.count; i++) {
            NSString *userId = [NSString stringWithFormat:@"%@", 
                                [[publicComments objectAtIndex:i] objectForKey:@"user_id"]];
            if([userId isEqualToString:commentUserId]){
                [newPublicComments addObject:comment];
            } else {
                [newPublicComments addObject:[publicComments objectAtIndex:i]];
            }
        }
        
        [newActiveStory setValue:[NSArray arrayWithArray:newPublicComments] forKey:@"public_comments"];
    } else if (foundComment) {
        [newActiveStory setValue:[NSArray arrayWithArray:newFriendsComments] forKey:@"friend_comments"];
    } else if (foundShare) {
        [newActiveStory setValue:[NSArray arrayWithArray:newFriendsShares] forKey:@"friend_shares"];
    }
    
    NSDictionary *newStory = [NSDictionary dictionaryWithDictionary:newActiveStory];

    return newStory;
}

@end
