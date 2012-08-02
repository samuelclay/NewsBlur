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
#import "MBProgressHUD.h"

@implementation UINavigationController (DelegateAutomaticDismissKeyboard)
- (BOOL)disablesAutomaticKeyboardDismissal {
    return [self.topViewController disablesAutomaticKeyboardDismissal];
}
@end

@interface FriendsListViewController()

@property (readwrite) BOOL inSearch_;

@end

@implementation FriendsListViewController

@synthesize appDelegate;
@synthesize friendSearchBar;
@synthesize friendsTable;
@synthesize suggestedUserProfiles;
@synthesize userProfiles;
@synthesize inSearch_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.navigationItem.title = @"Find Friends";
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Done" 
                                                                     style: UIBarButtonSystemItemCancel 
                                                                    target: self 
                                                                    action: @selector(doCancelButton)];
    [self.navigationItem setRightBarButtonItem:cancelButton];
    
    // Do any additional setup after loading the view from its nib.
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate]; 
    
    self.view.frame = CGRectMake(0, 0, 320, 416);
    self.contentSizeForViewInPopover = self.view.frame.size;
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];

//    UISearchBar *newSearchBar = [[UISearchBar alloc] init];
//    newSearchBar.frame = CGRectMake(0,0,0,38);
//    newSearchBar.placeholder = @"Search by username or email";
//    newSearchBar.delegate = self;
//    self.friendSearchBar = newSearchBar;
//    self.friendsTable.tableHeaderView = newSearchBar;

}

- (void)viewDidUnload
{
    [self setFriendSearchBar:nil];
    [self setSuggestedUserProfiles:nil];
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [self.friendSearchBar becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (void)doCancelButton {
    [appDelegate.modalNavigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark - UISearchBar delegate methods

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {
    if (searchText.length == 0) {
        self.userProfiles = nil; 
        self.inSearch_ = NO;
        [self.friendsTable reloadData];
    } else {
        self.inSearch_ = YES;
        [self loadFriendsList:searchText];
    }
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar {
    [theSearchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = nil;
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
    [self.friendsTable reloadData];
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    if (self.inSearch_) {
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
        
        
        [self.friendsTable reloadData];
    }
    
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 0;
//    if (self.inSearch_){
//        return 0;
//    } else {
//        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad){
//            return 28;
//        }else{
//            return 21;
//        }
//    }
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
    if (self.inSearch_){
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

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect vb = self.view.bounds;
    
    static NSString *CellIdentifier = @"ProfileBadgeCellIdentifier";
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] 
                initWithStyle:UITableViewCellStyleDefault 
                reuseIdentifier:nil];
    } else {
        [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    
    ProfileBadge *badge = [[ProfileBadge alloc] init];
    badge.frame = CGRectMake(5, 5, vb.size.width - 35, self.view.frame.size.height);
    
    
    if (self.inSearch_){
        int userProfileCount = [self.userProfiles count];
        
        if (userProfileCount) {
            if (userProfileCount > indexPath.row) {
                [badge refreshWithProfile:[self.userProfiles objectAtIndex:indexPath.row] showStats:NO withWidth:vb.size.width - 35 - 10];
                [cell.contentView addSubview:badge];
                cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
            }
        } else {
            
            // add a NO FRIENDS TO SUGGEST message on either the first or second row depending on iphone/ipad
            int row = 0;
            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
                row = 1;
            }
            
            if (indexPath.row == row) {
                UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, vb.size.width, 140)];
                [cell.contentView addSubview:msg];
                msg.text = @"No results.";
                msg.textColor = UIColorFromRGB(0x7a7a7a);
                if (vb.size.width > 320) {
                    msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 20.0];
                } else {
                    msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 14.0];
                }
                msg.textAlignment = UITextAlignmentCenter;
            }

        }
        
    } 
//    else {
//        
//        int userCount = [self.suggestedUserProfiles count];
//        if (!userCount) {
//            // add a NO FRIENDS TO SUGGEST message on either the first or second row depending on iphone/ipad
//            int row = 0;
//            if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//                row = 1;
//            }
//            
//            if (indexPath.row == row) {
//                UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, vb.size.width, 140)];
//                [cell.contentView addSubview:msg];
//                msg.text = @"Nobody left to recommend.  Good job!";
//                msg.textColor = UIColorFromRGB(0x7a7a7a);
//                if (vb.size.width > 320) {
//                    msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 20.0];
//                } else {
//                    msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 14.0];
//                }
//                msg.textAlignment = UITextAlignmentCenter;
//            }
//        } else {
//            cell.accessoryType = UITableViewCellAccessoryDetailDisclosureButton;
//            [badge refreshWithProfile:[self.suggestedUserProfiles objectAtIndex:indexPath.row] showStats:NO withWidth:vb.size.width - 35 - 10];
//            [cell.contentView addSubview:badge];
//        }
//    }

    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.friendSearchBar resignFirstResponder];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.friendSearchBar resignFirstResponder];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
    NSInteger currentRow = indexPath.row;
    int row = currentRow;
    appDelegate.activeUserProfileId = [[self.userProfiles objectAtIndex:row] objectForKey:@"user_id"];
    [self.friendSearchBar resignFirstResponder];
    [appDelegate.modalNavigationController pushViewController:appDelegate.userProfileViewController animated:YES];
    [appDelegate.userProfileViewController getUserProfile];
}

@end