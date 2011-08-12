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
@synthesize sitesButton;
@synthesize viewShowingAllFeeds;
@synthesize pull;
@synthesize lastUpdate;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictFoldersArray;

#pragma mark -
#pragma	mark Globals

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
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
	[self.feedTitlesTable deselectRowAtIndexPath:[feedTitlesTable indexPathForSelectedRow] animated:animated];
	if (appDelegate.activeFeedIndexPath) {
//		NSLog(@"Refreshing feed at %d / %d: %@", appDelegate.activeFeedIndexPath.section, appDelegate.activeFeedIndexPath.row, [appDelegate activeFeed]);
        [self.feedTitlesTable beginUpdates];
        [self.feedTitlesTable 
		 reloadRowsAtIndexPaths:[NSArray 
								 arrayWithObject:appDelegate.activeFeedIndexPath] 
		 withRowAnimation:UITableViewRowAnimationNone];
        [self.feedTitlesTable endUpdates];
		
		NSInteger previousLevel = [self.intelligenceControl selectedSegmentIndex] - 1;
		NSInteger newLevel = [appDelegate selectedIntelligence];
		[self updateFeedsWithIntelligence:previousLevel newLevel:newLevel];
	}
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_red.png"] forSegmentAtIndex:0];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_yellow.png"] forSegmentAtIndex:1];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_green.png"] forSegmentAtIndex:2];
    [self.intelligenceControl addTarget:self
								 action:@selector(selectIntelligence)
					   forControlEvents:UIControlEventValueChanged];
    [self.intelligenceControl setSelectedSegmentIndex:[appDelegate selectedIntelligence]+1];
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

- (void)fetchFeedList {
	NSURL *urlFeedList = [NSURL URLWithString:[NSString 
											   stringWithFormat:@"http://www.newsblur.com/reader/feeds?flat=true"]];
	responseData = [[NSMutableData data] retain];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL: urlFeedList];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
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
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
	//[connection release];
	[pull finishedLoading];
	[self loadFavicons];
	NSString *jsonString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
	[responseData release];
	if ([jsonString length] > 0) {
		NSDictionary *results = [[NSDictionary alloc] initWithDictionary:[jsonString JSONValue]];
		appDelegate.activeUsername = [results objectForKey:@"user"];
		[appDelegate setTitle:[results objectForKey:@"user"]];
		self.dictFolders = [results objectForKey:@"flat_folders"];
		self.dictFeeds = [results objectForKey:@"feeds"];
//		NSLog(@"Received Feeds: %@", dictFolders);
//		NSSortDescriptor *sortDescriptor;
//		sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"feed_title"
//													  ascending:YES] autorelease];
//		NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
		NSMutableDictionary *sortedFolders = [[NSMutableDictionary alloc] init];
//		NSArray *sortedArray;
		
		self.dictFoldersArray = [NSMutableArray array];
		for (id f in self.dictFolders) {
			[self.dictFoldersArray addObject:f];
//			NSArray *folder = [self.dictFolders objectForKey:f];
//			NSLog(@"F: %@", f);
//			NSLog(@"F: %@", folder);
//			NSLog(@"F: %@", sortDescriptors);
//			sortedArray = [folder sortedArrayUsingDescriptors:sortDescriptors];
//			[sortedFolders setValue:sortedArray forKey:f];
		}
		
//		self.dictFolders = sortedFolders;
		[self.dictFoldersArray sortUsingSelector:@selector(caseInsensitiveCompare:)];

		[self calculateFeedLocations];
		[self.feedTitlesTable reloadData];
		
		[sortedFolders release];
		[results release];
	}
	[jsonString release];
}


