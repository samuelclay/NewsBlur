/* Copyright 2012 IGN Entertainment, Inc. */

#import "FacebookService.h"
#import "FacebookSDK.h"
#import <Social/Social.h>
#import "REComposeViewController.h"

static FacebookService *_manager;

@interface FacebookService () <REComposeViewControllerDelegate>
@property (nonatomic, strong) NSString *urlSchemeSuffix;
@property (strong, nonatomic) NSMutableDictionary *params;
@end

@implementation FacebookService

+ (FacebookService *)sharedManager
{
    if (!_manager) {
        _manager = [[FacebookService alloc] init];
    }
    return _manager;
}

+ (BOOL)facebookAvailable
{
    if ([ShareThis isSocialAvailable]) {
        return YES;
    } else {
        return [FBSession defaultAppID] ? YES : NO;
    }
}

+ (void)shareWithParams:(NSDictionary *)params onViewController:(UIViewController *)viewController
{
    // IOS 6+ services
    if ([ShareThis isSocialAvailable]) {
        __block __weak SLComposeViewController *slComposeSheet = [SLComposeViewController composeViewControllerForServiceType:SLServiceTypeFacebook];
        [slComposeSheet setInitialText:[params objectForKey:@"title"]];
        [slComposeSheet addURL:[params objectForKey:@"url"]];
        [slComposeSheet addImage:[params objectForKey:@"image"]];
        [slComposeSheet setCompletionHandler:^
         (SLComposeViewControllerResult result){
             switch (result) {
                 case SLComposeViewControllerResultCancelled:
                     break;
                 case SLComposeViewControllerResultDone:
                     break;
                 default:
                     break;
             }
         }];
        [viewController presentViewController:slComposeSheet animated:YES completion:nil];
        
    } else {
        // IOS 5 services
        // Check if there is already an active session open
        if (FBSession.activeSession.isOpen) {
            [[self sharedManager] setParams:[[NSMutableDictionary alloc] initWithObjectsAndKeys:[[params objectForKey:@"url"] absoluteString], @"link", [params objectForKey:@"title"], @"name", [params objectForKey:@"image"], @"image", nil]];
            REComposeViewController *composeViewController = [[REComposeViewController alloc] init];
            composeViewController.title = @"Facebook";
            composeViewController.hasAttachment = YES;
            if ([params objectForKey:@"image"]) {
                composeViewController.attachmentImage = [params objectForKey:@"image"];
            }
            composeViewController.delegate = [self sharedManager];
            composeViewController.text = [params objectForKey:@"title"];
            composeViewController.navigationBar.tintColor = [UIColor colorWithRed:59.0/255.0 green:89.0/255.0 blue:152.0/255.0 alpha:1.0];
            
            UIModalPresentationStyle currentPresentationStyle = viewController.modalPresentationStyle;
            viewController.modalPresentationStyle = UIModalPresentationCurrentContext;
            [viewController presentViewController:composeViewController animated:YES completion:nil];
            viewController.modalPresentationStyle = currentPresentationStyle;

        } else {
            // Open active session
            [FacebookService openSessionWithAllowLoginUI:YES];
        }
    }
}

- (void)saveURLSchemeSuffix:(NSString *)suffix
{
    self.urlSchemeSuffix = suffix ? suffix : @"";
}

// Start the facebook session
+ (void)startSessionWithURLSchemeSuffix:(NSString *)suffix
{
    [[FacebookService sharedManager] saveURLSchemeSuffix:suffix];
    [FacebookService openSessionWithAllowLoginUI:NO];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appDidBecomeActive)
                                                 name:AppDidBecomeActiveNotificationName
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(appWillTerminate)
                                                 name:AppWillTerminateNotificationName
                                               object:nil];
}

// Notification called when application becomes active
+ (void)appDidBecomeActive
{
    [FBSession.activeSession handleDidBecomeActive];
}

// Notification called when application will terminate
+ (void)appWillTerminate
{
    [FBSession.activeSession close];
}

