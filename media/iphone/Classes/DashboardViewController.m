//
//  DashboardViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/10/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "DashboardViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ActivityModule.h"
#import "InteractionsModule.h"
#import "UserProfileViewController.h"
#import "JSON.h"

@implementation DashboardViewController

@synthesize appDelegate;
@synthesize interactionsLabel;
@synthesize interactionsModule;
@synthesize activitesLabel;
@synthesize activitiesModule;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
}

- (void)viewDidUnload {
    [self setAppDelegate:nil];
    [self setInteractionsLabel:nil];
    [self setInteractionsModule:nil];
    [self setActivitesLabel:nil];
    [self setActivitiesModule:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    CGRect frame = CGRectMake(0, 0, 400, 44);
    UILabel *label = [[[UILabel alloc] initWithFrame:frame] autorelease];
    label.backgroundColor = [UIColor clearColor];
    label.font = [UIFont boldSystemFontOfSize:16.0];
    label.textAlignment = UITextAlignmentCenter;
    label.textColor = [UIColor whiteColor];
    label.text = DASHBOARD_TITLE;
    self.navigationItem.titleView = label;
    
    [self repositionDashboard];
}

- (void)dealloc {
    [appDelegate release];
    [interactionsLabel release];
    [interactionsModule release];
    [activitesLabel release];
    [activitiesModule release];
    [super dealloc];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self repositionDashboard];
}

- (void)repositionDashboard {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;        
	if (UIInterfaceOrientationIsPortrait(orientation)) {
        self.interactionsLabel.frame = CGRectMake(151,
                                                  42,
                                                  self.interactionsLabel.frame.size.width,
                                                  self.interactionsLabel.frame.size.height);
        self.interactionsModule.frame = CGRectMake(self.interactionsModule.frame.origin.x,
                                                   self.interactionsModule.frame.origin.y,
                                                   440,
                                                   self.interactionsModule.frame.size.height);
        self.activitesLabel.frame = CGRectMake(151,
                                               494,
                                               self.activitesLabel.frame.size.width,
                                               self.activitesLabel.frame.size.height);
        self.activitiesModule.frame = CGRectMake(20, 
                                                 555, 
                                                 440, 
                                                 self.interactionsModule.frame.size.height);
    } else {
        self.interactionsLabel.frame = CGRectMake(80,
                                                  self.interactionsLabel.frame.origin.y,
                                                  self.interactionsLabel.frame.size.width,
                                                  self.interactionsLabel.frame.size.height);
        self.interactionsModule.frame = CGRectMake(self.interactionsModule.frame.origin.x,
                                                   self.interactionsModule.frame.origin.y,
                                                   320,
                                                   self.interactionsModule.frame.size.height);
        
        self.activitesLabel.frame = CGRectMake(450,
                                                  self.interactionsLabel.frame.origin.y,
                                                  self.activitesLabel.frame.size.width,
                                                  self.activitesLabel.frame.size.height);
        self.activitiesModule.frame = CGRectMake(380, 
                                                 100, 
                                                 320, 
                                                 self.interactionsModule.frame.size.height);        
    }
    
}

- (IBAction)doLogout:(id)sender {
    [appDelegate confirmLogout];
}

# pragma mark
# pragma Interactions

- (void)refreshInteractions {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/interactions?user_id=%@",
                           NEWSBLUR_URL,
                           [appDelegate.dictUserProfile objectForKey:@"user_id"]];

    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    
    [request setDidFinishSelector:@selector(finishLoadInteractions:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)finishLoadInteractions:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    appDelegate.dictUserInteractions = [results objectForKey:@"interactions"];
    [results release];

    InteractionsModule *interactions = [[InteractionsModule alloc] init];
    interactions.frame = CGRectMake(20, 100, 438, 300);
    [interactions refreshWithInteractions:appDelegate.dictUserInteractions];
    self.interactionsModule = interactions;
    [self.view addSubview:self.interactionsModule];
    [self repositionDashboard];
    [interactions release];
} 

- (void)requestFailed:(ASIHTTPRequest *)request {    
    NSLog(@"Error in finishLoadInteractions is %@", [request error]);
}

# pragma mark
# pragma Activities

- (void)refreshActivity {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/activities?user_id=%@",
                           NEWSBLUR_URL,
                           [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDidFinishSelector:@selector(finishLoadActivities:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)finishLoadActivities:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    appDelegate.dictUserActivities = results;
    [results release];
    
    ActivityModule *activity = [[ActivityModule alloc] init];
    activity.frame = CGRectMake(20, 510, 438, 300);
    [activity refreshWithActivities:appDelegate.dictUserActivities];
    self.activitiesModule = activity;
    [self.view addSubview:self.activitiesModule];
    [self repositionDashboard];
    [activity release];
}

@end
