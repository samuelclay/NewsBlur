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
#import "JSON.h"

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

- (void)refreshWithProfile:(NSDictionary *)profile {    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];    
    
    self.activeProfile = profile;
    
//    self.followingCount.text = [NSString stringWithFormat:@"%i", 
//                                [[results objectForKey:@"following_count"] intValue]];
//    self.followersCount.text = [NSString stringWithFormat:@"%i",
//                                [[results objectForKey:@"follower_count"] intValue]];
 
    int yCoordinatePointer = 0;
    
    // USERNAME
    UILabel *user = [[UILabel alloc] initWithFrame:CGRectMake(120,10,230,20)];
    user.text = [profile objectForKey:@"username"]; 
    user.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
    user.font = [UIFont fontWithName:@"Helvetica-Bold" size:20];
    self.username = user;
    [self addSubview:self.username];
    yCoordinatePointer = self.username.frame.origin.y + self.username.frame.size.height;
    [user release];
    
    // LOCATION
//    if ([profile objectForKey:@"location"] != [NSNull null]) {
//        UILabel *location = [[UILabel alloc] 
//                             initWithFrame:CGRectMake(120, 
//                                                      yCoordinatePointer, 
//                                                      190, 
//                                                      20)];
//        location.text = [profile objectForKey:@"location"];
//        location.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
//        location.font = [UIFont fontWithName:@"Helvetica" size:12];
//        self.userLocation = location;
//        [self addSubview:self.userLocation];
//        [location release];
//        yCoordinatePointer = yCoordinatePointer + self.userLocation.frame.size.height;
//    } 
    
    // BIO
    if ([profile objectForKey:@"bio"] != [NSNull null]) {
        UILabel *bio = [[UILabel alloc] 
                             initWithFrame:CGRectMake(120, 
                                                      yCoordinatePointer, 
                                                      190, 
                                                      20)];
        bio.text = [profile objectForKey:@"bio"];
        bio.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
        bio.font = [UIFont fontWithName:@"Helvetica" size:12];
        self.userDescription = bio;
        [self addSubview:self.userDescription];
        [bio release];
        yCoordinatePointer = yCoordinatePointer + self.userDescription.frame.size.height;
    } 
    
    // STATS
    UILabel *stats = [[UILabel alloc] initWithFrame:CGRectMake(120, yCoordinatePointer, 190, 20)];
    NSString *statsStr = [NSString stringWithFormat:@"%i shared stories · %i follower%@", 
                          [[profile objectForKey:@"shared_stories_count"] intValue],
                          [[profile objectForKey:@"follower_count"] intValue], 
                          [[profile objectForKey:@"follower_count"] intValue] == 1 ? @"" : @"s"];
    stats.text = statsStr;
    stats.font = [UIFont fontWithName:@"Helvetica" size:10];
    self.userStats = stats;
    [self addSubview:self.userStats];
    [stats release];
    
    // AVATAR
    NSString *photo_url = [profile objectForKey:@"photo_url"];

    if ([photo_url rangeOfString:@"graph.facebook.com"].location != NSNotFound) {
        photo_url = [photo_url stringByAppendingFormat:@"?type=large"];
    }
                     
    if ([photo_url rangeOfString:@"twimg"].location != NSNotFound) {
        photo_url = [photo_url stringByReplacingOccurrencesOfString:@"_normal" withString:@""];        
    }
    
    NSURL *imageURL = [Utilities convertToAbsoluteURL:photo_url];    
    NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
    UIImage *image = [UIImage imageWithData:imageData];
    UIImageView *avatar = [[UIImageView alloc] initWithImage:image];    
    avatar.frame = CGRectMake(10, 10, 100, 100);
    self.userAvatar = avatar;
    [self addSubview:self.userAvatar];
    [avatar release];
    
    // FOLLOW BUTTON
    UIButton *follow = [UIButton buttonWithType:UIButtonTypeRoundedRect];
    follow.frame = CGRectMake(120, 80, 100, 30);

    // check if self
    NSString *currentUserId = [NSString stringWithFormat:@"%@", [self.appDelegate.dictUserProfile objectForKey:@"user_id"]];    
    // check following to toggle follow button
    BOOL isFollowing = NO;
    BOOL isSelf = NO;
    NSArray *followingUserIds = [self.appDelegate.dictUserProfile objectForKey:@"following_user_ids"];
    for (int i = 0; i < followingUserIds.count ; i++) {
        NSString *followingUserId = [NSString stringWithFormat:@"%@", [followingUserIds objectAtIndex:i]];
        if ([currentUserId isEqualToString:[NSString stringWithFormat:@"%@", [profile objectForKey:@"user_id"]]]) {
            isSelf = YES;
        }
        if ([followingUserId isEqualToString:[NSString stringWithFormat:@"%@", [profile objectForKey:@"user_id"]]]) {
            isFollowing = YES;
        }
    }

    if (isSelf) {
        [follow setTitle:@"You" forState:UIControlStateNormal];
        follow.enabled = NO;
    } else if (isFollowing) {
        [follow setTitle:@"Following" forState:UIControlStateNormal];
    } else {
        [follow setTitle:@"Follow" forState:UIControlStateNormal];
    }
    
    [follow addTarget:self 
               action:@selector(doFollowButton:) 
       forControlEvents:UIControlEventTouchUpInside];
    
    self.followButton = follow;
    [self addSubview:self.followButton];

    // ACTIVITY INDICATOR
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    activityView.frame = CGRectMake(160, 85, 20, 20.0);
    self.activityIndicator = activityView;
    [self addSubview:self.activityIndicator];
    [activityView release];
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
    
    NSLog(@"url is %@", url);
    [request startAsynchronous];
}

- (void)finishFollowing:(ASIHTTPRequest *)request {

    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSLog(@"responseString is %@", responseString);
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    

    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"ERROR");
        [results release];
        return;
    } 
    
    [self.followButton setTitle:@"Following" forState:UIControlStateNormal];
    [results release];
}


- (void)finishUnfollowing:(ASIHTTPRequest *)request {
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSLog(@"responseString is %@", responseString);
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSLog(@"ERROR");
        [results release];
        return;
    } 
    
    NSLog(@"results %@", results);
    [self.followButton setTitle:@"Follow" forState:UIControlStateNormal];
    [results release];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

@end
