//
//  FeedDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "FeedDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "JSON.h"


@implementation FeedDetailViewController

@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider;
@synthesize stories;
@synthesize activeFeed;
@synthesize appDelegate;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		[appDelegate showNavigationBar:YES];
    }
    return self;
}

- (void)viewDidLoad {
    NSLog(@"Loaded Feed view: %@", self.activeFeed);
    [appDelegate showNavigationBar:YES];
    [self fetchFeedDetail];
    [super viewDidLoad];
}

- (void)viewDidAppear:(BOOL)animated {
    [appDelegate showNavigationBar:animated];
    
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [appDelegate hideNavigationBar:NO];
}

- (void)viewDidDisappear:(BOOL)animated {
    [appDelegate hideNavigationBar:YES];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
    NSLog(@"Unloading detail view: %@", self);
    [appDelegate hideNavigationBar:NO];
    self.activeFeed = nil;
    self.appDelegate = nil;
    self.stories = nil;
}

- (void)dealloc {
    [activeFeed release];
    [appDelegate release];
    [stories release];
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)fetchFeedDetail {
    if ([self.activeFeed objectForKey:@"id"] != nil) {
        NSString *theFeedDetailURL = [[NSString alloc] initWithFormat:@"http://nb.local.host:8000/reader/load_single_feed/?feed_id=%@", 
                                      [self.activeFeed objectForKey:@"id"]];
        NSLog(@"Url: %@", theFeedDetailURL);
        NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
        [theFeedDetailURL release];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL: urlFeedDetail];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        [connection release];
        [request release];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data 
{
	
	NSString *jsonString = [[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding];
	NSDictionary *results = [[NSDictionary alloc] initWithDictionary:[jsonString JSONValue]];
	
    NSArray *storiesArray = [[NSArray alloc] initWithArray:[results objectForKey:@"stories"]];
    self.stories = storiesArray;
    NSLog(@"Stories: %d -- %@", [self.stories count], [self storyTitlesTable]);
	[[self storyTitlesTable] reloadData];
    
    [storiesArray release];
    [results release];
	[jsonString release];
}


#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSLog(@"Stories: %d", [self.stories count]);
    return [self.stories count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *SimpleTableIdentifier = @"SimpleTableIdentifier";
	
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:SimpleTableIdentifier];
	if (cell == nil) {
		
		cell = [[[UITableViewCell alloc] 
				 initWithStyle:UITableViewCellStyleDefault
				 reuseIdentifier:SimpleTableIdentifier] autorelease];
	}
    
    cell.textLabel.text = [[self.stories objectAtIndex:indexPath.row] 
                           objectForKey:@"story_title"];
//	
//	int section_index = 0;
//	for (id f in self.dictFoldersArray) {
//		// NSLog(@"Cell: %i: %@", section_index, f);
//		if (section_index == indexPath.section) {
//			NSArray *feeds = [self.dictFolders objectForKey:f];
//			// NSLog(@"Cell: %i: %@: %@", section_index, f, [feeds objectAtIndex:indexPath.row]);
//			cell.textLabel.text = [[feeds objectAtIndex:indexPath.row] 
//								   objectForKey:@"feed_title"];
//			return cell;
//		}
//		section_index++;
//	}
//	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {

	
}

@end
