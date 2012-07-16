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
#import "ASIFormDataRequest.h"
#import "UserProfileViewController.h"
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

@synthesize popoverController;
@synthesize storyTitlesTable, feedViewToolbar, feedScoreSlider, feedMarkReadButton;
@synthesize settingsButton;
@synthesize stories;
@synthesize appDelegate;
@synthesize feedPage;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize intelligenceControl;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                         duration:(NSTimeInterval)duration {
    /* When MGSplitViewController rotates, it causes a 
     resize of our view; we need to resize our UIBarButtonControls or they will be 0-width */    
    [self.navigationItem.titleView sizeToFit];
}

- (void)viewWillAppear:(BOOL)animated {
    self.pageFinished = NO;
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    if (appDelegate.isRiverView || appDelegate.isSocialView) {
        self.storyTitlesTable.separatorStyle = UITableViewCellSeparatorStyleNone;
        //self.storyTitlesTable.separatorColor = [UIColor clearColor];
    } else {
        self.storyTitlesTable.separatorStyle = UITableViewCellSeparatorStyleSingleLine;
        self.storyTitlesTable.separatorColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:1.0];
    }
    
    
    // set center title
    UIView *titleLabel = [appDelegate makeFeedTitle:appDelegate.activeFeed];
    self.navigationItem.titleView = titleLabel;
    
    // set right avatar title image
    if (appDelegate.isSocialView) {
        UIButton *titleImageButton = [appDelegate makeRightFeedTitle:appDelegate.activeFeed];
        [titleImageButton addTarget:self action:@selector(showUserProfilePopover) forControlEvents:UIControlEventTouchUpInside];
        UIBarButtonItem *titleImageBarButton = [[UIBarButtonItem alloc] 
                                                 initWithCustomView:titleImageButton];
        self.navigationItem.rightBarButtonItem = titleImageBarButton;
    } else {
        self.navigationItem.rightBarButtonItem = nil;
    }

    
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
        //[self.storyTitlesTable reloadData];
    }
    [appDelegate setRecentlyReadStories:[NSMutableArray array]];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullets_all.png"] forSegmentAtIndex:0];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullets_yellow_green.png"] forSegmentAtIndex:1];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"bullet_green.png"] forSegmentAtIndex:2];
    [self.intelligenceControl addTarget:self
                         action:@selector(selectIntelligence)
               forControlEvents:UIControlEventValueChanged];
    [self.intelligenceControl setSelectedSegmentIndex:[appDelegate selectedIntelligence] + 1];
    
	[super viewWillAppear:animated];
        
    if ((appDelegate.isRiverView || appDelegate.isSocialView) || 
        [appDelegate.activeFolder isEqualToString:@"Everything"]) {
        settingsButton.enabled = NO;
    } else {
        settingsButton.enabled = YES;
    }    
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.popoverController dismissPopoverAnimated:YES];
}

- (void)viewDidAppear:(BOOL)animated { 
	[super viewDidAppear:animated];
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        // have the selected cell deselect
        [self.storyTitlesTable deselectRowAtIndexPath:[self.storyTitlesTable indexPathForSelectedRow]
                                             animated:YES];
    }
}


#pragma mark -
#pragma mark Initialization

- (void)resetFeedDetail {
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.feedPage = 1;
}

#pragma mark -
#pragma mark Regular and Social Feeds

- (void)fetchNextPage:(void(^)())callback {
    [self fetchFeedDetail:self.feedPage+1 withCallback:callback];
}

- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback {      
    NSString *theFeedDetailURL;
    
    if ([appDelegate.activeFeed objectForKey:@"id"] != nil && !self.pageFetching && !self.pageFinished) {
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        if (appDelegate.isSocialView) {
            theFeedDetailURL = [NSString stringWithFormat:@"http://%@/social/stories/%@/?page=%d", 
                                NEWSBLUR_URL,
                                [appDelegate.activeFeed objectForKey:@"user_id"],
                                self.feedPage];
        } else {
            theFeedDetailURL = [NSString stringWithFormat:@"http://%@/reader/feed/%@/?page=%d", 
                                NEWSBLUR_URL,
                                [appDelegate.activeFeed objectForKey:@"id"],
                                self.feedPage];
        }
        
        [self cancelRequests];
        __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            NSLog(@"in failed block %@", request);
            [self informError:[request error]];
        }];
        [request setCompletionBlock:^(void) {
            [self finishedLoadingFeed:request];
            if (callback) {
                callback();
            }
        }];
        [request setTimeOutSeconds:10];
        [request setTag:[[[appDelegate activeFeed] objectForKey:@"id"] intValue]];
        [request startAsynchronous];
    }
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
        
        NSString *theFeedDetailURL = [NSString stringWithFormat:
                                      @"http://%@/reader/river_stories/?feeds=%@&page=%d&read_stories_count=%d", 
                                      NEWSBLUR_URL,
                                      [appDelegate.activeFolderFeeds componentsJoinedByString:@"&feeds="],
                                      self.feedPage,
                                      readStoriesCount];
        
        [self cancelRequests];
        __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
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
#pragma mark Processing Stories

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
    
    if (!(appDelegate.isRiverView || appDelegate.isSocialView) && request.tag != [[results objectForKey:@"feed_id"] intValue]) {
        return;
    }
    
    if ([appDelegate isSocialView]) {
        NSArray *newFeeds = [results objectForKey:@"feeds"];
        for (int i = 0; i < newFeeds.count; i++){
            NSString *feedKey = [NSString stringWithFormat:@"%@", [[newFeeds objectAtIndex:i] objectForKey:@"id"]];
            [appDelegate.dictActiveFeeds setObject:[newFeeds objectAtIndex:i] 
                      forKey:feedKey];
        }
        [self loadFaviconsFromActiveFeed];
    }
    
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
        confirmedNewStories = [newStories copy];
    }
    
    // Adding new user profiles to appDelegate.activeFeedUserProfiles
    NSArray *newUserProfiles = [results objectForKey:@"user_profiles"];
    if ([newUserProfiles count]){
        NSMutableArray *confirmedNewUserProfiles = [NSMutableArray array];
        if ([appDelegate.activeFeedUserProfiles count]) {
            NSMutableSet *userProfileIds = [NSMutableSet set];
            for (id userProfile in appDelegate.activeFeedUserProfiles) {
                [userProfileIds addObject:[userProfile objectForKey:@"id"]];
            }
            for (id userProfile in newUserProfiles) {
                if (![userProfileIds containsObject:[userProfile objectForKey:@"id"]]) {
                    [confirmedNewUserProfiles addObject:userProfile];
                }
            }
        } else {
            confirmedNewUserProfiles = [newUserProfiles copy];
        }
        
        
        if (self.feedPage == 1) {
            [appDelegate setFeedUserProfiles:confirmedNewUserProfiles];
        } else if (newUserProfiles.count > 0) {        
            [appDelegate addFeedUserProfiles:confirmedNewUserProfiles];
        }
        
//        NSLog(@"activeFeedUserProfiles is %@", appDelegate.activeFeedUserProfiles);
//        NSLog(@"# of user profiles added: %i", appDelegate.activeFeedUserProfiles.count);
//        NSLog(@"user profiles added: %@", appDelegate.activeFeedUserProfiles);
    }
    
    [self renderStories:confirmedNewStories];
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
    
    if (existingStoriesCount > 0 && newVisibleStoriesCount > 0) {
        NSMutableArray *indexPaths = [[NSMutableArray alloc] init];
        for (int i=0; i < newVisibleStoriesCount; i++) {
            [indexPaths addObject:[NSIndexPath indexPathForRow:(existingStoriesCount+i) 
                                                     inSection:0]];
        }
        
        [self.storyTitlesTable reloadData];

    } else if (newVisibleStoriesCount > 0) {
        [self.storyTitlesTable reloadData];
        
    } else if (newStoriesCount == 0 || 
               (self.feedPage > 15 && 
                existingStoriesCount >= [appDelegate unreadCount])) {
        self.pageFinished = YES;
        [self.storyTitlesTable reloadData];
    }
        
    self.pageFetching = NO;
    
    [self performSelector:@selector(checkScroll)
               withObject:nil
               afterDelay:0.2];
}

