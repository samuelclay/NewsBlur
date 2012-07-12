//
//  NewsBlurViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurViewController.h"
#import "NewsBlurAppDelegate.h"
#import "DashboardViewController.h"
#import "FeedTableCell.h"
#import "FeedsMenuViewController.h"
#import "UserProfileViewController.h"
#import "ASIHTTPRequest.h"
#import "PullToRefreshView.h"
#import "MBProgressHUD.h"
#import "Base64.h"
#import "JSON.h"
#import "Utilities.h"


#define kTableViewRowHeight 40;
#define kBlurblogTableViewRowHeight 46;

@implementation NewsBlurViewController

@synthesize appDelegate;

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

#pragma mark -
#pragma mark Globals

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
        [appDelegate hideNavigationBar:NO];
    }
    return self;
}

- (void)viewDidLoad {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences integerForKey:@"siteDisplayMode"] == 0) {
        NSLog(@"Show ALL stories");
        self.viewShowingAllFeeds = YES;
        [self.intelligenceControl setSelectedSegmentIndex:0];
    } else if ([userPreferences integerForKey:@"siteDisplayMode"] == 1) {
        NSLog(@"Show UNREAD stories");
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:1];
    } else {
        NSLog(@"Show FOCUS stories");
        self.viewShowingAllFeeds = NO;
        [self.intelligenceControl setSelectedSegmentIndex:2];
        [appDelegate setSelectedIntelligence:1];
    }
    
    [appDelegate showNavigationBar:NO];
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

    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    // If there is an active feed or a set of feeds readin the river, 
    // we need to update its table row to match the updated unread counts.
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

    [self.intelligenceControl setImage:[UIImage imageNamed:@"16-List.png"] 
                     forSegmentAtIndex:0];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"unread_color.png"] 
                     forSegmentAtIndex:1];
    [self.intelligenceControl setImage:[UIImage imageNamed:@"focused_color.png"] 
                     forSegmentAtIndex:2];
    [self.intelligenceControl addTarget:self
                                 action:@selector(selectIntelligence)
                       forControlEvents:UIControlEventValueChanged];

    [appDelegate showNavigationBar:animated];
    
    [self.feedTitlesTable selectRowAtIndexPath:[feedTitlesTable indexPathForSelectedRow] 
                                      animated:YES scrollPosition:UITableViewScrollPositionMiddle];
    
    [appDelegate showDashboard];
}

