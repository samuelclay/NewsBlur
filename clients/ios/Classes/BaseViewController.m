#import "BaseViewController.h"
#import "NewsBlurAppDelegate.h"

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

#pragma mark -
#pragma mark Keyboard support
- (void)addKeyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle {
    UIKeyCommand *keyCommand = [UIKeyCommand keyCommandWithInput:input modifierFlags:modifierFlags action:action];
    if ([keyCommand respondsToSelector:@selector(discoverabilityTitle)] && [self respondsToSelector:@selector(addKeyCommand:)]) {
        keyCommand.discoverabilityTitle = discoverabilityTitle;
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
}

- (void) viewDidUnload {
	[super viewDidUnload];
}

- (void)viewWillTransitionToSize:(CGSize)size withTransitionCoordinator:(id<UIViewControllerTransitionCoordinator>)coordinator {
    [super viewWillTransitionToSize:size withTransitionCoordinator:coordinator];
    
    if ([self presentedViewController]) {
        [[self presentedViewController] viewWillTransitionToSize:size
                                       withTransitionCoordinator:coordinator];
    }
}

@end
