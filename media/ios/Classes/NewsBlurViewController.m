//
//  NewsBlurViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "DashboardViewController.h"
#import "FeedTableCell.h"
#import "FeedsMenuViewController.h"
#import "UserProfileViewController.h"
#import "StoryDetailViewController.h"
#import "ASIHTTPRequest.h"
#import "PullToRefreshView.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "Utilities.h"
#import "UIBarButtonItem+WEPopover.h"


#define kPhoneTableViewRowHeight 36;
#define kTableViewRowHeight 36;
#define kBlurblogTableViewRowHeight 47;
#define kPhoneBlurblogTableViewRowHeight 39;

@interface NewsBlurViewController () 

@property (nonatomic, strong) NSMutableDictionary *updatedDictSocialFeeds_;
@property (nonatomic, strong) NSMutableDictionary *updatedDictFeeds_;

@end

@implementation NewsBlurViewController

@synthesize appDelegate;
@synthesize innerView;
@synthesize feedTitlesTable;
@synthesize feedViewToolbar;
@synthesize feedScoreSlider;
@synthesize homeButton;
@synthesize intelligenceControl;
@synthesize activeFeedLocations;
@synthesize visibleFeeds;
@synthesize stillVisibleFeeds;
@synthesize viewShowingAllFeeds;
@synthesize pull;
@synthesize lastUpdate;
@synthesize imageCache;
@synthesize popoverController;
@synthesize currentRowAtIndexPath;
@synthesize noFocusMessage;
@synthesize toolbarLeftMargin;
@synthesize hasNoSites;
@synthesize updatedDictFeeds_;
@synthesize updatedDictSocialFeeds_;

#pragma mark -
#pragma mark Globals

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    popoverClass = [WEPopoverController class];
    
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    pull = [[PullToRefreshView alloc] initWithScrollView:self.feedTitlesTable];
    [pull setDelegate:self];
    [self.feedTitlesTable addSubview:pull];
    
    [[NSNotificationCenter defaultCenter] 
     addObserver:self
     selector:@selector(returnToApp)
     name:UIApplicationWillEnterForegroundNotification
     object:nil];
    
    imageCache = [[NSCache alloc] init];
    [imageCache setDelegate:self];
    
    [self.intelligenceControl setWidth:50 forSegmentAtIndex:0];
    [self.intelligenceControl setWidth:68 forSegmentAtIndex:1];
    [self.intelligenceControl setWidth:62 forSegmentAtIndex:2];
    self.intelligenceControl.hidden = YES;
    

}

- (void)viewWillAppear:(BOOL)animated {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController transitionFromFeedDetail];
    } 
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    [self setUserAvatarLayout:orientation];
    
    [super viewWillAppear:animated];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences integerForKey:@"selectedIntelligence"] == 1) {
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:2];
        [appDelegate setSelectedIntelligence:1];
    } else if ([userPreferences integerForKey:@"selectedIntelligence"] == 0) {
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:1];
        [appDelegate setSelectedIntelligence:0];
    } else { // default state, all stories
        self.viewShowingAllFeeds = YES;
        [self.intelligenceControl setSelectedSegmentIndex:0];
        [appDelegate setSelectedIntelligence:0];
    }
    
//    self.feedTitlesTable.separatorStyle = UITableViewCellSeparatorStyleNone; // DO NOT USE. THIS BREAKS SHIT.
    UIColor *bgColor = [UIColor colorWithRed:0.95 green:0.95 blue:0.95 alpha:1.0];
    self.feedTitlesTable.backgroundColor = bgColor;
    
    self.feedTitlesTable.separatorColor = [UIColor clearColor];
    
    // reset all feed detail specific data
    appDelegate.activeFeed = nil; 
    appDelegate.isSocialView = NO;
    appDelegate.isRiverView = NO;
    appDelegate.inFindingStoryMode = NO;
    [MBProgressHUD hideHUDForView:appDelegate.storyDetailViewController.view animated:NO];
    
    if (appDelegate.activeFeed || appDelegate.isRiverView) {        
        [self.feedTitlesTable beginUpdates];
        [self.feedTitlesTable 
         reloadRowsAtIndexPaths:[self.feedTitlesTable indexPathsForVisibleRows]
         withRowAnimation:UITableViewRowAnimationNone];
        [self.feedTitlesTable endUpdates];
        
        NSInteger previousLevel = [self.intelligenceControl selectedSegmentIndex] - 1;
        NSInteger newLevel = [appDelegate selectedIntelligence];
        if (newLevel != previousLevel) {
            [appDelegate setSelectedIntelligence:newLevel];
            if (!self.viewShowingAllFeeds) {
                [self updateFeedsWithIntelligence:previousLevel newLevel:newLevel];
            }
            [self redrawUnreadCounts];
        }
    }
    
    
    // perform these only if coming from the feed detail view
    if (appDelegate.inFeedDetail) {
        appDelegate.inFeedDetail = NO;
        // reload the data and then set the highlight again
        [self.feedTitlesTable reloadData];
        [self redrawUnreadCounts];
        [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath 
                                          animated:NO 
                                    scrollPosition:UITableViewScrollPositionNone]; 
    }

}

- (void)viewDidAppear:(BOOL)animated {
//    [self.feedTitlesTable selectRowAtIndexPath:self.currentRowAtIndexPath 
//                                      animated:NO 
//                                scrollPosition:UITableViewScrollPositionNone];
    
    [super viewDidAppear:animated];
    [self performSelector:@selector(fadeSelectedCell) withObject:self afterDelay:0.6];
    self.navigationController.navigationBar.backItem.title = @"All Sites";
}

- (void)fadeSelectedCell {
    [self.feedTitlesTable deselectRowAtIndexPath:[self.feedTitlesTable indexPathForSelectedRow]
                                        animated:YES];
}

