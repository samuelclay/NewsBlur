//
//  NewsBlurViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurViewController.h"
#import "NewsBlurAppDelegate.h"
#import "JSON.h"

@implementation NewsBlurViewController

@synthesize appDelegate;

@synthesize responseData;
@synthesize viewTableFeedTitles;
@synthesize feedViewToolbar;
@synthesize feedScoreSlider;
@synthesize logoutButton;

@synthesize feedTitleList;
@synthesize dictFolders;
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
	self.feedTitleList = [[NSMutableArray alloc] init];
	self.dictFolders = [[NSDictionary alloc] init];
	self.dictFoldersArray = [[NSMutableArray alloc] init];
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Logout" style:UIBarButtonItemStylePlain target:self action:@selector(doLogoutButton)];
	[appDelegate showNavigationBar:NO];
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
	[viewTableFeedTitles deselectRowAtIndexPath:[viewTableFeedTitles indexPathForSelectedRow] animated:animated];
	
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
	[feedTitleList release];
	[dictFolders release];
	[dictFoldersArray release];
	[appDelegate release];
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)fetchFeedList {
	NSURL *urlFeedList = [NSURL URLWithString:[NSString 
											   stringWithFormat:@"http://nb.local.host:8000/reader/feeds?flat=true"]];
	responseData = [[NSMutableData data] retain];
	NSURLRequest *request = [[NSURLRequest alloc] initWithURL: urlFeedList];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	[connection release];
	[request release];
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
	NSString *jsonString = [[NSString alloc] initWithData:responseData encoding:NSUTF8StringEncoding];
	[responseData release];
	if ([jsonString length] > 0) {
		NSDictionary *results = [[NSDictionary alloc] initWithDictionary:[jsonString JSONValue]];
		appDelegate.activeUsername = [results objectForKey:@"user"];
		[appDelegate setTitle:[results objectForKey:@"user"]];
		self.dictFolders = [results objectForKey:@"flat_folders"];
		//NSLog(@"Received Feeds: %@", dictFolders);
		NSSortDescriptor *sortDescriptor;
		sortDescriptor = [[[NSSortDescriptor alloc] initWithKey:@"feed_title"
													  ascending:YES] autorelease];
		NSArray *sortDescriptors = [NSArray arrayWithObject:sortDescriptor];
		NSMutableDictionary *sortedFolders = [[NSMutableDictionary alloc] init];
		NSArray *sortedArray;
		
		for (id f in self.dictFolders) {
			[self.dictFoldersArray addObject:f];
			
			sortedArray = [[self.dictFolders objectForKey:f] sortedArrayUsingDescriptors:sortDescriptors];
			[sortedFolders setValue:sortedArray forKey:f];
		}
		
		self.dictFolders = sortedFolders;
		[self.dictFoldersArray sortUsingSelector:@selector(caseInsensitiveCompare:)];
		
		[[self viewTableFeedTitles] reloadData];
		
		[sortedFolders release];
		[results release];
		[jsonString release];
	}
	[jsonString release];
}


- (IBAction)doLogoutButton {
	NSLog(@"Logging out...");
	NSString *urlS = @"http://nb.local.host:8000/reader/logout?api=1";
	NSURL *url = [NSURL URLWithString:urlS];
	NSURLRequest *urlR=[[[NSURLRequest alloc] initWithURL:url] autorelease];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
	LogoutDelegate *ld = [LogoutDelegate alloc];
	NSURLConnection *urlConnection = [[NSURLConnection alloc] initWithRequest:urlR delegate:ld];
	[urlConnection release];
	[ld release];
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self.dictFoldersArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
	int index = 0;
	for (id f in self.dictFoldersArray) {
		if (index == section) {
			// NSLog(@"Computing Table view header: %i: %@", index, f);
			return f;
		}
		index++;
	}
	return nil;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
	int index = 0;
	for (id f in self.dictFoldersArray) {
		if (index == section) {
			// NSLog(@"Computing Table view rows: %i: %@", index, f);	
			NSArray *feeds = [self.dictFolders objectForKey:f];
			//NSLog(@"Table view items: %i: %@", [feeds count], f);
			return [feeds count];
		}
		index++;
	}
	
	return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *SimpleTableIdentifier = @"SimpleTableIdentifier";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SimpleTableIdentifier];
	if (cell == nil) {
		cell = [[[UITableViewCell alloc] 
				 initWithStyle:UITableViewCellStyleDefault
				 reuseIdentifier:SimpleTableIdentifier] autorelease];
	}
	
	int section_index = 0;
	for (id f in self.dictFoldersArray) {
		// NSLog(@"Cell: %i: %@", section_index, f);
		if (section_index == indexPath.section) {
			NSArray *feeds = [self.dictFolders objectForKey:f];
			// NSLog(@"Cell: %i: %@: %@", section_index, f, [feeds objectAtIndex:indexPath.row]);
			cell.textLabel.text = [[feeds objectAtIndex:indexPath.row] 
								   objectForKey:@"feed_title"];
			return cell;
		}
		section_index++;
	}
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	int section_index = 0;
	for (id f in self.dictFoldersArray) {
		// NSLog(@"Cell: %i: %@", section_index, f);
		if (section_index == indexPath.section) {
			NSArray *feeds = [[NSArray alloc] initWithArray:[self.dictFolders objectForKey:f]];
			[appDelegate setActiveFeed:[feeds objectAtIndex:indexPath.row]];
			[feeds release];
			//NSLog(@"Active feed: %@", [appDelegate activeFeed]);
			break;
		}
		section_index++;
	}
	//NSLog(@"App Delegate: %@", self.appDelegate);
	
	[appDelegate loadFeedDetailView];
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