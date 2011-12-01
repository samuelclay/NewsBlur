//
//  NewsBlurAppDelegate.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "FeedDetailViewController.h"
#import "StoryDetailViewController.h"
#import "LoginViewController.h"
#import "AddViewController.h"
#import "OriginalStoryViewController.h"
#import "MBProgressHUD.h"
#import "Utilities.h"

@implementation NewsBlurAppDelegate

@synthesize window;
@synthesize navigationController;
@synthesize feedsViewController;
@synthesize feedDetailViewController;
@synthesize storyDetailViewController;
@synthesize loginViewController;
@synthesize addViewController;
@synthesize originalStoryViewController;

@synthesize activeUsername;
@synthesize isRiverView;
@synthesize activeFeed;
@synthesize activeFolder;
@synthesize activeFolderFeeds;
@synthesize activeFeedStories;
@synthesize activeFeedStoryLocations;
@synthesize activeFeedStoryLocationIds;
@synthesize activeStory;
@synthesize storyCount;
@synthesize visibleUnreadCount;
@synthesize originalStoryCount;
@synthesize selectedIntelligence;
@synthesize activeOriginalStoryURL;
@synthesize recentlyReadStories;
@synthesize recentlyReadFeeds;
@synthesize readStories;

@synthesize dictFolders;
@synthesize dictFeeds;
@synthesize dictFoldersArray;

- (BOOL)application:(UIApplication *)application didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {    
    
//    [TestFlight takeOff:@"101dd20fb90f7355703b131d9af42633_MjQ0NTgyMDExLTA4LTIxIDIzOjU3OjEzLjM5MDcyOA"];
    [ASIHTTPRequest setDefaultUserAgentString:@"NewsBlur iPhone App v1.0"];
    
    navigationController.viewControllers = [NSArray arrayWithObject:feedsViewController];
    [window addSubview:navigationController.view];
    [window makeKeyAndVisible];
    
    [feedsViewController fetchFeedList:YES];
    
	return YES;
}

- (void)viewDidLoad {
    self.selectedIntelligence = 1;
    self.visibleUnreadCount = 0;
    [self setRecentlyReadStories:[NSMutableArray array]];
}

- (void)dealloc {
    NSLog(@"Dealloc on AppDelegate");
    [feedsViewController release];
    [feedDetailViewController release];
    [storyDetailViewController release];
    [loginViewController release];
    [addViewController release];
    [originalStoryViewController release];
    [navigationController release];
    [window release];
    [activeUsername release];
    [activeFeed release];
    [activeFolder release];
    [activeFeedStories release];
    [activeFeedStoryLocations release];
    [activeFeedStoryLocationIds release];
    [activeStory release];
    [activeOriginalStoryURL release];
    [recentlyReadStories release];
    [recentlyReadFeeds release];
    [readStories release];
    
    [dictFolders release];
    [dictFeeds release];
    [dictFoldersArray release];
    
    [super dealloc];
}

- (void)hideNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:YES animated:animated];
}

- (void)showNavigationBar:(BOOL)animated {
    [[self navigationController] setNavigationBarHidden:NO animated:animated];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

#pragma mark -
#pragma mark Views

- (void)showLogin {
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:loginViewController animated:YES];
}

- (void)showAdd {
    UINavigationController *navController = self.navigationController;
    [addViewController initWithNibName:nil bundle:nil];
    [navController presentModalViewController:addViewController animated:YES];
    [addViewController reload];
}

- (void)reloadFeedsView {
    [self setTitle:@"NewsBlur"];
    [feedsViewController fetchFeedList:YES];
    [loginViewController dismissModalViewControllerAnimated:YES];
    self.navigationController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)loadFeedDetailView {
    UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle: @"All" style: UIBarButtonItemStyleBordered target: nil action: nil];
    [feedsViewController.navigationItem setBackBarButtonItem: newBackButton];
    [newBackButton release];
    UINavigationController *navController = self.navigationController;
    [self setStories:nil];
    [navController pushViewController:feedDetailViewController animated:YES];
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchFeedDetail:1 withCallback:nil];
    [self showNavigationBar:YES];
    navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    //    navController.navigationBar.tintColor = UIColorFromRGB(0x59f6c1);
}