// Called from AppDelegate's application open url method
+ (BOOL)handleFacebookOpenUrl:(NSURL *) url
{
    // attempt to extract a token from the url
    return [FBSession.activeSession handleOpenURL:url];
}

// Callback for session changes.
+ (void)sessionStateChanged:(FBSession *)session
                      state:(FBSessionState) state
                      error:(NSError *)error
{
    switch (state) {
        case FBSessionStateOpen:
            if (!error) {
                // We have a valid session
                NSLog(@"Facebook user session found");
            }
            break;
        case FBSessionStateClosed:
            NSLog(@"Closed");
            [FBSession.activeSession closeAndClearTokenInformation];
            break;
        case FBSessionStateClosedLoginFailed:
            NSLog(@"Failed");
            [FBSession.activeSession closeAndClearTokenInformation];
            break;
        default:
            break;
    }

    if (error) {
        UIAlertView *alertView = [[UIAlertView alloc]
                                  initWithTitle:@"Error"
                                  message:error.localizedDescription
                                  delegate:nil
                                  cancelButtonTitle:@"OK"
                                  otherButtonTitles:nil];
        [alertView show];
    }
}

// Opens a Facebook session and optionally shows the login UX.
+ (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI {
    return [[FacebookService sharedManager] openSessionWithAllowLoginUI:allowLoginUI];
}

- (BOOL)openSessionWithAllowLoginUI:(BOOL)allowLoginUI {
    BOOL result = NO;
    
    NSArray *permissions = [[NSArray alloc] initWithObjects:
                            @"publish_stream",
                            nil];

    FBSession *session =
    [[FBSession alloc] initWithAppID:nil
                         permissions:permissions
                     urlSchemeSuffix:self.urlSchemeSuffix
                  tokenCacheStrategy:nil];
    
    if (allowLoginUI ||
        (session.state == FBSessionStateCreatedTokenLoaded)) {
        [FBSession setActiveSession:session];
        [session openWithCompletionHandler:
         ^(FBSession *session, FBSessionState state, NSError *error) {
             [FacebookService sessionStateChanged:session state:state error:error];
         }];
        result = session.isOpen;
    }
    
    return result;
}

+ (void)closeSession {
    [FBSession.activeSession closeAndClearTokenInformation];
}

- (void)publishStory
{
    [FBRequestConnection
     startWithGraphPath:@"me/feed"
     parameters:self.params
     HTTPMethod:@"POST"
     completionHandler:^(FBRequestConnection *connection,
                         id result,
                         NSError *error) {

         if (!error) {
             return;
         }
         
         NSString *alertText = @"Error posting. Please make sure posting permission is allowed in your Facebook account.";
         // Show the result in an alert
         [[[UIAlertView alloc] initWithTitle:@"Result"
                                     message:alertText
                                    delegate:self
                           cancelButtonTitle:@"OK!"
                           otherButtonTitles:nil] show];
     }];
}

#pragma mark REComposeViewControllerDelegate
- (void)composeViewController:(REComposeViewController *)composeViewController didFinishWithResult:(REComposeResult)result
{
    if (result != REComposeResultPosted) {
        return;
    }
    
    // Add user message parameter if user filled it in
    if (![composeViewController.text isEqualToString:@""]) {
        [self.params setObject:composeViewController.text
                        forKey:@"message"];
    }
    
    // Ask for publish_actions permissions in context
    if ([FBSession.activeSession.permissions
         indexOfObject:@"publish_stream"] == NSNotFound) {
        // No permissions found in session, ask for it
        [FBSession.activeSession requestNewPublishPermissions:[NSArray arrayWithObject:@"publish_stream"]
                           defaultAudience:FBSessionDefaultAudienceFriends
                                            completionHandler:^(FBSession *session, NSError *error) {
                                                if (!error) {
                                                    // If permissions granted, publish the story
                                                    [self publishStory];
                                                }
                                            }];
    } else {
        // If permissions present, publish the story
        [self publishStory];
    }
}

@end