- (void)viewDidAppear:(BOOL)animated {
//    appDelegate.activeFeed = nil; 
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated {
    //[appDelegate showNavigationBar:YES];
    [self dismissFeedsMenu];
    [super viewWillDisappear:animated];
}

- (void)dismissFeedsMenu {
    if (popoverController.isPopoverVisible) {
        [popoverController dismissPopoverAnimated:NO];
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}

- (void)willAnimateRotationToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration {
    /* When MGSplitViewController rotates, it causes a resize of our view; we need to resize our UIBarButtonControls or they will be 0-width */    
    [self.navigationItem.titleView sizeToFit];
    UIButton *avatar = (UIButton *)self.navigationItem.leftBarButtonItem.customView; 
    CGRect buttonFrame = avatar.frame;
    buttonFrame.size = CGSizeMake(32, 32);
    avatar.frame = buttonFrame;
}

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
    [appDelegate release];
    
    [feedTitlesTable release];
    [feedViewToolbar release];
    [feedScoreSlider release];
    [homeButton release];
    [intelligenceControl release];
    [activeFeedLocations release];
    [visibleFeeds release];
    [stillVisibleFeeds release];
    [pull release];
    [lastUpdate release];
    [imageCache release];
    [popoverController release];
    
    [super dealloc];
}

#pragma mark -
#pragma mark Initialization

- (void)returnToApp {
    NSDate *decayDate = [[NSDate alloc] initWithTimeIntervalSinceNow:(BACKGROUND_REFRESH_SECONDS)];
    NSLog(@"Last Update: %@ - %f", self.lastUpdate, [self.lastUpdate timeIntervalSinceDate:decayDate]);
    if ([self.lastUpdate timeIntervalSinceDate:decayDate] < 0) {
        [self fetchFeedList:YES refreshFeeds:YES];
    }
    [decayDate release];
    
}

-(void)fetchFeedList:(BOOL)showLoader refreshFeeds:(BOOL)refreshFeeds {
    if (showLoader && appDelegate.navigationController.topViewController == appDelegate.feedsViewController) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
        HUD.labelText = @"On its way...";
    }
    
    if (refreshFeeds) {
        [self refreshFeedList];
        return;
    }

    NSURL *urlFeedList = [NSURL URLWithString:
                          [NSString stringWithFormat:@"http://%@/reader/feeds?flat=true",
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
    
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];

    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    self.stillVisibleFeeds = [NSMutableDictionary dictionary];
    self.visibleFeeds = [NSMutableDictionary dictionary];
    [pull finishedLoading];
    [self loadFavicons];

    appDelegate.activeUsername = [results objectForKey:@"user"];
    //if (appDelegate.feedsViewController.view.window) {
        [appDelegate setTitle:[results objectForKey:@"user"]];
    //}
    

    // adding user avatar to left
    NSString *url = [NSString stringWithFormat:@"%@", [[results objectForKey:@"social_profile"] objectForKey:@"photo_url"]];
    NSURL * imageURL = [NSURL URLWithString:url];
    NSData * imageData = [NSData dataWithContentsOfURL:imageURL];
    UIImage * userAvatarImage = [UIImage imageWithData:imageData];
    userAvatarImage = [Utilities roundCorneredImage:userAvatarImage radius:6];
    
    UIButton *userAvatarButton = [UIButton buttonWithType:UIButtonTypeCustom];
    userAvatarButton.bounds = CGRectMake(0, 0, 32, 32);
    [userAvatarButton addTarget:self action:@selector(showUserProfilePopover:) forControlEvents:UIControlEventTouchUpInside];
    [userAvatarButton setImage:userAvatarImage forState:UIControlStateNormal];

    UIBarButtonItem *userAvatar = [[UIBarButtonItem alloc] 
                                   initWithCustomView:userAvatarButton];
    
    self.navigationItem.leftBarButtonItem = userAvatar;
    [userAvatar release];
    
    // adding settings button to right
    
//    UIBarButtonItem *settingsButton = [[UIBarButtonItem alloc] init];
//
//    settingsButton.title = @"\u2699"; 
//    UIFont *f1 = [UIFont fontWithName:@"Helvetica" size:24.0]; 
//    NSDictionary *dict = [[NSDictionary alloc] initWithObjectsAndKeys:f1, UITextAttributeFont, nil]; 
//    [settingsButton setTitleTextAttributes:dict forState:UIControlStateNormal]; 
//    
//    self.navigationItem.rightBarButtonItem = settingsButton;
//    [settingsButton release];
        
    NSMutableDictionary *sortedFolders = [[NSMutableDictionary alloc] init];
    NSArray *sortedArray;
    
    // Set up dictUserProfile and dictUserActivities
    appDelegate.dictUserProfile = [results objectForKey:@"social_profile"];
    appDelegate.dictUserActivities = [results objectForKey:@"activities"];
    [appDelegate.dashboardViewController refreshInteractions];
    [appDelegate.dashboardViewController refreshActivity];

    // Set up dictSocialFeeds
    NSArray *socialFeedsArray = [results objectForKey:@"social_feeds"];
    NSMutableArray *socialFolder = [[NSMutableArray alloc] init];
    NSMutableDictionary *socialDict = [[NSMutableDictionary alloc] init];
    appDelegate.dictActiveFeeds = [[NSMutableDictionary alloc] init];
    
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
    NSMutableDictionary * allFolders = [results objectForKey:@"flat_folders"];
    [allFolders setValue:socialFolder forKey:@""]; 
    appDelegate.dictFolders = allFolders;
    
    // set up dictFeeds
    appDelegate.dictFeeds = [results objectForKey:@"feeds"];

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
    [self.feedTitlesTable reloadData];

    
//    NSLog(@"appDelegate.dictFolders: %@", appDelegate.dictFolders);
//    NSLog(@"appDelegate.dictFoldersArray: %@", appDelegate.dictFoldersArray);
    
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
        [upgradeConfirm release];
    }
    
    [sortedFolders release];
    [results release];
}

- (void)showUserProfilePopover:(id)sender {
    appDelegate.activeUserProfileId = [NSString stringWithFormat:@"%@", [appDelegate.dictUserProfile objectForKey:@"user_id"]];

    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (popoverController == nil) {
            popoverController = [[UIPopoverController alloc]
                                 initWithContentViewController:appDelegate.userProfileViewController];
            
            popoverController.delegate = self;
        } else {
            [popoverController setContentViewController:appDelegate.userProfileViewController];
        }
        

        
        [popoverController setPopoverContentSize:CGSizeMake(320, 400)];
        [popoverController presentPopoverFromBarButtonItem:self.navigationItem.leftBarButtonItem 
                                  permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                  animated:YES];  
    } else {
        NSLog(@"Implement for iPhone!");
    }

}

