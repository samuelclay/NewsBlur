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

@synthesize appDelegate;
@synthesize searchBar;
@synthesize searchDisplayController;
@synthesize suggestedUserProfiles;
@synthesize userProfiles;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"Find Friends";
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Close" 
                                                                     style: UIBarButtonSystemItemCancel 
                                                                    target: self 
                                                                    action: @selector(doCancelButton)];
    [self.navigationItem setRightBarButtonItem:cancelButton];
    
    // Do any additional setup after loading the view from its nib.
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]; 
    
    self.view.frame = CGRectMake(0, 0, 320, 416);
    self.contentSizeForViewInPopover = self.view.frame.size;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    
    
    UISearchBar *newSearchBar = [[UISearchBar alloc] init];
    UISearchDisplayController *newSearchBarController = [[UISearchDisplayController alloc] initWithSearchBar:newSearchBar contentsController:self];
    self.searchDisplayController = newSearchBarController;
    self.searchDisplayController.searchResultsDelegate = self;
    self.searchDisplayController.searchResultsDataSource = self;
    self.searchDisplayController.delegate = self;
    newSearchBar.frame = CGRectMake(0,0,0,38);
    newSearchBar.placeholder = @"Search by username or email";
    self.searchBar = newSearchBar;
    self.tableView.tableHeaderView = newSearchBar;

}

- (void)viewDidUnload
{
    [self setSearchBar:nil];
    [self setSearchDisplayController:nil];
    [self setSuggestedUserProfiles:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewDidAppear:(BOOL)animated {
//    [self.searchBar becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)doCancelButton {
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
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/find_friends?query=%@&limit=10",
                           NEWSBLUR_URL,
                           query];
    NSURL *url = [NSURL URLWithString:urlString];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)loadSuggestedFriendsList {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/social/load_user_friends",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(loadSuggestedFriendsListFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)loadSuggestedFriendsListFinished:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData= [responseString dataUsingEncoding:NSUTF8StringEncoding];    
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
    self.suggestedUserProfiles = [results objectForKey:@"recommended_users"];
    [self.tableView reloadData];
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSString *responseString = [request responseString];
    NSData *responseData= [responseString dataUsingEncoding:NSUTF8StringEncoding];    
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

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad){
        return 28;
    }else{
        return 21;
    }
}

- (UIView *)tableView:(UITableView *)tableView 
viewForHeaderInSection:(NSInteger)section {
    
    int headerLabelHeight, folderImageViewY;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        headerLabelHeight = 28;
        folderImageViewY = 3;
    } else {
        headerLabelHeight = 20;
        folderImageViewY = 0;
    }
    
    // create the parent view that will hold header Label
    UIControl* customView = [[UIControl alloc] 
                             initWithFrame:CGRectMake(0.0, 0.0, 
                                                      tableView.bounds.size.width, headerLabelHeight + 1)];
    UIView *borderTop = [[UIView alloc] 
                         initWithFrame:CGRectMake(0.0, 0, 
                                                  tableView.bounds.size.width, 1.0)];
    borderTop.backgroundColor = UIColorFromRGB(0xe0e0e0);
    borderTop.opaque = NO;
    [customView addSubview:borderTop];
    
    
    UIView *borderBottom = [[UIView alloc] 
                            initWithFrame:CGRectMake(0.0, headerLabelHeight, 
                                                     tableView.bounds.size.width, 1.0)];
    borderBottom.backgroundColor = [UIColorFromRGB(0xB7BDC6) colorWithAlphaComponent:0.5];
    borderBottom.opaque = NO;
    [customView addSubview:borderBottom];
    
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    customView.opaque = NO;
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:11];
    headerLabel.frame = CGRectMake(36.0, 1.0, 286.0, headerLabelHeight);
    headerLabel.shadowColor = [UIColor colorWithRed:.94 green:0.94 blue:0.97 alpha:1.0];
    headerLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    headerLabel.text = @"RECOMMENDED PEOPLE TO FOLLOW";
    
    customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
                                  colorWithAlphaComponent:0.8];
    [customView addSubview:headerLabel];
    
    UIImage *folderImage;
    int folderImageViewX = 10;
    
    folderImage = [UIImage imageNamed:@"group.png"];
    folderImageViewX = 9;
    UIImageView *folderImageView = [[UIImageView alloc] initWithImage:folderImage];
    folderImageView.frame = CGRectMake(folderImageViewX, folderImageViewY, 20, 20);
    [customView addSubview:folderImageView];    
    [customView setAutoresizingMask:UIViewAutoresizingNone];
    return customView;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 140;
}

- (void)searchDisplayController:(UISearchDisplayController *)controller didLoadSearchResultsTableView:(UITableView *)tableView {
    tableView.rowHeight = 140.0f;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    if ([tableView 
         isEqual:self.searchDisplayController.searchResultsTableView]){
        int userCount = [self.userProfiles count];
        return userCount;
    } else {
        int userCount = [self.suggestedUserProfiles count];
        if (!userCount) {
            return 3;
        }
        return userCount;
    }
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if ([tableView 
         isEqual:self.searchDisplayController.searchResultsTableView]){
        return nil;
    } else {
        return @"People To Follow";
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect vb = self.view.bounds;
    
    static NSString *CellIdentifier = @"ProfileBadgeCellIdentifier";
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] 
                initWithStyle:UITableViewCellStyleDefault 
                reuseIdentifier:CellIdentifier];
    } else {
        [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    
    ProfileBadge *badge = [[ProfileBadge alloc] init];
    badge.frame = CGRectMake(5, 5, vb.size.width - 35, self.view.frame.size.height);


    
    if ([tableView isEqual:self.searchDisplayController.searchResultsTableView]){
        [badge refreshWithProfile:[self.userProfiles objectAtIndex:indexPath.row] showStats:NO withWidth:vb.size.width - 35 - 10];
        [cell.contentView addSubview:badge];
        cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
    } else {
        int userCount = [self.suggestedUserProfiles count];
        if (!userCount) {
            if (indexPath.row == 0) {
                cell.textLabel.text = @"Nobody left to recommend. Good job!";
                cell.textLabel.font = [UIFont systemFontOfSize:14.0];
            }
        } else {
            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            [badge refreshWithProfile:[self.suggestedUserProfiles objectAtIndex:indexPath.row] showStats:NO withWidth:vb.size.width - 35 - 10];
            [cell.contentView addSubview:badge];
        }
        
    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    return cell;
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSInteger currentRow = indexPath.row;
    int row = currentRow;
    appDelegate.activeUserProfileId = [[self.userProfiles objectAtIndex:row] objectForKey:@"user_id"];
    [self.searchBar resignFirstResponder];
    [appDelegate.findFriendsNavigationController pushViewController:appDelegate.userProfileViewController animated:YES];
    [appDelegate.userProfileViewController getUserProfile];
}

@end
