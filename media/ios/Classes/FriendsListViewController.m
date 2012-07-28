//
//  FriendsListViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FriendsListViewController.h"
#import "NewsBlurAppDelegate.h"
#import "UserProfileViewController.h"
#import "ASIHTTPRequest.h"
#import "ProfileBadge.h"

@implementation FriendsListViewController

@synthesize friendsTable;
@synthesize appDelegate;
@synthesize searchBar;
@synthesize searchDisplayController;
@synthesize allItems;
@synthesize allItemIds;
@synthesize userProfiles;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"Find Friends";
    self.friendsTable.rowHeight = 140;
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Cancel" 
                                                                     style: UIBarButtonSystemItemCancel 
                                                                    target: self 
                                                                    action: @selector(doCancelButton)];
    [self.navigationItem setLeftBarButtonItem:cancelButton];

    self.friendsTable.scrollEnabled = YES;
    
    NSArray *items = [[NSArray alloc] initWithObjects:
                      @"roy",
                      @"samuel",
                      @"popular",
                      nil];
    
    NSArray *item_ids = [[NSArray alloc] initWithObjects:
                      @"27551",
                      @"13",
                      @"32048",
                      nil];
    
    self.allItemIds = item_ids;
    self.allItems = items;
    
    [self.friendsTable reloadData];
}

- (void)viewDidUnload
{
    [self setSearchBar:nil];
    [self setSearchDisplayController:nil];
    [self setFriendsTable:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated {
    [self.searchBar becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)doCancelButton {
    NSLog(@"do cancel button");
    [appDelegate.findFriendsNavigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark - UISearchDisplayController delegate methods

-(BOOL)searchDisplayController:(UISearchDisplayController *)controller 
shouldReloadTableForSearchString:(NSString *)searchString
{
    NSLog(@"search string is: %@", searchString);
    if (searchString.length == 0) {
        self.userProfiles = nil; 
    }
    [self loadFriendsList:searchString];
    return NO;
}

- (BOOL)searchDisplayController:(UISearchDisplayController *)controller 
shouldReloadTableForSearchScope:(NSInteger)searchOption
{
    return NO;
}

- (void)loadFriendsList:(NSString *)query {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/find_friends?query=%@",
                           NEWSBLUR_URL,
                           query];
    NSURL *url = [NSURL URLWithString:urlString];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}


- (void)requestFinished:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        return;
    }
    
    self.userProfiles = [results objectForKey:@"profiles"];

    
    [self.searchDisplayController.searchResultsTableView reloadData];
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{    
    int userCount = [self.userProfiles count];
    if (userCount) {
        return userCount;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[UITableViewCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:CellIdentifier];
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    
    int userCount = [self.userProfiles count];
    
    if (userCount) {
        [[cell.contentView viewWithTag:123123213] removeFromSuperview];
        
        ProfileBadge *profile = [[ProfileBadge alloc] init];
        [profile refreshWithProfile:[self.userProfiles objectAtIndex:indexPath.row]];
        profile.tag = 123123213;
        profile.frame = CGRectMake(0, 0, 320, 140);
        profile.activeProfile = [self.userProfiles objectAtIndex:indexPath.row];
        [cell.contentView addSubview:profile];
        
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
    } 

    [cell setNeedsLayout];
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 140;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath
{
    NSInteger currentRow = indexPath.row;
    
    int row = currentRow;
    
    appDelegate.activeUserProfileId = [[self.userProfiles objectAtIndex:row] objectForKey:@"user_id"];
    
    [appDelegate.userProfileViewController getUserProfile];
    [appDelegate.findFriendsNavigationController pushViewController:appDelegate.userProfileViewController animated:YES];
}

@end
