//
//  FeedDetailViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/20/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "FeedDetailViewController.h"
#import "NewsBlurAppDelegate.h"
#import "FeedDetailTableCell.h"
#import "PullToRefreshView.h"
#import "ASIFormDataRequest.h"
#import "NSString+HTML.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "JSON.h"
#import "StringHelper.h"
#import "Utilities.h"

#define kTableViewRowHeight 65;
#define kTableViewRiverRowHeight 81;
#define kMarkReadActionSheet 1;
#define kSettingsActionSheet 2;

@implementation FeedDetailViewController

@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider, feedMarkReadButton;
@synthesize settingsButton;
@synthesize stories;
@synthesize appDelegate;
@synthesize feedPage;
@synthesize pageFetching;
@synthesize pageRefreshing;
@synthesize pageFinished;
@synthesize intelligenceControl;
@synthesize pull;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewDidLoad {
	pull = [[PullToRefreshView alloc] initWithScrollView:self.storyTitlesTable];
    [pull setDelegate:self];
    [self.storyTitlesTable addSubview:pull];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    self.pageFinished = NO;
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    if (appDelegate.isRiverView) {
        self.storyTitlesTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        self.storyTitlesTable.separatorColor = [UIColor clearColor];
    } else {
        self.storyTitlesTable.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.storyTitlesTable.separatorColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:1.0];
    }
    
    UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
    self.navigationItem.titleView = titleLabel;

    // Commenting out until training is ready...
    //    UIBarButtonItem *trainBarButton = [UIBarButtonItem alloc];
    //    [trainBarButton setImage:[UIImage imageNamed:@"train.png"]];
    //    [trainBarButton setEnabled:YES];
    //    [self.navigationItem setRightBarButtonItem:trainBarButton animated:YES];
    //    [trainBarButton release];
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    for (id i in appDelegate.recentlyReadStories) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[i intValue]
                                                inSection:0];
//        NSLog(@"Read story: %d", [i intValue]);
        [indexPaths addObject:indexPath];
    }
    if ([indexPaths count] > 0) {
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
    }
    [appDelegate setRecentlyReadStories:[NSMutableArray array]];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_red.png"] forSegmentAtIndex:0];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_yellow.png"] forSegmentAtIndex:1];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_green.png"] forSegmentAtIndex:2];
    [self.intelligenceControl addTarget:self
                         action:@selector(selectIntelligence)
               forControlEvents:UIControlEventValueChanged];
    [self.intelligenceControl setSelectedSegmentIndex:[appDelegate selectedIntelligence]+1];
    
	[super viewWillAppear:animated];
    
    BOOL pullFound = NO;
    for (UIView *view in self.storyTitlesTable.subviews) {
        if ([view isKindOfClass:[PullToRefreshView class]]) {
            pullFound = YES;
            if (appDelegate.isRiverView) {
                [view removeFromSuperview];
            }
        }
    }
    if (!appDelegate.isRiverView && !pullFound) {
        [self.storyTitlesTable addSubview:pull];
    }
    
    if (appDelegate.isRiverView && [appDelegate.activeFolder isEqualToString:@"Everything"]) {
        settingsButton.enabled = NO;
    } else {
        settingsButton.enabled = YES;
    }
}

- (void)viewDidAppear:(BOOL)animated {
//    [[storyTitlesTable cellForRowAtIndexPath:[storyTitlesTable indexPathForSelectedRow]] setSelected:NO]; // TODO: DESELECT CELL --- done, see line below:
    [self.storyTitlesTable deselectRowAtIndexPath:[storyTitlesTable indexPathForSelectedRow] animated:YES];
    [pull refreshLastUpdatedDate];
    
	[super viewDidAppear:animated];
}

- (void)dealloc {
    [storyTitlesTable release];
    [feedViewToolbar release];
    [feedScoreSlider release];
    [feedMarkReadButton release];
    [settingsButton release];
    [stories release];
    [appDelegate release];
    [intelligenceControl release];
    [pull release];
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)resetFeedDetail {
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.pageRefreshing = NO;
    self.feedPage = 1;
}

- (void)fetchNextPage:(void(^)())callback {
    [self fetchFeedDetail:self.feedPage+1 withCallback:callback];
}

- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback {
    if ([appDelegate.activeFeed objectForKey:@"id"] != nil && !self.pageFetching && !self.pageFinished) {
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        
        NSString *theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/feed/%@?page=%d", 
                                      NEWSBLUR_URL,
                                      [appDelegate.activeFeed objectForKey:@"id"],
                                      self.feedPage];
        
        [self cancelRequests];
        __block ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            [self informError:[request error]];
        }];
        [request setCompletionBlock:^(void) {
            [self finishedLoadingFeed:request];
            if (callback) {
                callback();
            }
        }];
        [request setTimeOutSeconds:30];
        [request setTag:[[[appDelegate activeFeed] objectForKey:@"id"] intValue]];
        [request startAsynchronous];
    }
}

- (void)finishedLoadingFeed:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] >= 500) {
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.15 * NSEC_PER_SEC), 
                       dispatch_get_current_queue(), ^{
            [appDelegate.navigationController 
             popToViewController:[appDelegate.navigationController.viewControllers 
                                  objectAtIndex:0]  
             animated:YES];
        });
        [self informError:@"The server barfed!"];
        
        return;
    }
    
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    if (!appDelegate.isRiverView && request.tag != [[results objectForKey:@"feed_id"] intValue]) {
        [results release];
        return;
    }
    
    [pull finishedLoading];
    NSArray *newStories = [results objectForKey:@"stories"];
    NSMutableArray *confirmedNewStories = [NSMutableArray array];
    if ([appDelegate.activeFeedStories count]) {
        NSMutableSet *storyIds = [NSMutableSet set];
        for (id story in appDelegate.activeFeedStories) {
            [storyIds addObject:[story objectForKey:@"id"]];
        }
        for (id story in newStories) {
            if (![storyIds containsObject:[story objectForKey:@"id"]]) {
                [confirmedNewStories addObject:story];
            }
        }
    } else {
        confirmedNewStories = [[newStories copy] autorelease];
    }
    [self renderStories:confirmedNewStories];
    
    [results release];
}

#pragma mark -
#pragma mark River of News

- (void)fetchRiverPage:(int)page withCallback:(void(^)())callback {
    if (!self.pageFetching && !self.pageFinished) {
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        int readStoriesCount = 0;
        if (self.feedPage > 1) {
            for (id story in appDelegate.activeFeedStories) {
                if ([[story objectForKey:@"read_status"] intValue] == 1) {
                    readStoriesCount += 1;
                }
            }
        }
        
        NSString *theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/river_stories/?feeds=%@&page=%d&read_stories_count=%d", 
                                      NEWSBLUR_URL,
                                      [appDelegate.activeFolderFeeds componentsJoinedByString:@"&feeds="],
                                      self.feedPage,
                                      readStoriesCount];
        
        [self cancelRequests];
        __block ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            [self informError:[request error]];
        }];
        [request setCompletionBlock:^(void) {
            [self finishedLoadingFeed:request];
            if (callback) {
                callback();
            }
        }];
        [request setTimeOutSeconds:30];
        [request startAsynchronous];
    }
}

#pragma mark - 
#pragma mark Stories

