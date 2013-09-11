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
#import "NBContainerViewController.h"
#import "FeedDetailTableCell.h"
#import "ASIFormDataRequest.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "NSString+HTML.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "JSON.h"
#import "StringHelper.h"
#import "Utilities.h"
#import "UIBarButtonItem+WEPopover.h"
#import "WEPopoverController.h"
#import "UIBarButtonItem+Image.h"
#import "TransparentToolbar.h"
#import "FeedDetailMenuViewController.h"
#import "NBNotifier.h"
#import "NBLoadingCell.h"
#import "FMDatabase.h"

#define kTableViewRowHeight 61;
#define kTableViewRiverRowHeight 81;
#define kTableViewShortRowDifference 15;
#define kMarkReadActionSheet 1;
#define kSettingsActionSheet 2;

@interface FeedDetailViewController ()

@property (nonatomic) UIActionSheet* actionSheet_;  // add this line

@end

@implementation FeedDetailViewController

@synthesize popoverController;
@synthesize storyTitlesTable, feedMarkReadButton;
@synthesize settingsBarButton;
@synthesize separatorBarButton;
@synthesize titleImageBarButton;
@synthesize spacerBarButton, spacer2BarButton, spacer3BarButton;
@synthesize rightToolbar;
@synthesize appDelegate;
@synthesize feedPage;
@synthesize pageFetching;
@synthesize pageFinished;
@synthesize actionSheet_;
@synthesize finishedAnimatingIn;
@synthesize notifier;
@synthesize isOffline;
@synthesize isShowingOffline;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
    }
    return self;
}
 
- (void)viewDidLoad {
    [super viewDidLoad];
    
    popoverClass = [WEPopoverController class];
    self.storyTitlesTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.storyTitlesTable.separatorColor = UIColorFromRGB(0xE9E8E4);
    
    rightToolbar = [[TransparentToolbar alloc]
                    initWithFrame:CGRectMake(0, 0, 76, 44)];
    
    spacerBarButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacerBarButton.width = -12;
    spacer2BarButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacer2BarButton.width = -10;
    spacer3BarButton = [[UIBarButtonItem alloc]
                       initWithBarButtonSystemItem:UIBarButtonSystemItemFixedSpace target:nil action:nil];
    spacer3BarButton.width = -10;
    
    UIImage *separatorImage = [UIImage imageNamed:@"bar-separator.png"];
    separatorBarButton = [UIBarButtonItem barItemWithImage:separatorImage target:nil action:nil];
    [separatorBarButton setEnabled:NO];
    
    UIImage *settingsImage = [UIImage imageNamed:@"nav_icn_settings.png"];
    settingsBarButton = [UIBarButtonItem barItemWithImage:settingsImage target:self action:@selector(doOpenSettingsActionSheet:)];
    
    UIImage *markreadImage = [UIImage imageNamed:@"markread.png"];
    feedMarkReadButton = [UIBarButtonItem barItemWithImage:markreadImage target:self action:@selector(doOpenMarkReadActionSheet:)];

    titleImageBarButton = [UIBarButtonItem alloc];

    self.notifier = [[NBNotifier alloc] initWithTitle:@"Fetching stories..." inView:self.view];
    [self.view addSubview:self.notifier];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    return YES;
}


- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation 
                                         duration:(NSTimeInterval)duration {
    [self setUserAvatarLayout:toInterfaceOrientation];
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self checkScroll];
    [appDelegate.storyPageControl refreshPages];
}

- (void)viewWillAppear:(BOOL)animated {
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self setUserAvatarLayout:orientation];
    self.finishedAnimatingIn = NO;
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    
    // set center title
    UILabel *titleLabel = (UILabel *)[appDelegate makeFeedTitle:appDelegate.activeFeed];
    self.navigationItem.titleView = titleLabel;
    
    // set right avatar title image
    if (appDelegate.isSocialView) {
        UIButton *titleImageButton = [appDelegate makeRightFeedTitle:appDelegate.activeFeed];
        [titleImageButton addTarget:self action:@selector(showUserProfile) forControlEvents:UIControlEventTouchUpInside];
        titleImageBarButton.customView = titleImageButton;
        [rightToolbar setItems: [NSArray arrayWithObjects:
                                 spacerBarButton,
                                 feedMarkReadButton,
                                 spacer2BarButton,
                                 separatorBarButton,
                                 spacer3BarButton,
                                 titleImageBarButton, nil]];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:rightToolbar];
        titleImageBarButton.enabled = YES;
    } else {
        [rightToolbar setItems: [NSArray arrayWithObjects:
                                 spacerBarButton,
                                 feedMarkReadButton,
                                 spacer2BarButton,
                                 separatorBarButton,
                                 spacer3BarButton,
                                 settingsBarButton, nil]];
        self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithCustomView:rightToolbar];
    }
    
    NSMutableArray *indexPaths = [NSMutableArray array];
    NSLog(@"appDelegate.recentlyReadStoryLocations: %d - %@", self.isOffline, appDelegate.recentlyReadStoryLocations);
    for (id i in appDelegate.recentlyReadStoryLocations) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:[i intValue]
                                                    inSection:0];
