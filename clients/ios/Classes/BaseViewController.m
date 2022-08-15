#import "BaseViewController.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlur-Swift.h"

@implementation BaseViewController

#pragma mark -
#pragma mark HTTP requests

- (instancetype)init {
    if (self = [super init]) {

    }
    
    return self;
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
    
    [[ThemeManager themeManager] addThemeGestureRecognizerToView:self.view];
    [[ThemeManager themeManager] systemAppearanceDidChange:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark];
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
    
    if ([previousTraitCollection hasDifferentColorAppearanceComparedToTraitCollection:self.traitCollection]) {
        [[ThemeManager themeManager] systemAppearanceDidChange:self.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark];
    }
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    if (!ThemeManager.themeManager.isDarkTheme) {
        return UIStatusBarStyleDarkContent;
    }
    
    return UIStatusBarStyleLightContent;
}

@end
