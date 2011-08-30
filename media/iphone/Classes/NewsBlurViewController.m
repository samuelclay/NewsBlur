//
//  NewsBlurViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FeedTableCell.h"
#import "ASIHTTPRequest.h"
#import "PullToRefreshView.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "JSON.h"

#define kTableViewRowHeight 40;

#define UIColorFromRGB(rgbValue) [UIColor \
colorWithRed:((float)((rgbValue & 0xFF0000) >> 16))/255.0 \
green:((float)((rgbValue & 0xFF00) >> 8))/255.0 \
blue:((float)(rgbValue & 0xFF))/255.0 alpha:1.0]

@implementation NewsBlurViewController

@synthesize appDelegate;

@synthesize responseData;
@synthesize feedTitlesTable;
@synthesize feedViewToolbar;
@synthesize feedScoreSlider;
@synthesize logoutButton;
@synthesize intelligenceControl;
@synthesize activeFeedLocations;
@synthesize stillVisibleFeeds;
@synthesize visibleFeeds;
@synthesize sitesButton;
@synthesize viewShowingAllFeeds;
@synthesize pull;
@synthesize lastUpdate;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictFoldersArray;

#pragma mark -
#pragma mark Globals

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [appDelegate hideNavigationBar:NO];
    }
    return self;
}

- (void)viewDidLoad {
    self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(doLogoutButton)] autorelease];
    [appDelegate showNavigationBar:NO];
    self.viewShowingAllFeeds = NO;
    pull = [[PullToRefreshView alloc] initWithScrollView:self.feedTitlesTable];
    [pull setDelegate:self];
    [self.feedTitlesTable addSubview:pull];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(returnToApp)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.feedTitlesTable deselectRowAtIndexPath:[feedTitlesTable indexPathForSelectedRow] 
                                        animated:animated];
    if (appDelegate.activeFeedIndexPath) {
        //      NSLog(@"Refreshing feed at %d / %d: %@", appDelegate.activeFeedIndexPath.section, appDelegate.activeFeedIndexPath.row, [appDelegate activeFeed]);
        [self.feedTitlesTable beginUpdates];
        [self.feedTitlesTable 
         reloadRowsAtIndexPaths:[NSArray 
                                 arrayWithObject:appDelegate.activeFeedIndexPath] 
         withRowAnimation:UITableViewRowAnimationNone];
        [self.feedTitlesTable endUpdates];
        
        NSInteger previousLevel = [self.intelligenceControl selectedSegmentIndex] - 1;
        NSInteger newLevel = [appDelegate selectedIntelligence];
        if (newLevel != previousLevel) {
            [appDelegate setSelectedIntelligence:newLevel];
            [self updateFeedsWithIntelligence:previousLevel newLevel:newLevel];
            [self redrawUnreadCounts];
        }
    }
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_red.png"] 
                     forSegmentAtIndex:0];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_yellow.png"] 
                     forSegmentAtIndex:1];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_green.png"] 
                     forSegmentAtIndex:2];
    [self.intelligenceControl addTarget:self
                                 action:@selector(selectIntelligence)
                       forControlEvents:UIControlEventValueChanged];
    [self.intelligenceControl 
     setSelectedSegmentIndex:[appDelegate selectedIntelligence]+1];
    [appDelegate showNavigationBar:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    appDelegate.activeFeed = nil; 
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    //[appDelegate showNavigationBar:YES];
    [super viewWillDisappear:animated];
}

/*
 // Override to allow orientations other than the default portrait orientation.
 - (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
 // Return YES for supported orientations
 return (interfaceOrientation == UIInterfaceOrientationPortrait);
 }
 */

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {   
    [appDelegate release];
    
    [feedTitlesTable release];
    [feedViewToolbar release];
    [feedScoreSlider release];
    [logoutButton release];
    [intelligenceControl release];
    [activeFeedLocations release];
    [stillVisibleFeeds release];
    [visibleFeeds release];
    [sitesButton release];
    [pull release];
    [lastUpdate release];
    
    [dictFolders release];
    [dictFeeds release];
    [dictFoldersArray release];
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)returnToApp {
    NSDate *decayDate = [[NSDate alloc] initWithTimeIntervalSinceNow:(-10*60)];
    NSLog(@"Last Update: %@ - %f", self.lastUpdate, [self.lastUpdate timeIntervalSinceDate:decayDate]);
    if ([self.lastUpdate timeIntervalSinceDate:decayDate] < 0) {
        [self fetchFeedList:YES];
    }
    [decayDate release];
}

