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
    
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Next" style:UIBarButtonSystemItemDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Find Friends";
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
    self.twitterButton.selected = YES;
    self.twitterButton.userInteractionEnabled = NO;
}

- (void)selectFacebookButton {
    self.facebookButton.selected = YES;
    self.facebookButton.userInteractionEnabled = NO;
}

- (IBAction)toggleAutoFollowFriends:(id)sender {
    UISwitch *button = (UISwitch *)sender;
    
    NSURL *preferenceURL = [NSURL URLWithString:
                          [NSString stringWithFormat:@"http://%@/profile/set_preference",
                           NEWSBLUR_URL]];
    
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

@end