//        NSLog(@"Read story: %d", [i intValue]);
        if (![indexPaths containsObject:indexPath]) {
            [indexPaths addObject:indexPath];
        }
    }
    if ([indexPaths count] > 0 && [self.storyTitlesTable numberOfRowsInSection:0]) {
        [self.storyTitlesTable beginUpdates];
        [self.storyTitlesTable reloadRowsAtIndexPaths:indexPaths withRowAnimation:UITableViewRowAnimationNone];
        [self.storyTitlesTable endUpdates];
        //[self.storyTitlesTable reloadData];
    }
    
    appDelegate.recentlyReadStoryLocations = [NSMutableArray array];
    appDelegate.originalStoryCount = [appDelegate unreadCount];
    
	[super viewWillAppear:animated];
        
    if ((appDelegate.isSocialRiverView ||
         appDelegate.isSocialView ||
         [appDelegate.activeFolder isEqualToString:@"saved_stories"])) {
        settingsBarButton.enabled = NO;
    } else {
        settingsBarButton.enabled = YES;
    }
    
    if (appDelegate.isSocialRiverView || 
        [appDelegate.activeFolder isEqualToString:@"saved_stories"]) {
        feedMarkReadButton.enabled = NO;
    } else {
        feedMarkReadButton.enabled = YES;
    }
        
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        [self.storyTitlesTable reloadData];
        int location = appDelegate.locationOfActiveStory;
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:location inSection:0];
        if (indexPath && location >= 0) {
            [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionMiddle];
        }
        [self performSelector:@selector(fadeSelectedCell) withObject:self afterDelay:0.4];
    }
    
    [self.notifier setNeedsLayout];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (appDelegate.inStoryDetail && UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        appDelegate.inStoryDetail = NO;
        [appDelegate.storyPageControl resetPages];
        [self checkScroll];
    }
    
    self.finishedAnimatingIn = YES;
    [self testForTryFeed];
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
}

- (void)viewDidDisappear:(BOOL)animated {
    
}

- (void)fadeSelectedCell {
    // have the selected cell deselect
    int location = appDelegate.locationOfActiveStory;
    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:location inSection:0];
    if (indexPath) {
        [self.storyTitlesTable deselectRowAtIndexPath:indexPath animated:YES];
        
    }           

}

- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone && appDelegate.isSocialView) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            UIButton *avatar = (UIButton *)titleImageBarButton.customView;
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(32, 32);
            avatar.frame = buttonFrame;
        } else {
            UIButton *avatar = (UIButton *)titleImageBarButton.customView;
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(28, 28);
            avatar.frame = buttonFrame;
        }
    }
}


#pragma mark -
#pragma mark Initialization

- (void)resetFeedDetail {
    appDelegate.hasLoadedFeedDetail = NO;
    self.pageFetching = NO;
    self.pageFinished = NO;
    self.isOffline = NO;
    self.isShowingOffline = NO;
    self.feedPage = 1;
    appDelegate.activeStory = nil;
    [appDelegate.storyPageControl resetPages];
    appDelegate.recentlyReadStories = [NSMutableDictionary dictionary];
    appDelegate.recentlyReadStoryLocations = [NSMutableArray array];
    [self.notifier hideIn:0];
    [self cancelRequests];
    [self beginOfflineTimer];
}

- (void)reloadPage {
    [self resetFeedDetail];

    [appDelegate setStories:nil];
    appDelegate.storyCount = 0;
    appDelegate.activeClassifiers = [NSMutableDictionary dictionary];
    appDelegate.activePopularAuthors = [NSArray array];
    appDelegate.activePopularTags = [NSArray array];
        
    if (appDelegate.isRiverView) {
        [self fetchRiverPage:1 withCallback:nil];
    } else {
        [self fetchFeedDetail:1 withCallback:nil];
    }

    [self.storyTitlesTable reloadData];
    [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
}

- (void)beginOfflineTimer {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
        if (!appDelegate.storyLocationsCount && self.feedPage == 1) {
            self.isShowingOffline = YES;
            self.isOffline = YES;
            [self showLoadingNotifier];
            [self loadOfflineStories];
        }
    });
}

#pragma mark -
#pragma mark Regular and Social Feeds

- (void)fetchNextPage:(void(^)())callback {
    if (appDelegate.isRiverView) {
        [self fetchRiverPage:self.feedPage+1 withCallback:callback];
    } else {
        [self fetchFeedDetail:self.feedPage+1 withCallback:callback];
    }
}

- (void)fetchFeedDetail:(int)page withCallback:(void(^)())callback {
    NSString *theFeedDetailURL;
    
    if (!appDelegate.activeFeed) return;
    
    if (callback || (!self.pageFetching && !self.pageFinished)) {
    
        self.feedPage = page;
        self.pageFetching = YES;
        int storyCount = appDelegate.storyCount;
        if (storyCount == 0) {
            [self.storyTitlesTable reloadData];
            [storyTitlesTable scrollRectToVisible:CGRectMake(0, 0, 1, 1) animated:YES];
        }
        if (self.feedPage == 1) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                     (unsigned long)NULL), ^(void) {
                [appDelegate.database inDatabase:^(FMDatabase *db) {
                    [appDelegate prepareActiveCachedImages:db];
                }];
            });
        }
        
        if (self.isOffline) {
            [self loadOfflineStories];
            if (!self.isShowingOffline) {
                [self showOfflineNotifier];
            }
            return;
        }
        
        if (appDelegate.isSocialView) {
            theFeedDetailURL = [NSString stringWithFormat:@"%@/social/stories/%@/?page=%d",
                                NEWSBLUR_URL,
                                [appDelegate.activeFeed objectForKey:@"user_id"],
                                self.feedPage];
        } else {
            theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/feed/%@/?page=%d",
                                NEWSBLUR_URL,
                                [appDelegate.activeFeed objectForKey:@"id"],
                                self.feedPage];
        }
        
        theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                            theFeedDetailURL,
                            [appDelegate activeOrder]];
        theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                            theFeedDetailURL,
                            [appDelegate activeReadFilter]];
        
        [self cancelRequests];
        __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            NSLog(@"in failed block %@", request);
            if (request.isCancelled) {
                NSLog(@"Cancelled");
                return;
            } else if (self.feedPage == 1) {
                self.isOffline = YES;
                [self loadOfflineStories];
                [self showOfflineNotifier];
            } else {
                [self informError:[request error]];
                self.pageFinished = YES;
            }
            [self.storyTitlesTable reloadData];
        }];
        [request setCompletionBlock:^(void) {
            if (!appDelegate.activeFeed) return;
            [self finishedLoadingFeed:request];
            if (callback) {
                callback();
            }
        }];
        [request setTimeOutSeconds:30];
        [request setTag:[[[appDelegate activeFeed] objectForKey:@"id"] intValue]];
        [request startAsynchronous];
        [requests addObject:request];
    }
}