- (void)viewWillDisappear:(BOOL)animated {
    [self.popoverController dismissPopoverAnimated:YES];
    self.popoverController = nil;
    [super viewWillDisappear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    [self setUserAvatarLayout:toInterfaceOrientation];
}

- (void)setUserAvatarLayout:(UIInterfaceOrientation)orientation {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPhone) {
        if (UIInterfaceOrientationIsPortrait(orientation)) {
            UIButton *avatar = (UIButton *)self.navigationItem.leftBarButtonItem.customView; 
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(32, 32);
            avatar.frame = buttonFrame;
        } else {
            UIButton *avatar = (UIButton *)self.navigationItem.leftBarButtonItem.customView; 
            CGRect buttonFrame = avatar.frame;
            buttonFrame.size = CGSizeMake(28, 28);
            avatar.frame = buttonFrame;
        }
    }
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation {
    [self.feedTitlesTable reloadData];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [self setToolbarLeftMargin:nil];
    [self setNoFocusMessage:nil];
    [self setInnerView:nil];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}



#pragma mark -
#pragma mark Initialization

- (void)returnToApp {
    NSDate *decayDate = [[NSDate alloc] initWithTimeIntervalSinceNow:(BACKGROUND_REFRESH_SECONDS)];
    NSLog(@"Last Update: %@ - %f", self.lastUpdate, [self.lastUpdate timeIntervalSinceDate:decayDate]);
    if ([self.lastUpdate timeIntervalSinceDate:decayDate] < 0) {
        [self fetchFeedList:YES];
    }
    
}

-(void)fetchFeedList:(BOOL)showLoader {
    if (showLoader && appDelegate.navigationController.topViewController == appDelegate.feedsViewController) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        HUD.labelText = @"On its way...";
    }
    
    NSURL *urlFeedList = [NSURL URLWithString:
                          [NSString stringWithFormat:@"http://%@/reader/feeds?flat=true&update_counts=false",
                           NEWSBLUR_URL]];

    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:urlFeedList];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setDidFinishSelector:@selector(finishLoadingFeedList:)];
    [request setDidFailSelector:@selector(finishedWithError:)];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
    NSLog(@"urlFeedList is %@", urlFeedList);
    self.lastUpdate = [NSDate date];
}

- (void)finishedWithError:(ASIHTTPRequest *)request {    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [pull finishedLoading];
    
    // User clicking on another link before the page loads is OK.
    [self informError:[request error]];
}

- (void)finishLoadingFeedList:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] == 403) {
        return [appDelegate showLogin];
    } else if ([request responseStatusCode] >= 500) {
        [pull finishedLoading];
        return [self informError:@"The server barfed!"];
    }
    
    self.hasNoSites = NO;
    NSString *responseString = [request responseString];   
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];

//    NSLog(@"results are %@", results);
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    self.visibleFeeds = [NSMutableDictionary dictionary];
    [pull finishedLoading];
    [self loadFavicons];

    appDelegate.activeUsername = [results objectForKey:@"user"];

    // set title only if on currestont controller
    if (appDelegate.feedsViewController.view.window && [results objectForKey:@"user"]) {
        [appDelegate setTitle:[results objectForKey:@"user"]];
    }

    // adding user avatar to left
    NSString *url = [NSString stringWithFormat:@"%@", [[results objectForKey:@"social_profile"] objectForKey:@"photo_url"]];
    NSURL * imageURL = [NSURL URLWithString:url];
    NSData * imageData = [NSData dataWithContentsOfURL:imageURL];
    UIImage * userAvatarImage = [UIImage imageWithData:imageData];
    userAvatarImage = [Utilities roundCorneredImage:userAvatarImage radius:6];
    
    UIButton *userAvatarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    
    UIInterfaceOrientation orientation = [UIApplication sharedApplication].statusBarOrientation;
    userAvatarButton.bounds = CGRectMake(0, 0, 32, 32);
    [userAvatarButton addTarget:self action:@selector(showUserProfile) forControlEvents:UIControlEventTouchUpInside];
    [userAvatarButton setImage:userAvatarImage forState:UIControlStateNormal];


    UIBarButtonItem *userAvatar = [[UIBarButtonItem alloc] 
                                   initWithCustomView:userAvatarButton];
    
    self.navigationItem.leftBarButtonItem = userAvatar;
    [self setUserAvatarLayout:orientation];
    
    // adding settings button to right

