//
//  FTUXAddFriendsViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FirstTimeUserAddFriendsViewController.h"
#import "FirstTimeUserAddNewsBlurViewController.h"
#import "AuthorizeServicesViewController.h"

@interface FirstTimeUserAddFriendsViewController ()

@end

@implementation FirstTimeUserAddFriendsViewController

@synthesize appDelegate;
@synthesize nextButton;
@synthesize facebookButton;
@synthesize twitterButton;
@synthesize facebookActivityIndicator;
@synthesize twitterActivityIndicator;
@synthesize friendsLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Skip this step" style:UIBarButtonItemStyleDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Friends";
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    [self selectTwitterButton];
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    // Return YES for supported orientations
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        return YES;
//    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
//        return YES;
//    }
//    
//    return NO;
//}

- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController showViewController:appDelegate.firstTimeUserAddNewsBlurViewController sender:self];
}

- (IBAction)tapTwitterButton {
    AuthorizeServicesViewController *service = [[AuthorizeServicesViewController alloc] init];
    service.url = @"/oauth/twitter_connect";
    service.type = @"twitter";
    [appDelegate.ftuxNavigationController showViewController:service sender:self];
}


- (IBAction)tapFacebookButton {
    AuthorizeServicesViewController *service = [[AuthorizeServicesViewController alloc] init];
    service.url = @"/oauth/facebook_connect";
    service.type = @"facebook";
    [appDelegate.ftuxNavigationController showViewController:service sender:self];
}


- (void)selectTwitterButton {
    self.nextButton.title = @"Next";
    self.twitterButton.userInteractionEnabled = NO;
    [self.twitterButton setTitle:@"Connecting" forState:UIControlStateNormal];
    [self.twitterActivityIndicator startAnimating];
    [self connectToSocial];
}

- (void)selectFacebookButton {
    self.nextButton.title = @"Next";
    self.facebookButton.userInteractionEnabled = NO;
    [self.facebookButton setTitle:@"Connecting" forState:UIControlStateNormal];
    [self.facebookActivityIndicator startAnimating];
    [self connectToSocial];
}

#pragma mark -
#pragma mark Check Social

- (void)connectToSocial {
    NSString *urlString = [NSString stringWithFormat:@"%@/social/load_user_friends",
                           self.appDelegate.url];
    [appDelegate GET:urlString parameters:nil target:self success:@selector(finishConnectFromSocial:) failure:@selector(requestFailed:)];
}

- (void)requestFailed:(NSError *)error {
    NSLog(@"Error: %@", error);
    [self informError:error];
}

- (void)finishConnectFromSocial:(NSDictionary *)results {
    NSLog(@"Connect to social results: %@", results);
    
    BOOL facebookSync = [[[[results objectForKey:@"services"] objectForKey:@"facebook"] objectForKey:@"syncing"] boolValue];
    BOOL twitterSync = [[[[results objectForKey:@"services"] objectForKey:@"twitter"] objectForKey:@"syncing"] boolValue];

    if (![[[[results objectForKey:@"services"] objectForKey:@"facebook"] objectForKey:@"facebook_uid"] isKindOfClass:[NSNull class]]) {
        [self finishFacebookConnect];
    } else {
        if (facebookSync) {
            [self performSelector:@selector(connectToSocial) withObject:self afterDelay:3];
        }
    }
    
    if (![[[[results objectForKey:@"services"] objectForKey:@"twitter"] objectForKey:@"twitter_uid"] isKindOfClass:[NSNull class]]) {
        [self finishTwitterConnect];
    } else {
        if (twitterSync) {
            [self performSelector:@selector(connectToSocial) withObject:self afterDelay:3];
        }
    }
}

- (void)finishFacebookConnect {
    [self.facebookActivityIndicator stopAnimating];
    self.friendsLabel.textColor = UIColorFromRGB(0x333333);
    self.facebookButton.selected = YES;
    self.friendsLabel.text = @"You have successfully connected to Facebook.";
    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(self.facebookButton.frame.origin.x + self.facebookButton.frame.size.width - 24,
                                     self.facebookButton.frame.origin.y + 8,
                                     16,
                                     16);
    [self.view addSubview:checkmarkView];

}

- (void)finishTwitterConnect {
    [self.twitterActivityIndicator stopAnimating];
    self.friendsLabel.textColor = UIColorFromRGB(0x333333);
    self.friendsLabel.text = @"You have successfully connected to Twitter.";
    
    self.twitterButton.selected = YES;
    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(self.twitterButton.frame.origin.x + self.twitterButton.frame.size.width - 24,
                                     self.twitterButton.frame.origin.y + 8,
                                     16,
                                     16);
    [self.view addSubview:checkmarkView];
}

#pragma mark -
#pragma mark Toggle Auto Follow

- (IBAction)toggleAutoFollowFriends:(id)sender {
    UISwitch *button = (UISwitch *)sender;
    
    NSString *urlString = [NSString stringWithFormat:@"%@/profile/set_preference", self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];

    if (button.on) {
        [params setObject:@"false" forKey:@"autofollow_friends"];
    } else {
        [params setObject:@"true" forKey:@"autofollow_friends"];
    }
    
    [appDelegate POST:urlString parameters:params target:self success:@selector(finishToggleAutoFollowFriends:) failure:@selector(requestFailed:)];
}

- (void)finishToggleAutoFollowFriends:(NSDictionary *)results {
    NSLog(@"results are %@", results);
}

- (void)changeMessaging:(NSString *)msg {
    self.friendsLabel.text = msg;
    self.friendsLabel.textColor = [UIColor redColor];
}

@end
