#import "BaseViewController.h"
#import "NewsBlurAppDelegate.h"

@implementation BaseViewController

#pragma mark -
#pragma mark HTTP requests

- (ASIHTTPRequest*) requestWithURL:(NSString*) s {
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:s]];
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
    NSLog(@"Error: %@", error);
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
    HUD.labelText = errorMessage;
    [HUD hide:YES afterDelay:1];
    
//    UIAlertView* alertView = [[UIAlertView alloc]
//                              initWithTitle:@"Error"
//                              message:localizedDescription delegate:nil
//                              cancelButtonTitle:@"OK"
//                              otherButtonTitles:nil];
//    [alertView show];
//    [alertView release];
}

#pragma mark -
#pragma mark UIViewController

- (void) viewDidLoad {
	[super viewDidLoad];
}

- (void) viewDidUnload {
	[super viewDidUnload];
}

#pragma mark -
#pragma mark Memory management

- (void)dealloc {
	[self cancelRequests];
	
}


@end