- (void)loadRiverFeedDetailView {
    UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle: @"All" style: UIBarButtonItemStyleBordered target: nil action: nil];
    [feedsViewController.navigationItem setBackBarButtonItem: newBackButton];
    [newBackButton release];
    UINavigationController *navController = self.navigationController;
    [self setStories:nil];
    [navController pushViewController:feedDetailViewController animated:YES];
    [feedDetailViewController resetFeedDetail];
    [feedDetailViewController fetchRiverPage:1 withCallback:nil];
    [self showNavigationBar:YES];
    navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    //    navController.navigationBar.tintColor = UIColorFromRGB(0x59f6c1);
}

- (void)loadStoryDetailView {
    NSString *feedTitle;
    if (self.isRiverView) {
        feedTitle = self.activeFolder;
    } else {
        feedTitle = [activeFeed objectForKey:@"feed_title"];
    }
    UIBarButtonItem *newBackButton = [[UIBarButtonItem alloc] initWithTitle:feedTitle style: UIBarButtonItemStyleBordered target: nil action: nil];
    [feedDetailViewController.navigationItem setBackBarButtonItem: newBackButton];
    [newBackButton release];
    UINavigationController *navController = self.navigationController;   
    [navController pushViewController:storyDetailViewController animated:YES];
    [navController.navigationItem setLeftBarButtonItem:[[[UIBarButtonItem alloc] initWithTitle:feedTitle style:UIBarButtonItemStyleBordered target:nil action:nil] autorelease]];
    navController.navigationItem.hidesBackButton = YES;
    navController.navigationBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
}

- (void)navigationController:(UINavigationController *)navController 
      willShowViewController:(UIViewController *)viewController animated:(BOOL)animated {
    if (viewController == feedDetailViewController) {
        UIView *backButtonView = [[UIView alloc] initWithFrame:CGRectMake(0,0,70,35)];
        UIButton *myBackButton = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
        [myBackButton setFrame:CGRectMake(0,0,70,35)];
        [myBackButton setImage:[UIImage imageNamed:@"toolbar_back_button.png"] forState:UIControlStateNormal];
        [myBackButton setEnabled:YES];
        [myBackButton addTarget:viewController.navigationController action:@selector(popViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
        [backButtonView addSubview:myBackButton];
        [myBackButton release];
        UIBarButtonItem* backButton = [[UIBarButtonItem alloc] initWithCustomView:backButtonView];
        viewController.navigationItem.leftBarButtonItem = backButton;
        navController.navigationItem.leftBarButtonItem = backButton;
        viewController.navigationItem.hidesBackButton = YES;
        navController.navigationItem.hidesBackButton = YES;
        
        [backButtonView release];
        [backButton release];
    }
}

- (void)setTitle:(NSString *)title {
    UILabel *label = [[UILabel alloc] init];
    [label setFont:[UIFont boldSystemFontOfSize:16.0]];
    [label setBackgroundColor:[UIColor clearColor]];
    [label setTextColor:[UIColor whiteColor]];
    [label setText:title];
    [label sizeToFit];
    [navigationController.navigationBar.topItem setTitleView:label];
    [label release];
}

- (void)showOriginalStory:(NSURL *)url {
    self.activeOriginalStoryURL = url;
    UINavigationController *navController = self.navigationController;
    [navController presentModalViewController:originalStoryViewController animated:YES];
}

- (void)closeOriginalStory {
    [originalStoryViewController dismissModalViewControllerAnimated:YES];
}

- (int)indexOfNextStory {
    int activeLocation = [self locationOfActiveStory];
//    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    int readStatus = -1;
//    NSLog(@"ActiveStory: %d (%d)/%d", activeLocation, activeIndex, self.storyCount);
    for (int i=activeLocation+1; i < [self.activeFeedStoryLocations count]; i++) {
        int location = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
        NSDictionary *story = [activeFeedStories objectAtIndex:location];
        readStatus = [[story objectForKey:@"read_status"] intValue];
//        NSLog(@"+1 readStatus at %d (%d): %d", location, i, readStatus);
        if (readStatus == 0) {
//            NSLog(@"NextStory after: %d", i);
            return location;
        }
    }
    if (activeLocation > 0) {
        for (int i=activeLocation-1; i >= 0; i--) {
            int location = [[self.activeFeedStoryLocations objectAtIndex:i] intValue];
            NSDictionary *story = [activeFeedStories objectAtIndex:location];
            readStatus = [[story objectForKey:@"read_status"] intValue];
//            NSLog(@"-1 readStatus at %d (%d): %d", location, i, readStatus);
            if (readStatus == 0) {
//                NSLog(@"NextStory before: %d", i);
                return location;
            }
        }
    }
    return -1;
}

- (int)indexOfPreviousStory {
    NSInteger activeIndex = [self indexOfActiveStory];
    return MAX(-1, activeIndex-1);
}

- (int)indexOfActiveStory {
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [activeFeedStories objectAtIndex:i];
        if ([activeStory objectForKey:@"id"] == [story objectForKey:@"id"]) {
            return i;
        }
    }
    return -1;
}

- (int)locationOfActiveStory {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == 
            [self.activeStory objectForKey:@"id"]) {
            return i;
        }
    }
    return -1;
}

