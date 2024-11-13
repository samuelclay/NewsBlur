#import "BaseViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@implementation BaseViewController

@synthesize appDelegate;

#pragma mark -
#pragma mark HTTP requests

- (instancetype)init {
    if (self = [super init]) {
        self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    }
    
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
}

- (BOOL)becomeFirstResponder {
    BOOL success = [super becomeFirstResponder];
    
    NSLog(@"%@ becomeFirstResponder: %@", self, success ? @"yes" : @"no");  // log
    
    return success;
}

#pragma mark -
#pragma mark View methods

- (void)informError:(id)error {
    [self informError:error details:nil statusCode:0];
}

- (void)informError:(id)error statusCode:(NSInteger)statusCode {
    [self informError:error details:nil statusCode:statusCode];
}

- (void)informError:(id)error details:(NSString *)details statusCode:(NSInteger)statusCode {
    NSLog(@"informError: %@", error);
    NSString *errorMessage;
    if ([error isKindOfClass:[NSString class]]) {
        errorMessage = error;
    } else if (statusCode == 503) {
        return [self informError:@"In maintenance mode"];
    } else if (statusCode >= 400) {
        return [self informError:@"The server barfed!"];
    } else {
        errorMessage = [error localizedDescription];
        if ([error code] == 4 &&
            [errorMessage rangeOfString:@"cancelled"].location != NSNotFound) {
            return;
        }
    }
    
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    [HUD setCustomView:[[UIImageView alloc]
                        initWithImage:[UIImage imageNamed:@"warning.gif"]]];
    [HUD setMode:MBProgressHUDModeCustomView];
    if (details) {
        [HUD setDetailsLabelText:details];
    }
    HUD.labelText = errorMessage;
    [HUD hide:YES afterDelay:(details ? 3 : 1)];
    
    //    UIAlertView* alertView = [[UIAlertView alloc]
    //                              initWithTitle:@"Error"
    //                              message:localizedDescription delegate:nil
    //                              cancelButtonTitle:@"OK"
    //                              otherButtonTitles:nil];
    //    [alertView show];
    //    [alertView release];
}

- (void)informMessage:(NSString *)message {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.mode = MBProgressHUDModeText;
    HUD.labelText = message;
    [HUD hide:YES afterDelay:.75];
}

- (void)informLoadingMessage:(NSString *)message {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = message;
    [HUD hide:YES afterDelay:2];
}

- (void)systemAppearanceDidChange:(BOOL)isDark {
    [[ThemeManager themeManager] systemAppearanceDidChange:isDark];
}

- (void)updateTheme {
    // Subclasses should override this, calling super, to update their nav bar, table, etc
    
    appDelegate.splitViewController.view.backgroundColor = UIColorFromLightDarkRGB(0x555555, 0x777777);
}

- (void)tableView:(UITableView *)tableView redisplayCellAtIndexPath:(NSIndexPath *)indexPath {
    [[tableView cellForRowAtIndexPath:indexPath] setNeedsDisplay];
}

- (void)tableView:(UITableView *)tableView selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    [self tableView:tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:UITableViewScrollPositionNone];
}

