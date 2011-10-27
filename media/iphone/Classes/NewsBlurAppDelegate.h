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
@class AddViewController;
@class OriginalStoryViewController;

@interface NewsBlurAppDelegate : BaseViewController <UIApplicationDelegate> {
    UIWindow *window;
    UINavigationController *navigationController;
    NewsBlurViewController *feedsViewController;
    FeedDetailViewController *feedDetailViewController;
    StoryDetailViewController *storyDetailViewController;
    LoginViewController *loginViewController;
    AddViewController *addViewController;
    OriginalStoryViewController *originalStoryViewController;
    
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
    NSMutableArray * recentlyReadStories;
    NSMutableArray * readStories;
    
	NSDictionary * dictFolders;
    NSDictionary * dictFeeds;
    NSMutableArray * dictFoldersArray;
}

@property (nonatomic, retain) IBOutlet UIWindow *window;
@property (nonatomic, readonly, retain) IBOutlet UINavigationController *navigationController;
@property (nonatomic, retain) IBOutlet NewsBlurViewController *feedsViewController;
@property (nonatomic, retain) IBOutlet FeedDetailViewController *feedDetailViewController;
@property (nonatomic, retain) IBOutlet StoryDetailViewController *storyDetailViewController;
@property (nonatomic, retain) IBOutlet LoginViewController *loginViewController;
@property (nonatomic, retain) IBOutlet AddViewController *addViewController;
@property (nonatomic, retain) IBOutlet OriginalStoryViewController *originalStoryViewController;

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
@property (readwrite) NSInteger selectedIntelligence;
@property (readwrite, retain) NSMutableArray * recentlyReadStories;
@property (readwrite, retain) NSMutableArray * readStories;

@property (nonatomic, retain) NSDictionary *dictFolders;
@property (nonatomic, retain) NSDictionary *dictFeeds;
@property (nonatomic, retain) NSMutableArray *dictFoldersArray;

- (void)showLogin;
- (void)showAdd;
- (void)loadFeedDetailView;
- (void)loadRiverFeedDetailView;
- (void)loadStoryDetailView;
- (void)reloadFeedsView;
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
- (int)visibleUnreadCount;
- (void)markActiveStoryRead;
- (void)markActiveFeedAllRead;
- (void)calculateStoryLocations;
+ (int)computeStoryScore:(NSDictionary *)intelligence;

@end

