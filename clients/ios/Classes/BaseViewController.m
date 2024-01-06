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

- (void)updateTheme {
    // Subclasses should override this, calling super, to update their nav bar, table, etc
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
    
    [[ThemeManager themeManager] systemAppearanceDidChange:isDark];
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
    UIInterfaceOrientation orientation = self.view.window.windowScene.interfaceOrientation;
    if (orientation == UIInterfaceOrientationPortrait || orientation == UIInterfaceOrientationPortraitUpsideDown) {
        return YES;
    } else {
        return NO;
    }
}

- (BOOL)isCompactWidth {
    return self.view.window.windowScene.traitCollection.horizontalSizeClass == UIUserInterfaceSizeClassCompact;
    //return self.compactWidth > 0.0;
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

- (IBAction)showLogout:(id)sender {
    [self.appDelegate confirmLogout];
}

- (IBAction)chooseColumns:(id)sender {
    UICommand *command = sender;
    NSString *string = command.propertyList;
    
    [[NSUserDefaults standardUserDefaults] setObject:string forKey:@"split_behavior"];
    
    [UIView animateWithDuration:0.5 animations:^{
        [self.appDelegate updateSplitBehavior:YES];
    }];
    
    [self.appDelegate.detailViewController updateLayoutWithReload:NO fetchFeeds:YES];
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

@end
