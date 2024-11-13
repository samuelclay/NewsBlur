#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"

@class NewsBlurAppDelegate;

@interface BaseViewController : UIViewController {
    NewsBlurAppDelegate *appDelegate;
}

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;

@property (nonatomic, readonly) BOOL isPhone;
@property (nonatomic, readonly) BOOL isMac;
@property (nonatomic, readonly) BOOL isVision;
@property (nonatomic, readonly) BOOL isPortrait;
@property (nonatomic, readonly) BOOL isCompactWidth;
@property (nonatomic, readonly) BOOL isGrid;
@property (nonatomic, readonly) BOOL isFeedShown;
@property (nonatomic, readonly) BOOL isStoryShown;

- (void)informError:(id)error;
- (void)informError:(id)error statusCode:(NSInteger)statusCode;
- (void)informMessage:(NSString *)message;
- (void)informLoadingMessage:(NSString *)message;

- (void)addKeyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle;
- (void)addKeyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle wantPriority:(BOOL)wantPriority;
- (void)addCancelKeyCommandWithAction:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle;

- (void)systemAppearanceDidChange:(BOOL)isDark;
- (void)updateTheme;

- (void)tableView:(UITableView *)tableView redisplayCellAtIndexPath:(NSIndexPath *)indexPath;
- (void)tableView:(UITableView *)tableView selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (void)tableView:(UITableView *)tableView selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition;
- (void)tableView:(UITableView *)tableView deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

- (void)collectionView:(UICollectionView *)collectionView redisplayCellAtIndexPath:(NSIndexPath *)indexPath;
- (void)collectionView:(UICollectionView *)collectionView selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;
- (void)collectionView:(UICollectionView *)collectionView selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition;
- (void)collectionView:(UICollectionView *)collectionView deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated;

- (IBAction)newSite:(id)sender;
- (IBAction)reloadFeeds:(id)sender;
- (IBAction)showMuteSites:(id)sender;
- (IBAction)showOrganizeSites:(id)sender;
- (IBAction)showWidgetSites:(id)sender;
- (IBAction)showNotifications:(id)sender;
- (IBAction)showFindFriends:(id)sender;
- (IBAction)showPremium:(id)sender;
- (IBAction)showSupportForum:(id)sender;
- (IBAction)showManageAccount:(id)sender;
- (IBAction)showLogout:(id)sender;

- (IBAction)findInFeeds:(id)sender;
- (IBAction)findInFeedDetail:(id)sender;

- (IBAction)chooseColumns:(id)sender;
- (IBAction)chooseLayout:(id)sender;
- (IBAction)chooseTitle:(id)sender;
- (IBAction)choosePreview:(id)sender;
- (IBAction)chooseGridColumns:(id)sender;
- (IBAction)chooseGridHeight:(id)sender;
- (IBAction)chooseFontSize:(id)sender;
- (IBAction)chooseSpacing:(id)sender;
- (IBAction)chooseTheme:(id)sender;

- (IBAction)moveSite:(id)sender;
- (IBAction)openRenameSite:(id)sender;
- (IBAction)muteSite:(id)sender;
- (IBAction)deleteSite:(id)sender;
- (IBAction)openTrainSite:(id)sender;
- (IBAction)openNotifications:(id)sender;
- (IBAction)openStatistics:(id)sender;
- (IBAction)instaFetchFeed:(id)sender;
- (IBAction)doMarkAllRead:(id)sender;
- (IBAction)openMarkReadMenu:(id)sender;
- (IBAction)openSettingsMenu:(id)sender;
- (IBAction)nextSite:(id)sender;
- (IBAction)previousSite:(id)sender;
- (IBAction)nextFolder:(id)sender;
- (IBAction)previousFolder:(id)sender;
- (IBAction)openAllStories:(id)sender;

- (IBAction)showSendTo:(id)sender;
- (IBAction)showTrain:(id)sender;
- (IBAction)showShare:(id)sender;
- (IBAction)nextUnreadStory:(id)sender;
- (IBAction)nextStory:(id)sender;
- (IBAction)previousStory:(id)sender;
- (IBAction)toggleTextStory:(id)sender;
- (IBAction)openInBrowser:(id)sender;

@end

