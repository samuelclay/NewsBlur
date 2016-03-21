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
#import "ASIHTTPRequest.h"

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
    // Do any additional setup after loading the view from its nib.
    
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Skip this step" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Friends";
}

- (void)viewDidUnload {
    [self setNextButton:nil];
    [self setFacebookButton:nil];
    [self setTwitterButton:nil];
    [self setFacebookActivityIndicator:nil];
    [self setTwitterActivityIndicator:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
//    [self selectTwitterButton];
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
        return YES;
    }
    
    return NO;
}

- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController pushViewController:appDelegate.firstTimeUserAddNewsBlurViewController animated:YES];
}

- (IBAction)tapTwitterButton {
    AuthorizeServicesViewController *service = [[AuthorizeServicesViewController alloc] init];
    service.url = @"/oauth/twitter_connect";
    service.type = @"twitter";
    [appDelegate.ftuxNavigationController pushViewController:service animated:YES];
}


- (IBAction)tapFacebookButton {
    AuthorizeServicesViewController *service = [[AuthorizeServicesViewController alloc] init];
    service.url = @"/oauth/facebook_connect";
    service.type = @"facebook";
    [appDelegate.ftuxNavigationController pushViewController:service animated:YES];
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
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setValidatesSecureCertificate:NO];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishConnectFromSocial:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];
}

- (void)finishConnectFromSocial:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    NSLog(@"results are %@", results);
    
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
    
    NSURL *preferenceURL = [NSURL URLWithString:
                          [NSString stringWithFormat:@"%@/profile/set_preference",
                           self.appDelegate.url]];
    
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:preferenceURL];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    
    if (button.on) {
        [request setPostValue:@"false" forKey:@"autofollow_friends"];
    } else {
        [request setPostValue:@"true" forKey:@"autofollow_friends"];
    }
    
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setDidFinishSelector:@selector(finishToggleAutoFollowFriends:)];
    [request setDidFailSelector:@selector(finishedWithError:)];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

- (void)finishedWithError:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    NSLog(@"results are %@", results);
    
}

- (void)finishToggleAutoFollowFriends:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    NSLog(@"results are %@", results);
}

- (void)changeMessaging:(NSString *)msg {
    self.friendsLabel.text = msg;
    self.friendsLabel.textColor = [UIColor redColor];
}

@end
