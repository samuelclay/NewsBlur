/* Copyright 2012 IGN Entertainment, Inc. */

#import "EmailService.h"
#import "NewsBlurAppDelegate.h"

static EmailService *_manager;

@implementation EmailService

+ (EmailService *)sharedManager
{
    if (!_manager) {
        _manager = [[EmailService alloc] init];
    }
    return _manager;
}

+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    [[EmailService sharedManager] shareWithParams:params onViewController:viewController];
}

- (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    if ([MFMailComposeViewController canSendMail]) {
        MFMailComposeViewController *mailer = [[MFMailComposeViewController alloc] init];
        [[mailer navigationBar] setTintColor:[UIColor blackColor]];
        mailer.mailComposeDelegate = self;
        mailer.modalPresentationStyle = UIModalPresentationCurrentContext;
        [mailer setSubject:[params objectForKey:@"title"]];
        NewsBlurAppDelegate *appDelegate = [NewsBlurAppDelegate sharedAppDelegate];

        NSString *emailBody = [NSString stringWithFormat:@"<p><a href=\"%@\">%@</a></p><hr><br>%@",
                               [[params objectForKey:@"url"] absoluteString],
                               [[params objectForKey:@"title"] absoluteString],
                               [appDelegate.activeStory objectForKey:@"story_content"]];
        [mailer setMessageBody:emailBody isHTML:YES];
        [viewController presentModalViewController:mailer animated:YES];
    } else {
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Failure"
                                                        message:@"Email composition failure. Please try again."
                                                       delegate:nil
                                              cancelButtonTitle:@"OK"
                                              otherButtonTitles:nil];
        [alert show];
    }
}

- (void)mailComposeController:(MFMailComposeViewController *)controller
          didFinishWithResult:(MFMailComposeResult)result
                        error:(NSError *)error
{
    [[controller presentingViewController] dismissModalViewControllerAnimated:YES];
}

@end