//    UIImage *settingsImage = [UIImage imageNamed:@"settings.png"];
//    UIButton *settings = [UIButton buttonWithType:UIButtonTypeCustom];    
//    settings.bounds = CGRectMake(0, 0, 32, 32);
//    [settings addTarget:self action:@selector(showSettingsPopover:) forControlEvents:UIControlEventTouchUpInside];
//    [settings setImage:settingsImage forState:UIControlStateNormal];
//    
//    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] 
//                                   initWithCustomView:settings];
    
    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"settings.png"] style:UIBarButtonItemStylePlain target:self action:@selector(showSettingsPopover:)];

    
    self.navigationItem.rightBarButtonItem = settingsButton;
    
    NSMutableDictionary *sortedFolders = [[NSMutableDictionary alloc] init];
    NSArray *sortedArray;
    
    // Set up dictUserProfile and userActivitiesArray
    appDelegate.dictUserProfile = [results objectForKey:@"social_profile"];
    appDelegate.userActivitiesArray = [results objectForKey:@"activities"];
    
    // Only update the dashboard if there is a social profile
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.dashboardViewController refreshInteractions];
        [appDelegate.dashboardViewController refreshActivity];
    }
    
    // Set up dictSocialFeeds
    NSArray *socialFeedsArray = [results objectForKey:@"social_feeds"];
    NSMutableArray *socialFolder = [[NSMutableArray alloc] init];
    NSMutableDictionary *socialDict = [[NSMutableDictionary alloc] init];
    NSMutableDictionary *tempActiveFeeds = [[NSMutableDictionary alloc] init];
    appDelegate.dictActiveFeeds = tempActiveFeeds;
    
    for (int i = 0; i < socialFeedsArray.count; i++) {
        NSString *userKey = [NSString stringWithFormat:@"%@", 
                             [[socialFeedsArray objectAtIndex:i] objectForKey:@"id"]];
        [socialFolder addObject: [[socialFeedsArray objectAtIndex:i] objectForKey:@"id"]];
        [socialDict setObject:[socialFeedsArray objectAtIndex:i] 
                       forKey:userKey];
    }
    
    appDelegate.dictSocialFeeds = socialDict;
    [self loadAvatars];
    
    // set up dictFolders
    NSMutableDictionary * allFolders = [[NSMutableDictionary alloc] init];
    
    if (![[results objectForKey:@"flat_folders"] isKindOfClass:[NSArray class]]) {
        allFolders = [[results objectForKey:@"flat_folders"] mutableCopy];
    }

    [allFolders setValue:socialFolder forKey:@""]; 
    
    if (![[allFolders allKeys] containsObject:@" "]) {
        [allFolders setValue:[[NSArray alloc] init] forKey:@" "]; 
    }
    
    appDelegate.dictFolders = allFolders;
    
    // set up dictFeeds
    appDelegate.dictFeeds = [[results objectForKey:@"feeds"] mutableCopy];

    // sort all the folders
    appDelegate.dictFoldersArray = [NSMutableArray array];
    for (id f in appDelegate.dictFolders) {
        [appDelegate.dictFoldersArray addObject:f];
        NSArray *folder = [appDelegate.dictFolders objectForKey:f];
        sortedArray = [folder sortedArrayUsingComparator:^NSComparisonResult(id id1, id id2) {
            NSString *feedTitleA;
            NSString *feedTitleB;
            
            if ([appDelegate isSocialFeed:[NSString stringWithFormat:@"%@", id1]]) {
                feedTitleA = [[appDelegate.dictSocialFeeds 
                               objectForKey:[NSString stringWithFormat:@"%@", id1]] 
                              objectForKey:@"feed_title"];
                feedTitleB = [[appDelegate.dictSocialFeeds 
                               objectForKey:[NSString stringWithFormat:@"%@", id2]] 
                              objectForKey:@"feed_title"];
            } else {
                feedTitleA = [[appDelegate.dictFeeds 
                                         objectForKey:[NSString stringWithFormat:@"%@", id1]] 
                                        objectForKey:@"feed_title"];
                feedTitleB = [[appDelegate.dictFeeds 
                                         objectForKey:[NSString stringWithFormat:@"%@", id2]] 
                                        objectForKey:@"feed_title"];
            }
            return [feedTitleA caseInsensitiveCompare:feedTitleB];
        }];
        [sortedFolders setValue:sortedArray forKey:f];
    }
    appDelegate.dictFolders = sortedFolders;
    [appDelegate.dictFoldersArray sortUsingSelector:@selector(caseInsensitiveCompare:)];

    if (self.viewShowingAllFeeds) {
        [self calculateFeedLocations:NO];
    } else {
        [self calculateFeedLocations:YES];
    }
    
    // test for empty
    
    if ([[appDelegate.dictFeeds allKeys] count] == 0 &&
        [[appDelegate.dictSocialFeeds allKeys] count] == 0) {
        self.hasNoSites = YES;
    }
    
    [self.feedTitlesTable reloadData];

    // assign categories for FTUX
    
    if (![[results objectForKey:@"categories"] isKindOfClass:[NSNull class]]){
        appDelegate.categories = [[results objectForKey:@"categories"] objectForKey:@"categories"];
        appDelegate.categoryFeeds = [[results objectForKey:@"categories"] objectForKey:@"feeds"];
    }
    
    // test for latest version of app
    NSString *serveriPhoneVersion = [results objectForKey:@"iphone_version"];  
    NSString *currentiPhoneVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleVersion"];
    
    float serveriPhoneVersionFloat = [serveriPhoneVersion floatValue];
    float currentiPhoneVersionFloat = [currentiPhoneVersion floatValue];

    if (currentiPhoneVersionFloat < serveriPhoneVersionFloat) {
        NSLog(@"Version: %f - %f", serveriPhoneVersionFloat, currentiPhoneVersionFloat);
        NSString *title = [NSString stringWithFormat:@
                           "You should download the new version of NewsBlur.\n\nNew version: v%@\nYou have: v%@", 
                           serveriPhoneVersion, 
                           currentiPhoneVersion];
        UIAlertView *upgradeConfirm = [[UIAlertView alloc] initWithTitle:title 
                                                                 message:nil 
                                                                delegate:self 
                                                       cancelButtonTitle:@"Cancel" 
                                                       otherButtonTitles:@"Upgrade!", nil];
        [upgradeConfirm show];
        [upgradeConfirm setTag:2];
    }

    [self refreshFeedList];
    
    // start up the first time user experience
    if ([[results objectForKey:@"social_feeds"] count] == 0 &&
        [[[results objectForKey:@"feeds"] allKeys] count] == 0) {
        [appDelegate showFirstTimeUser];
        return;
    }
    
    BOOL hasFocusStory = NO;
    for (id feedId in appDelegate.dictFeeds) {
        NSDictionary *feed = [appDelegate.dictFeeds objectForKey:feedId];
        if ([[feed objectForKey:@"ps"] intValue] > 0) {
            hasFocusStory = YES;
            break;
        }
    }

    if (!hasFocusStory) {
        [self.intelligenceControl removeSegmentAtIndex:2 animated:NO];
        [self.intelligenceControl setWidth:90 forSegmentAtIndex:0];
        [self.intelligenceControl setWidth:90 forSegmentAtIndex:1];
    } else {
        UIImage *green = [UIImage imageNamed:@"green_focus.png"];
        if (self.intelligenceControl.numberOfSegments == 2) {
            [self.intelligenceControl insertSegmentWithImage:green atIndex:2 animated:NO];
            [self.intelligenceControl setWidth:50 forSegmentAtIndex:0];
            [self.intelligenceControl setWidth:68 forSegmentAtIndex:1];
            [self.intelligenceControl setWidth:62 forSegmentAtIndex:2];
        }
    }
    
    self.intelligenceControl.hidden = NO;
}