- (void)loadOfflineStories {
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
    [appDelegate.database inDatabase:^(FMDatabase *db) {
        NSArray *feedIds;
        int limit = 12;
        int offset = (self.feedPage - 1) * limit;
        
        if (appDelegate.isRiverView) {
            feedIds = appDelegate.activeFolderFeeds;
        } else if (appDelegate.activeFeed) {
            feedIds = @[[appDelegate.activeFeed objectForKey:@"id"]];
        } else {
            return;
        }
        
        NSString *orderSql;
        if ([appDelegate.activeOrder isEqualToString:@"oldest"]) {
            orderSql = @"ASC";
        } else {
            orderSql = @"DESC";
        }
        NSString *readFilterSql;
        if ([appDelegate.activeReadFilter isEqualToString:@"unread"]) {
            readFilterSql = @"INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash";
        } else {
            readFilterSql = @"";
        }
        NSString *sql = [NSString stringWithFormat:@"SELECT * FROM stories s %@ WHERE s.story_feed_id IN (%@) ORDER BY s.story_timestamp %@ LIMIT %d OFFSET %d",
                         readFilterSql,
                         [feedIds componentsJoinedByString:@","],
                         orderSql,
                         limit, offset];
        FMResultSet *cursor = [db executeQuery:sql];
        NSMutableArray *offlineStories = [NSMutableArray array];
        
        while ([cursor next]) {
            NSDictionary *story = [cursor resultDictionary];
            [offlineStories addObject:[NSJSONSerialization
                                       JSONObjectWithData:[[story objectForKey:@"story_json"]
                                                           dataUsingEncoding:NSUTF8StringEncoding]
                                       options:nil error:nil]];
        }
        
        if ([appDelegate.activeReadFilter isEqualToString:@"all"]) {
            NSString *unreadHashSql = [NSString stringWithFormat:@"SELECT s.story_hash FROM stories s INNER JOIN unread_hashes uh ON s.story_hash = uh.story_hash WHERE s.story_feed_id IN (%@)",
                             [feedIds componentsJoinedByString:@","]];
            FMResultSet *unreadHashCursor = [db executeQuery:unreadHashSql];
            NSMutableDictionary *unreadStoryHashes;
            if (self.feedPage == 1) {
                unreadStoryHashes = [NSMutableDictionary dictionary];
            } else {
                unreadStoryHashes = appDelegate.unreadStoryHashes;
            }
            while ([unreadHashCursor next]) {
                [unreadStoryHashes setObject:[NSNumber numberWithBool:YES] forKey:[unreadHashCursor objectForColumnName:@"story_hash"]];
            }
            appDelegate.unreadStoryHashes = unreadStoryHashes;
        }
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            if (!self.isOffline) {
                NSLog(@"Online before offline rendered. Tossing offline stories.");
                return;
            }
            if (![offlineStories count]) {
                self.pageFinished = YES;
                [self.storyTitlesTable reloadData];
            } else {
                [self renderStories:offlineStories];
            }
            if (!self.isShowingOffline) {
                [self showOfflineNotifier];
            }
        });
    }];
    });
}

- (void)showOfflineNotifier {
//    [self.notifier hide];
    self.notifier.style = NBOfflineStyle;
    self.notifier.title = @"Offline";
    [self.notifier show];
}

