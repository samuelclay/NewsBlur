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
#import "JSON.h"

@implementation DashboardViewController

@synthesize bottomToolbar;
@synthesize interactionsTable;
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
    [self setInteractionsTable:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    self.navigationItem.title = DASHBOARD_TITLE;
    self.bottomToolbar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)dealloc {
    [appDelegate release];
    [bottomToolbar release];
    [interactionsTable release];
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

- (void)refreshActivity {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/profile?user_id=%@",
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
    
    appDelegate.dictUserActivity = [results objectForKey:@"activities"];
    [results release];
    
    ActivityModule *activity = [[ActivityModule alloc] init];
    activity.frame = CGRectMake(20, 510, 438, 300);
    activity.backgroundColor = [UIColor redColor];
    [activity refreshWithActivities:appDelegate.dictUserActivity asSelf:YES];
    [self.view addSubview:activity];
    [activity release];
}


- (void)finishLoadInteractions:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    appDelegate.dictUserInteractions = [results objectForKey:@"interactions"];
    [results release];
    [self.interactionsTable reloadData];
} 

- (void)requestFailed:(ASIHTTPRequest *)request {    
    NSLog(@"Error in finishLoadInteractions is %@", [request error]);
}



#pragma mark -
#pragma mark Table View - Interactions List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{    
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (userInteractions) {
        return userInteractions;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:CellIdentifier] autorelease];
    }
    
    int userInteractions = [appDelegate.dictUserInteractions count];
    if (userInteractions) {
        
        NSDictionary *interaction = [appDelegate.dictUserInteractions objectAtIndex:indexPath.row];
        NSString *category = [interaction objectForKey:@"category"];
        NSString *content = [interaction objectForKey:@"content"];
        NSString *username = [[interaction objectForKey:@"with_user"] objectForKey:@"username"];
        if ([category isEqualToString:@"follow"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ is now following you", username];
        } else if ([category isEqualToString:@"comment_reply"]) {
            cell.textLabel.text = [NSString stringWithFormat:@"%@ replied to your comment: %@", username, content];
        }
        cell.textLabel.font = [UIFont systemFontOfSize:13];
    }
    
    return cell;
}

@end
