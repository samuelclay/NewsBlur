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

- (void)refreshWithProfile:(NSDictionary *)profile showStats:(BOOL)showStats withWidth:(int)width {    
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
    
    UIImage *placeholder = [UIImage imageNamed:@"user"];
    UIImageView *avatar = [[UIImageView alloc] init];
    avatar.frame = CGRectMake(10, 10, 80, 80);

    [avatar setImageWithURL:[NSURL URLWithString:photo_url]
                    placeholderImage:placeholder];
    
    // scale and crop image
    [avatar setContentMode:UIViewContentModeScaleAspectFill];
    [avatar setClipsToBounds:YES];
    [self.contentView addSubview:avatar];
    
    // username
    UILabel *user = [[UILabel alloc] initWithFrame:CGRectZero];
    user.textColor = UIColorFromRGB(0xAE5D15);
    user.font = [UIFont fontWithName:@"Helvetica-Bold" size:18];
    user.backgroundColor = [UIColor clearColor];
    self.username = user;
    self.username.frame = CGRectMake(kTopBadgeTextXCoordinate, 10, width - kTopBadgeTextXCoordinate - 10, 22);
    self.username.text = [profile objectForKey:@"username"]; 
    [self.contentView addSubview:username];

    
    // FOLLOW BUTTON
    UIButton *follow = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    follow.frame = CGRectMake(10, 96, 80, 24);
    
    NSString *profileUsername = [NSString stringWithFormat:@"%@", [profile objectForKey:@"username"]];   
    
    // check follow button status    
    if ([profileUsername isEqualToString:@"You"]) {
        [follow setTitle:@"You" forState:UIControlStateNormal];
        follow.enabled = NO;
    } else if ([[profile objectForKey:@"followed_by_you"] intValue]) {
        [follow setTitle:@"Following" forState:UIControlStateNormal];
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
        bio.lineBreakMode = UILineBreakModeTailTruncation;
        bio.numberOfLines = 5;
        bio.backgroundColor = [UIColor clearColor];
        
        // Calculate the expected size based on the font and linebreak mode of your label
        CGSize maximumLabelSize = CGSizeMake(width - kTopBadgeTextXCoordinate - 10, 60);
        CGSize expectedLabelSize = [bio.text
                                    sizeWithFont:bio.font 
                                    constrainedToSize:maximumLabelSize 
                                    lineBreakMode:bio.lineBreakMode];
        CGRect newFrame = bio.frame;
        newFrame.size.height = expectedLabelSize.height;
        bio.frame = newFrame;
        
        self.userDescription = bio;
        [self.contentView addSubview:self.userDescription];
        yCoordinatePointer = yCoordinatePointer + self.userDescription.frame.size.height + 6;
    } 
    
    // LOCATION
    if ([profile objectForKey:@"location"] != [NSNull null]) {
        UILabel *location = [[UILabel alloc] 
                             initWithFrame:CGRectMake(kTopBadgeTextXCoordinate + 16, 
                                                      yCoordinatePointer, 
                                                      width - kTopBadgeTextXCoordinate - 10, 
                                                      20)];
        location.text = [profile objectForKey:@"location"];
        location.textColor = UIColorFromRGB(0x666666);
        location.backgroundColor = [UIColor clearColor];
        location.font = [UIFont fontWithName:@"Helvetica" size:12];
        self.userLocation = location;
        [self.contentView addSubview:self.userLocation];
        
        UIImage *locationIcon = [UIImage imageNamed:@"7-location-place.png"];
        UIImageView *locationIconView = [[UIImageView alloc] initWithImage:locationIcon];
        locationIconView.Frame = CGRectMake(kTopBadgeTextXCoordinate,
                                            yCoordinatePointer + 2, 
                                            16, 
                                            16);
        [self.contentView addSubview:locationIconView];
    } 
    
    if (showStats) {
        UIView *horizontalBar = [[UIView alloc] initWithFrame:CGRectMake(0, kTopBadgeHeight, width, 1)];
        horizontalBar.backgroundColor = [UIColor lightGrayColor];
        [self.contentView addSubview:horizontalBar];
        
        UIView *leftVerticalBar = [[UIView alloc] initWithFrame:CGRectMake((width/3), kTopBadgeHeight, 1, 55)];
        leftVerticalBar.backgroundColor = [UIColor lightGrayColor];
        [self.contentView addSubview:leftVerticalBar];
        
        UIView *rightVerticalBar = [[UIView alloc] initWithFrame:CGRectMake((width/3) * 2, kTopBadgeHeight, 1, 55)];
        rightVerticalBar.backgroundColor = [UIColor lightGrayColor];
        [self.contentView addSubview:rightVerticalBar];
        
        // Shared
        UILabel *shared = [[UILabel alloc] initWithFrame:CGRectMake(0, kTopBadgeHeight + 10, (width/3), 20)];
        NSString *sharedStr = [NSString stringWithFormat:@"%i",
                               [[profile objectForKey:@"shared_stories_count"] intValue]];
        shared.text = sharedStr;
        shared.textAlignment = UITextAlignmentCenter;
        shared.font = [UIFont boldSystemFontOfSize:20];
        shared.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:shared];
        
        UILabel *sharedLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, kTopBadgeHeight + 30, (width/3), 20)];
        NSString *sharedLabelStr = [NSString stringWithFormat:@"Shared Stor%@",
                                    [[profile objectForKey:@"shared_stories_count"] intValue] == 1 ? @"y" : @"ies"];
        sharedLabel.text = sharedLabelStr;
        sharedLabel.textAlignment = UITextAlignmentCenter;
        sharedLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
        sharedLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:sharedLabel];
        
        
        // Following
        UILabel *following = [[UILabel alloc] initWithFrame:CGRectMake((width/3), kTopBadgeHeight + 10, (width/3), 20)];
        NSString *followingStr = [NSString stringWithFormat:@"%i",
                                  [[profile objectForKey:@"following_count"] intValue]];
        following.text = followingStr;
        following.textAlignment = UITextAlignmentCenter;
        following.font = [UIFont boldSystemFontOfSize:20];
        following.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:following];
        
        UILabel *followingLabel = [[UILabel alloc] initWithFrame:CGRectMake((width/3), kTopBadgeHeight + 30, (width/3), 20)];
        NSString *followingLabelStr = [NSString stringWithFormat:@"Following"];
        followingLabel.text = followingLabelStr;
        followingLabel.textAlignment = UITextAlignmentCenter;
        followingLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
        followingLabel.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:followingLabel];
        
        
        // Followers
        UILabel *followers = [[UILabel alloc] initWithFrame:CGRectMake((width/3) * 2, kTopBadgeHeight + 10, (width/3), 20)];
        NSString *followersStr = [NSString stringWithFormat:@"%i", 
                                  [[profile objectForKey:@"follower_count"] intValue]];
        followers.text = followersStr;
        followers.textAlignment = UITextAlignmentCenter;
        followers.font = [UIFont boldSystemFontOfSize:20];
        followers.backgroundColor = [UIColor clearColor];
        [self.contentView addSubview:followers];
        
        UILabel *followersLabel = [[UILabel alloc] initWithFrame:CGRectMake((width/3) * 2, kTopBadgeHeight + 30, (width/3), 20)];
        NSString *followersLabelStr = [NSString stringWithFormat:@"Follower%@", 
                                       [[profile objectForKey:@"follower_count"] intValue] == 1 ? @"" : @"s"];
        followersLabel.text = followersLabelStr;
        followersLabel.textAlignment = UITextAlignmentCenter;
        followersLabel.font = [UIFont fontWithName:@"Helvetica" size:12];
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
    [appDelegate reloadFeedsView:NO];
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
    [appDelegate reloadFeedsView:NO];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

@end