- (void)showLoadingNotifier {
    [self.notifier hide];
    self.notifier.style = NBLoadingStyle;
    self.notifier.title = @"Fetching recent stories...";
    [self.notifier show];
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
//            [self.notifier initWithTitle:@"Loading more..." inView:self.view];

        }
        
        if (self.feedPage == 1) {
            dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                                     (unsigned long)NULL), ^(void) {
                [appDelegate.database inDatabase:^(FMDatabase *db) {
                    [appDelegate prepareActiveCachedImages:db];
                }];
            });
        }
        
        if (self.isOffline) {
            [self loadOfflineStories];
            return;
        }
        
        NSString *theFeedDetailURL;
        
        if (appDelegate.isSocialRiverView) {
            if ([appDelegate.activeFolder isEqualToString:@"river_global"]) {
                theFeedDetailURL = [NSString stringWithFormat:
                                    @"%@/social/river_stories/?global_feed=true&page=%d",
                                    NEWSBLUR_URL,
                                    self.feedPage];
                
            } else {
                theFeedDetailURL = [NSString stringWithFormat:
                                    @"%@/social/river_stories/?page=%d", 
                                    NEWSBLUR_URL,
                                    self.feedPage];
            }
        } else if ([appDelegate.activeFolder isEqual:@"saved_stories"]) {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"%@/reader/starred_stories/?page=%d",
                                NEWSBLUR_URL,
                                self.feedPage];
        } else {
            theFeedDetailURL = [NSString stringWithFormat:
                                @"%@/reader/river_stories/?f=%@&page=%d", 
                                NEWSBLUR_URL,
                                [appDelegate.activeFolderFeeds componentsJoinedByString:@"&f="],
                                self.feedPage];
        }
        
        
        theFeedDetailURL = [NSString stringWithFormat:@"%@&order=%@",
                            theFeedDetailURL,
                            [appDelegate activeOrder]];
        theFeedDetailURL = [NSString stringWithFormat:@"%@&read_filter=%@",
                            theFeedDetailURL,
                            [appDelegate activeReadFilter]];

        [self cancelRequests];
        __weak ASIHTTPRequest *request = [self requestWithURL:theFeedDetailURL];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            if (request.isCancelled) {
                NSLog(@"Cancelled");
                return;
            } else if (self.feedPage == 1) {
                self.isOffline = YES;
                self.isShowingOffline = NO;
                [self loadOfflineStories];
                [self showOfflineNotifier];
            } else {
                [self informError:[request error]];
                self.pageFinished = YES;
                [self.storyTitlesTable reloadData];
            }
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
    if (request.isCancelled) {
        NSLog(@"Cancelled");
        return;
    } else if ([request responseStatusCode] >= 500) {
        if (self.feedPage == 1) {
            self.isOffline = YES;
            self.isShowingOffline = NO;
            [self loadOfflineStories];
            [self showOfflineNotifier];
        }
        if ([request responseStatusCode] == 503) {
            [self informError:@"In maintenance mode"];
            self.pageFinished = YES;
        } else {
            [self informError:@"The server barfed."];
        }
        [self.storyTitlesTable reloadData];
        
        return;
    }
    
    appDelegate.hasLoadedFeedDetail = YES;
    self.isOffline = NO;
    self.isShowingOffline = NO;
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    id feedId = [results objectForKey:@"feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    
    if (!(appDelegate.isRiverView || appDelegate.isSocialView || appDelegate.isSocialRiverView) 
        && request.tag != [feedId intValue]) {
        return;
    }
    
    if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        NSArray *newFeeds = [results objectForKey:@"feeds"];
        for (int i = 0; i < newFeeds.count; i++){
            NSString *feedKey = [NSString stringWithFormat:@"%@", [[newFeeds objectAtIndex:i] objectForKey:@"id"]];
            [appDelegate.dictActiveFeeds setObject:[newFeeds objectAtIndex:i] 
                      forKey:feedKey];
        }
        [self loadFaviconsFromActiveFeed];
    }
    
    NSMutableDictionary *newClassifiers = [[results objectForKey:@"classifiers"] mutableCopy];
    if (appDelegate.isRiverView || appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        for (id key in [newClassifiers allKeys]) {
            [appDelegate.activeClassifiers setObject:[newClassifiers objectForKey:key] forKey:key];
        }
    } else {
        [appDelegate.activeClassifiers setObject:newClassifiers forKey:feedIdStr];
    }
    appDelegate.activePopularAuthors = [results objectForKey:@"feed_authors"];
    appDelegate.activePopularTags = [results objectForKey:@"feed_tags"];
    
    NSArray *newStories = [results objectForKey:@"stories"];
    NSMutableArray *confirmedNewStories = [[NSMutableArray alloc] init];
    if (self.feedPage == 1) {
        confirmedNewStories = [newStories copy];
    } else {
        NSMutableSet *storyIds = [NSMutableSet set];
        for (id story in appDelegate.activeFeedStories) {
            [storyIds addObject:[story objectForKey:@"id"]];
        }
        for (id story in newStories) {
            if (![storyIds containsObject:[story objectForKey:@"id"]]) {
                [confirmedNewStories addObject:story];
            }
        }
    }
    
    // Adding new user profiles to appDelegate.activeFeedUserProfiles

    NSArray *newUserProfiles = [[NSArray alloc] init];
    if ([results objectForKey:@"user_profiles"] != nil) {
        newUserProfiles = [results objectForKey:@"user_profiles"];
    }
    // add self to user profiles
    if (self.feedPage == 1) {
        newUserProfiles = [newUserProfiles arrayByAddingObject:appDelegate.dictSocialProfile];
    }
    
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
    
    self.pageFinished = NO;
    [self renderStories:confirmedNewStories];
    [appDelegate.storyPageControl resizeScrollView];
    [appDelegate.storyPageControl setStoryFromScroll:YES];
    [appDelegate.storyPageControl advanceToNextUnread];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT,
                                             (unsigned long)NULL), ^(void) {
        [appDelegate.database inTransaction:^(FMDatabase *db, BOOL *rollback) {
            for (NSDictionary *story in confirmedNewStories) {
                [db executeUpdate:@"INSERT into stories"
                 "(story_feed_id, story_hash, story_timestamp, story_json) VALUES "
                 "(?, ?, ?, ?)",
                 [story objectForKey:@"story_feed_id"],
                 [story objectForKey:@"story_hash"],
                 [story objectForKey:@"story_timestamp"],
                 [story JSONRepresentation]
                 ];
            }
            //    NSLog(@"Inserting %d stories: %@", [confirmedNewStories count], [db lastErrorMessage]);
        }];
    });

    [self.notifier hide];
}

#pragma mark -
#pragma mark Stories

- (void)renderStories:(NSArray *)newStories {

    NSInteger newStoriesCount = [newStories count];
    
    if (newStoriesCount > 0) {
        if (self.feedPage == 1) {
            [appDelegate setStories:newStories];
        } else {
            [appDelegate addStories:newStories];
        }
    } else {
        self.pageFinished = YES;
    }
    
    [self.storyTitlesTable reloadData];
    
    self.pageFetching = NO;
        
    if (self.finishedAnimatingIn) {
        [self testForTryFeed];
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController syncNextPreviousButtons];
    }
    
    [self performSelector:@selector(checkScroll)
               withObject:nil
               afterDelay:0.1];
}

