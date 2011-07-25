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

#define kTableViewRowHeight 60;

@implementation FeedDetailViewController

@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider, feedMarkReadButton;
@synthesize stories;
@synthesize appDelegate;
@synthesize jsonString;
@synthesize feedPage;
@synthesize pageFetching;
@synthesize pageFinished;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
//    NSLog(@"Loaded Feed view: %@", appDelegate.activeFeed);
    self.pageFinished = NO;
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

- (void)fetchFeedDetail:(int)page {
//    NSLog(@"fetching page %d. %d fetching, %d finished.", self.feedPage, self.pageFetching, self.pageFinished);
    if ([appDelegate.activeFeed objectForKey:@"id"] != nil && !self.pageFetching && !self.pageFinished) {
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        
        NSString *theFeedDetailURL = [[NSString alloc] 
                                      initWithFormat:@"http://nb.local.host:8000/reader/feed/%@?page=%d", 
                                      [appDelegate.activeFeed objectForKey:@"id"],
                                      self.feedPage];
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
    NSArray *newStories = [results objectForKey:@"stories"];
    NSInteger newStoriesCount = [newStories count];
    NSInteger existingStoriesCount = appDelegate.storyCount;
    
    if (self.feedPage == 1) {
        [appDelegate setStories:newStories];
    } else if (newStoriesCount > 0) {
        [appDelegate addStories:newStories];
    }
    
//    NSLog(@"Stories: %d stories, page %d. %d new stories.", existingStoriesCount, self.feedPage, newStoriesCount);
    
    if (existingStoriesCount > 0 && newStoriesCount > 0) {
//        NSLog(@"Loading new stories on top of existing stories.");
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        for (int i=0; i < newStoriesCount; i++) {
            int row = existingStoriesCount+i;
            [indexPaths addObject:[NSIndexPath indexPathForRow:row inSection:0]];
        }
        [self.storyTitlesTable insertRowsAtIndexPaths:indexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
        [indexPaths release];
    } else if (newStoriesCount > 0) {
//        NSLog(@"Loading first page of new stories.");
        [self.storyTitlesTable reloadData];
    } else if (newStoriesCount == 0) {
//        NSLog(@"End of feed stories.");
        self.pageFinished = YES;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:existingStoriesCount 
                                                    inSection:0];
        NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
    }
    
    self.pageFetching = NO;
    
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
    
    self.pageFetching = NO;
}

- (UITableViewCell *)makeLoadingCell {
    UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:@"NoReuse"] autorelease];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        UIView * blue = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 321, 17)];
        [cell.contentView addSubview:blue];
        blue.backgroundColor = [UIColor whiteColor];
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:0.5f];
        blue.backgroundColor = [UIColor colorWithRed:.7f green:0.7f blue:0.7f alpha:1.0f];
        [UIView commitAnimations];
        [blue release];
    } else {
        cell.textLabel.text = @"Loading...";
        
        UIActivityIndicatorView *spinner = [[[UIActivityIndicatorView alloc] 
                                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray] autorelease];
        
        // Spacer is a 1x1 transparent png
        UIImage *spacer = [UIImage imageNamed:@"spacer"];
        
        UIGraphicsBeginImageContext(spinner.frame.size);
        
        [spacer drawInRect:CGRectMake(0,0,spinner.frame.size.width,spinner.frame.size.height)];
        UIImage* resizedSpacer = UIGraphicsGetImageFromCurrentImageContext();
        
        UIGraphicsEndImageContext();
        cell.imageView.image = resizedSpacer;
        [cell.imageView addSubview:spinner];
        [spinner startAnimating];
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    int storyCount = appDelegate.storyCount;
    if (self.pageFetching) {
        return storyCount + 1;
    } else {
        return storyCount;
    }
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
    
    if (indexPath.row >= appDelegate.storyCount) {
        return [self makeLoadingCell];
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
        cell.storyTitle.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
        cell.storyTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:12];
        cell.storyAuthor.textColor = [UIColor colorWithRed:0.58f green:0.58f blue:0.58f alpha:1.0];
        cell.storyAuthor.font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
        cell.storyDate.textColor = [UIColor colorWithRed:0.14f green:0.18f blue:0.42f alpha:1.0];
        cell.storyDate.font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
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
        cell.storyTitle.textColor = [UIColor colorWithRed:0.15f green:0.25f blue:0.25f alpha:0.9];
        cell.storyTitle.font = [UIFont fontWithName:@"Helvetica" size:12];
        cell.storyAuthor.textColor = [UIColor colorWithRed:0.58f green:0.58f blue:0.58f alpha:0.5];
        cell.storyAuthor.font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
        cell.storyDate.textColor = [UIColor colorWithRed:0.14f green:0.18f blue:0.42f alpha:0.5];
        cell.storyDate.font = [UIFont fontWithName:@"Helvetica" size:10];
        cell.storyUnreadIndicator.image = nil;
    }

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < appDelegate.storyCount) {
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] objectAtIndex:indexPath.row]];
        [appDelegate loadStoryDetailView];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
//    NSLog(@"Height for row: %d of %d stories. (Finished: %d)", indexPath.row, appDelegate.storyCount, self.pageFinished);
    if (indexPath.row >= appDelegate.storyCount && self.pageFinished) {
        return 16;
    } else {
        return kTableViewRowHeight;
    }
}

- (void)scrollViewDidScroll: (UIScrollView *)scroll {
    NSInteger currentOffset = scroll.contentOffset.y;
    NSInteger maximumOffset = scroll.contentSize.height - scroll.frame.size.height;
    
    if (maximumOffset - currentOffset <= 10.0) {
        [self fetchFeedDetail:self.feedPage+1];
    }
}

@end
