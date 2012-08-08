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
#import "AddSiteViewController.h"
#import "MBProgressHUD.h"
#import "AddSiteTableCell.h"

#define FIND_SITES_ROW_HEIGHT 74;

@implementation UINavigationController (DelegateAutomaticDismissKeyboard)
- (BOOL)disablesAutomaticKeyboardDismissal {
    return [self.topViewController disablesAutomaticKeyboardDismissal];
}
@end

@interface FindSitesViewController()

@property (readwrite) BOOL inSearch_;
@property (nonatomic) NSString *searchTerm_;
@property (nonatomic, strong) UIActivityIndicatorView *loadingIndicator_;
@end

@implementation FindSitesViewController

@synthesize appDelegate;
@synthesize sitesSearchBar;
@synthesize sitesTable;
@synthesize sites;
@synthesize inSearch_;
@synthesize searchTerm_;
@synthesize loadingIndicator_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewDidLoad
{
    
    // loading indicator
    UIActivityIndicatorView *loader = [[UIActivityIndicatorView alloc] 
                                       initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    
    
    self.loadingIndicator_ = loader;
    [self.view addSubview:self.loadingIndicator_];

    
    
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

- (void)viewDidAppear:(BOOL)animated {
    CGRect vb = self.view.bounds;
    self.loadingIndicator_.frame = CGRectMake(vb.size.width - 52, 12,20,20);
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
    if (searchBar.text.length == 0) {
        self.sites = nil; 
        self.inSearch_ = NO;
        [self.sitesTable reloadData];
    } else {
        self.inSearch_ = YES;
        self.searchTerm_ = searchText;
        [self loadSitesList:searchText];
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

- (void)loadSitesList:(NSString *)query {
    [self.loadingIndicator_ startAnimating];
//    [MBProgressHUD hideHUDForView:self.view animated:YES];
//    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
//    HUD.labelText = @"Searching...";
    
    NSString *urlString = [NSString stringWithFormat:@"http://%@/rss_feeds/feed_autocomplete?term=%@&limit=10&v=2",
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
        NSDictionary *results = [NSJSONSerialization 
                                 JSONObjectWithData:responseData
                                 options:kNilOptions 
                                 error:&error];
        // int statusCode = [request responseStatusCode];
        
        self.sites = [results objectForKey:@"feeds"];

        [self.sitesTable reloadData];
        
        NSString *originalSearchTerm = [NSString stringWithFormat:@"%@", [results objectForKey:@"term"]];
        if ([self.searchTerm_ isEqualToString:originalSearchTerm]) {
            [self.loadingIndicator_ stopAnimating];
        }
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
        if (siteCount == 0) {
            return 3;
        }
        return siteCount;
    } else {
        return 3;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    CGRect vb = self.view.bounds;
    
    static NSString *CellIdentifier = @"AddSiteEmptyCellIdentifier";
    int sitesCount = [self.sites count];
    
    if (self.inSearch_ && sitesCount){
        if (sitesCount > indexPath.row) {
            
            
            
            
            AddSiteTableCell *cell = (AddSiteTableCell *)[tableView 
                                                                dequeueReusableCellWithIdentifier:@"AddSiteCellIdentifier"]; 
            if (cell == nil) {
                cell = [[AddSiteTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                                  reuseIdentifier:nil];
            }
            
            
            NSDictionary *site = [self.sites objectAtIndex:indexPath.row];
            
            NSString *siteTitle = [site objectForKey:@"label"];
            cell.siteTitle = siteTitle; 
            
            // adding comma to the number of subscribers
            NSNumberFormatter *formatter = [NSNumberFormatter new];
            [formatter setNumberStyle:NSNumberFormatterDecimalStyle]; // this line is important!
            NSString *formatted = [formatter stringFromNumber:[NSNumber numberWithInteger:[[site objectForKey:@"num_subscribers"] intValue]]];
            NSString *subscribers = [NSString stringWithFormat:@"%@ subscribers", formatted];
            cell.siteSubscribers = subscribers;
            
            // feed color bar border
            unsigned int colorBorder = 0;
            NSString *faviconColor = [site valueForKey:@"favicon_color"];
            
            if ([faviconColor class] == [NSNull class]) {
                faviconColor = @"505050";
            }    
            NSScanner *scannerBorder = [NSScanner scannerWithString:faviconColor];
            [scannerBorder scanHexInt:&colorBorder];
            
            cell.feedColorBar = UIColorFromRGB(colorBorder);
            
            // feed color bar border
            NSString *faviconFade = [site valueForKey:@"favicon_fade"];
            if ([faviconFade class] == [NSNull class]) {
                faviconFade = @"505050";
            }    
            scannerBorder = [NSScanner scannerWithString:faviconFade];
            [scannerBorder scanHexInt:&colorBorder];
            cell.feedColorBarTopBorder =  UIColorFromRGB(colorBorder);
            
            // favicon
//                cell.siteFavicon = [Utilities getImage:feedIdStr];
            
            // undread indicator
            
            return cell;
        }
    }
    
    UITableViewCell *cell = [tableView 
                             dequeueReusableCellWithIdentifier:CellIdentifier];
    
    if (cell == nil) {
        cell = [[UITableViewCell alloc] 
                initWithStyle:UITableViewCellStyleSubtitle 
                reuseIdentifier:nil];
    } else {
        [[[cell contentView] subviews] makeObjectsPerformSelector: @selector(removeFromSuperview)];
    }
    
    int row = 0;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        row = 1;
    }
    
    UILabel *msg = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, vb.size.width, 74)];
    msg.textColor = UIColorFromRGB(0x7a7a7a);
    if (vb.size.width > 320) {
        msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 20.0];
    } else {
        msg.font = [UIFont fontWithName:@"Helvetica-Bold" size: 14.0];
    }
    msg.textAlignment = UITextAlignmentCenter;
    
    if (self.inSearch_ && sitesCount){
        if (indexPath.row == row) {
            [cell.contentView addSubview:msg];
            msg.text = @"No results.";
        }
    } else {
        if (indexPath.row == row) {
            msg.text = @"Search for sites above";
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
    [appDelegate.modalNavigationController pushViewController:appDelegate.addSiteViewController animated:YES];
}

- (void)tableView:(UITableView *)tableView accessoryButtonTappedForRowWithIndexPath:(NSIndexPath *)indexPath {
//    NSInteger currentRow = indexPath.row;
//    int row = currentRow;
//    [self.sitesSearchBar resignFirstResponder];

//    [appDelegate.modalNavigationController pushViewController:appDelegate.userProfileViewController animated:YES];
//    [appDelegate.userProfileViewController getUserProfile];
}

@end
