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
#import "ASIFormDataRequest.h"
#import "GTMNString+HTML.h"
#import "JSON.h"

#define kTableViewRowHeight 65;

@implementation FeedDetailViewController

@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider, feedMarkReadButton;
@synthesize stories;
@synthesize appDelegate;
@synthesize jsonString;
@synthesize feedPage;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize intelligenceControl;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewWillAppear:(BOOL)animated {
    self.pageFinished = NO;
    self.title = [appDelegate.activeFeed objectForKey:@"feed_title"];
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (id i in appDelegate.recentlyReadStories) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[i intValue]
                                                inSection:0];
        [indexPaths addObject:indexPath];
    }
    [appDelegate setRecentlyReadStories:[NSMutableArray array]];
    if ([indexPaths count] > 0) {
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
    }
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_red.png"] forSegmentAtIndex:0];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_yellow.png"] forSegmentAtIndex:1];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_green.png"] forSegmentAtIndex:2];
    [self.intelligenceControl addTarget:self
                         action:@selector(selectIntelligence)
               forControlEvents:UIControlEventValueChanged];
    [self.intelligenceControl setSelectedSegmentIndex:[appDelegate selectedIntelligence]+1];
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

- (void)dealloc {
    [storyTitlesTable release];
    [feedViewToolbar release];
    [feedScoreSlider release];
    [feedMarkReadButton release];
    [stories release];
    [appDelegate release];
    [jsonString release];
    [intelligenceControl release];
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)fetchFeedDetail:(int)page {
    if ([appDelegate.activeFeed objectForKey:@"id"] != nil && !self.pageFetching && !self.pageFinished) {
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        
        NSString *theFeedDetailURL = [[NSString alloc] 
                                      initWithFormat:@"http://www.newsblur.com/reader/feed/%@?page=%d", 
                                      [appDelegate.activeFeed objectForKey:@"id"],
                                      self.feedPage];
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
    NSInteger existingStoriesCount = [[appDelegate activeFeedStoryLocations] count];
    
    if (self.feedPage == 1) {
        [appDelegate setStories:newStories];
    } else if ([newStories count] > 0) {        
        [appDelegate addStories:newStories];
    }
    
    NSInteger newStoriesCount = [[appDelegate activeFeedStoryLocations] count] - existingStoriesCount;
    
    if (existingStoriesCount > 0 && newStoriesCount > 0) {
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        for (int i=0; i < newStoriesCount; i++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:(existingStoriesCount+i) 
                                                     inSection:0]];
        }
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable insertRowsAtIndexPaths:indexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
        [indexPaths release];
    } else if (newStoriesCount > 0) {
        [self.storyTitlesTable reloadData];
    } else if (newStoriesCount == 0) {
        self.pageFinished = YES;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:existingStoriesCount 
                                                    inSection:0];
        NSArray *indexPaths = [NSArray arrayWithObject:indexPath];
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable reloadRowsAtIndexPaths:indexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
    }
    
    self.pageFetching = NO;
    
    [self performSelector:@selector(checkScroll)
               withObject:nil
               afterDelay:1.0];
    
    [results release];
    [jsonS release];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [connection release];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription]);
    
    self.pageFetching = NO;
}

- (UITableViewCell *)makeLoadingCell {
    UITableViewCell *cell = [[[UITableViewCell alloc] 
                              initWithStyle:UITableViewCellStyleSubtitle 
                              reuseIdentifier:@"NoReuse"] autorelease];
    
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
    int storyCount = [[appDelegate activeFeedStoryLocations] count];

    // The + 1 is for the finished/loading bar.
    return storyCount + 1;
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
    
    if (indexPath.row >= [[appDelegate activeFeedStoryLocations] count]) {
        return [self makeLoadingCell];
    }
    
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor.text = [[story objectForKey:@"story_authors"] uppercaseString];
    } else {
        cell.storyAuthor.text = @"";
    }
    NSString *title = [story objectForKey:@"story_title"];