- (void)tableView:(UITableView *)tableView selectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UITableViewScrollPosition)scrollPosition {
    [tableView selectRowAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
    [self tableView:tableView redisplayCellAtIndexPath:indexPath];
}

- (void)tableView:(UITableView *)tableView deselectRowAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    [tableView deselectRowAtIndexPath:indexPath animated:animated];
    [self tableView:tableView redisplayCellAtIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView redisplayCellAtIndexPath:(NSIndexPath *)indexPath {
    [[collectionView cellForItemAtIndexPath:indexPath] setNeedsDisplay];
}

- (void)collectionView:(UICollectionView *)collectionView selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    [self collectionView:collectionView selectItemAtIndexPath:indexPath animated:animated scrollPosition:UICollectionViewScrollPositionNone];
}

- (void)collectionView:(UICollectionView *)collectionView selectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated scrollPosition:(UICollectionViewScrollPosition)scrollPosition {
    [collectionView selectItemAtIndexPath:indexPath animated:animated scrollPosition:scrollPosition];
    [self collectionView:collectionView redisplayCellAtIndexPath:indexPath];
}

- (void)collectionView:(UICollectionView *)collectionView deselectItemAtIndexPath:(NSIndexPath *)indexPath animated:(BOOL)animated {
    [collectionView deselectItemAtIndexPath:indexPath animated:animated];
    [self collectionView:collectionView redisplayCellAtIndexPath:indexPath];
}

#pragma mark -
#pragma mark Keyboard support
- (void)addKeyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle {
    [self addKeyCommandWithInput:input modifierFlags:modifierFlags action:action discoverabilityTitle:discoverabilityTitle wantPriority:NO];
}

- (void)addKeyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle wantPriority:(BOOL)wantPriority {
    UIKeyCommand *keyCommand = [UIKeyCommand keyCommandWithInput:input modifierFlags:modifierFlags action:action];
    if ([keyCommand respondsToSelector:@selector(discoverabilityTitle)] && [self respondsToSelector:@selector(addKeyCommand:)]) {
        keyCommand.discoverabilityTitle = discoverabilityTitle;
        if (@available(iOS 15.0, *)) {
            keyCommand.wantsPriorityOverSystemBehavior = wantPriority;
        }
        [self addKeyCommand:keyCommand];
    }
}

- (void)addCancelKeyCommandWithAction:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle {
    [self addKeyCommandWithInput:UIKeyInputEscape modifierFlags:0 action:action discoverabilityTitle:discoverabilityTitle];
    [self addKeyCommandWithInput:@"." modifierFlags:UIKeyModifierCommand action:action discoverabilityTitle:discoverabilityTitle];
}

#pragma mark -
#pragma mark UIViewController

- (void) viewDidLoad {
    [super viewDidLoad];
    
    BOOL isDark = [NewsBlurAppDelegate sharedAppDelegate].window.windowScene.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.view];
    [[ThemeManager themeManager] systemAppearanceDidChange:isDark];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    if ([self presentedViewController]) {
        [[self presentedViewController] viewWillTransitionToSize:size
                                       withTransitionCoordinator:coordinator];
    }
}

- (void)traitCollectionDidChange:(UITraitCollection *)previousTraitCollection {
    [super traitCollectionDidChange:previousTraitCollection];
    
    BOOL isDark = [NewsBlurAppDelegate sharedAppDelegate].window.windowScene.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
    
    [self systemAppearanceDidChange:isDark];
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (!ThemeManager.themeManager.isDarkTheme) {
        return UIStatusBarStyleDarkContent;
    }
    
    return UIStatusBarStyleLightContent;
}

- (BOOL)isPhone {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone;
}

- (BOOL)isMac {
    return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomMac;
}