- (IBAction)showMenuButton:(id)sender {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        if (popoverController == nil) {
            popoverController = [[UIPopoverController alloc]
                                 initWithContentViewController:appDelegate.feedsMenuViewController];
            
            popoverController.delegate = self;
        } else {
            [popoverController setContentViewController:appDelegate.feedsMenuViewController];
        }
        
        [popoverController setPopoverContentSize:CGSizeMake(200, 86)];
        [popoverController presentPopoverFromBarButtonItem:sender
                                  permittedArrowDirections:UIPopoverArrowDirectionAny 
                                                  animated:YES];  
    } else {
        [appDelegate showFeedsMenu]; 
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
            
            if (!self.viewShowingAllFeeds ||
                (self.viewShowingAllFeeds && ![self.stillVisibleFeeds objectForKey:feedIdStr])) {
                if (maxScore < intelligenceLevel) {
                    [indexPaths addObject:indexPath];
                }
            }
        }
    }
    
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
    return [appDelegate.dictFoldersArray count];
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    return [appDelegate.dictFoldersArray objectAtIndex:section];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    return [[self.activeFeedLocations objectForKey:folderName] count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
                     cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *feed;
    static NSString *FeedCellIdentifier = @"FeedCellIdentifier";
    
    FeedTableCell *cell = (FeedTableCell *)[tableView dequeueReusableCellWithIdentifier:FeedCellIdentifier];    
    if (cell == nil) {
        cell = [[[FeedTableCell alloc] initWithStyle:UITableViewCellStyleDefault  reuseIdentifier:@"FeedCellIdentifier"] autorelease];
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
        cell.feedFavicon = [Utilities getImage:feedIdStr];
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
        
    [appDelegate loadFeedDetailView];
}

- (CGFloat)tableView:(UITableView *)tableView 
           heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    NSString *folderName = [appDelegate.dictFoldersArray objectAtIndex:indexPath.section];
    
    if ([folderName isEqualToString:@""]) { // blurblogs
        return kBlurblogTableViewRowHeight;
    } else {
        return kTableViewRowHeight;
    }
}

- (UIView *)tableView:(UITableView *)tableView 
            viewForHeaderInSection:(NSInteger)section {
    
    int headerLabelHeight, folderImageViewY, disclosureImageViewY;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        headerLabelHeight = 24;
        folderImageViewY = 4;
        disclosureImageViewY = 5;
    } else {
        headerLabelHeight = 20;
        folderImageViewY = 2;
        disclosureImageViewY = 3;
    }
        
    // create the parent view that will hold header Label
    UIControl* customView = [[[UIControl alloc] 
                              initWithFrame:CGRectMake(0.0, 0.0, 
                                                       tableView.bounds.size.width, headerLabelHeight + 1)] 
                             autorelease];
    
    
    UIView *borderBottom = [[[UIView alloc] 
                             initWithFrame:CGRectMake(0.0, headerLabelHeight, 
                                                      tableView.bounds.size.width, 1.0)]
                            autorelease];
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
        headerLabel.text = @"BLURBLOGS";
        customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
                                      colorWithAlphaComponent:0.8];
    } else if (section == 1) {
        headerLabel.text = @"EVERYTHING";
        customView.backgroundColor = [UIColorFromRGB(0xE6DDD7)
                                      colorWithAlphaComponent:0.8];
    } else {
        headerLabel.text = [[appDelegate.dictFoldersArray objectAtIndex:section] uppercaseString];
        customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
                                      colorWithAlphaComponent:0.8];
    }
    [customView addSubview:headerLabel];
    [headerLabel release];
    
    UIImage *folderImage = [UIImage imageNamed:@"folder.png"];
    UIImageView *folderImageView = [[UIImageView alloc] initWithImage:folderImage];
    folderImageView.frame = CGRectMake(12.0, folderImageViewY, 16.0, 16.0);
    [customView addSubview:folderImageView];
    [folderImageView release];

    if (section != 0) {    
        UIImage *disclosureImage = [UIImage imageNamed:@"disclosure.png"];
        UIImageView *disclosureImageView = [[UIImageView alloc] initWithImage:disclosureImage];
        disclosureImageView.frame = CGRectMake(customView.frame.size.width - 20, disclosureImageViewY, 9.0, 14.0);
        [customView addSubview:disclosureImageView];
        [disclosureImageView release];
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
    // current position of social header
    if (button.tag == 0) { 
        return;
    }
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
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad){
        return 25;
    }else{
        return 21;
    }
}