- (void)connection:(NSURLConnection *)connection didFailWithError:(NSError *)error {
    
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
    UITableViewCell *cell = [[UITableViewCell alloc] 
                              initWithStyle:UITableViewCellStyleSubtitle 
                              reuseIdentifier:@"NoReuse"];
    
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        int height = 0;
        
        if (appDelegate.isRiverView || appDelegate.isSocialView) {
            height = kTableViewRiverRowHeight;
        } else {
            height = kTableViewRowHeight;
        }
        
        fleuron.frame = CGRectMake(0, 0, self.view.frame.size.width, height);
        fleuron.contentMode = UIViewContentModeCenter;
        [cell.contentView addSubview:fleuron];
        fleuron.backgroundColor = [UIColor whiteColor];
    } else {
        cell.textLabel.text = @"Loading...";
        
        UIActivityIndicatorView *spinner = [[UIActivityIndicatorView alloc] 
                                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
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

    // The +1 is for the finished/loading bar.
    return storyCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    static NSString *cellIdentifier;
    NSDictionary *feed ;
    
    if (appDelegate.isRiverView || appDelegate.isSocialView) {
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
                if (([(FeedDetailTableCell *)oneObject tag] == 0 && !(appDelegate.isRiverView || appDelegate.isSocialView)) ||
                    ([(FeedDetailTableCell *)oneObject tag] == 1 && (appDelegate.isRiverView || appDelegate.isSocialView))) {
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
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    
    if ([appDelegate isSocialView]) {
        feed = [appDelegate.dictActiveFeeds objectForKey:feedIdStr];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
    
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
    
    // River view gradient
    if ((appDelegate.isRiverView || appDelegate.isSocialView) && cell) {
        UIView *feedTitleBar = [self makeFeedTitleBar:feed cell:cell makeRect:CGRectMake(0, 1, 12, cell.frame.size.height)];
        cell.feedGradient = feedTitleBar;
        [cell addSubview:cell.feedGradient];
        
        // top border
        UIView *topBorder = [[UIView alloc] init];
        topBorder.frame = CGRectMake(12, 0, self.view.frame.size.width, 1);
        topBorder.backgroundColor = [UIColor colorWithRed:.9 green:.9 blue:.9 alpha:1.0];
        [cell addSubview:topBorder]; 
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
        [self changeRowStyleToRead:cell];
    }

    int rowIndex = [appDelegate locationOfActiveStory];
    if (rowIndex == indexPath.row) {
        [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
    }

	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < [appDelegate.activeFeedStoryLocations count]) {
        
        FeedDetailTableCell *cell = (FeedDetailTableCell*) [tableView cellForRowAtIndexPath:indexPath];
        [self changeRowStyleToRead:cell];
       
        int location = [[[appDelegate activeFeedStoryLocations] objectAtIndex:indexPath.row] intValue];
        [appDelegate setActiveStory:[[appDelegate activeFeedStories] objectAtIndex:location]];
        [appDelegate setOriginalStoryCount:[appDelegate unreadCount]];
        [appDelegate loadStoryDetailView];

    }
}

- (void)changeRowStyleToRead:(FeedDetailTableCell *)cell {
    cell.storyAuthor.textColor = UIColorFromRGB(0xcccccc);
    cell.storyAuthor.font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    cell.storyDate.textColor = [UIColor colorWithRed:0.14f green:0.18f blue:0.42f alpha:0.5];
    cell.storyDate.font = [UIFont fontWithName:@"Helvetica" size:10];
    cell.storyUnreadIndicator.alpha = 0.15f;
    cell.feedGradient.alpha = 0.25f;
    cell.storyTitle.font = [UIFont fontWithName:@"Helvetica" size:12];
    if ((appDelegate.isRiverView || appDelegate.isSocialView) && cell) {
        cell.storyTitle.textColor = UIColorFromRGB(0xcccccc);
    } else {
        cell.storyTitle.textColor = [UIColor colorWithRed:0.15f green:0.25f blue:0.25f alpha:0.9];
    }
    
//    for (CALayer *layer in [cell.feedGradient.layer sublayers]) {
//        if ([[layer name] isEqualToString:@"feedColorBarBorder"]) {
////            layer.backgroundColor = UIColorFromRGB(0xcccccc).CGColor;
//        }
//    }

}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    if (appDelegate.isRiverView || appDelegate.isSocialView) {
        return kTableViewRiverRowHeight;
    } else {
        return kTableViewRowHeight;
    }
}

- (UIView *)makeFeedTitleBar:(NSDictionary *)feed cell:(UITableViewCell *)cell makeRect:(CGRect)rect {
    UIView *gradientView = [[UIView alloc] init];
    gradientView.opaque = YES;
    
    UILabel *titleLabel = [[UILabel alloc] init];
    titleLabel.text = [feed objectForKey:@"feed_title"];
    titleLabel.backgroundColor = [UIColor whiteColor];
    titleLabel.textAlignment = UITextAlignmentLeft;
    titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
    titleLabel.numberOfLines = 1;
    titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:11.0];
    titleLabel.shadowOffset = CGSizeMake(0, 1);
    titleLabel.textColor = UIColorFromRGB(0x606060);
    titleLabel.frame = CGRectMake(40, 3, self.view.frame.size.width - 60, 20);
    titleLabel.highlightedTextColor = UIColorFromRGB(0xE0E0E0);
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    UIImage *titleImage = [Utilities getImage:feedIdStr];
    UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
    titleImageView.alpha = 0.6;
    titleImageView.frame = CGRectMake(18, 5, 16.0, 16.0);
    [titleLabel addSubview:titleImageView];
    
    [gradientView addSubview:titleLabel];
    [gradientView addSubview:titleImageView];
    
    // top color border
    unsigned int colorBorder = 0;
    NSString *faviconFade = [feed valueForKey:@"favicon_fade"];
    if ([faviconFade class] == [NSNull class]) {
        faviconFade = @"505050";
    }    
    NSScanner *scannerBorder = [NSScanner scannerWithString:faviconFade];
    [scannerBorder scanHexInt:&colorBorder];
    CALayer  *feedColorBarBorder = [CALayer layer];
    feedColorBarBorder.frame = CGRectMake(0, 0, 12, 1);
    feedColorBarBorder.backgroundColor = UIColorFromRGB(colorBorder).CGColor;
    feedColorBarBorder.opacity = 1;
    [gradientView.layer addSublayer:feedColorBarBorder];
    
    // favicon color bar
    unsigned int color = 0;
    NSString *faviconColor = [feed valueForKey:@"favicon_color"];
    if ([faviconColor class] == [NSNull class]) {
        faviconColor = @"505050";
    }
    NSScanner *scanner = [NSScanner scannerWithString:faviconColor];
    [scanner scanHexInt:&color];
    CALayer *feedColorBar = [CALayer layer];
    feedColorBar.frame = rect;
    feedColorBar.backgroundColor = UIColorFromRGB(color).CGColor;
    feedColorBar.opacity = 1;
    feedColorBar.name = @"feedColorBarBorder";
    [gradientView.layer addSublayer:feedColorBar]; 

    return gradientView;
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
        } else if (buttonIndex == 2) {
            [self instafetchFeed];
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
        
        NSString *fetchText = @"Insta-fetch stories";
        [options addButtonWithTitle:fetchText];

    }
    
    options.cancelButtonIndex = [options addButtonWithTitle:@"Cancel"];
    options.tag = kSettingsActionSheet;
    [options showInView:self.view];
}

- (void)confirmDeleteSite {
    UIAlertView *deleteConfirm = [[UIAlertView alloc] 
                                  initWithTitle:@"Positive?" 
                                  message:nil 
                                  delegate:self 
                                  cancelButtonTitle:@"Cancel" 
                                  otherButtonTitles:@"Delete", 
                                  nil];
    [deleteConfirm show];
    [deleteConfirm setTag:0];
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
    
    __weak ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
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
    
    __weak ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
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

- (void)showUserProfilePopover {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"user_id"]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (popoverController == nil) {
            popoverController = [[UIPopoverController alloc]
                                 initWithContentViewController:appDelegate.userProfileViewController];
            
            popoverController.delegate = self;
        } else {
            if (popoverController.isPopoverVisible) {
                [popoverController dismissPopoverAnimated:YES];
                return;
            }
            [popoverController setContentViewController:appDelegate.userProfileViewController];
        }
        
        [popoverController setPopoverContentSize:CGSizeMake(320, 416)];
        [popoverController presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem 
                                  permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                  animated:YES];  
    } else {
        [appDelegate showUserProfileModal];
    }
}