//    cell.storyTitle.text = [title stringByDecodingHTMLEntities];
    cell.storyTitle.text = title;
    cell.storyDate.text = [story objectForKey:@"short_parsed_date"];
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_green.png"];
    } else if (score == 0) {
        cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_yellow.png"];
    } else if (score < 0) {
        cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_red.png"];
    }
    
    if ([[story objectForKey:@"read_status"] intValue] != 1) {
        // Unread story
        cell.storyTitle.textColor = [UIColor colorWithRed:0.1f green:0.1f blue:0.1f alpha:1.0];
        cell.storyTitle.font = [UIFont fontWithName:@"Helvetica-Bold" size:13];
        cell.storyAuthor.textColor = [UIColor colorWithRed:0.58f green:0.58f blue:0.58f alpha:1.0];
        cell.storyAuthor.font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
        cell.storyDate.textColor = [UIColor colorWithRed:0.14f green:0.18f blue:0.42f alpha:1.0];
        cell.storyDate.font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
        cell.storyUnreadIndicator.alpha = 1;

    } else {
        // Read story
        cell.storyTitle.textColor = [UIColor colorWithRed:0.15f green:0.25f blue:0.25f alpha:0.9];
        cell.storyTitle.font = [UIFont fontWithName:@"Helvetica" size:12];
        cell.storyAuthor.textColor = [UIColor colorWithRed:0.58f green:0.58f blue:0.58f alpha:0.5];
        cell.storyAuthor.font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
        cell.storyDate.textColor = [UIColor colorWithRed:0.14f green:0.18f blue:0.42f alpha:0.5];
        cell.storyDate.font = [UIFont fontWithName:@"Helvetica" size:10];
        cell.storyUnreadIndicator.alpha = 0.15f;
    }

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < appDelegate.storyCount) {
        int location = [[[appDelegate activeFeedStoryLocations] objectAtIndex:indexPath.row] intValue];
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] objectAtIndex:location]];
        [appDelegate loadStoryDetailView];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [[appDelegate activeFeedStoryLocations] count]) {
        if (self.pageFinished) return 16;
        else return kTableViewRowHeight;
    } else {
        return kTableViewRowHeight;
    }
}

- (void)scrollViewDidScroll: (UIScrollView *)scroll {
    [self checkScroll];
}

- (void)checkScroll {
    NSInteger currentOffset = self.storyTitlesTable.contentOffset.y;
    NSInteger maximumOffset = self.storyTitlesTable.contentSize.height - self.storyTitlesTable.frame.size.height;
    
    if (maximumOffset - currentOffset <= 60.0) {
        [self fetchFeedDetail:self.feedPage+1];
    }
}

- (IBAction)markAllRead {
    NSString *urlString = @"http://www.newsblur.com/reader/mark_feed_as_read";
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[appDelegate.activeFeed objectForKey:@"id"] forKey:@"feed_id"]; 
    [request setDelegate:nil];
    [request setDidFinishSelector:@selector(markedAsRead)];
    [request setDidFailSelector:@selector(markedAsRead)];
    [request startAsynchronous];
    [appDelegate markActiveFeedAllRead];
    [appDelegate.navigationController 
     popToViewController:[appDelegate.navigationController.viewControllers 
                          objectAtIndex:0]  
     animated:YES];
}

- (void)markedAsRead {
    
}

- (IBAction)selectIntelligence {
    NSInteger newLevel = [self.intelligenceControl selectedSegmentIndex] - 1;
    NSInteger previousLevel = [appDelegate selectedIntelligence];
    NSMutableArray *insertIndexPaths = [NSMutableArray array];
    NSMutableArray *deleteIndexPaths = [NSMutableArray array];
    
    if (newLevel == previousLevel) return;
    
    if (newLevel < previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
        [appDelegate calculateStoryLocations];
    }

    for (int i=0; i < [[appDelegate activeFeedStoryLocations] count]; i++) {
        int location = [[[appDelegate activeFeedStoryLocations] objectAtIndex:i] intValue];
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:i inSection:0];
        NSDictionary *story = [appDelegate.activeFeedStories objectAtIndex:location];
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        
        if (previousLevel == -1) {
            if (newLevel == 0 && score == -1) {
                [deleteIndexPaths addObject:indexPath];
            } else if (newLevel == 1 && score < 1) {
                [deleteIndexPaths addObject:indexPath];
            }
        } else if (previousLevel == 0) {
            if (newLevel == -1 && score == -1) {
                [insertIndexPaths addObject:indexPath];
            } else if (newLevel == 1 && score == 0) {
                [deleteIndexPaths addObject:indexPath];
            }
        } else if (previousLevel == 1) {
            if (newLevel == 0 && score == 0) {
                [insertIndexPaths addObject:indexPath];
            } else if (newLevel == -1 && score < 1) {
                [insertIndexPaths addObject:indexPath];
            }
        }
    }
    
    if (newLevel > previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
        [appDelegate calculateStoryLocations];
    }
    
    [self.storyTitlesTable beginUpdates];
    if ([deleteIndexPaths count] > 0) {
        [self.storyTitlesTable deleteRowsAtIndexPaths:deleteIndexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
    }
    if ([insertIndexPaths count] > 0) {
        [self.storyTitlesTable insertRowsAtIndexPaths:insertIndexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
    }
    [self.storyTitlesTable endUpdates];
    
    [self performSelector:@selector(checkScroll)
                withObject:nil
                afterDelay:1.0];
}

- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow {
    int row = [[[appDelegate activeFeedStoryLocations] objectAtIndex:indexPathRow] intValue];
    return [appDelegate.activeFeedStories objectAtIndex:row];
}

@end
