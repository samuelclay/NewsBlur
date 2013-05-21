/* Copyright 2012 IGN Entertainment, Inc. */

#import "MessageService.h"

static MessageService *_manager;

@implementation MessageService

+ (MessageService *)sharedManager
{
    if (!_manager) {
        _manager = [[MessageService alloc] init];
    }
    return _manager;
}

+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    [[MessageService sharedManager] shareWithParams:params onViewController:viewController];
}

- (void)messageComposeViewController:(MFMessageComposeViewController *)controller didFinishWithResult:(MessageComposeResult)result
{
    [[controller presentingViewController] dismissModalViewControllerAnimated:YES];
}

- (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    if ([MFMessageComposeViewController canSendText]) {
        MFMessageComposeViewController *controller = [[MFMessageComposeViewController alloc] init];
        controller.body = [[params objectForKey:@"title"] stringByAppendingFormat:@"\n%@",[[params objectForKey:@"url"] absoluteString]];
        controller.messageComposeDelegate = self;
        [viewController presentModalViewController:controller animated:YES];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failure"
                                                        message:@"Messaging Failed."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

@end