- (void)didSelectSectionHeader:(UIButton *)button {
    // current position of social header
    if (button.tag == 0) { 
        return;
    }
    
    appDelegate.readStories = [NSMutableArray array];
    appDelegate.isRiverView = YES;
    NSMutableArray *feeds = [NSMutableArray array];

    if (button.tag == 0) {
        [appDelegate setActiveFolder:@"Everything"];
        for (NSString *folderName in self.activeFeedLocations) {
            NSArray *originalFolder = [appDelegate.dictFolders objectForKey:folderName];
            NSArray *folderFeeds = [self.activeFeedLocations objectForKey:folderName];
            for (int l=0; l < [folderFeeds count]; l++) {
                [feeds addObject:[originalFolder objectAtIndex:[[folderFeeds objectAtIndex:l] intValue]]];
            }
        }
    } else {
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

- (IBAction)selectIntelligence {
    [MBProgressHUD hideHUDForView:self.feedTitlesTable animated:NO];
    MBProgressHUD *hud = [MBProgressHUD showHUDAddedTo:self.feedTitlesTable animated:YES];
    
	hud.mode = MBProgressHUDModeText;
	hud.removeFromSuperViewOnHide = YES;
    
    int selectedSegmentIndex = [self.intelligenceControl selectedSegmentIndex];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];    
    if (selectedSegmentIndex == 0) {
        hud.labelText = @"All stories";
        [userPreferences setInteger:0 forKey:@"siteDisplayMode"];
        [userPreferences synchronize];
        
        if (appDelegate.selectedIntelligence == 1) {
            [appDelegate setSelectedIntelligence:0];
            [self updateFeedsWithIntelligence:1 newLevel:0];
            [self redrawUnreadCounts]; 
        }
        self.viewShowingAllFeeds = YES;
        [self switchSitesUnread];
    } else if(selectedSegmentIndex == 1) {
        hud.labelText = @"Unread stories";
        [userPreferences setInteger:1 forKey:@"siteDisplayMode"];
        [userPreferences synchronize];
        
        if (appDelegate.selectedIntelligence == 1) {
            [appDelegate setSelectedIntelligence:0];
            [self updateFeedsWithIntelligence:1 newLevel:0];
            [self redrawUnreadCounts];
        }
        self.viewShowingAllFeeds = NO;
        [self switchSitesUnread];
    } else {
        hud.labelText = @"Focus stories";
        [userPreferences setInteger:2 forKey:@"siteDisplayMode"];
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

    [self calculateFeedLocations:YES];
}

- (void)redrawUnreadCounts {
    for (UITableViewCell *cell in self.feedTitlesTable.visibleCells) {
        [cell setNeedsDisplay];
    }
}

- (void)calculateFeedLocations:(BOOL)markVisible {
    NSDictionary *feed = [[NSDictionary alloc] init]; 
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

            if (self.viewShowingAllFeeds) {
                NSNumber *location = [NSNumber numberWithInt:f];
                [feedLocations addObject:location];
            } else {
                int maxScore = [NewsBlurViewController computeMaxScoreForFeed:feed];
//                NSLog(@"Computing score for %@: %d in %d (markVisible: %d)", 
//                        [feed objectForKey:@"feed_title"], maxScore, appDelegate.selectedIntelligence, markVisible);
                if (maxScore >= appDelegate.selectedIntelligence) {
                    NSNumber *location = [NSNumber numberWithInt:f];
                    [feedLocations addObject:location];
                    if (markVisible) {
                        [self.visibleFeeds setObject:[NSNumber numberWithBool:YES] forKey:feedIdStr];
                    }
                }
            }
        }
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
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    
    [request setDidFinishSelector:@selector(saveAndDrawFavicons:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setDelegate:self];
    [request startAsynchronous];
}

- (void)loadAvatars {
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in appDelegate.dictSocialFeeds) {
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
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^{
        for (id feed_id in results) {
            NSDictionary *feed = [appDelegate.dictFeeds objectForKey:feed_id];
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
            [results release];
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
    [self refreshFeedList];
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
    [self fetchFeedList:NO refreshFeeds:NO];
}

// called when the date shown needs to be updated, optional
- (NSDate *)pullToRefreshViewLastUpdated:(PullToRefreshView *)view {
    return self.lastUpdate;
}

@end