- (void)testForTryFeed {
    if (appDelegate.inFindingStoryMode && appDelegate.tryFeedStoryId) {
        for (int i = 0; i < appDelegate.activeFeedStories.count; i++) {
            NSString *storyIdStr = [[appDelegate.activeFeedStories objectAtIndex:i] objectForKey:@"id"];
            if ([storyIdStr isEqualToString:appDelegate.tryFeedStoryId]) {
                NSDictionary *feed = [appDelegate.activeFeedStories objectAtIndex:i];
                
                int score = [NewsBlurAppDelegate computeStoryScore:[feed objectForKey:@"intelligence"]];
                
                if (score < appDelegate.selectedIntelligence) {
                    [self changeIntelligence:score];
                }
                int locationOfStoryId = [appDelegate locationOfStoryId:storyIdStr];
                NSIndexPath *indexPath = [NSIndexPath indexPathForRow:locationOfStoryId inSection:0];
                
                [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:YES scrollPosition:UITableViewScrollPositionBottom];
                
                FeedDetailTableCell *cell = (FeedDetailTableCell *)[self.storyTitlesTable cellForRowAtIndexPath:indexPath];
                [self loadStory:cell atRow:indexPath.row];
                
                // found the story, reset the two flags.
                //                appDelegate.tryFeedStoryId = nil;
                appDelegate.inFindingStoryMode = NO;
            }
        }
    }
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
    int height = 40;
    UITableViewCell *cell = [[UITableViewCell alloc]
                             initWithStyle:UITableViewCellStyleSubtitle
                             reuseIdentifier:@"NoReuse"];
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    if (self.pageFinished) {
        UIImage *img = [UIImage imageNamed:@"fleuron.png"];
        UIImageView *fleuron = [[UIImageView alloc] initWithImage:img];
        
        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }

        fleuron.frame = CGRectMake(0, 0, self.view.frame.size.width, height);
        fleuron.contentMode = UIViewContentModeCenter;
        [cell.contentView addSubview:fleuron];
        return cell;
    } else {//if ([appDelegate.storyLocationsCount]) {
        NBLoadingCell *loadingCell = [[NBLoadingCell alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, height)];
        return loadingCell;
    }
    
    return cell;
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section { 
    int storyCount = appDelegate.storyLocationsCount;

    // The +1 is for the finished/loading bar.
    return storyCount + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *cellIdentifier;
    NSDictionary *feed ;
    
    if (appDelegate.isRiverView || appDelegate.isSocialView) {
        cellIdentifier = @"FeedRiverDetailCellIdentifier";
    } else {
        cellIdentifier = @"FeedDetailCellIdentifier";
    }
    
    FeedDetailTableCell *cell = (FeedDetailTableCell *)[tableView 
                                                        dequeueReusableCellWithIdentifier:cellIdentifier]; 
    if (cell == nil) {
        cell = [[FeedDetailTableCell alloc] initWithStyle:UITableViewCellStyleDefault
                                          reuseIdentifier:nil];
    }
        
    if (indexPath.row >= appDelegate.storyLocationsCount) {
        return [self makeLoadingCell];
    }
        
    NSDictionary *story = [self getStoryAtRow:indexPath.row];
    
    id feedId = [story objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", feedId];
    
    if (appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        feed = [appDelegate.dictActiveFeeds objectForKey:feedIdStr];
        // this is to catch when a user is already subscribed
        if (!feed) {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
    }
        
    NSString *siteTitle = [feed objectForKey:@"feed_title"];
    cell.siteTitle = siteTitle; 

    NSString *title = [story objectForKey:@"story_title"];
    cell.storyTitle = [title stringByDecodingHTMLEntities];

    cell.storyDate = [story objectForKey:@"short_parsed_date"];
    cell.isStarred = [story objectForKey:@"starred"];
    cell.isShared = [story objectForKey:@"shared"];
    
    if ([[story objectForKey:@"story_authors"] class] != [NSNull class]) {
        cell.storyAuthor = [[story objectForKey:@"story_authors"] uppercaseString];
    } else {
        cell.storyAuthor = @"";
    }
    
    // feed color bar border
    unsigned int colorBorder = 0;
    NSString *faviconColor = [feed valueForKey:@"favicon_fade"];

    if ([faviconColor class] == [NSNull class] || !faviconColor) {
        faviconColor = @"707070";
    }    
    NSScanner *scannerBorder = [NSScanner scannerWithString:faviconColor];
    [scannerBorder scanHexInt:&colorBorder];

    cell.feedColorBar = UIColorFromRGB(colorBorder);
    
    // feed color bar border
    NSString *faviconFade = [feed valueForKey:@"favicon_color"];
    if ([faviconFade class] == [NSNull class] || !faviconFade) {
        faviconFade = @"505050";
    }    
    scannerBorder = [NSScanner scannerWithString:faviconFade];
    [scannerBorder scanHexInt:&colorBorder];
    cell.feedColorBarTopBorder =  UIColorFromRGB(colorBorder);
    
    // favicon
    cell.siteFavicon = [Utilities getImage:feedIdStr];
    
    // undread indicator
    
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    cell.storyScore = score;
    
    if (!appDelegate.hasLoadedFeedDetail) {
        cell.isRead = ([appDelegate.activeReadFilter isEqualToString:@"all"] &&
                       ![[appDelegate.unreadStoryHashes objectForKey:[story objectForKey:@"story_hash"]] boolValue]) ||
                      [[appDelegate.recentlyReadStories objectForKey:[story objectForKey:@"story_hash"]] boolValue];
//        NSLog(@"Offline: %d (%d/%d) - %@ - %@", cell.isRead, ![[appDelegate.unreadStoryHashes objectForKey:[story objectForKey:@"story_hash"]] boolValue], [[appDelegate.recentlyReadStories objectForKey:[story objectForKey:@"story_hash"]] boolValue], [story objectForKey:@"story_title"], [story objectForKey:@"story_hash"]);
    } else {
        cell.isRead = [[story objectForKey:@"read_status"] intValue] == 1 ||
                      [[appDelegate.recentlyReadStories objectForKey:[story objectForKey:@"story_hash"]] boolValue];
//        NSLog(@"Online: %d (%d/%d) - %@ - %@", cell.isRead, [[story objectForKey:@"read_status"] intValue] == 1, [[appDelegate.recentlyReadStories objectForKey:[story objectForKey:@"story_hash"]] boolValue], [story objectForKey:@"story_title"], [story objectForKey:@"story_hash"]);
    }
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
        && !appDelegate.masterContainerViewController.storyTitlesOnLeft
        && UIInterfaceOrientationIsPortrait(orientation)) {
        cell.isShort = YES;
    }

    if (appDelegate.isRiverView || appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        cell.isRiverOrSocial = YES;
    }

    if (UI_USER_INTERFACE_IDIOM() ==  UIUserInterfaceIdiomPad) {
        int rowIndex = [appDelegate locationOfActiveStory];
        if (rowIndex == indexPath.row) {
            [self.storyTitlesTable selectRowAtIndexPath:indexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
        } 
    }

	return cell;
}

- (void)loadStory:(FeedDetailTableCell *)cell atRow:(int)row {
    cell.isRead = YES;
    [cell setNeedsLayout];
    int storyIndex = [appDelegate indexFromLocation:row];
    appDelegate.activeStory = [[appDelegate activeFeedStories] objectAtIndex:storyIndex];
    [appDelegate loadStoryDetailView];
}

- (void)redrawUnreadStory {
    int rowIndex = [appDelegate locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    cell.isRead = [[appDelegate.activeStory objectForKey:@"read_status"] boolValue];
    cell.isShared = [[appDelegate.activeStory objectForKey:@"shared"] boolValue];
    cell.isStarred = [[appDelegate.activeStory objectForKey:@"starred"] boolValue];
    [cell setNeedsDisplay];
}

- (void)changeActiveStoryTitleCellLayout {
    int rowIndex = [appDelegate locationOfActiveStory];
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    FeedDetailTableCell *cell = (FeedDetailTableCell*) [self.storyTitlesTable cellForRowAtIndexPath:indexPath];
    cell.isRead = YES;
    [cell setNeedsLayout];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row < appDelegate.storyLocationsCount) {
        // mark the cell as read
        FeedDetailTableCell *cell = (FeedDetailTableCell*) [tableView cellForRowAtIndexPath:indexPath];        
        [self loadStory:cell atRow:indexPath.row];
    }
}

- (void)tableView:(UITableView *)tableView didEndDisplayingCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell class] == [NBLoadingCell class]) {
        [(NBLoadingCell *)cell endAnimation];
    }
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {
    if ([cell class] == [NBLoadingCell class]) {
        [(NBLoadingCell *)cell animate];
    }
}
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {        UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    
    int storyCount = appDelegate.storyLocationsCount;
    
    if (storyCount && indexPath.row == storyCount) {
        return 40;
    } else if (appDelegate.isRiverView || appDelegate.isSocialView || appDelegate.isSocialRiverView) {
        int height = kTableViewRiverRowHeight;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }
        return height;
    } else {
        int height = kTableViewRowHeight;
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad
            && !appDelegate.masterContainerViewController.storyTitlesOnLeft
            && UIInterfaceOrientationIsPortrait(orientation)) {
            height = height - kTableViewShortRowDifference;
        }
        return height;
    }
}

