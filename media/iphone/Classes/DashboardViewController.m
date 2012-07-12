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
#import "JSON.h"

@implementation DashboardViewController

@synthesize bottomToolbar;
@synthesize appDelegate;

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
    [self setBottomToolbar:nil];
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

    self.bottomToolbar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)dealloc {
    [appDelegate release];
    [bottomToolbar release];
    [super dealloc];
}


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
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
    [self.view addSubview:interactions];
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
    [self.view addSubview:activity];
    [activity release];
}

@end
