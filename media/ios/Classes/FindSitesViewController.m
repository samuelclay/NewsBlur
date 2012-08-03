//
//  FriendsListViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/1/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "FindSitesViewController.h"
#import "MBProgressHUD.h"

#define FIND_SITES_ROW_HEIGHT 74;

@implementation UINavigationController (DelegateAutomaticDismissKeyboard)
- (BOOL)disablesAutomaticKeyboardDismissal {
    return [self.topViewController disablesAutomaticKeyboardDismissal];
}
@end

@interface FindSitesViewController()

@property (readwrite) BOOL inSearch_;

@end

@implementation FindSitesViewController

@synthesize appDelegate;
@synthesize sitesSearchBar;
@synthesize sitesTable;
@synthesize sites;
@synthesize inSearch_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    
    self.navigationItem.title = @"Find Sites";
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Done" 
                                                                     style: UIBarButtonSystemItemCancel 
                                                                    target: self 
                                                                    action: @selector(doCancelButton)];
    [self.navigationItem setRightBarButtonItem:cancelButton];
        
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    self.sitesTable.rowHeight = FIND_SITES_ROW_HEIGHT;
    
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    
    self.appDelegate = nil;
    self.sitesSearchBar = nil;
    self.sitesTable = nil;
    self.sites = nil;

}

- (void)viewWillAppear:(BOOL)animated {
    [self.sitesSearchBar becomeFirstResponder];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.sitesTable reloadData];
}

- (void)doCancelButton {
    [appDelegate.modalNavigationController dismissModalViewControllerAnimated:YES];
}

#pragma mark - UISearchBar delegate methods

- (void)searchBar:(UISearchBar *)searchBar textDidChange:(NSString *)searchText {

}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar {
    [theSearchBar resignFirstResponder];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [searchBar resignFirstResponder];
    if (searchBar.text.length == 0) {
        self.sites = nil; 
        self.inSearch_ = NO;
        [self.sitesTable reloadData];
    } else {
        self.inSearch_ = YES;
        [self loadSitesList:searchBar.text];
    }
}

- (void)searchBarCancelButtonClicked:(UISearchBar *)searchBar {
    searchBar.text = nil;
}

- (void)loadSitesList:(NSString *)query {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Searching...";
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/rss_feeds/feed_autocomplete?term=%@&limit=10",
                           NEWSBLUR_URL, [query stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    
    NSURL *url = [NSURL URLWithString:urlString];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    if (self.inSearch_) {
        NSString *responseString = [request responseString];
        NSData *responseData= [responseString dataUsingEncoding:NSUTF8StringEncoding];    
        NSError *error;
        NSArray *results = [NSJSONSerialization 
                                 JSONObjectWithData:responseData
                                 options:kNilOptions 
                                 error:&error];
        // int statusCode = [request responseStatusCode];
        
        self.sites = results;

        [self.sitesTable reloadData];
    }
    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

- (BOOL)disablesAutomaticKeyboardDismissal {
    return NO;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return FIND_SITES_ROW_HEIGHT;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    if (self.inSearch_){
        int siteCount = [self.sites count];
        return siteCount;
    } else {
        return 0;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect vb = self.view.bounds;
    
    static NSString *CellIdentifier = @"ProfileBadgeCellIdentifier";
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] 
                initWithStyle:UITableViewCellStyleSubtitle 
                reuseIdentifier:nil];
    } else {
        [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    

    if (self.inSearch_){
        int sitesCount = [self.sites count];
        
        if (sitesCount) {
            if (sitesCount > indexPath.row) {
                cell.detailTextLabel.text = [NSString stringWithFormat:@"%@", [[self.sites objectAtIndex:indexPath.row] objectForKey:@"value"]];
                cell.textLabel.text = [NSString stringWithFormat:@"%@", [[self.sites objectAtIndex:indexPath.row] objectForKey:@"label"]];
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
        
    } else {
        
        int row = 0;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            row = 1;
        }
        
        if (indexPath.row == row) {
            UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, vb.size.width, 140)];
            [cell.contentView addSubview:msg];
            msg.text = @"Search for sites above";
            msg.textColor = UIColorFromRGB(0x7a7a7a);
            if (vb.size.width > 320) {
                msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 20.0];
            } else {
                msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 14.0];
            }
            msg.textAlignment = UITextAlignmentCenter;
        }
    }
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    return cell;
}

- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    [self.sitesSearchBar resignFirstResponder];
}

-(void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [self.sitesSearchBar resignFirstResponder];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
//    NSInteger currentRow = indexPath.row;
//    int row = currentRow;
//    [self.sitesSearchBar resignFirstResponder];

//    [appDelegate.modalNavigationController pushViewController:appDelegate.userProfileViewController animated:YES];
//    [appDelegate.userProfileViewController getUserProfile];
}

@end