- (void)scrollViewDidScroll: (UIScrollView *)scroll {
    [self checkScroll];
}

- (void)checkScroll {
    NSInteger currentOffset = self.storyTitlesTable.contentOffset.y;
    NSInteger maximumOffset = self.storyTitlesTable.contentSize.height - self.storyTitlesTable.frame.size.height;
    
    if (![self.appDelegate.activeFeedStories count]) return;
    
    if (maximumOffset - currentOffset <= 60.0 || 
        (appDelegate.inFindingStoryMode)) {
        if (appDelegate.isRiverView) {
            [self fetchRiverPage:self.feedPage+1 withCallback:nil];
        } else {
            [self fetchFeedDetail:self.feedPage+1 withCallback:nil];   
        }
    }
}

- (void)changeIntelligence:(NSInteger)newLevel {
    NSInteger previousLevel = [appDelegate selectedIntelligence];
    NSMutableArray *insertIndexPaths = [NSMutableArray array];
    NSMutableArray *deleteIndexPaths = [NSMutableArray array];
    
    if (newLevel == previousLevel) return;
    
    if (newLevel < previousLevel) {
        [appDelegate setSelectedIntelligence:newLevel];
        NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
        [userPreferences setInteger:(newLevel + 1) forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        [appDelegate calculateStoryLocations];
    }
    
    for (int i=0; i < appDelegate.storyLocationsCount; i++) {
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
}

- (NSDictionary *)getStoryAtRow:(NSInteger)indexPathRow {
    int row = [[[appDelegate activeFeedStoryLocations] objectAtIndex:indexPathRow] intValue];
    return [appDelegate.activeFeedStories objectAtIndex:row];
}

#pragma mark -
#pragma mark Feed Actions


- (void)markFeedsReadWithAllStories:(BOOL)includeHidden {
    if (!self.isOffline && appDelegate.isRiverView && includeHidden &&
        [appDelegate.activeFolder isEqualToString:@"everything"]) {
        // Mark folder as read
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_all_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setDelegate:nil];
        [request startAsynchronous];
        
        [appDelegate markActiveFolderAllRead];
    } else if (!self.isOffline && appDelegate.isRiverView && includeHidden) {
        // Mark folder as read
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        for (id feed_id in [appDelegate.dictFolders objectForKey:appDelegate.activeFolder]) {
            [request addPostValue:feed_id forKey:@"feed_id"];
        }
        [request setDelegate:nil];
        [request startAsynchronous];
        
        [appDelegate markActiveFolderAllRead];
    } else if (!self.isOffline && !appDelegate.isRiverView && includeHidden) {
        // Mark feed as read
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[appDelegate.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
        [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
        [request setDidFailSelector:@selector(requestFailed:)];
        [request setDelegate:self];
        [request startAsynchronous];
        [appDelegate markFeedAllRead:[appDelegate.activeFeed objectForKey:@"id"]];
    } else if (!includeHidden) {
        // Mark visible stories as read
        NSDictionary *feedsStories = [appDelegate markVisibleStoriesRead];
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/mark_feed_stories_as_read",
                               NEWSBLUR_URL];
        NSURL *url = [NSURL URLWithString:urlString];
        ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
        [request setPostValue:[feedsStories JSONRepresentation] forKey:@"feeds_stories"]; 
        [request setDelegate:self];
        [request setUserInfo:feedsStories];
        [request setDidFinishSelector:@selector(finishMarkAllAsRead:)];
        [request setDidFailSelector:@selector(requestFailedMarkStoryRead:)];
        [request startAsynchronous];
    } else {
        // Must be offline and marking all as read, so load all stories.
        NSMutableDictionary *feedsStories = [NSMutableDictionary dictionary];
        
        [appDelegate.database inDatabase:^(FMDatabase *db) {
            NSArray *feedIds;
            
            if (appDelegate.isRiverView) {
                feedIds = appDelegate.activeFolderFeeds;
            } else if (appDelegate.activeFeed) {
                feedIds = @[[appDelegate.activeFeed objectForKey:@"id"]];
            } else {
                return;
            }
            
            NSString *sql = [NSString stringWithFormat:@"SELECT u.story_feed_id, u.story_hash "
                             "FROM unread_hashes u WHERE u.story_feed_id IN (%@)",
                             [feedIds componentsJoinedByString:@","]];
            FMResultSet *cursor = [db executeQuery:sql];
            
            while ([cursor next]) {
                NSDictionary *story = [cursor resultDictionary];
                NSString *feedIdStr = [story objectForKey:@"story_feed_id"];
                NSString *storyHash = [story objectForKey:@"story_hash"];

                if (![feedsStories objectForKey:feedIdStr]) {
                    [feedsStories setObject:[NSMutableArray array] forKey:feedIdStr];
                }
                
                NSMutableArray *stories = [feedsStories objectForKey:feedIdStr];
                [stories addObject:storyHash];
            }
        }];

        for (NSString *feedId in [feedsStories allKeys]) {
            [appDelegate markFeedAllRead:feedId];
        }
        [appDelegate queueReadStories:feedsStories];
    }
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.navigationController popToRootViewControllerAnimated:YES];
        [appDelegate.masterContainerViewController transitionFromFeedDetail];
    } else {
        [appDelegate.navigationController 
         popToViewController:[appDelegate.navigationController.viewControllers 
                              objectAtIndex:0]  
         animated:YES];
    }
}