- (void)changeActiveFeedDetailRow {
    int rowIndex = [appDelegate locationOfActiveStory];
                    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    NSIndexPath *offsetIndexPath = [NSIndexPath indexPathForRow:rowIndex - 1 inSection:0];

    [storyTitlesTable selectRowAtIndexPath:indexPath 
                                  animated:YES 
                            scrollPosition:UITableViewScrollPositionNone];
    
    FeedDetailTableCell *cell = (FeedDetailTableCell *) [storyTitlesTable cellForRowAtIndexPath:indexPath];
    // check to see if the cell is completely visible
    CGRect cellRect = [storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    cellRect = [storyTitlesTable convertRect:cellRect toView:storyTitlesTable.superview];
    
    BOOL completelyVisible = CGRectContainsRect(storyTitlesTable.frame, cellRect);
    
    [self changeRowStyleToRead:cell];
    if (!completelyVisible) {
        [storyTitlesTable scrollToRowAtIndexPath:offsetIndexPath 
                                atScrollPosition:UITableViewScrollPositionTop 
                                        animated:YES];
    }
}


#pragma mark -
#pragma mark instafetchFeed

// called when the user taps refresh button

- (void)instafetchFeed {
    NSLog(@"Instafetch");
    
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
    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)finishedRefreshingFeed:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];

    [self renderStories:[results objectForKey:@"stories"]];    
}

- (void)failRefreshingFeed:(ASIHTTPRequest *)request {
    NSLog(@"Fail: %@", request);
    [self informError:[request error]];
    [self fetchFeedDetail:1 withCallback:nil];
}

#pragma mark -
#pragma mark loadSocial Feeds

- (void)loadFaviconsFromActiveFeed {
    NSArray * keys = [appDelegate.dictActiveFeeds allKeys];
    NSString *feedIdsQuery = [NSString stringWithFormat:@"?feed_ids=%@", 
                               [[keys valueForKey:@"description"] componentsJoinedByString:@"&feed_ids="]];        
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/favicons%@",
                           NEWSBLUR_URL,
                           feedIdsQuery];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest  *request = [ASIHTTPRequest  requestWithURL:url];

    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request {

    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSDictionary *feed = [appDelegate.dictActiveFeeds objectForKey:feed_id];
            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
            [appDelegate.dictActiveFeeds setValue:feed forKey:feed_id];
            
            NSString *favicon = [feed objectForKey:@"favicon"];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [Utilities saveImage:faviconImage feedId:feed_id];
            }
        }
        [Utilities saveimagesToDisk];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.storyTitlesTable reloadData];
        });
    });
    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

@end