- (void)pushReadStory:(id)storyId {
    if ([self.readStories lastObject] != storyId) {
        [self.readStories addObject:storyId];
    }
}

- (id)popReadStory {
    if (storyCount == 0) {
        return nil;
    } else {
        [self.readStories removeLastObject];
        id lastStory = [self.readStories lastObject];
        return lastStory;
    }
}

- (int)locationOfStoryId:(id)storyId {
    for (int i=0; i < [activeFeedStoryLocations count]; i++) {
        if ([activeFeedStoryLocationIds objectAtIndex:i] == storyId) {
            return [[activeFeedStoryLocations objectAtIndex:i] intValue];
        }
    }
    return -1;
}

- (int)unreadCount {
    if (self.isRiverView) {
        return [self unreadCountForFolder:nil];
    } else { 
        return [self unreadCountForFeed:nil];
    }
}

- (int)unreadCountForFeed:(NSString *)feedId {
    int total = 0;
    NSDictionary *feed;

    if (feedId) {
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
        feed = [self.dictFeeds objectForKey:feedIdStr];
    } else {
        feed = self.activeFeed;
    }
    
    total += [[feed objectForKey:@"ps"] intValue];
    if ([self selectedIntelligence] <= 0) {
        total += [[feed objectForKey:@"nt"] intValue];
    }
    if ([self selectedIntelligence] <= -1) {
        total += [[feed objectForKey:@"ng"] intValue];
    }
    
    return total;
}

- (int)unreadCountForFolder:(NSString *)folderName {
    int total = 0;
    NSArray *folder;
    
    if (!folderName) {
        folder = [self.dictFolders objectForKey:self.activeFolder];
    } else {
        folder = [self.dictFolders objectForKey:folderName];
    }
    
    for (id feedId in folder) {
        total += [self unreadCountForFeed:feedId];
    }
    
    return total;
}

- (void)addStories:(NSArray *)stories {
    self.activeFeedStories = [self.activeFeedStories arrayByAddingObjectsFromArray:stories];
    self.storyCount = [self.activeFeedStories count];
    [self calculateStoryLocations];
}

- (void)setStories:(NSArray *)activeFeedStoriesValue {
    self.activeFeedStories = activeFeedStoriesValue;
    self.storyCount = [self.activeFeedStories count];
    self.recentlyReadStories = [NSMutableArray array];
    self.recentlyReadFeeds = [NSMutableSet set];
    [self calculateStoryLocations];
}

- (void)markActiveStoryRead {
    int activeLocation = [self locationOfActiveStory];
    if (activeLocation == -1) {
        return;
    }
    id feedId = [self.activeStory objectForKey:@"story_feed_id"];
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    int activeIndex = [[activeFeedStoryLocations objectAtIndex:activeLocation] intValue];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    NSDictionary *story = [activeFeedStories objectAtIndex:activeIndex];
    if (self.activeFeed != feed) {
//        NSLog(@"activeFeed; %@, feed: %@", activeFeed, feed);
        self.activeFeed = feed;
    }
    
    [self.recentlyReadStories addObject:[NSNumber numberWithInt:activeLocation]];
    [self markStoryRead:story feed:feed];
//    NSLog(@"Marked read %d-%d: %@: %d", activeIndex, activeLocation, self.recentlyReadStories, score);
}