- (void)showUserProfile {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];
    appDelegate.activeUserProfileName = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"username"]];
//    appDelegate.activeUserProfileName = @"You";
    [appDelegate showUserProfileModal:self.navigationItem.leftBarButtonItem];
}

- (IBAction)tapAddSite:(id)sender {
    [appDelegate showAddSiteModal:sender];
}

- (void)showSettingsPopover:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController showFeedMenuPopover:sender];
    } else {
        if (self.popoverController == nil) {
            self.popoverController = [[WEPopoverController alloc]
                                      initWithContentViewController:appDelegate.feedsMenuViewController];
            
            self.popoverController.delegate = self;
        } else {
            [self.popoverController dismissPopoverAnimated:YES];
            self.popoverController = nil;
        }
        
        if ([self.popoverController respondsToSelector:@selector(setContainerViewProperties:)]) {
            [self.popoverController setContainerViewProperties:[self improvedContainerViewProperties]];
        }
        [self.popoverController setPopoverContentSize:CGSizeMake(200, 86)];
        [self.popoverController presentPopoverFromBarButtonItem:self.navigationItem.rightBarButtonItem 
                                       permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                       animated:YES];
    }
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    if (alertView.tag == 2) {
        if (buttonIndex == 0) {
            return;
        } else {
            //  this doesn't work in simulator!!! because simulator has no app store
            NSURL *url = [NSURL URLWithString:@"http://phobos.apple.com/WebObjects/MZStore.woa/wa/viewSoftware?id=463981119&mt=8"];
            [[UIApplication sharedApplication] openURL:url];
        }
    }
}

- (void)switchSitesUnread {
    NSDictionary *feed;
    
    NSInteger intelligenceLevel = [appDelegate selectedIntelligence];
    NSMutableArray *indexPaths = [NSMutableArray array];
    
    // if show all sites, calculate feeds and mark visible
    if (self.viewShowingAllFeeds) {
        [self calculateFeedLocations:NO];
    }
    
    //    NSLog(@"View showing all: %d and %@", self.viewShowingAllFeeds, self.stillVisibleFeeds);
    
    for (int s=0; s < [appDelegate.dictFoldersArray count]; s++) {
        NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:s];
        NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
        NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
        for (int f=0; f < [activeFolderFeeds count]; f++) {
            int location = [[activeFolderFeeds objectAtIndex:f] intValue];
            id feedId = [originalFolder objectAtIndex:location];
            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:f inSection:s];
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
            if ([appDelegate isSocialFeed:feedIdStr]) {
                feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr];
            } else {
                feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
            }
            
            int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
            
//            BOOL isUser = [[NSString stringWithFormat:@"%@", feedId]
//                           isEqualToString:
//                           [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"id"]]];
            
            // if unread
            if (!self.viewShowingAllFeeds) {
                if (maxScore < intelligenceLevel) {
                    [indexPaths addObject:indexPath];
                }
            } else if (self.viewShowingAllFeeds && ![self.stillVisibleFeeds objectForKey:feedIdStr]) {
                if (maxScore < intelligenceLevel) {
                    [indexPaths addObject:indexPath];
                }
            }
        }
    }
        
    // if show unreads, calculate feeds and mark visible
    if (!self.viewShowingAllFeeds) {
        [self calculateFeedLocations:YES];
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
    
    CGPoint offset = CGPointMake(0, 0);
    [self.feedTitlesTable setContentOffset:offset animated:YES];
    
    // Forget still visible feeds, since they won't be populated when
    // all feeds are showing, and shouldn't be populated after this
    // hide/show runs.
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    [self redrawUnreadCounts];
}

#pragma mark -
#pragma mark Table View - Feed List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if (self.hasNoSites) {
        return 2;
    }
    return [appDelegate.dictFoldersArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [appDelegate.dictFoldersArray objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (self.hasNoSites) {
        return 1;
    }

    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    return [[self.activeFeedLocations objectForKey:folderName] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
                     cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    // messaging when there are no sites
    if (self.hasNoSites) {
        UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:@"EmptyCell"];    
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault  reuseIdentifier:nil];
        }
        cell.textLabel.font=[UIFont systemFontOfSize:14.0];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        if (indexPath.section == 0) {
            cell.textLabel.text = @"Tap the settings to find friends.";
        } else {
            cell.textLabel.text = @"Tap + to add sites.";
        }
        
        return cell;
    }

    
    NSDictionary *feed;

    NSString *CellIdentifier;
    
    if (indexPath.section == 0) {
        CellIdentifier = @"BlurblogCellIdentifier";
    } else {
        CellIdentifier = @"FeedCellIdentifier";
    }
        
    FeedTableCell *cell = (FeedTableCell *)[tableView dequeueReusableCellWithIdentifier:CellIdentifier];    
    if (cell == nil) {
        cell = [[FeedTableCell alloc] initWithStyle:UITableViewCellStyleDefault  reuseIdentifier:CellIdentifier];
        cell.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    }
    

    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    NSArray *feeds = [appDelegate.dictFolders objectForKey:folderName];
    NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
    int location = [[activeFolderFeeds objectAtIndex:indexPath.row] intValue];
    id feedId = [feeds objectAtIndex:location];
    
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    BOOL isSocial = [appDelegate isSocialFeed:feedIdStr];
    

    
    if (isSocial) {
        feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr];
        cell.feedFavicon = [Utilities getImage:feedIdStr isSocial:YES];
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        cell.feedFavicon = [Utilities getImage:feedIdStr];
    }
    cell.feedTitle     = [feed objectForKey:@"feed_title"];
    cell.positiveCount = [[feed objectForKey:@"ps"] intValue];
    cell.neutralCount  = [[feed objectForKey:@"nt"] intValue];
    cell.negativeCount = [[feed objectForKey:@"ng"] intValue];
    cell.isSocial      = isSocial;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
        didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.hasNoSites) {
        return;
    }
    
    // set the current row pointer
    self.currentRowAtIndexPath = indexPath;
    
    NSDictionary *feed;
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    NSArray *feeds = [appDelegate.dictFolders objectForKey:folderName];
    NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
    int location = [[activeFolderFeeds objectAtIndex:indexPath.row] intValue];
    id feedId = [feeds objectAtIndex:location];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    
    if ([appDelegate isSocialFeed:feedIdStr]) {
        feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr];
        appDelegate.isSocialView = YES;
    } else {
        feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        appDelegate.isSocialView = NO;
    }
    
    // If all feeds are already showing, no need to remember this one.
    if (!self.viewShowingAllFeeds) {
        [self.stillVisibleFeeds setObject:indexPath forKey:feedIdStr];
    }
    
    [appDelegate setActiveFeed:feed];
    [appDelegate setActiveFolder:folderName];
    appDelegate.readStories = [NSMutableArray array];
    appDelegate.isRiverView = NO;
    appDelegate.isSocialRiverView = NO;
        
    [appDelegate loadFeedDetailView];
}