- (void)renderStories:(NSArray *)newStories {
    NSInteger existingStoriesCount = [[appDelegate activeFeedStoryLocations] count];
    NSInteger newStoriesCount = [newStories count];
    
    if (self.feedPage == 1) {
        [appDelegate setStories:newStories];
    } else if (newStoriesCount > 0) {        
        [appDelegate addStories:newStories];
    }
    
    NSInteger newVisibleStoriesCount = [[appDelegate activeFeedStoryLocations] count] - existingStoriesCount;
    
//    NSLog(@"Paging: %d/%d", existingStoriesCount, [appDelegate unreadCount]);
    
    if (existingStoriesCount > 0 && newVisibleStoriesCount > 0) {
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        for (int i=0; i < newVisibleStoriesCount; i++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:(existingStoriesCount+i) 
                                                     inSection:0]];
        }
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable insertRowsAtIndexPaths:indexPaths 
                                     withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
        [indexPaths release];
    } else if (newVisibleStoriesCount > 0) {
        [self.storyTitlesTable reloadData];
    } else if (newStoriesCount == 0 || 
               (self.feedPage > 15 && 
                existingStoriesCount >= [appDelegate unreadCount])) {
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
               afterDelay:0.2];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    [connection release];
    
    // inform the user
    NSLog(@"Connection failed! Error - %@",
          [error localizedDescription]);
    
    self.pageFetching = NO;
    
	// User clicking on another link before the page loads is OK.
	if ([error code] != NSURLErrorCancelled) {
		[self informError:error];
	}
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
    if (self.pageRefreshing) {
        // Refreshing feed
        return 1;
    } else {    
        int storyCount = [[appDelegate activeFeedStoryLocations] count];

        // The +1 is for the finished/loading bar.
        return storyCount + 1;
    }
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *cellIdentifier;

    if (appDelegate.isRiverView) {
        cellIdentifier = @"FeedRiverDetailCellIdentifier";
    } else {
        cellIdentifier = @"FeedDetailCellIdentifier";
    }

    FeedDetailTableCell *cell = (FeedDetailTableCell *)[tableView 
                                                        dequeueReusableCellWithIdentifier:cellIdentifier];
	if (cell == nil) {
		NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"FeedDetailTableCell"
                                                     owner:self
                                                   options:nil];
        for (id oneObject in nib) {
            if ([oneObject isKindOfClass:[FeedDetailTableCell class]]) {
                if (([(FeedDetailTableCell *)oneObject tag] == 0 && !appDelegate.isRiverView) ||
                    ([(FeedDetailTableCell *)oneObject tag] == 1 && appDelegate.isRiverView)) {
                    cell = (FeedDetailTableCell *)oneObject;
                    break;
                }

            }
        }
	}
    
    if (indexPath.row >= [[appDelegate activeFeedStoryLocations] count]) {
        return [self makeLoadingCell];
    }
    
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    id feedId = [story objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor.text = [[story objectForKey:@"story_authors"] 
                                 uppercaseString];
    } else {
        cell.storyAuthor.text = @"";
    }
    
    BOOL isStoryRead = [[story objectForKey:@"read_status"] intValue] == 1;
    NSString *title = [story objectForKey:@"story_title"];
    cell.storyTitle.text = [title stringByDecodingHTMLEntities];
    cell.storyDate.text = [story objectForKey:@"short_parsed_date"];
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_green.png"];
    } else if (score == 0) {
        cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_yellow.png"];
    } else if (score < 0) {
        cell.storyUnreadIndicator.image = [UIImage imageNamed:@"bullet_red.png"];
    }
    
    // River view
    if (appDelegate.isRiverView && cell) {
        UIView *gradientView = [appDelegate makeFeedTitleGradient:feed 
                                withRect:CGRectMake(0, 0, cell.frame.size.width, 21)];
        [cell.feedGradient addSubview:gradientView];
    }
            
    if (!isStoryRead) {
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
//        cell.feedTitle.font = [UIFont fontWithName:@"Helvetica" size:11];
//        cell.feedTitle.textColor = [UIColor blackColor];
//        cell.feedTitle.shadowColor = nil;
//        cell.feedFavicon.alpha = 0.5f;
        cell.feedGradient.alpha = 0.25f;
    }

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [appDelegate.activeFeedStoryLocations count]) {
        int location = [[[appDelegate activeFeedStoryLocations] objectAtIndex:indexPath.row] intValue];
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] objectAtIndex:location]];
        [appDelegate setOriginalStoryCount:[appDelegate unreadCount]];
        [appDelegate loadStoryDetailView];
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= [[appDelegate activeFeedStoryLocations] count]) {
        if (self.pageFinished) return 16;
        else return kTableViewRowHeight;
    } else {
        if (appDelegate.isRiverView) {
            return kTableViewRiverRowHeight;
        } else {
            return kTableViewRowHeight;
        }
    }
}

- (void)scrollViewDidScroll: (UIScrollView *)scroll {
    [self checkScroll];
}

- (void)checkScroll {
    NSInteger currentOffset = self.storyTitlesTable.contentOffset.y;
    NSInteger maximumOffset = self.storyTitlesTable.contentSize.height - self.storyTitlesTable.frame.size.height;
    
    if (maximumOffset - currentOffset <= 60.0) {
        if (appDelegate.isRiverView) {
            [self fetchRiverPage:self.feedPage+1 withCallback:nil];
        } else {
            [self fetchFeedDetail:self.feedPage+1 withCallback:nil];   
        }
    }
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

#pragma mark -
#pragma mark Feed Actions


- (void)markFeedsReadWithAllStories:(BOOL)includeHidden {
    NSLog(@"mark feeds read: %d %d", appDelegate.isRiverView, includeHidden);
    if (appDelegate.isRiverView && includeHidden) {
        // Mark folder as read
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        for (id feed_id in [appDelegate.dictFolders objectForKey:appDelegate.activeFolder]) {
            [request addPostValue:feed_id forKey:@"feed_id"];
        }
        [request setDelegate:nil];
        [request startAsynchronous];
        
        [appDelegate markActiveFolderAllRead];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    } else if (!appDelegate.isRiverView && includeHidden) {
        // Mark feed as read
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[appDelegate.activeFeed objectForKey:@"id"] forKey:@"feed_id"]; 
        [request setDelegate:nil];
        [request startAsynchronous];
        
        [appDelegate markActiveFeedAllRead];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    } else {
        // Mark visible stories as read
        NSDictionary *feedsStories = [appDelegate markVisibleStoriesRead];
        NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/mark_feed_stories_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[feedsStories JSONRepresentation] forKey:@"feeds_stories"]; 
        [request setDelegate:nil];
        [request startAsynchronous];
        
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    }
}