- (NSDictionary *)markVisibleStoriesRead {
    NSMutableDictionary *feedsStories = [NSMutableDictionary dictionary];
    for (NSDictionary *story in self.activeFeedStories) {
        if ([[story objectForKey:@"read_status"] intValue] != 0) {
            continue;
        }
        NSString *feedIdStr = [NSString stringWithFormat:@"%@",[story objectForKey:@"story_feed_id"]];
        NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
        if (![feedsStories objectForKey:feedIdStr]) {
            [feedsStories setObject:[NSMutableArray array] forKey:feedIdStr];
        }
        NSMutableArray *stories = [feedsStories objectForKey:feedIdStr];
        [stories addObject:[story objectForKey:@"id"]];
        [self markStoryRead:story feed:feed];
    }   
    NSLog(@"feedsStories: %@", feedsStories);
    return feedsStories;
}

- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    NSDictionary *story = nil;
    for (NSDictionary *s in self.activeFeedStories) {
        if ([[s objectForKey:@"story_guid"] isEqualToString:storyId]) {
            story = s;
            break;
        }
    }
    [self markStoryRead:story feed:feed];
}

- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
    [story setValue:[NSNumber numberWithInt:1] forKey:@"read_status"];
    self.visibleUnreadCount -= 1;
    if (![self.recentlyReadFeeds containsObject:[story objectForKey:@"story_feed_id"]]) {
        [self.recentlyReadFeeds addObject:[story objectForKey:@"story_feed_id"]];
    }
    int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
    if (score > 0) {
        int unreads = MAX(0, [[feed objectForKey:@"ps"] intValue] - 1);
        [feed setValue:[NSNumber numberWithInt:unreads] forKey:@"ps"];
    } else if (score == 0) {
        int unreads = MAX(0, [[feed objectForKey:@"nt"] intValue] - 1);
        [feed setValue:[NSNumber numberWithInt:unreads] forKey:@"nt"];
    } else if (score < 0) {
        int unreads = MAX(0, [[feed objectForKey:@"ng"] intValue] - 1);
        [feed setValue:[NSNumber numberWithInt:unreads] forKey:@"ng"];
    }
    [self.dictFeeds setValue:feed forKey:feedIdStr];

}

- (void)markActiveFeedAllRead {    
    id feedId = [self.activeFeed objectForKey:@"id"];
    [self markFeedAllRead:feedId];
}

- (void)markActiveFolderAllRead {    
    for (id feedId in [self.dictFolders objectForKey:self.activeFolder]) {
        [self markFeedAllRead:feedId];
    }
}

- (void)markFeedAllRead:(id)feedId {
    NSString *feedIdStr = [NSString stringWithFormat:@"%@",feedId];
    NSDictionary *feed = [self.dictFeeds objectForKey:feedIdStr];
    
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"ps"];
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"nt"];
    [feed setValue:[NSNumber numberWithInt:0] forKey:@"ng"];
    [self.dictFeeds setValue:feed forKey:feedIdStr];    
}

- (void)calculateStoryLocations {
    self.visibleUnreadCount = 0;
    self.activeFeedStoryLocations = [NSMutableArray array];
    self.activeFeedStoryLocationIds = [NSMutableArray array];
    for (int i=0; i < self.storyCount; i++) {
        NSDictionary *story = [self.activeFeedStories objectAtIndex:i];
        int score = [NewsBlurAppDelegate computeStoryScore:[story objectForKey:@"intelligence"]];
        if (score >= self.selectedIntelligence) {
            NSNumber *location = [NSNumber numberWithInt:i];
            [self.activeFeedStoryLocations addObject:location];
            [self.activeFeedStoryLocationIds addObject:[story objectForKey:@"id"]];
            if ([[story objectForKey:@"read_status"] intValue] == 0) {
                self.visibleUnreadCount += 1;
            }
        }
    }
}

+ (int)computeStoryScore:(NSDictionary *)intelligence {
    int score = 0;
    int title = [[intelligence objectForKey:@"title"] intValue];
    int author = [[intelligence objectForKey:@"author"] intValue];
    int tags = [[intelligence objectForKey:@"tags"] intValue];

    int score_max = MAX(title, MAX(author, tags));
    int score_min = MIN(title, MIN(author, tags));

    if (score_max > 0)      score = score_max;
    else if (score_min < 0) score = score_min;
    
    if (score == 0) score = [[intelligence objectForKey:@"feed"] integerValue];

//    NSLog(@"%d/%d -- %d: %@", score_max, score_min, score, intelligence);
    return score;
}