- (CGFloat)tableView:(UITableView *)tableView 
           heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (self.hasNoSites) {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return kBlurblogTableViewRowHeight;            
        } else {
            return kPhoneBlurblogTableViewRowHeight;
        }
    }
    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    
    if ([folderName isEqualToString:@""]) { // blurblogs
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return kBlurblogTableViewRowHeight;            
        } else {
            return kPhoneBlurblogTableViewRowHeight;
        }
    } else {
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            return kTableViewRowHeight;            
        } else {
            return kPhoneTableViewRowHeight;
        }
    }
}

- (UIView *)tableView:(UITableView *)tableView 
            viewForHeaderInSection:(NSInteger)section {
    
    int headerLabelHeight, folderImageViewY, disclosureImageViewY;
    
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        headerLabelHeight = 27;
        folderImageViewY = 3;
        disclosureImageViewY = 7;
//    } else {
//        headerLabelHeight = 20;
//        folderImageViewY = 0;
//        disclosureImageViewY = 4;
//    }
        
    // create the parent view that will hold header Label
    UIControl* customView = [[UIControl alloc] 
                              initWithFrame:CGRectMake(0.0, 0.0, 
                                                       tableView.bounds.size.width, headerLabelHeight + 1)];
    UIView *borderTop = [[UIView alloc] 
                            initWithFrame:CGRectMake(0.0, 0, 
                                                     tableView.bounds.size.width, 1.0)];
    borderTop.backgroundColor = UIColorFromRGB(0xe0e0e0);
    borderTop.opaque = NO;
    [customView addSubview:borderTop];
    
    
    UIView *borderBottom = [[UIView alloc] 
                             initWithFrame:CGRectMake(0.0, headerLabelHeight, 
                                                      tableView.bounds.size.width, 1.0)];
    borderBottom.backgroundColor = [UIColorFromRGB(0xB7BDC6) colorWithAlphaComponent:0.5];
    borderBottom.opaque = NO;
    [customView addSubview:borderBottom];
    
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    customView.opaque = NO;
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:11];
    headerLabel.frame = CGRectMake(36.0, 1.0, 286.0, headerLabelHeight);
    headerLabel.shadowColor = [UIColor colorWithRed:.94 green:0.94 blue:0.97 alpha:1.0];
    headerLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    if (section == 0) {
        headerLabel.text = @"All Blurblog Stories";
//        customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
//                                      colorWithAlphaComponent:0.8];
    } else if (section == 1) {
        headerLabel.text = @"All Stories";
//        customView.backgroundColor = [UIColorFromRGB(0xE6DDD7)
//                                      colorWithAlphaComponent:0.8];
    } else {
        headerLabel.text = [[appDelegate.dictFoldersArray objectAtIndex:section] uppercaseString];
//        customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
//                                      colorWithAlphaComponent:0.8];
    }
    
    customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
                                  colorWithAlphaComponent:0.8];
    [customView addSubview:headerLabel];
    
    UIImage *folderImage;
    int folderImageViewX = 10;
    
    if (section == 0) {
        folderImage = [UIImage imageNamed:@"group.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if (section == 1) {
        folderImage = [UIImage imageNamed:@"archive.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else {
        folderImage = [UIImage imageNamed:@"folder_2.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        } else {
            folderImageViewX = 7;
        }
    }
    UIImageView *folderImageView = [[UIImageView alloc] initWithImage:folderImage];
    folderImageView.frame = CGRectMake(folderImageViewX, folderImageViewY, 20, 20);
    [customView addSubview:folderImageView];

    if (!self.hasNoSites) {    
        UIImage *disclosureImage = [UIImage imageNamed:@"disclosure.png"];
        UIImageView *disclosureImageView = [[UIImageView alloc] initWithImage:disclosureImage];
        disclosureImageView.frame = CGRectMake(customView.frame.size.width - 20, disclosureImageViewY, 9.0, 14.0);
        [customView addSubview:disclosureImageView];
    }

    UIButton *invisibleHeaderButton = [UIButton buttonWithType:UIButtonTypeCustom];
    invisibleHeaderButton.frame = CGRectMake(0, 0, customView.frame.size.width, customView.frame.size.height);
    invisibleHeaderButton.alpha = .1;
    invisibleHeaderButton.tag = section;
    [invisibleHeaderButton addTarget:self action:@selector(didSelectSectionHeader:) forControlEvents:UIControlEventTouchUpInside];
    [customView addSubview:invisibleHeaderButton];
    
    [invisibleHeaderButton addTarget:self action:@selector(sectionTapped:) forControlEvents:UIControlEventTouchDown];
    [invisibleHeaderButton addTarget:self action:@selector(sectionUntapped:) forControlEvents:UIControlEventTouchUpInside];
    [invisibleHeaderButton addTarget:self action:@selector(sectionUntappedOutside:) forControlEvents:UIControlEventTouchUpOutside];
    
    [customView setAutoresizingMask:UIViewAutoresizingNone];
    return customView;
}

- (IBAction)sectionTapped:(UIButton *)button {
    button.backgroundColor =[UIColor colorWithRed:0.15 green:0.55 blue:0.95 alpha:1.0];
}

- (IBAction)sectionUntapped:(UIButton *)button {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 1.15 * NSEC_PER_SEC), 
                   dispatch_get_current_queue(), ^{
        button.backgroundColor = [UIColor clearColor];
   });
}

