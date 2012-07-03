//
//  SocialBadge.m
//  NewsBlur
//
//  Created by Roy Yang on 7/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "SocialBadge.h"
#import "NewsBlurAppDelegate.h"
#import "Utilities.h"

@implementation SocialBadge

@synthesize appDelegate;
@synthesize userAvatar;
@synthesize username = _username;
@synthesize userLocation;
@synthesize userDescription;
@synthesize userStats;
@synthesize followButton;

- (void)baseInit {
    _username = nil;
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        [self baseInit];
    }
    return self;
}


- (void)dealloc {
    [appDelegate release];
    [userAvatar release];
    [username release];
    [userLocation release];
    [userDescription release];
    [userStats release];
    [followButton release];
    [super dealloc];
}

/*
// Only override drawRect: if you perform custom drawing.
// An empty implementation adversely affects performance during animation.
- (void)drawRect:(CGRect)rect
{
    // Drawing code
}
*/

- (void)layoutSubviews {
    [super layoutSubviews];    


}

- (void)refreshWithDict:(NSDictionary *)profile {
    
    
//    self.followingCount.text = [NSString stringWithFormat:@"%i", 
//                                [[results objectForKey:@"following_count"] intValue]];
//    self.followersCount.text = [NSString stringWithFormat:@"%i",
//                                [[results objectForKey:@"follower_count"] intValue]];
//    

//    
//    
//    // check following to toggle follow button
//    BOOL isFollowing = NO;
//    NSArray *followingUserIds = [appDelegate.dictUserProfile objectForKey:@"following_user_ids"];
//    for (int i = 0; i < followingUserIds.count ; i++) {
//        NSString *followingUserId = [NSString stringWithFormat:@"%@", [followingUserIds objectAtIndex:i]];
//        if ([followingUserId isEqualToString:[NSString stringWithFormat:@"%@", appDelegate.activeUserProfile]]) {
//            isFollowing = YES;
//        }
//    }    
//    if (isFollowing) {
//        [self.followButton setTitle:@"Following" forState:UIControlStateNormal];
//    }

    int yCoordinatePointer = 0;
    
    UILabel *user = [[UILabel alloc] initWithFrame:CGRectMake(80,0,320,20)];
    user.text = [profile objectForKey:@"username"]; 
    user.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
    user.font = [UIFont fontWithName:@"Helvetica-Bold" size:20];
    self.username = user;
    [self addSubview:self.username];
    yCoordinatePointer = self.username.frame.origin.y + self.username.frame.size.height + 6;
    [user release];
    
    if ([profile objectForKey:@"location"] != [NSNull null]) {
        UILabel *location = [[UILabel alloc] 
                             initWithFrame:CGRectMake(80, 
                                                      yCoordinatePointer, 
                                                      320, 
                                                      20)];
        location.text = [profile objectForKey:@"location"];
        location.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
        location.font = [UIFont fontWithName:@"Helvetica" size:12];
        self.userLocation = location;
        [self addSubview:self.userLocation];
        [location release];
        yCoordinatePointer = yCoordinatePointer + self.userLocation.frame.size.height + 6;
    } 
    
    if ([profile objectForKey:@"bio"] != [NSNull null]) {
        UILabel *bio = [[UILabel alloc] 
                             initWithFrame:CGRectMake(80, 
                                                      yCoordinatePointer, 
                                                      320, 
                                                      20)];
        bio.text = [profile objectForKey:@"bio"];
        bio.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
        bio.font = [UIFont fontWithName:@"Helvetica" size:14];
        self.userDescription = bio;
        [self addSubview:self.userDescription];
        [bio release];
        yCoordinatePointer = yCoordinatePointer + self.userDescription.frame.size.height + 6;

    } 
    
    UILabel *stats = [[UILabel alloc] initWithFrame:CGRectMake(80, yCoordinatePointer, 320, 20)];
    NSString *statsStr = [NSString stringWithFormat:@"%i shared stories · %i followers", 
                          [[profile objectForKey:@"shared_stories_count"] intValue],
                          [[profile objectForKey:@"follower_count"] intValue]];
    stats.text = statsStr;
    stats.font = [UIFont fontWithName:@"Helvetica" size:10];
    self.userStats = stats;
    [self addSubview:self.userStats];
    [stats release];
    

    NSURL *imageURL = [Utilities convertToAbsoluteURL:[profile objectForKey:@"photo_url"]];    
    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
    UIImage *image = [UIImage imageWithData:imageData];
    UIImageView *avatar = [[UIImageView alloc] initWithImage:image];    
    self.userAvatar = avatar;
    self.userAvatar.frame = CGRectMake(10, 10, 60, 60);
    [self addSubview:self.userAvatar];
    [avatar release];
}

- (IBAction)doFollowButton:(id)sender {
    if ([self.followButton.currentTitle isEqualToString:@"Following"]) {
        [self.followButton setTitle:@"Follow" forState:UIControlStateNormal];
    } else {
        [self.followButton setTitle:@"Following" forState:UIControlStateNormal];
    }
}
    

@end