+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end {
    UIView *gradientView = [[[UIView alloc] initWithFrame:rect] autorelease];
    
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = CGRectMake(0, 1, rect.size.width, rect.size.height-1);
    gradient.opacity = 1;
    unsigned int color = 0;
    unsigned int colorFade = 0;
    if ([start class] == [NSNull class]) {
        start = @"505050";
    }
    if ([end class] == [NSNull class]) {
        end = @"303030";
    }
    NSScanner *scanner = [NSScanner scannerWithString:start];
    [scanner scanHexInt:&color];
    NSScanner *scannerFade = [NSScanner scannerWithString:end];
    [scannerFade scanHexInt:&colorFade];
    gradient.colors = [NSArray arrayWithObjects:(id)[UIColorFromRGB(color) CGColor], (id)[UIColorFromRGB(colorFade) CGColor], nil];
    
    CALayer *whiteBackground = [CALayer layer];
    whiteBackground.frame = CGRectMake(0, 1, rect.size.width, rect.size.height-1);
    whiteBackground.backgroundColor = [UIColor whiteColor].CGColor;
    [gradientView.layer addSublayer:whiteBackground];
    
    [gradientView.layer addSublayer:gradient];
    
    CALayer *topBorder = [CALayer layer];
    topBorder.frame = CGRectMake(0, 1, rect.size.width, 1);
    topBorder.backgroundColor = UIColorFromRGB(colorFade).CGColor;
    topBorder.opacity = 1;
    [gradientView.layer addSublayer:topBorder];
    
    CALayer *bottomBorder = [CALayer layer];
    bottomBorder.frame = CGRectMake(0, rect.size.height-1, rect.size.width, 1);
    bottomBorder.backgroundColor = UIColorFromRGB(colorFade).CGColor;
    bottomBorder.opacity = 1;
    [gradientView.layer addSublayer:bottomBorder];
    
    return gradientView;
}

- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect {
    UIView *gradientView;
    if (self.isRiverView) {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:rect
                        startColor:[feed objectForKey:@"favicon_color"] 
                        endColor:[feed objectForKey:@"favicon_fade"]];
        
        UILabel *titleLabel = [[[UILabel alloc] init] autorelease];
        titleLabel.text = [feed objectForKey:@"feed_title"];
        titleLabel.backgroundColor = [UIColor clearColor];
        titleLabel.textAlignment = UITextAlignmentLeft;
        titleLabel.lineBreakMode = UILineBreakModeTailTruncation;
        titleLabel.font = [UIFont fontWithName:@"Helvetica-Bold" size:11.0];
        titleLabel.shadowOffset = CGSizeMake(0, 1);
        if ([[feed objectForKey:@"favicon_text_color"] class] != [NSNull class]) {
            titleLabel.textColor = [[feed objectForKey:@"favicon_text_color"] 
                                    isEqualToString:@"white"] ?
                [UIColor whiteColor] :
                [UIColor blackColor];            
            titleLabel.shadowColor = [[feed objectForKey:@"favicon_text_color"] 
                                      isEqualToString:@"white"] ?
                UIColorFromRGB(0x202020) :
                UIColorFromRGB(0xd0d0d0);
        } else {
            titleLabel.textColor = [UIColor whiteColor];
            titleLabel.shadowColor = [UIColor blackColor];
        }
        titleLabel.frame = CGRectMake(32, 1, window.frame.size.width-20, 20);
        
        NSString *feedIdStr = [NSString stringWithFormat:@"%@", [feed objectForKey:@"id"]];
        UIImage *titleImage = [Utilities getImage:feedIdStr];
        UIImageView *titleImageView = [[UIImageView alloc] initWithImage:titleImage];
        titleImageView.frame = CGRectMake(8, 3, 16.0, 16.0);
        [titleLabel addSubview:titleImageView];
        [titleImageView release];
        
        [gradientView addSubview:titleLabel];
        [gradientView addSubview:titleImageView];
    } else {
        gradientView = [NewsBlurAppDelegate 
                        makeGradientView:CGRectMake(0, -1, window.frame.size.width, 10) 
                        startColor:[feed objectForKey:@"favicon_color"] 
                        endColor:[feed objectForKey:@"favicon_fade"]];
    }
    
    gradientView.opaque = YES;
    
    return gradientView;
}

@end