- (BOOL)isVision {
    if (@available(iOS 17.0, *)) {
        return [[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomVision;
    } else {
        return NO;
    }
}

- (BOOL)isPortrait {
    UIWindow *window = [NewsBlurAppDelegate sharedAppDelegate].window;
    UIInterfaceOrientation orientation = window.windowScene.interfaceOrientation;
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isCompactWidth {
    UIWindow *window = [NewsBlurAppDelegate sharedAppDelegate].window;
    UITraitCollection *traits = window.windowScene.traitCollection;
    
    return traits.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    //return self.compactWidth > 0.0;
}

- (BOOL)isGrid {
    return self.appDelegate.detailViewController.storyTitlesInGrid;
}

- (BOOL)isFeedShown {
    return appDelegate.storiesCollection.activeFeed != nil || appDelegate.storiesCollection.activeFolder != nil;
}

- (BOOL)isStoryShown {
    return !appDelegate.storyPagesViewController.currentPage.view.isHidden && appDelegate.storyPagesViewController.currentPage.noStoryMessage.isHidden;
}

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(chooseLayout:) || action == @selector(findInFeedDetail:)) {
        return self.isFeedShown;
    } else if (action == @selector(chooseTitle:) || action == @selector(choosePreview:)) {
        return self.isFeedShown && !self.isGrid;
    } else if (action == @selector(chooseGridColumns:) || action == @selector(chooseGridHeight:)) {
        return self.isFeedShown && self.isGrid;
    } else if (action == @selector(openTrainSite) ||
        action == @selector(openTrainSite:) ||
        action == @selector(openNotifications:) ||
        action == @selector(openStatistics:) ||
        action == @selector(moveSite:) ||
        action == @selector(openRenameSite:) ||
        action == @selector(deleteSite:)) {
        return self.isFeedShown && appDelegate.storiesCollection.isCustomFolderOrFeed;
    } else if (action == @selector(muteSite) || 
               action == @selector(muteSite:)) {
        return self.isFeedShown && !appDelegate.storiesCollection.isRiverView;
    } else if (action == @selector(instaFetchFeed:) ||
               action == @selector(doMarkAllRead:)) {
        return self.isFeedShown;
    } else if (action == @selector(showSendTo:) ||
               action == @selector(showTrain:) ||
               action == @selector(showShare:) ||
               action == @selector(nextUnreadStory:) ||
               action == @selector(nextStory:) ||
               action == @selector(previousStory:) ||
               action == @selector(toggleTextStory:) ||
               action == @selector(openInBrowser:)) {
        return self.isStoryShown;
    } else {
        return [super canPerformAction:action withSender:sender];
    }
}

- (void)validateCommand:(UICommand *)command {
    [super validateCommand:command];
    
    if (command.action == @selector(chooseColumns:)) {
        command.state = [command.propertyList isEqualToString:appDelegate.detailViewController.behaviorString];
    } else if (command.action == @selector(chooseLayout:)) {
        NSString *value = self.appDelegate.storiesCollection.activeStoryTitlesPosition;
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(chooseIntelligence:)) {
        NSInteger intelligence = [[NSUserDefaults standardUserDefaults] integerForKey:@"selectedIntelligence"];
        NSString *value = [NSString stringWithFormat:@"%@", @(intelligence + 1)];
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(toggleSidebar:)) {
        UISplitViewController *splitViewController = self.appDelegate.splitViewController;
        if (splitViewController.preferredDisplayMode != UISplitViewControllerDisplayModeTwoBesideSecondary) {
            command.title = @"Show Sidebar";
        } else {
            command.title = @"Hide Sidebar";
        }
    } else if (command.action == @selector(chooseTitle:)) {
        NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"story_list_preview_text_size"];
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(choosePreview:)) {
        NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"story_list_preview_images_size"];
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(chooseGridColumns:)) {
        NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"grid_columns"];
        if (value == nil) {
            value = @"auto";
        }
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(chooseGridHeight:)) {
        NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"grid_height"];
        if (value == nil) {
            value = @"medium";
        }
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(chooseFontSize:)) {
        NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"feed_list_font_size"];
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(chooseSpacing:)) {
        NSString *value = [[NSUserDefaults standardUserDefaults] objectForKey:@"feed_list_spacing"];
        command.state = [command.propertyList isEqualToString:value];
    } else if (command.action == @selector(chooseTheme:)) {
        command.state = [command.propertyList isEqualToString:ThemeManager.themeManager.theme];
    } else if (command.action == @selector(openRenameSite:)) {
        if (appDelegate.storiesCollection.isRiverOrSocial) {
            command.title = @"Rename Folder…";
        } else {
            command.title = @"Rename Site…";
        }
    } else if (command.action == @selector(deleteSite:)) {
        if (appDelegate.storiesCollection.isRiverOrSocial) {
            command.title = @"Delete Folder…";
        } else {
            command.title = @"Delete Site…";
        }
    } else if (command.action == @selector(toggleStorySaved:)) {
        BOOL isRead = [[self.appDelegate.activeStory objectForKey:@"starred"] boolValue];
        if (isRead) {
            command.title = @"Unsave This Story";
        } else {
            command.title = @"Save This Story";
        }
    } else if (command.action == @selector(toggleStoryUnread:)) {
        BOOL isRead = [[self.appDelegate.activeStory objectForKey:@"read_status"] boolValue];
        if (isRead) {
            command.title = @"Mark as Unread";
        } else {
            command.title = @"Mark as Read";
        }
    }
}

#pragma mark -
#pragma mark File menu

- (IBAction)newSite:(id)sender {
    [appDelegate.feedsViewController tapAddSite:nil];
}

- (IBAction)reloadFeeds:(id)sender {
    [appDelegate reloadFeedsView:NO];
}

- (IBAction)showMuteSites:(id)sender {
    [self.appDelegate showMuteSites];
}

- (IBAction)showOrganizeSites:(id)sender {
    [self.appDelegate showOrganizeSites];
}

- (IBAction)showWidgetSites:(id)sender {
    [self.appDelegate showWidgetSites];
}

- (IBAction)showNotifications:(id)sender {
    [self.appDelegate openNotificationsWithFeed:nil];
}

- (IBAction)showFindFriends:(id)sender {
    [self.appDelegate showFindFriends];
}

- (IBAction)showPremium:(id)sender {
    [self.appDelegate showPremiumDialog];
}

- (IBAction)showSupportForum:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://forum.newsblur.com"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (IBAction)showManageAccount:(id)sender {
    NSURL *url = [NSURL URLWithString:@"https://www.newsblur.com/?next=account"];
    [[UIApplication sharedApplication] openURL:url options:@{} completionHandler:nil];
}