- (IBAction)sectionUntappedOutside:(UIButton *)button {
    button.backgroundColor = [UIColor clearColor];
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
//    NSString *folder = [appDelegate.dictFoldersArray objectAtIndex:section];
//    if ([[folder stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceCharacterSet]] length] == 0) {
//        return 0;
//    }
    
    if ([tableView.dataSource tableView:tableView numberOfRowsInSection:section] == 0 &&
        section != 1) {
        return 0;
    }
    
    return 28;
}

- (void)didSelectSectionHeader:(UIButton *)button {
    // reset pointer to the cells
    self.currentRowAtIndexPath = nil;
    
    appDelegate.readStories = [NSMutableArray array];
    
    NSMutableArray *feeds = [NSMutableArray array];

    if (button.tag == 0) {
        appDelegate.isSocialRiverView = YES;
        appDelegate.isRiverView = YES;
        // add all the feeds from every NON blurblog folder
        [appDelegate setActiveFolder:@"All Blurblog Stories"];
        for (NSString *folderName in self.activeFeedLocations) {
            if ([folderName isEqualToString:@""]) { // remove all blurblugs which is a blank folder name
                NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
                NSArray *folderFeeds = [self.activeFeedLocations objectForKey:folderName];
                for (int l=0; l < [folderFeeds count]; l++) {
                    [feeds addObject:[originalFolder objectAtIndex:[[folderFeeds objectAtIndex:l] intValue]]];
                }
            }
        }
    } else if (button.tag == 1) {
        appDelegate.isSocialRiverView = NO;
        appDelegate.isRiverView = YES;
        // add all the feeds from every NON blurblog folder
        [appDelegate setActiveFolder:@"All Stories"];
        for (NSString *folderName in self.activeFeedLocations) {
            if (![folderName isEqualToString:@""]) { // remove all blurblugs which is a blank folder name
                NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
                NSArray *folderFeeds = [self.activeFeedLocations objectForKey:folderName];
                for (int l=0; l < [folderFeeds count]; l++) {
                    [feeds addObject:[originalFolder objectAtIndex:[[folderFeeds objectAtIndex:l] intValue]]];
                }
            }
        }
    } else {
        appDelegate.isSocialRiverView = NO;
        appDelegate.isRiverView = YES;
        NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:button.tag];
        
        [appDelegate setActiveFolder:folderName];
        NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
        NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
        for (int l=0; l < [activeFolderFeeds count]; l++) {
            [feeds addObject:[originalFolder objectAtIndex:[[activeFolderFeeds objectAtIndex:l] intValue]]];
        }

    }
    appDelegate.activeFolderFeeds = feeds;

    [appDelegate loadRiverFeedDetailView];
}

- (void)changeToAllMode {
    [self.intelligenceControl setSelectedSegmentIndex:0];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];   
    [userPreferences setInteger:-1 forKey:@"selectedIntelligence"];
    [userPreferences synchronize];
}

