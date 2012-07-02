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
#import "JSON.h"

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
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Cancel" 
                                                                     style: UIBarButtonSystemItemCancel 
                                                                    target: self 
                                                                    action: @selector(doCancelButton)];
    [self.navigationItem setLeftBarButtonItem:cancelButton];
    [cancelButton release];

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
    [items release];
    [item_ids release];
    
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

- (void)dealloc {
    [appDelegate release];
    [searchBar release];
    [searchDisplayController release];
    [friendsTable release];
    [userProfiles release];
    [userProfileIds release];
    [super dealloc];
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
//    [self filterContentForSearchText:searchString 
//                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
//                                      objectAtIndex:[self.searchDisplayController.searchBar
//                                                     selectedScopeButtonIndex]]];

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
//    [self filterContentForSearchText:[self.searchDisplayController.searchBar text] 
//                               scope:[[self.searchDisplayController.searchBar scopeButtonTitles]
//                                      objectAtIndex:searchOption]];
    NSLog(@"shouldReloadTableForSearchScope, %@", searchOption);
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
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        [results release];
        return;
    }
    
    self.userProfiles = [results objectForKey:@"profiles"];

    [results release];
    
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
        return [self.allItems count];
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] 
                 initWithStyle:UITableViewCellStyleDefault 
                 reuseIdentifier:CellIdentifier] autorelease];
        
        cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
    }

    
    int userCount = [self.userProfiles count];
    
    if (userCount) {
        cell.textLabel.text = [[self.userProfiles objectAtIndex:indexPath.row] objectForKey:@"username"];
    } else {
        cell.textLabel.text = [self.allItems objectAtIndex:indexPath.row];
    }

    [cell setNeedsLayout];
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    NSInteger currentRow = indexPath.row;
    
    int row = currentRow;
    NSLog(@"the row is %i", row);
    
    appDelegate.activeUserProfile = [[self.userProfiles objectAtIndex:row] objectForKey:@"user_id"];
    
    [appDelegate.userProfileViewController getUserProfile];
    [appDelegate.findFriendsNavigationController pushViewController:appDelegate.userProfileViewController animated:YES];
}

@end
