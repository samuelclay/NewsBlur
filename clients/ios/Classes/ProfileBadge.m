//
//  ProfileBadge.m
//  NewsBlur
//
//  Created by Roy Yang on 7/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "ProfileBadge.h"
#import "NewsBlurAppDelegate.h"
#import "Utilities.h"
#import "ASIHTTPRequest.h"
#import "UIImageView+AFNetworking.h"
#import <QuartzCore/QuartzCore.h>

#define kTopBadgeHeight 125
#define kTopBadgeTextXCoordinate 100
#define kFollowColor 0x0a6720
#define kFollowTextColor 0xffffff
#define kFollowingColor 0xcccccc
#define kFollowingTextColor 0x333333

@interface ProfileBadge ()

@property (readwrite) int moduleWidth;
@property (readwrite) BOOL shouldShowStats;

@end

@implementation ProfileBadge

@synthesize shouldShowStats;
@synthesize appDelegate;
@synthesize userAvatar;
@synthesize username;
@synthesize userLocation;
@synthesize userDescription;
@synthesize userStats;
@synthesize followButton;
@synthesize activeProfile;
@synthesize activityIndicator;
@synthesize moduleWidth;


- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        userAvatar = nil;
        username = nil;
        userLocation = nil;
        userDescription = nil;
        userStats = nil;
        followButton = nil;
        activeProfile = nil;
        activityIndicator = nil;
    }
    
    return self;
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

- (void)refreshWithProfile:(NSDictionary *)profile showStats:(BOOL)showStats withWidth:(int)newWidth {
    int width;

    if (newWidth) {
        width = newWidth;
        self.moduleWidth = newWidth;
    } else {
        width = self.moduleWidth;
        for (UIView *subview in [self.contentView subviews]) {
            [subview removeFromSuperview];
        }
    }
    
    self.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
    if (showStats) {
        shouldShowStats = showStats;
    }    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];    
    self.activeProfile = profile;
    int yCoordinatePointer = 0;

    // AVATAR
    NSString *photo_url = [profile objectForKey:@"photo_url"];
    
    if ([photo_url rangeOfString:@"graph.facebook.com"].location != NSNotFound) {
        photo_url = [photo_url stringByAppendingFormat:@"?type=large"];
    }
    
    if ([photo_url rangeOfString:@"twimg"].location != NSNotFound) {
        photo_url = [photo_url stringByReplacingOccurrencesOfString:@"_normal" withString:@""];        
    }
    