- (void)requestFailedMarkStoryRead:(ASIFormDataRequest *)request {
    //    [self informError:@"Failed to mark story as read"];
    NSDictionary *feedsStories = request.userInfo;
    [appDelegate queueReadStories:feedsStories];
}

- (void)finishMarkAllAsRead:(ASIFormDataRequest *)request {
    if (request.responseStatusCode != 200) {
        [self requestFailedMarkStoryRead:request];
    }
//    NSString *responseString = [request responseString];
//    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
//    NSError *error;
//    NSDictionary *results = [NSJSONSerialization 
//                             JSONObjectWithData:responseData
//                             options:kNilOptions 
//                             error:&error];
    

}

- (IBAction)doOpenMarkReadActionSheet:(id)sender {
    // already displaying action sheet?
    if (self.actionSheet_) {
        [self.actionSheet_ dismissWithClickedButtonIndex:-1 animated:YES];
        self.actionSheet_ = nil;
        return;
    }
    
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
    
    self.actionSheet_ = options;
    [appDelegate calculateStoryLocations];
    int visibleUnreadCount = appDelegate.visibleUnreadCount;
    int totalUnreadCount = [appDelegate unreadCount];
    NSArray *buttonTitles = nil;
    BOOL showVisible = YES;
    BOOL showEntire = YES;
//    if ([appDelegate.activeFolder isEqualToString:@"everything"]) showEntire = NO;
    if (visibleUnreadCount >= totalUnreadCount || visibleUnreadCount <= 0) showVisible = NO;
    NSString *entireText = [NSString stringWithFormat:@"Mark %@ read", 
                            appDelegate.isRiverView ?
                            [appDelegate.activeFolder isEqualToString:@"everything"] ?
                            @"everything" :
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
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [options showFromBarButtonItem:self.feedMarkReadButton animated:YES];
    } else {
        [options showInView:self.view];
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex {
//    NSLog(@"Action option #%d on %d", buttonIndex, actionSheet.tag);
    if (actionSheet.tag == 1) {
        int visibleUnreadCount = appDelegate.visibleUnreadCount;
        int totalUnreadCount = [appDelegate unreadCount];
        BOOL showVisible = YES;
        BOOL showEntire = YES;
//        if ([appDelegate.activeFolder isEqualToString:@"everything"]) showEntire = NO;
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

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex {
    // just set to nil
    actionSheet_ = nil;
}

- (IBAction)doOpenSettingsActionSheet:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showFeedDetailMenuPopover:self.settingsBarButton];
    } else {
        if (self.popoverController == nil) {
            self.popoverController = [[WEPopoverController alloc]
                                      initWithContentViewController:(UIViewController *)appDelegate.feedDetailMenuViewController];
            [appDelegate.feedDetailMenuViewController buildMenuOptions];
            self.popoverController.delegate = self;
        } else {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
        
        if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
            [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
        }
        int menuCount = [appDelegate.feedDetailMenuViewController.menuOptions count] + 2;
        [self.popoverController setPopoverContentSize:CGSizeMake(260, 38 * menuCount)];
        [self.popoverController presentPopoverFromBarButtonItem:self.settingsBarButton
                                       permittedArrowDirections:UIPopoverArrowDirectionUp
                                                       animated:YES];
    }

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
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/delete_feed", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[[appDelegate activeFeed] objectForKey:@"id"] forKey:@"feed_id"];
    [request addPostValue:[appDelegate extractFolderName:appDelegate.activeFolder] forKey:@"in_folder"];
    [request setDidFailSelector:@selector(requestFailed:)];
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
    
    NSString *theFeedDetailURL = [NSString stringWithFormat:@"%@/reader/delete_folder", 
                                  NEWSBLUR_URL];
    NSURL *urlFeedDetail = [NSURL URLWithString:theFeedDetailURL];
    
    __block ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:urlFeedDetail];
    [request setDelegate:self];
    [request addPostValue:[appDelegate extractFolderName:appDelegate.activeFolder] 
                   forKey:@"folder_to_delete"];
    [request addPostValue:[appDelegate extractFolderName:[appDelegate extractParentFolderName:appDelegate.activeFolder]] 
                   forKey:@"in_folder"];
    [request setDidFailSelector:@selector(requestFailed:)];
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

- (void)openTrainSite {
    [appDelegate openTrainSite];
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [appDelegate.activeFeed objectForKey:@"username"]];
    [appDelegate showUserProfileModal:self.navigationItem.rightBarButtonItem];
}

- (void)changeActiveFeedDetailRow {
    int rowIndex = [appDelegate locationOfActiveStory];
                    
    NSIndexPath *indexPath = [NSIndexPath indexPathForRow:rowIndex inSection:0];
    NSIndexPath *offsetIndexPath = [NSIndexPath indexPathForRow:rowIndex - 1 inSection:0];

    [storyTitlesTable selectRowAtIndexPath:indexPath 
                                  animated:YES 
                            scrollPosition:UITableViewScrollPositionNone];
    
    // check to see if the cell is completely visible
    CGRect cellRect = [storyTitlesTable rectForRowAtIndexPath:indexPath];
    
    cellRect = [storyTitlesTable convertRect:cellRect toView:storyTitlesTable.superview];
    
    BOOL completelyVisible = CGRectContainsRect(storyTitlesTable.frame, cellRect);
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
    NSString *urlString = [NSString
                           stringWithFormat:@"%@/reader/refresh_feed/%@", 
                           NEWSBLUR_URL,
                           [appDelegate.activeFeed objectForKey:@"id"]];
    [self cancelRequests];
    ASIHTTPRequest *request = [self requestWithURL:urlString];
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
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
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
    
    if (![keys count]) {
        // if no new favicons, return
        return;
    }
    
    NSString *feedIdsQuery = [NSString stringWithFormat:@"?feed_ids=%@", 
                               [[keys valueForKey:@"description"] componentsJoinedByString:@"&feed_ids="]];        
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/favicons%@",
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
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSMutableDictionary *feed = [[appDelegate.dictActiveFeeds objectForKey:feed_id] mutableCopy];
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
    [appDelegate informError:error];
}

#pragma mark -
#pragma mark WEPopoverControllerDelegate implementation

- (void)popoverControllerDidDismissPopover:(WEPopoverController *)thePopoverController {
	//Safe to release the popover here
	self.popoverController = nil;
}

- (BOOL)popoverControllerShouldDismissPopover:(WEPopoverController *)thePopoverController {
	//The popover is automatically dismissed if you click outside it, unless you return NO here
	return YES;
}

- (WEPopoverContainerViewProperties *)improvedContainerViewProperties {
	
	WEPopoverContainerViewProperties *props = [WEPopoverContainerViewProperties alloc];
	NSString *bgImageName = nil;
	CGFloat bgMargin = 0.0;
	CGFloat bgCapSize = 0.0;
	CGFloat contentMargin = 5.0;
	
	bgImageName = @"popoverBg.png";
	
	// These constants are determined by the popoverBg.png image file and are image dependent
	bgMargin = 13; // margin width of 13 pixels on all sides popoverBg.png (62 pixels wide - 36 pixel background) / 2 == 26 / 2 == 13
	bgCapSize = 31; // ImageSize/2  == 62 / 2 == 31 pixels
	
	props.leftBgMargin = bgMargin;
	props.rightBgMargin = bgMargin;
	props.topBgMargin = bgMargin;
	props.bottomBgMargin = bgMargin;
	props.leftBgCapSize = bgCapSize;
	props.topBgCapSize = bgCapSize;
	props.bgImageName = bgImageName;
	props.leftContentMargin = contentMargin;
	props.rightContentMargin = contentMargin - 1; // Need to shift one pixel for border to look correct
	props.topContentMargin = contentMargin;
	props.bottomContentMargin = contentMargin;
	
	props.arrowMargin = 4.0;
	
	props.upArrowImageName = @"popoverArrowUp.png";
	props.downArrowImageName = @"popoverArrowDown.png";
	props.leftArrowImageName = @"popoverArrowLeft.png";
	props.rightArrowImageName = @"popoverArrowRight.png";
	return props;
}


@end