- (IBAction)showLogout:(id)sender {
    [self.appDelegate confirmLogout];
}

#pragma mark -
#pragma mark Edit menu

- (IBAction)findInFeeds:(id)sender {
    [self.appDelegate showColumn:UISplitViewControllerColumnPrimary debugInfo:@"findInFeeds"];
    [self.appDelegate.feedsViewController.searchBar becomeFirstResponder];
}

- (IBAction)findInFeedDetail:(id)sender {
    [self.appDelegate showColumn:UISplitViewControllerColumnSupplementary debugInfo:@"findInFeedDetail"];
    [self.appDelegate.feedDetailViewController.searchBar becomeFirstResponder];
}

#pragma mark -
#pragma mark View menu

- (IBAction)chooseColumns:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"split_behavior"];
    
    [UIView animateWithDuration:0.5 animations:^{
        [self.appDelegate updateSplitBehavior:YES];
    }];
    
    [self.appDelegate.detailViewController updateLayoutWithReload:NO fetchFeeds:YES];
}

- (IBAction)chooseLayout:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    NSString *key = self.appDelegate.storiesCollection.storyTitlesPositionKey;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:key];
    
    [self.appDelegate.detailViewController updateLayoutWithReload:YES fetchFeeds:YES];
}

- (IBAction)chooseIntelligence:(id)sender {
    UICommand *command = sender;
    NSInteger index = [command.propertyList integerValue];
    
    [self.appDelegate.feedsViewController.intelligenceControl setSelectedSegmentIndex:index];
    [self.appDelegate.feedsViewController selectIntelligence];
}

- (IBAction)chooseTitle:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"story_list_preview_text_size"];
    
    [self.appDelegate resizePreviewSize];
}

- (IBAction)choosePreview:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"story_list_preview_images_size"];
    
    [self.appDelegate resizePreviewSize];
}

- (IBAction)chooseGridColumns:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"grid_columns"];
    
    [self.appDelegate.detailViewController updateLayoutWithReload:YES fetchFeeds:YES];
}

- (IBAction)chooseGridHeight:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"grid_height"];
    
    [self.appDelegate.detailViewController updateLayoutWithReload:YES fetchFeeds:YES];
}

- (IBAction)chooseFontSize:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"feed_list_font_size"];
    
    [self.appDelegate resizeFontSize];
}

- (IBAction)chooseSpacing:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"feed_list_spacing"];
    
    [self.appDelegate.feedsViewController reloadFeedTitlesTable];
    [self.appDelegate.feedDetailViewController reloadWithSizing];
}

- (IBAction)chooseTheme:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [ThemeManager themeManager].theme = string;
}

- (IBAction)toggleSidebar:(id)sender{
    UISplitViewController *splitViewController = self.appDelegate.splitViewController;
    
    [UIView animateWithDuration:0.2 animations:^{
        NSLog(@"toggleSidebar: displayMode: %@; preferredDisplayMode: %@; UISplitViewControllerDisplayModeSecondaryOnly: %@; UISplitViewControllerDisplayModeTwoBesideSecondary: %@, UISplitViewControllerDisplayModeOneBesideSecondary: %@; ", @(splitViewController.displayMode), @(splitViewController.preferredDisplayMode), @(UISplitViewControllerDisplayModeSecondaryOnly), @(UISplitViewControllerDisplayModeTwoBesideSecondary), @(UISplitViewControllerDisplayModeOneBesideSecondary));  // log
        
        if (splitViewController.splitBehavior == UISplitViewControllerSplitBehaviorOverlay) {
            splitViewController.preferredDisplayMode = (splitViewController.displayMode != UISplitViewControllerDisplayModeTwoOverSecondary ? UISplitViewControllerDisplayModeTwoOverSecondary : UISplitViewControllerDisplayModeOneOverSecondary);
        } else if (splitViewController.splitBehavior == UISplitViewControllerSplitBehaviorDisplace) {
            if (splitViewController.preferredDisplayMode == UISplitViewControllerDisplayModeTwoDisplaceSecondary &&
                splitViewController.displayMode == UISplitViewControllerDisplayModeSecondaryOnly) {
                splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeOneBesideSecondary;
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeTwoDisplaceSecondary;
                });
            } else {
                splitViewController.preferredDisplayMode = (splitViewController.displayMode != UISplitViewControllerDisplayModeTwoDisplaceSecondary ? UISplitViewControllerDisplayModeTwoDisplaceSecondary : UISplitViewControllerDisplayModeOneBesideSecondary);
            }
        } else {
            if (splitViewController.preferredDisplayMode == UISplitViewControllerDisplayModeTwoBesideSecondary &&
                splitViewController.displayMode == UISplitViewControllerDisplayModeSecondaryOnly) {
                splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeOneBesideSecondary;
                
                dispatch_async(dispatch_get_main_queue(), ^(void) {
                    splitViewController.preferredDisplayMode = UISplitViewControllerDisplayModeTwoBesideSecondary;
                });
            } else {
                splitViewController.preferredDisplayMode = (splitViewController.displayMode != UISplitViewControllerDisplayModeTwoBesideSecondary ? UISplitViewControllerDisplayModeTwoBesideSecondary : UISplitViewControllerDisplayModeOneBesideSecondary);
            }
        }
    }];
}