//    UIImage *placeholder = [UIImage imageNamed:@"user_light"];
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.frame = CGRectMake(10, 10, 80, 80);

    [avatar setImageWithURL:[NSURL URLWithString:photo_url]
                    placeholderImage:nil];
    
    // scale and crop image
    [avatar setContentMode:UIViewContentModeScaleAspectFill];
    [avatar setClipsToBounds:YES];
    [self.contentView addSubview:avatar];
    
    // username
    UILabel *user = [[UILabel alloc] initWithFrame:CGRectZero];
    user.textColor = UIColorFromFixedRGB(NEWSBLUR_LINK_COLOR);
    user.font = [UIFont fontWithName:@"Helvetica-Bold" size:18];
    user.backgroundColor = [UIColor clearColor];
    self.username = user;
    self.username.frame = CGRectMake(kTopBadgeTextXCoordinate, 10, width - kTopBadgeTextXCoordinate - 10, 22);
    self.username.text = [profile objectForKey:@"username"]; 
    [self.contentView addSubview:username];
    
    // FOLLOW BUTTON
    UIButton *follow = [UIButton buttonWithType:UIButtonTypeCustom];
    follow.frame = CGRectMake(10, 96, 80, 24);
    
    follow.layer.borderColor = UIColorFromRGB(0x808080).CGColor;
    follow.layer.borderWidth = 0.5f;
    follow.layer.cornerRadius = 10.0f;
    
    [follow setTitleColor:UIColorFromFixedRGB(kFollowTextColor) forState:UIControlStateNormal];
    follow.backgroundColor = UIColorFromFixedRGB(kFollowColor);
    
    // check follow button status    
    if ([[profile objectForKey:@"yourself"] intValue]) {
        [follow setTitle:@"You" forState:UIControlStateNormal];
        follow.enabled = NO;
    } else if ([[profile objectForKey:@"followed_by_you"] intValue]) {
        [follow setTitle:@"Following" forState:UIControlStateNormal];
        follow.backgroundColor = UIColorFromFixedRGB(kFollowingColor);
        [follow setTitleColor:UIColorFromFixedRGB(kFollowingTextColor) forState:UIControlStateNormal];
    } else {
        [follow setTitle:@"Follow" forState:UIControlStateNormal];
    }
    
    follow.titleLabel.font = [UIFont systemFontOfSize:12];
    [follow addTarget:self 
               action:@selector(doFollowButton:) 
     forControlEvents:UIControlEventTouchUpInside];
    
    self.followButton = follow;
    [self.contentView addSubview:self.followButton];
    
    // ACTIVITY INDICATOR
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityView.frame = CGRectMake(40, 98, 20, 20.0);
    self.activityIndicator = activityView;
    
    [self.contentView addSubview:self.activityIndicator];
    
    yCoordinatePointer = self.username.frame.origin.y + self.username.frame.size.height;
        
    // BIO
    if ([profile objectForKey:@"bio"] != [NSNull null]) {
        UILabel *bio = [[UILabel alloc] 
                             initWithFrame:CGRectMake(kTopBadgeTextXCoordinate, 
                                                      yCoordinatePointer, 
                                                      width - kTopBadgeTextXCoordinate - 10, 
                                                      60)];
        bio.text = [profile objectForKey:@"bio"];
        bio.textColor = UIColorFromRGB(0x333333);
        bio.font = [UIFont fontWithName:@"Helvetica" size:12];
        bio.lineBreakMode = NSLineBreakByTruncatingTail;
        bio.numberOfLines = 5;
        bio.backgroundColor = [UIColor clearColor];
        
        // Calculate the expected size based on the font and linebreak mode of your label
        CGSize maximumLabelSize = CGSizeMake(width - kTopBadgeTextXCoordinate - 10, 60);
        NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
        paragraphStyle.lineBreakMode = bio.lineBreakMode;
        CGSize expectedLabelSize = [bio.text
                                    boundingRectWithSize:maximumLabelSize
                                    options:nil
                                    attributes:@{NSFontAttributeName: bio.font,
                                                 NSParagraphStyleAttributeName: paragraphStyle}
                                    context:nil].size;
        CGRect newFrame = bio.frame;
        newFrame.size.height = expectedLabelSize.height;
        bio.frame = newFrame;
        
        self.userDescription = bio;
        [self.contentView addSubview:self.userDescription];
        yCoordinatePointer = yCoordinatePointer + self.userDescription.frame.size.height + 6;
    } 
    
    // LOCATION
    if ([profile objectForKey:@"location"] != [NSNull null] &&
        [[profile objectForKey:@"location"] length]) {
        UILabel *location = [[UILabel alloc] 
                             initWithFrame:CGRectMake(kTopBadgeTextXCoordinate + 16, 
                                                      yCoordinatePointer, 
                                                      width - kTopBadgeTextXCoordinate - 10 - 16, 
                                                      20)];
        location.text = [profile objectForKey:@"location"];
        location.textColor = UIColorFromRGB(0x666666);
        location.backgroundColor = [UIColor clearColor];
        location.font = [UIFont fontWithName:@"Helvetica" size:12];
        self.userLocation = location;
        [self.contentView addSubview:self.userLocation];
        
        UIImage *locationIcon = [UIImage imageNamed:@"7-location-place.png"];
        UIImageView *locationIconView = [[UIImageView alloc] initWithImage:locationIcon];
        locationIconView.frame = CGRectMake(kTopBadgeTextXCoordinate,
                                            yCoordinatePointer + 2, 
                                            16, 
                                            16);
        [self.contentView addSubview:locationIconView];
    } 
    
    if (shouldShowStats) {
        UIView *horizontalBar = [[UIView alloc] initWithFrame:CGRectMake(0, kTopBadgeHeight, width, 1)];
        horizontalBar.backgroundColor = UIColorFromRGB(0xCBCBCB);
        [self.contentView addSubview:horizontalBar];
        
        UIView *leftVerticalBar = [[UIView alloc] initWithFrame:CGRectMake((width/3), kTopBadgeHeight, 1, 55)];
        leftVerticalBar.backgroundColor = UIColorFromRGB(0xCBCBCB);
        [self.contentView addSubview:leftVerticalBar];
        
        UIView *rightVerticalBar = [[UIView alloc] initWithFrame:CGRectMake((width/3) * 2, kTopBadgeHeight, 1, 55)];
        rightVerticalBar.backgroundColor = UIColorFromRGB(0xCBCBCB);
        [self.contentView addSubview:rightVerticalBar];
        
        // Shared
        UILabel *shared = [[UILabel alloc] initWithFrame:CGRectMake(0, kTopBadgeHeight + 10, (width/3), 20)];
        NSString *sharedStr = [NSString stringWithFormat:@"%i",
                               [[profile objectForKey:@"shared_stories_count"] intValue]];
        shared.text = sharedStr;
        shared.textAlignment = NSTextAlignmentCenter;
        shared.font = [UIFont boldSystemFontOfSize:20];
        shared.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
        shared.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:shared];
        
        UILabel *sharedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, kTopBadgeHeight + 30, (width/3), 20)];
        NSString *sharedLabelStr = [NSString stringWithFormat:@"Shared Stor%@",
                                    [[profile objectForKey:@"shared_stories_count"] intValue] == 1 ? @"y" : @"ies"];
        sharedLabel.text = sharedLabelStr;
        sharedLabel.textAlignment = NSTextAlignmentCenter;
        sharedLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
        sharedLabel.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
        sharedLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:sharedLabel];
        
        
        // Following
        UILabel *following = [[UILabel alloc] initWithFrame:CGRectMake((width/3), kTopBadgeHeight + 10, (width/3), 20)];
        NSString *followingStr = [NSString stringWithFormat:@"%i",
                                  [[profile objectForKey:@"following_count"] intValue]];
        following.text = followingStr;
        following.textAlignment = NSTextAlignmentCenter;
        following.font = [UIFont boldSystemFontOfSize:20];
        following.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
        following.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:following];
        
        UILabel *followingLabel = [[UILabel alloc] initWithFrame:CGRectMake((width/3), kTopBadgeHeight + 30, (width/3), 20)];
        NSString *followingLabelStr = [NSString stringWithFormat:@"Following"];
        followingLabel.text = followingLabelStr;
        followingLabel.textAlignment = NSTextAlignmentCenter;
        followingLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
        followingLabel.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
        followingLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:followingLabel];
        
        
        // Followers
        UILabel *followers = [[UILabel alloc] initWithFrame:CGRectMake((width/3) * 2, kTopBadgeHeight + 10, (width/3), 20)];
        NSString *followersStr = [NSString stringWithFormat:@"%i", 
                                  [[profile objectForKey:@"follower_count"] intValue]];
        followers.text = followersStr;
        followers.textAlignment = NSTextAlignmentCenter;
        followers.font = [UIFont boldSystemFontOfSize:20];
        followers.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
        followers.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:followers];
        
        UILabel *followersLabel = [[UILabel alloc] initWithFrame:CGRectMake((width/3) * 2, kTopBadgeHeight + 30, (width/3), 20)];
        NSString *followersLabelStr = [NSString stringWithFormat:@"Follower%@", 
                                       [[profile objectForKey:@"follower_count"] intValue] == 1 ? @"" : @"s"];
        followersLabel.text = followersLabelStr;
        followersLabel.textAlignment = NSTextAlignmentCenter;
        followersLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
        followersLabel.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
        followersLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:followersLabel];
    }

    
}