- (IBAction)doOpenMarkReadActionSheet:(id)sender {
    // Individual sites just get marked as read, no action sheet needed.
    if (!appDelegate.isRiverView) {
        [self markFeedsReadWithAllStories:YES];
        return;
    }
    
    NSString *title = appDelegate.isRiverView ? 
                      appDelegate.activeFolder : 
                      [appDelegate.activeFeed objectForKey:@"feed_title"];
    UIActionSheet *options = [[UIActionSheet alloc] 
                              initWithTitle:title
                              delegate:self
                              cancelButtonTitle:nil
                              destructiveButtonTitle:nil
                              otherButtonTitles:nil];
    
    int visibleUnreadCount = appDelegate.visibleUnreadCount;
    int totalUnreadCount = [appDelegate unreadCount];
    NSArray *buttonTitles = nil;
    BOOL showVisible = YES;
    BOOL showEntire = YES;
    if ([appDelegate.activeFolder isEqualToString:@"Everything"]) showEntire = NO;
    if (visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0) showVisible = NO;  
    NSString *entireText = [NSString stringWithFormat:@"Mark %@ read", 
                            appDelegate.isRiverView ? 
                            @"entire folder" : 
                            @"this site"];
    NSString *visibleText = [NSString stringWithFormat:@"Mark %@ read", 
                             visibleUnreadCount == 1 ? @"this story as" : 
                                [NSString stringWithFormat:@"these %d stories", 
                                 visibleUnreadCount]];
    if (showVisible && showEntire) {
        buttonTitles = [NSArray arrayWithObjects:visibleText, entireText, nil];
        options.destructiveButtonIndex = 1;
    } else if (showVisible && !showEntire) {
        buttonTitles = [NSArray arrayWithObjects:visibleText, nil];
        options.destructiveButtonIndex = -1;
    } else if (!showVisible && showEntire) {
        buttonTitles = [NSArray arrayWithObjects:entireText, nil];
        options.destructiveButtonIndex = 0;
    }
    
    for (id title in buttonTitles) {
        [options addButtonWithTitle:title];
    }
    options.cancelButtonIndex = [options addButtonWithTitle:@"Cancel"];
    
    options.tag = kMarkReadActionSheet;
    [options showInView:self.view];
    [options release];
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
//    NSLog(@"Action option #%d on %d", buttonIndex, actionSheet.tag);
    if (actionSheet.tag == 1) {
        int visibleUnreadCount = appDelegate.visibleUnreadCount;
        int totalUnreadCount = [appDelegate unreadCount];
        BOOL showVisible = YES;
        BOOL showEntire = YES;
        if ([appDelegate.activeFolder isEqualToString:@"Everything"]) showEntire = NO;
        if (visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0) showVisible = NO;
//        NSLog(@"Counts: %d %d = %d", visibleUnreadCount, totalUnreadCount, visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0);

        if (showVisible && showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:NO];
            } else if (buttonIndex == 1) {
                [self markFeedsReadWithAllStories:YES];
            }               
        } else if (showVisible && !showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:NO];
            }   
        } else if (!showVisible && showEntire) {
            if (buttonIndex == 0) {
                [self markFeedsReadWithAllStories:YES];
            }
        }
    } else if (actionSheet.tag == 2) {
        if (buttonIndex == 0) {
            [self confirmDeleteSite];
        } else if (buttonIndex == 1) {
            [self openMoveView];
        }
    }
}