- (IBAction)doLogoutButton {
	NSLog(@"Logging out...");
	NSString *urlS = @"http://www.newsblur.com/reader/logout?api=1";
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

- (IBAction)switchSitesUnread {
	self.viewShowingAllFeeds = !self.viewShowingAllFeeds;
	
	if (self.viewShowingAllFeeds) {
		[self.sitesButton setTitle:@"Unreads"];
	} else {
		[self.sitesButton setTitle:@"All Sites"];
	}
	
	NSInteger intelligenceLevel = [appDelegate selectedIntelligence];
	NSMutableArray *indexPaths = [NSMutableArray array];

	if (self.viewShowingAllFeeds) {
		[self calculateFeedLocations];
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
			
			if (maxScore < intelligenceLevel) {
				[indexPaths addObject:indexPath];
			}
		}
	}
	
	if (!self.viewShowingAllFeeds) {
		[self calculateFeedLocations];
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
//		NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"FeedTableCell"
//                                                     owner:nil
//                                                   options:nil];
//        for (id oneObject in nib) {
//            if ([oneObject isKindOfClass:[FeedTableCell class]]) {
//                cell = (FeedTableCell *)oneObject;
//				break;
//            }
//        }
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
	cell.neutralCount = [[feed objectForKey:@"nt"] intValue];
	cell.negativeCount = [[feed objectForKey:@"ng"] intValue];
//	[cell.feedUnreadView loadHTMLString:[self showUnreadCount:feed] baseURL:nil];
	
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

	[appDelegate setActiveFeed:feed];
	[appDelegate setActiveFeedIndexPath:indexPath];
	
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
	headerLabel.frame = CGRectMake(26.0, 1.0, 286.0, 20.0);
	headerLabel.text = [[self.dictFoldersArray objectAtIndex:section] uppercaseString];
	headerLabel.shadowColor = [UIColor colorWithRed:.94 green:0.94 blue:0.97 alpha:1.0];
	headerLabel.shadowOffset = CGSizeMake(1.0, 1.0);
	[customView addSubview:headerLabel];
	[headerLabel release];
	
	UIImage *folderImage = [UIImage imageNamed:@"folder.png"];
	UIImageView *folderImageView = [[UIImageView alloc] initWithImage:folderImage];
	folderImageView.frame = CGRectMake(10.0, 2.0, 16.0, 16.0);
	[customView addSubview:folderImageView];
	[folderImageView release];
	
	return customView;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
	return 21;
}

- (NSString *)showUnreadCount:(NSDictionary *)feed {
	NSString *imgCssString = [NSString stringWithFormat:@"<style>"
                              "body {"
                              "  line-height: 18px;"
                              "  font-size: 13px;"
                              "  font-family: 'Lucida Grande',Helvetica, Arial;"
                              "  text-rendering: optimizeLegibility;"
                              "  margin: 0;"
							  "  background-color: white"
                              "}"
							  ".NB-count {"
							  "  float: right;"
							  "  margin: 0px 2px 0 0;"
							  "  padding: 2px 4px 2px;"
							  "  border: none;"
							  "  border-radius: 5px;"
							  "  font-weight: bold;"
							  "}"
							  ".NB-positive {"
							  "  color: white;"
							  "  background-color: #559F4D;"
							  "  background-image: -webkit-gradient(linear, 0% 0%, 0% 100%, from(#559F4D), to(#3B7613));"
							  "}"
							  ".NB-neutral {"
							  "  background-color: #F9C72A;"
							  "  background-image: -webkit-gradient(linear, 0% 0%, 0% 100%, from(#F9C72A), to(#E4AB00));"
							  "}"
							  ".NB-negative {"
							  "  color: white;"
							  "  background-color: #CC2A2E;"
							  "  background-image: -webkit-gradient(linear, 0% 0%, 0% 100%, from(#CC2A2E), to(#9B181B));"
							  "}"
                              "</style>"];
	int negativeCount = [[feed objectForKey:@"ng"] intValue];
	int neutralCount = [[feed objectForKey:@"nt"] intValue];
	int positiveCount = [[feed objectForKey:@"ps"] intValue];
	
	NSString *negativeCountString = [NSString stringWithFormat:@"<div class=\"NB-count NB-negative\">%@</div>",
									 [feed objectForKey:@"ng"]];
	NSString *neutralCountString = [NSString stringWithFormat:@"<div class=\"NB-count NB-neutral\">%@</div>",
									 [feed objectForKey:@"nt"]];
	NSString *positiveCountString = [NSString stringWithFormat:@"<div class=\"NB-count NB-positive\">%@</div>",
									 [feed objectForKey:@"ps"]];
    NSString *htmlString = [NSString stringWithFormat:@"%@ %@ %@ %@",
                            imgCssString, 
							!!positiveCount ? positiveCountString : @"", 
							!!neutralCount ? neutralCountString : @"", 
							!!negativeCount ? negativeCountString : @""];

    return htmlString;
}


- (IBAction)selectIntelligence {
	if (!self.viewShowingAllFeeds) {
		NSInteger newLevel = [self.intelligenceControl selectedSegmentIndex] - 1;
		NSInteger previousLevel = [appDelegate selectedIntelligence];
		[self updateFeedsWithIntelligence:previousLevel newLevel:newLevel];
	}
	// TODO: Refresh cells on screen to show correct unread pills.
}

- (void)updateFeedsWithIntelligence:(int)previousLevel newLevel:(int)newLevel {
    NSMutableArray *insertIndexPaths = [NSMutableArray array];
    NSMutableArray *deleteIndexPaths = [NSMutableArray array];

    if (newLevel < previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
		[self calculateFeedLocations];
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
			
			if (previousLevel == -1) {
				if (newLevel == 0 && maxScore == -1) {
					[deleteIndexPaths addObject:indexPath];
				} else if (newLevel == 1 && maxScore < 1) {
					[deleteIndexPaths addObject:indexPath];
				}
			} else if (previousLevel == 0) {
				if (newLevel == -1 && maxScore == -1) {
					[insertIndexPaths addObject:indexPath];
				} else if (newLevel == 1 && maxScore == 0) {
					[deleteIndexPaths addObject:indexPath];
				}
			} else if (previousLevel == 1) {
				if (newLevel == 0 && maxScore == 0) {
					[insertIndexPaths addObject:indexPath];
				} else if (newLevel == -1 && (maxScore == -1 || maxScore == 0)) {
					[insertIndexPaths addObject:indexPath];
				}
			}
		}
	}
    
    if (newLevel > previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
		[self calculateFeedLocations];
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

- (void)calculateFeedLocations {
    self.activeFeedLocations = [NSMutableDictionary dictionary];
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
	NSString *urlString = @"http://www.newsblur.com/reader/favicons";
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
	[self fetchFeedList];
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

@end