- (void)fetchFeedList:(BOOL)showLoader {
    if (showLoader && appDelegate.feedsViewController.view.window) {
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        HUD.labelText = @"On its way...";
    }
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    NSURL *urlFeedList = [NSURL URLWithString:
                          [NSString stringWithFormat:@"http://%@/reader/feeds?flat=true",
                           NEWSBLUR_URL]];
    responseData = [[NSMutableData data] retain];
    NSURLRequest *request = [[NSURLRequest alloc] initWithURL: urlFeedList];
    NSURLConnection *connection = [[NSURLConnection alloc] 
                                   initWithRequest:request delegate:self];
    [connection release];
    [request release];
    
    self.lastUpdate = [NSDate date];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    [responseData setLength:0];
    NSHTTPURLResponse* httpResponse = (NSHTTPURLResponse*)response;
    int responseStatusCode = [httpResponse statusCode];
    if (responseStatusCode == 403) {
        [appDelegate showLogin];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    //NSLog(@"didReceiveData: %@", data);
    [responseData appendData:data];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"%@", [NSString stringWithFormat:@"Connection failed: %@", [error description]]);
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [pull finishedLoading];
    
    // User clicking on another link before the page loads is OK.
    if ([error code] != NSURLErrorCancelled) {
        [NewsBlurAppDelegate informError:error];
    }
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    //[connection release];
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    self.visibleFeeds = [NSMutableDictionary dictionary];
    [pull finishedLoading];
    [self loadFavicons];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    NSString *jsonString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
    [responseData release];
    
    if ([jsonString length] > 0) {
        NSDictionary *results = [[NSDictionary alloc] 
                                 initWithDictionary:[jsonString JSONValue]];
        appDelegate.activeUsername = [results objectForKey:@"user"];
        if (appDelegate.feedsViewController.view.window) {
            [appDelegate setTitle:[results objectForKey:@"user"]];
        }
        self.dictFolders = [results objectForKey:@"flat_folders"];
        self.dictFeeds = [results objectForKey:@"feeds"];
        //      NSLog(@"Received Feeds: %@", dictFolders);
        //      NSSortDescriptor *sortDescriptor;
        //      sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"feed_title"
        //                                                    ascending:YES] autorelease];
        //      NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
        NSMutableDictionary *sortedFolders = [[NSMutableDictionary alloc] init];
        //      NSArray *sortedArray;
        
        self.dictFoldersArray = [NSMutableArray array];
        for (id f in self.dictFolders) {
            //          NSString *folderTitle = [f 
            //                                   stringByTrimmingCharactersInSet:
            //                                   [NSCharacterSet whitespaceCharacterSet]];
            [self.dictFoldersArray addObject:f];
            //          NSArray *folder = [self.dictFolders objectForKey:f];
            //          NSLog(@"F: %@", f);
            //          NSLog(@"F: %@", folder);
            //          NSLog(@"F: %@", sortDescriptors);
            //          sortedArray = [folder sortedArrayUsingDescriptors:sortDescriptors];
            //          [sortedFolders setValue:sortedArray forKey:f];
        }
        
        //      self.dictFolders = sortedFolders;
        [self.dictFoldersArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
        
        [self calculateFeedLocations:YES];
        [self.feedTitlesTable reloadData];
        
        [sortedFolders release];
        [results release];
    }
    
    [jsonString release];
}


- (IBAction)doLogoutButton {
    UIAlertView *logoutConfirm = [[UIAlertView alloc] initWithTitle:@"Positive?" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Logout", nil];
    [logoutConfirm show];
    [logoutConfirm release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (buttonIndex == 0) {
        return;
    } else {
        NSLog(@"Logging out...");
        NSString *urlS = [NSString stringWithFormat:@"http://%@/reader/logout?api=1",
                          NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlS];
        NSURLRequest *urlR=[[[NSURLRequest alloc] initWithURL:url] autorelease];
        [[NSHTTPCookieStorage sharedHTTPCookieStorage]
         setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
        LogoutDelegate *ld = [LogoutDelegate alloc];
        NSURLConnection *urlConnection = [[NSURLConnection alloc] 
                                          initWithRequest:urlR 
                                          delegate:ld];
        [urlConnection release];
        [ld release];
    }
}

- (IBAction)doSwitchSitesUnread {
    self.viewShowingAllFeeds = !self.viewShowingAllFeeds;
    
    if (self.viewShowingAllFeeds) {
        [self.sitesButton setTitle:@"Unreads"];
    } else {
        [self.sitesButton setTitle:@"All Sites"];
    }
    
    NSInteger intelligenceLevel = [appDelegate selectedIntelligence];
    NSMutableArray *indexPaths = [NSMutableArray array];
    
    if (self.viewShowingAllFeeds) {
        [self calculateFeedLocations:NO];
    }
    
    for (int s=0; s < [self.dictFoldersArray count]; s++) {
        NSString *folderName = [self.dictFoldersArray objectAtIndex:s];
        NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
        NSArray *originalFolder = [self.dictFolders objectForKey:folderName];
        for (int f=0; f < [activeFolderFeeds count]; f++) {
            int location = [[activeFolderFeeds objectAtIndex:f] intValue];
            id feedId = [originalFolder objectAtIndex:location];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:f inSection:s];
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
            NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
            int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
            
            if (maxScore < intelligenceLevel && 
                ![self.stillVisibleFeeds objectForKey:feedIdStr]) {
                [indexPaths addObject:indexPath];
            }
        }
    }
    
    if (!self.viewShowingAllFeeds) {
        [self calculateFeedLocations:YES];
    }
    
    [self.feedTitlesTable beginUpdates];
    if ([indexPaths count] > 0) {
        if (self.viewShowingAllFeeds) {
            [self.feedTitlesTable insertRowsAtIndexPaths:indexPaths 
                                        withRowAnimation:UITableViewRowAnimationNone];
        } else {
            [self.feedTitlesTable deleteRowsAtIndexPaths:indexPaths 
                                        withRowAnimation:UITableViewRowAnimationNone];
        }
    }
    [self.feedTitlesTable endUpdates];
    
    // Forget still visible feeds, since they won't be populated when
    // all feeds are showing, and shouldn't be populated after this
    // hide/show runs.
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    [self redrawUnreadCounts];
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return [self.dictFoldersArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [self.dictFoldersArray objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *folderName = [self.dictFoldersArray objectAtIndex:section];
    return [[self.activeFeedLocations objectForKey:folderName] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *FeedCellIdentifier = @"FeedCellIdentifier";
    
    FeedTableCell *cell = (FeedTableCell *)[tableView dequeueReusableCellWithIdentifier:FeedCellIdentifier];    
    if (cell == nil) {
        cell = [[[FeedTableCell alloc] initWithFrame:CGRectZero reuseIdentifier:@"FeedCellIdentifier"] autorelease];
        cell.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
        
    }
    
    NSString *folderName = [self.dictFoldersArray objectAtIndex:indexPath.section];
    NSArray *feeds = [self.dictFolders objectForKey:folderName];
    NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
    int location = [[activeFolderFeeds objectAtIndex:indexPath.row] intValue];
    id feedId = [feeds objectAtIndex:location];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    cell.feedTitle = [feed objectForKey:@"feed_title"];
    
    NSString *favicon = [feed objectForKey:@"favicon"];
    if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
        NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
        cell.feedFavicon = [UIImage imageWithData:imageData];
    } else {
        cell.feedFavicon = [UIImage imageNamed:@"world.png"];
    }
    
    cell.positiveCount = [[feed objectForKey:@"ps"] intValue];
    cell.neutralCount  = [[feed objectForKey:@"nt"] intValue];
    cell.negativeCount = [[feed objectForKey:@"ng"] intValue];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString *folderName = [self.dictFoldersArray objectAtIndex:indexPath.section];
    NSArray *feeds = [self.dictFolders objectForKey:folderName];
    NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
    int location = [[activeFolderFeeds objectAtIndex:indexPath.row] intValue];
    id feedId = [feeds objectAtIndex:location];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    
    // If all feeds are already showing, no need to remember this one.
    if (!self.viewShowingAllFeeds) {
        [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
    }
    
    [appDelegate setActiveFeed:feed];
    [appDelegate setActiveFeedIndexPath:indexPath];
    appDelegate.readStories = [NSMutableArray array];
    
    [appDelegate loadFeedDetailView];
}

- (CGFloat)tableView:(UITableView *)tableView 
heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kTableViewRowHeight;
}

- (UIView *)tableView:(UITableView *)tableView 
viewForHeaderInSection:(NSInteger)section {
    // create the parent view that will hold header Label
    UIView* customView = [[[UIView alloc] 
                           initWithFrame:CGRectMake(0.0, 0.0, 
                                                    tableView.bounds.size.width, 21.0)] 
                          autorelease];
    
    
    UIView *borderBottom = [[[UIView alloc] 
                             initWithFrame:CGRectMake(0.0, 20.0, 
                                                      tableView.bounds.size.width, 1.0)]
                            autorelease];
    borderBottom.backgroundColor = [UIColorFromRGB(0xB7BDC6) colorWithAlphaComponent:0.5];
    borderBottom.opaque = NO;
    [customView addSubview:borderBottom];
    
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
                                  colorWithAlphaComponent:0.8];
    customView.opaque = NO;
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:11];
    headerLabel.frame = CGRectMake(36.0, 1.0, 286.0, 20.0);
    headerLabel.text = [[self.dictFoldersArray objectAtIndex:section] uppercaseString];
    headerLabel.shadowColor = [UIColor colorWithRed:.94 green:0.94 blue:0.97 alpha:1.0];
    headerLabel.shadowOffset = CGSizeMake(1.0, 1.0);
    [customView addSubview:headerLabel];
    [headerLabel release];
    
    UIImage *folderImage = [UIImage imageNamed:@"folder.png"];
    UIImageView *folderImageView = [[UIImageView alloc] initWithImage:folderImage];
    folderImageView.frame = CGRectMake(14.0, 2.0, 16.0, 16.0);
    [customView addSubview:folderImageView];
    [folderImageView release];
    
    return customView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    NSString *folder = [self.dictFoldersArray objectAtIndex:section];
    if ([[folder stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
        return 0;
    }
    return 21;
}

- (IBAction)selectIntelligence {
    NSInteger newLevel = [self.intelligenceControl selectedSegmentIndex] - 1;
    NSInteger previousLevel = [appDelegate selectedIntelligence];
    [appDelegate setSelectedIntelligence:newLevel];
    
    if (!self.viewShowingAllFeeds) {
        //      NSLog(@"Select Intelligence from %d to %d.", previousLevel, newLevel);
        [self updateFeedsWithIntelligence:previousLevel newLevel:newLevel];
    }
    
    [self redrawUnreadCounts];
}

- (void)updateFeedsWithIntelligence:(int)previousLevel newLevel:(int)newLevel {
    NSMutableArray *insertIndexPaths = [NSMutableArray array];
    NSMutableArray *deleteIndexPaths = [NSMutableArray array];
    
    if (newLevel <= previousLevel) {
        [self calculateFeedLocations:NO];
    }
    
    for (int s=0; s < [self.dictFoldersArray count]; s++) {
        NSString *folderName = [self.dictFoldersArray objectAtIndex:s];
        NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
        NSArray *originalFolder = [self.dictFolders objectForKey:folderName];
        for (int f=0; f < [originalFolder count]; f++) {
            NSNumber *feedId = [originalFolder objectAtIndex:f];
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
            NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
            int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
            
            if ([self.visibleFeeds objectForKey:feedIdStr]) {
                if (maxScore < newLevel) {
                    for (int l=0; l < [activeFolderFeeds count]; l++) {
                        if ([originalFolder objectAtIndex:[[activeFolderFeeds objectAtIndex:l] intValue]] == feedId) {
                            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:l inSection:s];
                            [deleteIndexPaths addObject:indexPath];
                            if ([self.stillVisibleFeeds objectForKey:feedIdStr]) {
                                [self.stillVisibleFeeds removeObjectForKey:feedIdStr];
                            }
                            break;
                        }
                    }
                }
            } else {
                if (maxScore >= newLevel) {
                    for (int l=0; l < [activeFolderFeeds count]; l++) {
                        if ([originalFolder objectAtIndex:[[activeFolderFeeds objectAtIndex:l] intValue]] == feedId) {
                            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:l inSection:s];
                            [self.visibleFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedIdStr];
                            [insertIndexPaths addObject:indexPath];
                            break;
                        }
                    }
                }
                
            }
        }
    }
    
    for (id feedIdStr in [self.stillVisibleFeeds allKeys]) {
        NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
        int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
        if (previousLevel != newLevel && maxScore < newLevel) {
            [deleteIndexPaths addObject:[self.stillVisibleFeeds objectForKey:feedIdStr]];
            [self.stillVisibleFeeds removeObjectForKey:feedIdStr];
            [self.visibleFeeds removeObjectForKey:feedIdStr];
        }
    }
    
    if (newLevel > previousLevel) {
        [self calculateFeedLocations:YES];
    }
    
    [self.feedTitlesTable beginUpdates];
    if ([deleteIndexPaths count] > 0) {
        [self.feedTitlesTable deleteRowsAtIndexPaths:deleteIndexPaths 
                                    withRowAnimation:UITableViewRowAnimationNone];
    }
    if ([insertIndexPaths count] > 0) {
        [self.feedTitlesTable insertRowsAtIndexPaths:insertIndexPaths 
                                    withRowAnimation:UITableViewRowAnimationNone];
    }
    [self.feedTitlesTable endUpdates];
}

- (void)redrawUnreadCounts {
    for (UITableViewCell *cell in self.feedTitlesTable.visibleCells) {
        [cell setNeedsDisplay];
    }
}

- (void)calculateFeedLocations:(BOOL)markVisible {
    self.activeFeedLocations = [NSMutableDictionary dictionary];
    if (markVisible) {
        self.visibleFeeds = [NSMutableDictionary dictionary];
    }
    for (NSString *folderName in self.dictFoldersArray) {
        NSArray *folder = [self.dictFolders objectForKey:folderName];
        NSMutableArray *feedLocations = [NSMutableArray array];
        for (int f=0; f < [folder count]; f++) {
            id feedId = [folder objectAtIndex:f];
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
            NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
            
            if (self.viewShowingAllFeeds) {
                NSNumber *location = [NSNumber numberWithInt:f];
                [feedLocations addObject:location];
            } else {
                int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
                if (maxScore >= appDelegate.selectedIntelligence) {
                    NSNumber *location = [NSNumber numberWithInt:f];
                    [feedLocations addObject:location];
                    if (markVisible) {
                        [self.visibleFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedIdStr];
                    }
                }
            }
        }
        [self.activeFeedLocations setObject:feedLocations forKey:folderName];
    }
}

+ (int)computeMaxScoreForFeed:(NSDictionary *)feed {
    int maxScore = -2;
    if ([[feed objectForKey:@"ng"] intValue] > 0) maxScore = -1;
    if ([[feed objectForKey:@"nt"] intValue] > 0) maxScore = 0;
    if ([[feed objectForKey:@"ps"] intValue] > 0) maxScore = 1;
    return maxScore;
}

#pragma mark -
#pragma mark Favicons


- (void)loadFavicons {
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/favicons",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
    
    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    for (id feed_id in results) {
        NSDictionary *feed = [self.dictFeeds objectForKey:feed_id];
        [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
        [self.dictFeeds setValue:feed forKey:feed_id];
    }
    
    [results release];
    [self.feedTitlesTable reloadData];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}


#pragma mark -
#pragma mark PullToRefresh

// called when the user pulls-to-refresh
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view {
    [self fetchFeedList:NO];
}

// called when the date shown needs to be updated, optional
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view {
    return self.lastUpdate;
}

@end


@implementation LogoutDelegate

@synthesize appDelegate;

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response {
    
}
- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data {
    
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    appDelegate = [[UIApplication sharedApplication] delegate];
    NSLog(@"Logout: %@", appDelegate);
    [appDelegate reloadFeedsView];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    NSLog(@"%@", [NSString stringWithFormat:@"Connection failed: %@", [error description]]);
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    
    // User clicking on another link before the page loads is OK.
    if ([error code] != NSURLErrorCancelled) {
        [NewsBlurAppDelegate informError:error];
    }
}

@end