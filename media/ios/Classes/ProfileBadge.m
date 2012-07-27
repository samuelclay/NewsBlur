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
#import <QuartzCore/QuartzCore.h>

#define kTopBadgeHeight 125
#define kTopBadgeTextXCoordinate 110

@implementation ProfileBadge

@synthesize appDelegate;
@synthesize userAvatar;
@synthesize username;
@synthesize userLocation;
@synthesize userDescription;
@synthesize userStats;
@synthesize followButton;
@synthesize activeProfile;
@synthesize activityIndicator;


- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
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

- (void)refreshWithProfile:(NSDictionary *)profile {    
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
    
    NSURL *imageURL = [NSURL URLWithString:photo_url];
    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
    UIImage *image = [UIImage imageWithData:imageData];
    
    image = [Utilities roundCorneredImage:image radius:6];
    UIImageView *avatar = [[UIImageView alloc] initWithImage:image];
    avatar.frame = CGRectMake(20, 10, 80, 80);
    
    CALayer * l = [avatar layer];
    [l setMasksToBounds:YES];
    [l setCornerRadius:6.0];
    
    // scale and crop image
    [avatar setContentMode:UIViewContentModeScaleAspectFill];
    [avatar setClipsToBounds:YES];
    
    self.userAvatar = avatar;
    [self addSubview:self.userAvatar];
    
    // FOLLOW BUTTON
    UIButton *follow = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    follow.frame = CGRectMake(20, 96, 80, 24);
    
    // check follow button status
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictUserProfile objectForKey:@"user_id"]];   
    NSString *profileUserId = [NSString stringWithFormat:@"%@", [profile objectForKey:@"user_id"]];   
    NSLog(@"is following you %@", [profile objectForKey:@"following_you"]);
    
    if ([currentUserId isEqualToString:profileUserId]) {
        [follow setTitle:@"You" forState:UIControlStateNormal];
        follow.enabled = NO;
    } else if ([profile objectForKey:@"following_you"]) {
        [follow setTitle:@"Following" forState:UIControlStateNormal];
    } else {
        [follow setTitle:@"Follow" forState:UIControlStateNormal];
    }
    
    follow.titleLabel.font = [UIFont systemFontOfSize:12];
    [follow addTarget:self 
               action:@selector(doFollowButton:) 
     forControlEvents:UIControlEventTouchUpInside];
    
    self.followButton = follow;
    [self addSubview:self.followButton];
    
    // ACTIVITY INDICATOR
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityView.frame = CGRectMake(50, 98, 20, 20.0);
    self.activityIndicator = activityView;
    [self addSubview:self.activityIndicator];
    
    // USERNAME
    UILabel *user = [[UILabel alloc] initWithFrame:CGRectMake(kTopBadgeTextXCoordinate, 10, 190, 22)];
    user.text = [profile objectForKey:@"username"]; 
    user.textColor = UIColorFromRGB(0xAE5D15);
    user.font = [UIFont fontWithName:@"Helvetica-Bold" size:18];
    user.backgroundColor = [UIColor clearColor];
    self.username = user;
    [self addSubview:self.username];
    yCoordinatePointer = self.username.frame.origin.y + self.username.frame.size.height;
        
    // BIO
    if ([profile objectForKey:@"bio"] != [NSNull null]) {
        UILabel *bio = [[UILabel alloc] 
                             initWithFrame:CGRectMake(kTopBadgeTextXCoordinate, 
                                                      yCoordinatePointer, 
                                                      190, 
                                                      60)];
        bio.text = [profile objectForKey:@"bio"];
        bio.textColor = UIColorFromRGB(0x333333);
        bio.font = [UIFont fontWithName:@"Helvetica" size:12];
        bio.lineBreakMode = UILineBreakModeTailTruncation;
        bio.numberOfLines = 5;
        bio.backgroundColor = [UIColor clearColor];
        
        // Calculate the expected size based on the font and linebreak mode of your label
        CGSize maximumLabelSize = CGSizeMake(190, 60);
        CGSize expectedLabelSize = [bio.text
                                    sizeWithFont:bio.font 
                                    constrainedToSize:maximumLabelSize 
                                    lineBreakMode:bio.lineBreakMode];
        CGRect newFrame = bio.frame;
        newFrame.size.height = expectedLabelSize.height;
        bio.frame = newFrame;
        
        self.userDescription = bio;
        [self addSubview:self.userDescription];
        yCoordinatePointer = yCoordinatePointer + self.userDescription.frame.size.height + 6;
    } 
    
    // LOCATION
    if ([profile objectForKey:@"location"] != [NSNull null]) {
        UILabel *location = [[UILabel alloc] 
                             initWithFrame:CGRectMake(kTopBadgeTextXCoordinate + 16, 
                                                      yCoordinatePointer, 
                                                      190, 
                                                      20)];
        location.text = [profile objectForKey:@"location"];
        location.textColor = UIColorFromRGB(0x666666);
        location.backgroundColor = [UIColor clearColor];
        location.font = [UIFont fontWithName:@"Helvetica" size:12];
        self.userLocation = location;
        [self addSubview:self.userLocation];
        
        UIImage *locationIcon = [UIImage imageNamed:@"7-location-place.png"];
        UIImageView *locationIconView = [[UIImageView alloc] initWithImage:locationIcon];
        locationIconView.Frame = CGRectMake(kTopBadgeTextXCoordinate,
                                            yCoordinatePointer + 2, 
                                            16, 
                                            16);
        [self addSubview:locationIconView];
    } 
    
    UIView *horizontalBar = [[UIView alloc] initWithFrame:CGRectMake(10, kTopBadgeHeight, self.frame.size.width - 20, 1)];
    horizontalBar.backgroundColor = [UIColor lightGrayColor];
    horizontalBar.autoresizingMask = 0x3f;
    [self addSubview:horizontalBar];
    
    UIView *leftVerticalBar = [[UIView alloc] initWithFrame:CGRectMake(((self.frame.size.width - 20)/3) + 10, kTopBadgeHeight, 1, 55)];
    leftVerticalBar.backgroundColor = [UIColor lightGrayColor];
    [self addSubview:leftVerticalBar];
    
    UIView *rightVerticalBar = [[UIView alloc] initWithFrame:CGRectMake(((self.frame.size.width - 20)/3)*2 + 10, kTopBadgeHeight, 1, 55)];
    rightVerticalBar.backgroundColor = [UIColor lightGrayColor];
    [self addSubview:rightVerticalBar];
    
    // Shared
    UILabel *shared = [[UILabel alloc] initWithFrame:CGRectMake(20, kTopBadgeHeight + 10, 80, 20)];
    NSString *sharedStr = [NSString stringWithFormat:@"%i",
                              [[profile objectForKey:@"shared_stories_count"] intValue]];
    shared.text = sharedStr;
    shared.textAlignment = UITextAlignmentCenter;
    shared.font = [UIFont boldSystemFontOfSize:20];
    shared.backgroundColor = [UIColor clearColor];
    [self addSubview:shared];
    
    UILabel *sharedLabel = [[UILabel alloc] initWithFrame:CGRectMake(20, kTopBadgeHeight + 30, 80, 20)];
    NSString *sharedLabelStr = [NSString stringWithFormat:@"Shared Stor%@",
                                [[profile objectForKey:@"shared_stories_count"] intValue] == 1 ? @"y" : @"ies"];
    sharedLabel.text = sharedLabelStr;
    sharedLabel.textAlignment = UITextAlignmentCenter;
    sharedLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
    sharedLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:sharedLabel];
    
    
    // Following
    UILabel *following = [[UILabel alloc] initWithFrame:CGRectMake(120, kTopBadgeHeight + 10, 80, 20)];
    NSString *followingStr = [NSString stringWithFormat:@"%i",
                          [[profile objectForKey:@"following_count"] intValue]];
    following.text = followingStr;
    following.textAlignment = UITextAlignmentCenter;
    following.font = [UIFont boldSystemFontOfSize:20];
    following.backgroundColor = [UIColor clearColor];
    [self addSubview:following];
    
    UILabel *followingLabel = [[UILabel alloc] initWithFrame:CGRectMake(120, kTopBadgeHeight + 30, 80, 20)];
    NSString *followingLabelStr = [NSString stringWithFormat:@"Following"];
    followingLabel.text = followingLabelStr;
    followingLabel.textAlignment = UITextAlignmentCenter;
    followingLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
    followingLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:followingLabel];
    
    
    // Followers
    UILabel *followers = [[UILabel alloc] initWithFrame:CGRectMake(220, kTopBadgeHeight + 10, 80, 20)];
    NSString *followersStr = [NSString stringWithFormat:@"%i", 
                              [[profile objectForKey:@"follower_count"] intValue]];
    followers.text = followersStr;
    followers.textAlignment = UITextAlignmentCenter;
    followers.font = [UIFont boldSystemFontOfSize:20];
    followers.backgroundColor = [UIColor clearColor];
    [self addSubview:followers];
    
    UILabel *followersLabel = [[UILabel alloc] initWithFrame:CGRectMake(220, kTopBadgeHeight + 30, 80, 20)];
    NSString *followersLabelStr = [NSString stringWithFormat:@"Follower%@", 
                              [[profile objectForKey:@"follower_count"] intValue] == 1 ? @"" : @"s"];
    followersLabel.text = followersLabelStr;
    followersLabel.textAlignment = UITextAlignmentCenter;
    followersLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
    followersLabel.backgroundColor = [UIColor clearColor];
    [self addSubview:followersLabel];
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
        urlString = [NSString stringWithFormat:@"http://%@/social/follow",
                               NEWSBLUR_URL,
                               [self.activeProfile objectForKey:@"user_id"]];
    } else {
        urlString = [NSString stringWithFormat:@"http://%@/social/unfollow",
                               NEWSBLUR_URL,
                               [self.activeProfile objectForKey:@"user_id"]];
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
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

@end