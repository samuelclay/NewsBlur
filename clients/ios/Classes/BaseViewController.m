#import "BaseViewController.h"
#import "NewsBlurAppDelegate.h"

@implementation BaseViewController

#pragma mark -
#pragma mark HTTP requests

- (ASIHTTPRequest*) requestWithURL:(NSString*) s {
    ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:s]];
    [request setValidatesSecureCertificate:NO];
	[self addRequest:request];
	return request;
}

- (ASIFormDataRequest*) formRequestWithURL:(NSString*) s {
	ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:[NSURL URLWithString:s]];
	[self addRequest:request];
	return request;
}

- (void) addRequest:(ASIHTTPRequest*)request {
	[request setDelegate:self];
	if (!requests) {
		requests = [[NSMutableArray alloc] initWithCapacity:3];
	} else {
		[self clearFinishedRequests];
	}
	[requests addObject:request];
}

- (void) clearFinishedRequests {
	NSMutableArray* toremove = [[NSMutableArray alloc] initWithCapacity:[requests count]];
	for (ASIHTTPRequest* r in requests) {
		if ([r isFinished]) {
			[toremove addObject:r];
		}
	}
	
	for (ASIHTTPRequest* r in toremove) {
		[requests removeObject:r];
	}
}

- (void) cancelRequests {
	for (ASIHTTPRequest* r in requests) {
		r.delegate = nil;
		[r cancel];
	}	
	[requests removeAllObjects];
}

#pragma mark -
#pragma mark View methods

- (void)informError:(id)error {
    [self informError:error details:nil];
}

- (void)informError:(id)error details:(NSString *)details {
    NSLog(@"informError: %@", error);
    NSString *errorMessage;
    if ([error isKindOfClass:[NSString class]]) {
        errorMessage = error;
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

#pragma mark -
#pragma mark Memory management

- (void)dealloc {
	[self cancelRequests];
	
}


@end
