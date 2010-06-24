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
@synthesize jsonString;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
		[appDelegate showNavigationBar:YES];
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    //NSLog(@"Loaded Feed view: %@", self.activeFeed);
    [self fetchFeedDetail];
    
    UILabel *label = [[UILabel alloc] init];
	[label setFont:[UIFont boldSystemFontOfSize:16.0]];
	[label setBackgroundColor:[UIColor clearColor]];
	[label setTextColor:[UIColor whiteColor]];
	[label setText:[self.activeFeed objectForKey:@"feed_title"]];
    [label sizeToFit];
	[self.navigationController.navigationBar.topItem setTitleView:label];
    self.navigationController.navigationBar.backItem.title = @"All";
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.8];
	[label release];
    
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [appDelegate showNavigationBar:animated];
    
	[super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    
    [appDelegate hideNavigationBar:animated];
}

- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
    //NSLog(@"Unloading detail view: %@", self);
    self.activeFeed = nil;
    self.appDelegate = nil;
    self.stories = nil;
    self.jsonString = nil;
}

- (void)dealloc {
    [activeFeed release];
    [appDelegate release];
    [stories release];
    [jsonString release];
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)fetchFeedDetail {
    if ([self.activeFeed objectForKey:@"id"] != nil) {
        NSString *theFeedDetailURL = [[NSString alloc] initWithFormat:@"http://nb.local.host:8000/reader/load_single_feed/?feed_id=%@", 
                                      [self.activeFeed objectForKey:@"id"]];
        //NSLog(@"Url: %@", theFeedDetailURL);
        NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
        [theFeedDetailURL release];
        jsonString = nil;
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL: urlFeedDetail];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        [connection release];
        [request release];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data 
{   
	if(jsonString == nil) {
        jsonString = [[NSMutableString alloc] 
                      initWithData:data 
                      encoding:NSUTF8StringEncoding];
        
	} else {
		NSMutableString *temp_string = [[NSMutableString alloc] 
                                        initWithString:jsonString];
		
		[jsonString release];
		jsonString = [[NSMutableString alloc] 
                      initWithData:data 
                      encoding:NSUTF8StringEncoding];
		[temp_string appendString:jsonString];
        
		[jsonString release];
		jsonString = [[NSMutableString alloc] initWithString: temp_string];
		[temp_string release];
        
	}
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[jsonString JSONValue]];
	
    NSArray *storiesArray = [[NSArray alloc] 
                             initWithArray:[results objectForKey:@"stories"]];
    self.stories = storiesArray;
    //NSLog(@"Stories: %d -- %@", [self.stories count], [self storyTitlesTable]);
	[[self storyTitlesTable] reloadData];
    
    [storiesArray release];
    [results release];
	[jsonString release];
}


#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //NSLog(@"Stories: %d", [self.stories count]);
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
