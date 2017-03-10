#import <UIKit/UIKit.h>
#import "MBProgressHUD.h"
#import "AFNetworking.h"

@interface BaseViewController : UIViewController {
	
    AFHTTPSessionManager *manager;
	
}

- (void) cancelRequests;

- (void)informError:(id)error;
- (void)informError:(id)error details:(NSString *)details;
- (void)informMessage:(NSString *)message;
- (void)informLoadingMessage:(NSString *)message;

- (void)addKeyCommandWithInput:(NSString *)input modifierFlags:(UIKeyModifierFlags)modifierFlags action:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle;
- (void)addCancelKeyCommandWithAction:(SEL)action discoverabilityTitle:(NSString *)discoverabilityTitle;

- (void)updateTheme;

@end