#pragma mark -
#pragma mark Site menu

- (IBAction)moveSite:(id)sender {
    [self.appDelegate.feedDetailViewController openMoveView:self.appDelegate.navigationController];
}

- (IBAction)openRenameSite:(id)sender {
    [self.appDelegate.feedDetailViewController openRenameSite];
}

- (IBAction)muteSite:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Are you sure you wish to mute %@?", self.appDelegate.storiesCollection.activeTitle] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle: @"Mute Site" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self.appDelegate.feedDetailViewController muteSite];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)deleteSite:(id)sender {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:[NSString stringWithFormat:@"Are you sure you wish to delete %@?", self.appDelegate.storiesCollection.activeTitle] message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addAction:[UIAlertAction actionWithTitle: @"Delete Site" style:UIAlertActionStyleDestructive handler:^(UIAlertAction * action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        [self.appDelegate.feedDetailViewController deleteSite];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel handler:nil]];
    [self presentViewController:alertController animated:YES completion:nil];
}

- (IBAction)openTrainSite:(id)sender {
    [self.appDelegate.feedDetailViewController openTrainSite];
}

- (IBAction)openNotifications:(id)sender {
    [self.appDelegate.feedDetailViewController openNotifications:sender];
}

- (IBAction)openStatistics:(id)sender {
    [self.appDelegate.feedDetailViewController openStatistics:sender];
}

- (IBAction)instaFetchFeed:(id)sender {
    [self.appDelegate.feedDetailViewController instafetchFeed];
}

- (IBAction)doMarkAllRead:(id)sender {
    [self.appDelegate.feedDetailViewController doMarkAllRead:sender];
}

// These two are needed for the toolbar in Grid view.
- (IBAction)openMarkReadMenu:(id)sender {
    [self.appDelegate.feedDetailViewController doOpenMarkReadMenu:sender];
}

- (IBAction)openSettingsMenu:(id)sender {
    [self.appDelegate.feedDetailViewController doOpenSettingsMenu:sender];
}

- (IBAction)nextSite:(id)sender {
    [self.appDelegate.feedsViewController selectNextFeed:sender];
}

- (IBAction)previousSite:(id)sender {
    [self.appDelegate.feedsViewController selectPreviousFeed:sender];
}

- (IBAction)nextFolder:(id)sender {
    [self.appDelegate.feedsViewController selectNextFolder:sender];
}

- (IBAction)previousFolder:(id)sender {
    [self.appDelegate.feedsViewController selectPreviousFolder:sender];
}

- (IBAction)openAllStories:(id)sender {
    [self.appDelegate.feedsViewController selectEverything:sender];
}

#pragma mark -
#pragma mark Story menu

- (IBAction)showSendTo:(id)sender {
    [appDelegate showSendTo:self sender:sender];
}

- (IBAction)showTrain:(id)sender {
    [self.appDelegate openTrainStory:self.appDelegate.storyPagesViewController.fontSettingsButton];
}

- (IBAction)showShare:(id)sender {
    [self.appDelegate.storyPagesViewController.currentPage openShareDialog];
}

- (IBAction)nextUnreadStory:(id)sender {
    [self.appDelegate.storyPagesViewController doNextUnreadStory:sender];
}

- (IBAction)nextStory:(id)sender {
    [self.appDelegate.storyPagesViewController changeToNextPage:sender];
}

- (IBAction)previousStory:(id)sender {
    [self.appDelegate.storyPagesViewController changeToPreviousPage:sender];
}

- (IBAction)toggleTextStory:(id)sender {
    [self.appDelegate.storyPagesViewController toggleTextView:sender];
}

- (IBAction)openInBrowser:(id)sender {
    [self.appDelegate.storyPagesViewController showOriginalSubview:sender];
}

@end
