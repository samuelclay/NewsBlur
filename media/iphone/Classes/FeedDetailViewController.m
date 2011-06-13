//
//  FeedDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "FeedDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FeedDetailTableCell.h"
#import "JSON.h"

#define kTableViewRowHeight 55;

@implementation FeedDetailViewController

@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider, feedMarkReadButton;
@synthesize stories;
@synthesize appDelegate;
@synthesize jsonString;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    NSLog(@"Loaded Feed view: %@", appDelegate.activeFeed);
    
    self.title = [appDelegate.activeFeed objectForKey:@"feed_title"];
    
	[super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    //[appDelegate showNavigationBar:animated];
    [[storyTitlesTable cellForRowAtIndexPath:[storyTitlesTable indexPathForSelectedRow]] setSelected:NO]; // TODO: DESELECT CELL 
	[super viewDidAppear:animated];
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
    self.appDelegate = nil;
    self.jsonString = nil;
}

- (void)dealloc {
    [appDelegate release];
    [stories release];
    [jsonString release];
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)fetchFeedDetail {
    if ([appDelegate.activeFeed objectForKey:@"id"] != nil) {
        NSString *theFeedDetailURL = [[NSString alloc] 
                                      initWithFormat:@"http://nb.local.host:8000/reader/feed/%@", 
                                      [appDelegate.activeFeed objectForKey:@"id"]];
        //NSLog(@"Url: %@", theFeedDetailURL);
        NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
        [theFeedDetailURL release];
        jsonString = [[NSMutableData data] retain];
        NSURLRequest *request = [[NSURLRequest alloc] initWithURL: urlFeedDetail];
        NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
        [connection release];
        [request release];
    }
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
    [jsonString setLength:0];
}

- (void)connection:(NSURLConnection *)connection didReceiveData:(NSData *)data 
{   
    [jsonString appendData:data];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)connection {
    NSString *jsonS = [[NSString alloc] 
                       initWithData:jsonString 
                       encoding:NSUTF8StringEncoding];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[jsonS JSONValue]];
	
    NSArray *storiesArray = [[NSArray alloc] 
                             initWithArray:[results objectForKey:@"stories"]];
    [appDelegate setActiveFeedStories:storiesArray];
    //NSLog(@"Stories: %d -- %@", [appDelegate.activeFeedStories count], [self storyTitlesTable]);
	[[self storyTitlesTable] reloadData];
    
    [storiesArray release];
    [results release];
    [jsonS release];
	[jsonString release];
}

- (void)connection:(NSURLConnection *)connection
  didFailWithError:(NSError *)error
{
    // release the connection, and the data object
    [connection release];
    // receivedData is declared as a method instance elsewhere
    [jsonString release];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription]);
}


#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    //NSLog(@"Stories: %d", [appDelegate.activeFeedStories count]);
    return [appDelegate.activeFeedStories count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	static NSString *FeedDetailCellIdentifier = @"FeedDetailCellIdentifier";
	
	FeedDetailTableCell *cell = (FeedDetailTableCell *)[tableView dequeueReusableCellWithIdentifier:FeedDetailCellIdentifier];
	if (cell == nil) {
		NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"FeedDetailTableCell"
                                                     owner:self
                                                   options:nil];
        for (id oneObject in nib) {
            if ([oneObject isKindOfClass:[FeedDetailTableCell class]]) {
                cell = (FeedDetailTableCell *)oneObject;
            }
        }
	}
    
    NSDictionary *story = [appDelegate.activeFeedStories objectAtIndex:indexPath.row];
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor.text = [[story objectForKey:@"story_authors"] uppercaseString];
    } else {
        cell.storyAuthor.text = @"";
    }
    cell.storyTitle.text = [story objectForKey:@"story_title"];
    cell.storyDate.text = [story objectForKey:@"short_parsed_date"];
    
    if ([[story objectForKey:@"read_status"] intValue] != 1) {
        // Unread story
        cell.storyTitle.textColor = [UIColor colorWithRed:0.05f green:0.05f blue:0.05f alpha:0.9];
        cell.storyAuthor.textColor = [UIColor colorWithRed:0.86f green:0.66f blue:0.36 alpha:0.9];
        cell.storyDate.textColor = [UIColor colorWithRed:0.26f green:0.36f blue:0.36 alpha:0.9];
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score > 0) {
            cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_green.png"];
        } else if (score == 0) {
            cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_orange.png"];
        } else if (score < 0) {
            cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_red.png"];
        }
    } else {
        // Read story
        //cell.storyTitle.font = 
        cell.storyTitle.textColor = [UIColor colorWithRed:0.26f green:0.36f blue:0.36 alpha:0.4];
        cell.storyAuthor.textColor = [UIColor colorWithRed:0.76f green:0.56f blue:0.36 alpha:0.4];
        cell.storyDate.textColor = [UIColor colorWithRed:0.26f green:0.36f blue:0.36 alpha:0.4];
        cell.storyUnreadIndicator.image = nil;
    }

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [appDelegate setActiveStory:[[appDelegate activeFeedStories] objectAtIndex:indexPath.row]];
	[appDelegate loadStoryDetailView];
	
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kTableViewRowHeight;
}

@end