- (void)initProfile {
    for(UIView *subview in [self subviews]) {
        [subview removeFromSuperview];
        
    }
}

- (void)doFollowButton:(id)sender {
    NSString *urlString;
    
    [self.activityIndicator startAnimating];
    
    if ([self.followButton.currentTitle isEqualToString:@"Follow"]) {
        urlString = [NSString stringWithFormat:@"%@/social/follow",
                               self.appDelegate.url];
    } else {
        urlString = [NSString stringWithFormat:@"%@/social/unfollow",
                               self.appDelegate.url];
    }
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setDelegate:self];
    [request setPostValue:[self.activeProfile objectForKey:@"user_id"] forKey:@"user_id"];
    if ([self.followButton.currentTitle isEqualToString:@"Follow"]) {
        [request setDidFinishSelector:@selector(finishFollowing:)];        
    } else {
        [request setDidFinishSelector:@selector(finishUnfollowing:)];
    }
    [request setDidFailSelector:@selector(requestFailed:)];
    
    [request startAsynchronous];
}

- (void)finishFollowing:(ASIHTTPRequest *)request {

    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];

    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"ERROR");
        return;
    } 
    
    [self.followButton setTitle:@"Following" forState:UIControlStateNormal];
    self.followButton.backgroundColor = UIColorFromFixedRGB(kFollowColor);
    [self.followButton setTitleColor:UIColorFromFixedRGB(kFollowTextColor) forState:UIControlStateNormal];
    [appDelegate reloadFeedsView:NO];
    
    NSMutableDictionary *newProfile = [self.activeProfile mutableCopy];
    NSNumber *count = [newProfile objectForKey:@"follower_count"];
    int value = [count intValue];
    count = [NSNumber numberWithInt:value + 1];
    
    [newProfile setObject:count forKey:@"follower_count"];
    [newProfile setObject:[NSNumber numberWithInt:1] forKey:@"followed_by_you"];
    [self refreshWithProfile:newProfile showStats:self.shouldShowStats withWidth:0];
}


- (void)finishUnfollowing:(ASIHTTPRequest *)request {
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"ERROR");
        return;
    } 
    
    NSLog(@"results %@", results);
    [self.followButton setTitle:@"Follow" forState:UIControlStateNormal];
    self.followButton.backgroundColor = UIColorFromFixedRGB(kFollowingColor);
    [self.followButton setTitleColor:UIColorFromFixedRGB(kFollowingTextColor) forState:UIControlStateNormal];
    
    [appDelegate reloadFeedsView:NO];
    
    NSMutableDictionary *newProfile = [self.activeProfile mutableCopy];
    NSNumber *count = [newProfile objectForKey:@"follower_count"];
    int value = [count intValue];
    count = [NSNumber numberWithInt:value - 1];
    
    [newProfile setObject:count forKey:@"follower_count"];
    [newProfile setObject:[NSNumber numberWithInt:0] forKey:@"followed_by_you"];
    [self refreshWithProfile:newProfile showStats:self.shouldShowStats withWidth:0];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}
@end