- (IBAction)doOpenSettingsActionSheet {
    NSString *title = appDelegate.isRiverView ? 
    appDelegate.activeFolder : 
    [appDelegate.activeFeed objectForKey:@"feed_title"];
    UIActionSheet *options = [[UIActionSheet alloc] 
                              initWithTitle:title
                              delegate:self
                              cancelButtonTitle:nil
                              destructiveButtonTitle:nil
                              otherButtonTitles:nil];
    
    if (![title isEqualToString:@"Everything"]) {
        NSString *deleteText = [NSString stringWithFormat:@"Delete %@", 
                                appDelegate.isRiverView ? 
                                @"this entire folder" : 
                                @"this site"];
        [options addButtonWithTitle:deleteText];
        options.destructiveButtonIndex = 0;
        
        NSString *moveText = @"Move to another folder";
        [options addButtonWithTitle:moveText];
    }
    
    options.cancelButtonIndex = [options addButtonWithTitle:@"Cancel"];
    options.tag = kSettingsActionSheet;
    [options showInView:self.view];
    [options release];
}

- (void)confirmDeleteSite {
    UIAlertView *deleteConfirm = [[UIAlertView alloc] initWithTitle:@"Positive?" message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Delete", nil];
    [deleteConfirm show];
    [deleteConfirm setTag:0];
    [deleteConfirm release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 0) {
        if (buttonIndex == 0) {
            return;
        } else {
            if (appDelegate.isRiverView) {
                [self deleteFolder];
            } else {
                [self deleteSite];
            }
        }
    }
}

- (void)deleteSite {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/delete_feed", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[[appDelegate activeFeed] objectForKey:@"id"] forKey:@"feed_id"];
    [request addPostValue:[appDelegate extractFolderName:appDelegate.activeFolder] forKey:@"in_folder"];
    [request setFailedBlock:^(void) {
        [self informError:[request error]];
    }];
    [request setCompletionBlock:^(void) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
    [request setTimeOutSeconds:30];
    [request setTag:[[[appDelegate activeFeed] objectForKey:@"id"] intValue]];
    [request startAsynchronous];
}

- (void)deleteFolder {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Deleting...";
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/delete_folder", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[appDelegate extractFolderName:appDelegate.activeFolder] 
                   forKey:@"folder_to_delete"];
    [request addPostValue:[appDelegate extractFolderName:[appDelegate extractParentFolderName:appDelegate.activeFolder]] 
                   forKey:@"in_folder"];
    [request setFailedBlock:^(void) {
        [self informError:[request error]];
    }];
    [request setCompletionBlock:^(void) {
        [appDelegate reloadFeedsView:YES];
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
        [MBProgressHUD hideHUDForView:self.view animated:YES];
    }];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

- (void)openMoveView {
    [appDelegate showMoveSite];
}

#pragma mark -
#pragma mark PullToRefresh

// called when the user pulls-to-refresh
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view {    
    if (appDelegate.isRiverView) {
        [pull finishedLoading];
        return;
    }
    
    NSString *urlString = [NSString 
                           stringWithFormat:@"http://%@/reader/refresh_feed/%@", 
                           NEWSBLUR_URL,
                           [appDelegate.activeFeed objectForKey:@"id"]];
    [self cancelRequests];
    __block ASIHTTPRequest *request = [self requestWithURL:urlString];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setDidFinishSelector:@selector(finishedRefreshingFeed:)];
    [request setDidFailSelector:@selector(failRefreshingFeed:)];
    [request setTimeOutSeconds:60];
    [request startAsynchronous];
    
    [appDelegate setStories:nil];
    self.feedPage = 1;
    self.pageFetching = YES;
    self.pageRefreshing = YES;
//    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)finishedRefreshingFeed:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    [pull finishedLoading];
    self.pageRefreshing = NO;
    [self renderStories:[results objectForKey:@"stories"]];
    [self.storyTitlesTable reloadData];
    [results release];
}

- (void)failRefreshingFeed:(ASIHTTPRequest *)request {
    NSLog(@"Fail: %@", request);
    self.pageRefreshing = NO;
    [self informError:[request error]];
    [pull finishedLoading];
    [self fetchFeedDetail:1 withCallback:nil];
}

// called when the date shown needs to be updated, optional
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view {
//    NSLog(@"Updated; %@", [appDelegate.activeFeed objectForKey:@"updated_seconds_ago"]);
    int seconds = -1 * [[appDelegate.activeFeed objectForKey:@"updated_seconds_ago"] intValue];
    return [[[NSDate alloc] initWithTimeIntervalSinceNow:seconds] autorelease];
}


@end