- (IBAction)selectIntelligence {
    [MBProgressHUD hideHUDForView:self.feedTitlesTable animated:NO];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.innerView animated:YES];
	hud.mode = MBProgressHUDModeText;
	hud.removeFromSuperViewOnHide = YES;
    
    int selectedSegmentIndex = [self.intelligenceControl selectedSegmentIndex];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if (selectedSegmentIndex == 0) {
        hud.labelText = @"All Stories";
        [userPreferences setInteger:-1 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        if (appDelegate.selectedIntelligence != 0) {
            int previousLevel = appDelegate.selectedIntelligence;
            [appDelegate setSelectedIntelligence:0];
            [self updateFeedsWithIntelligence:previousLevel newLevel:0];
            [self redrawUnreadCounts]; 
        }
        self.viewShowingAllFeeds = YES;
        [self switchSitesUnread];
    } else if(selectedSegmentIndex == 1) {
//        NSString *unreadStr = [NSString stringWithFormat:@"%i Unread Stories", appDelegate.allUnreadCount];
        hud.labelText = @"Unread Stories";
        [userPreferences setInteger:0 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        if (appDelegate.selectedIntelligence != 0) {
            int previousLevel = appDelegate.selectedIntelligence;
            [appDelegate setSelectedIntelligence:0];
            [self updateFeedsWithIntelligence:previousLevel newLevel:0];
            [self redrawUnreadCounts];
        }
        self.viewShowingAllFeeds = NO;
        [self switchSitesUnread];
    } else {
        hud.labelText = @"Focus Stories";
        [userPreferences setInteger:1 forKey:@"selectedIntelligence"];
        [userPreferences synchronize];
        
        if (self.viewShowingAllFeeds == YES) {
            self.viewShowingAllFeeds = NO;
            [self switchSitesUnread];
        }
        [appDelegate setSelectedIntelligence:1];
        [self updateFeedsWithIntelligence:0 newLevel:1];
        [self redrawUnreadCounts];
    }
    
	[hud hide:YES afterDelay:0.75];
        
//    [self.feedTitlesTable reloadData];
}

- (void)updateFeedsWithIntelligence:(int)previousLevel newLevel:(int)newLevel {
    NSMutableArray *insertIndexPaths = [NSMutableArray array];
    NSMutableArray *deleteIndexPaths = [NSMutableArray array];
    NSMutableDictionary *addToVisibleFeeds = [NSMutableDictionary dictionary];
    
    if (newLevel <= previousLevel) {
        [self calculateFeedLocations:NO];
    }
    
    for (int s=0; s < [appDelegate.dictFoldersArray count]; s++) {
        NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:s];
        NSArray *activeFolderFeeds = [self.activeFeedLocations objectForKey:folderName];
        NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
        
//        if (s == 9) {
//            NSLog(@"Section %d: %@. %d to %d", s, folderName, previousLevel, newLevel);
//        }
        
        for (int f=0; f < [originalFolder count]; f++) {
            NSNumber *feedId = [originalFolder objectAtIndex:f];
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
            NSDictionary *feed;
            
//            BOOL isUser = [feedIdStr isEqualToString:
//                           [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"id"]]];
            
            if ([appDelegate isSocialFeed:feedIdStr]) {
                feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr]; 
            } else {
                feed = [appDelegate.dictFeeds objectForKey:feedIdStr]; 
            }
            int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
            
//            if (s == 9) {
//                NSLog(@"MaxScore: %d for %@ (%@/%@/%@). Visible: %@", maxScore, 
//                      [feed objectForKey:@"feed_title"],
//                      [feed objectForKey:@"ng"], [feed objectForKey:@"nt"], [feed objectForKey:@"ng"],
//                      [self.visibleFeeds objectForKey:feedIdStr]);
//            }
            
            if ([self.visibleFeeds objectForKey:feedIdStr]) {
                if (maxScore < newLevel) {
                    for (int l=0; l < [activeFolderFeeds count]; l++) {
                        if ([originalFolder objectAtIndex:[[activeFolderFeeds objectAtIndex:l] intValue]] == feedId) {
                            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:l inSection:s];
                            [deleteIndexPaths addObject:indexPath];
                            if ([self.stillVisibleFeeds objectForKey:feedIdStr]) {
                                [self.stillVisibleFeeds removeObjectForKey:feedIdStr];
                            }
                            break;
                        }
                    }
                }
            } else {
                if (maxScore >= newLevel) {
                    for (int l=0; l < [activeFolderFeeds count]; l++) {
                        if ([originalFolder objectAtIndex:[[activeFolderFeeds objectAtIndex:l] intValue]] == feedId) {
                            NSIndexPath *indexPath = [NSIndexPath indexPathForRow:l inSection:s];
                            [addToVisibleFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedIdStr];
                            [insertIndexPaths addObject:indexPath];
                            break;
                        }
                    }
                }
                
            }
        }
    }
    
    for (id feedIdStr in addToVisibleFeeds) {
        [self.visibleFeeds setObject:[addToVisibleFeeds objectForKey:feedIdStr] forKey:feedIdStr];
    }
    
    for (id feedIdStr in [self.stillVisibleFeeds allKeys]) {
        NSDictionary *feed;
        if ([appDelegate isSocialFeed:feedIdStr]) {
            feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr];
        } else {
            feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
        }

        int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
        if (previousLevel != newLevel && maxScore < newLevel) {
            [deleteIndexPaths addObject:[self.stillVisibleFeeds objectForKey:feedIdStr]];
            [self.stillVisibleFeeds removeObjectForKey:feedIdStr];
            [self.visibleFeeds removeObjectForKey:feedIdStr];
        }
    }
    
    if (newLevel > previousLevel) {
        [self calculateFeedLocations:NO];
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
    
    // scrolls to the top and fixes header rendering bug
    CGPoint offsetOne = CGPointMake(0, 1);
    CGPoint offset = CGPointMake(0, 0);
    [self.feedTitlesTable setContentOffset:offsetOne animated:NO];
    [self.feedTitlesTable setContentOffset:offset animated:NO];

    [self calculateFeedLocations:YES];
}

- (void)redrawUnreadCounts {
    for (UITableViewCell *cell in self.feedTitlesTable.visibleCells) {
        [cell setNeedsDisplay];
    }
}

