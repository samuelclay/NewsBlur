//
//  NewsBlurAppDelegate.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/16/10.
//  Copyright NewsBlur 2010. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "BaseViewController.h"

@class NewsBlurViewController;
@class FeedDetailViewController;
@class StoryDetailViewController;
@class LoginViewController;
@class AddSiteViewController;
@class MoveSiteViewController;
@class OriginalStoryViewController;
@class DetailViewController;

@interface NewsBlurAppDelegate : BaseViewController <UIApplicationDelegate> {
    UIWindow *window;
    UISplitViewController *splitViewController;
    UINavigationController *navigationController;
    NewsBlurViewController *feedsViewController;
    FeedDetailViewController *feedDetailViewController;
    StoryDetailViewController *storyDetailViewController;
    LoginViewController *loginViewController;
    AddSiteViewController *addSiteViewController;
    MoveSiteViewController *moveSiteViewController;
    OriginalStoryViewController *originalStoryViewController;
    DetailViewController *detailViewController;
    
    NSString * activeUsername;
    BOOL isRiverView;
    NSDictionary * activeFeed;
    NSString * activeFolder;
    NSArray * activeFolderFeeds;
    NSArray * activeFeedStories;
    NSMutableArray * activeFeedStoryLocations;
    NSMutableArray * activeFeedStoryLocationIds;
    NSDictionary * activeStory;
    NSURL * activeOriginalStoryURL;
    
    int storyCount;
    int originalStoryCount;
    NSInteger selectedIntelligence;
    int visibleUnreadCount;
    NSMutableArray * recentlyReadStories;
    NSMutableSet * recentlyReadFeeds;
    NSMutableArray * readStories;
    
	NSDictionary * dictFolders;
    NSDictionary * dictFeeds;
    NSMutableArray * dictFoldersArray;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, retain) IBOutlet UISplitViewController *splitViewController;
@property (nonatomic, readonly, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, retain) IBOutlet NewsBlurViewController *feedsViewController;
@property (nonatomic, retain) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic, retain) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic, retain) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, retain) IBOutlet AddSiteViewController *addSiteViewController;
@property (nonatomic, retain) IBOutlet MoveSiteViewController *moveSiteViewController;
@property (nonatomic, retain) IBOutlet OriginalStoryViewController *originalStoryViewController;
@property (nonatomic, retain) IBOutlet DetailViewController *detailViewController;

@property (readwrite, retain) NSString * activeUsername;
@property (nonatomic, readwrite) BOOL isRiverView;
@property (readwrite, retain) NSDictionary * activeFeed;
@property (readwrite, retain) NSString * activeFolder;
@property (readwrite, retain) NSArray * activeFolderFeeds;
@property (readwrite, retain) NSArray * activeFeedStories;
@property (readwrite, retain) NSMutableArray * activeFeedStoryLocations;
@property (readwrite, retain) NSMutableArray * activeFeedStoryLocationIds;
@property (readwrite, retain) NSDictionary * activeStory;
@property (readwrite, retain) NSURL * activeOriginalStoryURL;
@property (readwrite) int storyCount;
@property (readwrite) int originalStoryCount;
@property (readwrite) int visibleUnreadCount;
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite, retain) NSMutableArray * recentlyReadStories;
@property (readwrite, retain) NSMutableSet * recentlyReadFeeds;
@property (readwrite, retain) NSMutableArray * readStories;

@property (nonatomic, retain) NSDictionary *dictFolders;
@property (nonatomic, retain) NSDictionary *dictFeeds;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;

+ (NewsBlurAppDelegate*) sharedAppDelegate;

- (void)showLogin;
- (void)showAdd;
- (void)showMoveSite;
- (void)loadFeedDetailView;
- (void)loadRiverFeedDetailView;
- (void)loadStoryDetailView;
- (void)reloadFeedsView:(BOOL)showLoader;
- (void)hideNavigationBar:(BOOL)animated;
- (void)showNavigationBar:(BOOL)animated;
- (void)setTitle:(NSString *)title;
- (void)showOriginalStory:(NSURL *)url;
- (void)closeOriginalStory;

- (int)indexOfNextStory;
- (int)indexOfPreviousStory;
- (int)indexOfActiveStory;
- (int)locationOfActiveStory;
- (void)pushReadStory:(id)storyId;
- (id)popReadStory;
- (int)locationOfStoryId:(id)storyId;

- (void)setStories:(NSArray *)activeFeedStoriesValue;
- (void)addStories:(NSArray *)stories;
- (int)unreadCount;
- (int)unreadCountForFeed:(NSString *)feedId;
- (int)unreadCountForFolder:(NSString *)folderName;
- (void)markActiveStoryRead;
- (NSDictionary *)markVisibleStoriesRead;
- (void)markStoryRead:(NSString *)storyId feedId:(id)feedId;
- (void)markStoryRead:(NSDictionary *)story feed:(NSDictionary *)feed;
- (void)markActiveFeedAllRead;
- (void)markActiveFolderAllRead;
- (void)markFeedAllRead:(id)feedId;
- (void)calculateStoryLocations;
+ (int)computeStoryScore:(NSDictionary *)intelligence;
- (NSString *)extractFolderName:(NSString *)folderName;
- (NSString *)extractParentFolderName:(NSString *)folderName;
+ (UIView *)makeGradientView:(CGRect)rect startColor:(NSString *)start endColor:(NSString *)end;
- (UIView *)makeFeedTitleGradient:(NSDictionary *)feed withRect:(CGRect)rect;
- (UIView *)makeFeedTitle:(NSDictionary *)feed;

@end