- (void)calculateFeedLocations:(BOOL)markVisible {
    NSDictionary *feed; 
    self.activeFeedLocations = [NSMutableDictionary dictionary];
    if (markVisible) {
        self.visibleFeeds = [NSMutableDictionary dictionary];
    }
    for (NSString *folderName in appDelegate.dictFoldersArray) {
        NSArray *folder = [appDelegate.dictFolders objectForKey:folderName];
        NSMutableArray *feedLocations = [NSMutableArray array];
        for (int f = 0; f < [folder count]; f++) {
            id feedId = [folder objectAtIndex:f];
            NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
            
            if ([folderName isEqualToString:@""]){
                feed = [appDelegate.dictSocialFeeds objectForKey:feedIdStr];
            } else {
                feed = [appDelegate.dictFeeds objectForKey:feedIdStr];
            }      
            
//            BOOL isUser = [[NSString stringWithFormat:@"%@", feedId]
//                           isEqualToString:
//                           [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"id"]]];

            if (self.viewShowingAllFeeds) {
                NSNumber *location = [NSNumber numberWithInt:f];
                [feedLocations addObject:location];
            } else {
                int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
//                if ([folderName isEqualToString:@""]){
//                NSLog(@"Computing score for %@: %d in %d (markVisible: %d)", 
//                        [feed objectForKey:@"feed_title"], maxScore, appDelegate.selectedIntelligence, markVisible);
//                }
                               
                if (maxScore >= appDelegate.selectedIntelligence) {
                    NSNumber *location = [NSNumber numberWithInt:f];
                    [feedLocations addObject:location];
                    if (markVisible) {
                        [self.visibleFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedIdStr];
                    }
                }
            }

        }
        if ([folderName isEqualToString:@""]){
//            NSLog(@"feedLocations count is %i: ", [feedLocations count]);
        }
//            NSLog(@"feedLocations %@", feedLocations);
        [self.activeFeedLocations setObject:feedLocations forKey:folderName];
        
    }
//    NSLog(@"Active feed locations %@", self.activeFeedLocations);
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
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/favicons",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIHTTPRequest  *request = [ASIHTTPRequest  requestWithURL:url];
    
    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)loadAvatars {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (NSString *feed_id in [appDelegate.dictSocialFeeds allKeys]) {
            NSDictionary *feed = [appDelegate.dictSocialFeeds objectForKey:feed_id];
            NSURL *imageURL = [NSURL URLWithString:[feed objectForKey:@"photo_url"]];
            NSData *imageData = [NSData dataWithContentsOfURL:imageURL];
            UIImage *faviconImage = [UIImage imageWithData:imageData];
            
            faviconImage = [Utilities roundCorneredImage:faviconImage radius:6];
            
            [Utilities saveImage:faviconImage feedId:feed_id];
        }
        
        [Utilities saveimagesToDisk];
        
        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.feedTitlesTable reloadData];
        });
    });
}



- (void)saveAndDrawFavicons:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSMutableDictionary *feed = [[appDelegate.dictFeeds objectForKey:feed_id] mutableCopy]; 
            [feed setValue:[results objectForKey:feed_id] forKey:@"favicon"];
            [appDelegate.dictFeeds setValue:feed forKey:feed_id];
            
            NSString *favicon = [feed objectForKey:@"favicon"];
            if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
                NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
                UIImage *faviconImage = [UIImage imageWithData:imageData];
                [Utilities saveImage:faviconImage feedId:feed_id];
            }
        }
        [Utilities saveimagesToDisk];

        dispatch_sync(dispatch_get_main_queue(), ^{
            [self.feedTitlesTable reloadData];
        });
    });
    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark PullToRefresh

// called when the user pulls-to-refresh
- (void)pullToRefreshViewShouldRefresh:(PullToRefreshView *)view {
    [self fetchFeedList:NO];
}


- (void)refreshFeedList {
    // refresh the feed
    NSURL *urlFeedList = [NSURL URLWithString:
                          [NSString stringWithFormat:@"http://%@/reader/refresh_feeds",
                           NEWSBLUR_URL]];
    
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:urlFeedList];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    [request setDelegate:self];
    [request setResponseEncoding:NSUTF8StringEncoding];
    [request setDefaultResponseEncoding:NSUTF8StringEncoding];
    [request setDidFinishSelector:@selector(finishRefreshingFeedList:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}

- (void)finishRefreshingFeedList:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] == 403) {
        return [appDelegate showLogin];
    } else if ([request responseStatusCode] >= 500) {
        [pull finishedLoading];
        return [self informError:@"The server barfed!"];
    }
    
    NSString *responseString = [request responseString];   
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    
    NSMutableDictionary *updatedDictFeeds = [appDelegate.dictFeeds mutableCopy];    
    NSDictionary *newFeedCounts = [results objectForKey:@"feeds"];
    for (id feed in newFeedCounts) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", feed];
        NSMutableDictionary *newFeed = [[appDelegate.dictFeeds objectForKey:feedIdStr] mutableCopy];
        NSMutableDictionary *newFeedCount = [newFeedCounts objectForKey:feed];

        if ([newFeed isKindOfClass:[NSDictionary class]]) {
            
            [newFeed setObject:[newFeedCount objectForKey:@"ng"] forKey:@"ng"];
            [newFeed setObject:[newFeedCount objectForKey:@"nt"] forKey:@"nt"];
            [newFeed setObject:[newFeedCount objectForKey:@"ps"] forKey:@"ps"];
            [updatedDictFeeds setObject:newFeed forKey:feedIdStr];
        }
    }
    
    NSMutableDictionary *updatedDictSocialFeeds = [appDelegate.dictSocialFeeds mutableCopy]; 
    NSDictionary *newSocialFeedCounts = [results objectForKey:@"social_feeds"];
    for (id feed in newSocialFeedCounts) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", feed];
        NSMutableDictionary *newFeed = [[appDelegate.dictSocialFeeds objectForKey:feedIdStr] mutableCopy];
        NSMutableDictionary *newFeedCount = [newSocialFeedCounts objectForKey:feed];

        if ([newFeed isKindOfClass:[NSDictionary class]]) {
            [newFeed setObject:[newFeedCount objectForKey:@"ng"] forKey:@"ng"];
            [newFeed setObject:[newFeedCount objectForKey:@"nt"] forKey:@"nt"];
            [newFeed setObject:[newFeedCount objectForKey:@"ps"] forKey:@"ps"];
            [updatedDictSocialFeeds setObject:newFeed forKey:feedIdStr];
        }
    }

    appDelegate.dictSocialFeeds = updatedDictSocialFeeds;
    appDelegate.dictFeeds = updatedDictFeeds;
    [self.feedTitlesTable reloadData];
}

// called when the date shown needs to be updated, optional
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view {
    return self.lastUpdate;
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


/**
 Thanks to Paul Solt for supplying these background images and container view properties
 */
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

- (void)resetToolbar {
    self.navigationItem.leftBarButtonItem = nil;
    self.navigationItem.titleView = nil;
    self.navigationItem.rightBarButtonItem = nil;
}


@end