/* Copyright 2012 IGN Entertainment, Inc. */

#import "ShareThis.h"
#import "InstapaperActivityItem.h"
#import "PocketActivityItem.h"
#import "TwitterService.h"
#import "FacebookService.h"
#import "EmailService.h"
#import "MessageService.h"
#import "InstapaperService.h"
#import "PocketService.h"
#import "ReadabilityService.h"
#import "ReadabilityActivityItem.h"

static ShareThis *_manager;
NSString *const AppDidBecomeActiveNotificationName = @"appDidBecomeActive";
NSString *const AppWillTerminateNotificationName = @"appWillTerminate";

@interface ShareThis () <UIActionSheetDelegate>
@property (nonatomic, strong) UIActionSheet *actionSheet;
@property (nonatomic, strong) NSDictionary *params;
@property (nonatomic, strong) UIViewController *viewControllerToShowServiceOn;
@property (nonatomic) STContentType contentType;
@property (nonatomic, strong) NSMutableArray *actionSheetServiceButtonList;
@end

@implementation ShareThis

+ (ShareThis *)sharedManager
{
    if (!_manager) {
        _manager = [[ShareThis alloc] init];
    }
    return _manager;
}

// Check if a social framework class is available
// If available, then device is ios6+
+ (BOOL)isSocialAvailable
{
    return NSClassFromString(@"SLComposeViewController") != nil;
}

// Save the view controller to later use to show service on
- (void)saveViewController:(UIViewController *)viewController
{
    self.viewControllerToShowServiceOn = viewController;
}

// Save dictionary with given parameters
// Need this so UIActionSheet delegate can have access to the parameters
- (NSDictionary *)saveDictionaryWithUrl:(NSURL *)url title:(NSString *)title image:(UIImage *)image
{
    self.params = [[NSDictionary alloc] initWithObjectsAndKeys:
     url ? url : @"", @"url",
     title ? title : @"", @"title",
     image, @"image",
     nil];
    
    return self.params;
}

#pragma mark Removing / Deallocating
- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"appDidBecomeActive" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"appWillTerminate" object:nil];
}

#pragma mark Sharing
// Perform the type of sharing service with passed in parameters
+ (void)shareURL:(NSURL *) url title:(NSString *)title image:(UIImage *)image withService:(STServiceType)service  onViewController:(UIViewController *)viewController
{
    // Save the view to later use it to show/dismiss services
    [[ShareThis sharedManager] saveViewController:viewController];
    // Save the params to share
    NSDictionary *params = [[ShareThis sharedManager] saveDictionaryWithUrl:url title:title image:image];
    switch (service) {
        case STServiceTypeFacebook:
            [FacebookService shareWithParams:params onViewController:viewController];
            break;
        case STServiceTypeTwitter:
            [TwitterService shareWithParams:params onViewController:viewController];
            break;
        case STServiceTypeMail:
            [EmailService shareWithParams:params onViewController:viewController];
            break;
        case STServiceTypeMessage:
            [MessageService shareWithParams:params onViewController:viewController];
            break;
        case STServiceTypeInstapaper:
            [InstapaperService shareWithParams:params onViewController:viewController];
            break;
        case STServiceTypePocket:
            if ([[ShareThis sharedManager] pocketAPIKey]) {
                [PocketService shareWithParams:params onViewController:viewController];
            }
            break;
        case STServiceTypeReadability:
            if ([[ShareThis sharedManager] readabilityKey] && [[ShareThis sharedManager] readabilitySecret]) {
                [ReadabilityService shareWithParams:params onViewController:viewController];
            }
            break;
        case STServiceTypeServiceCount:
        default:
            break;
    }
}

#pragma mark ActionSheet / ActivityView
+ (void)showShareOptionsToShareUrl:(NSURL *)url title:(NSString *)title image:(UIImage *)image onViewController:(UIViewController *)viewController
{
    [[ShareThis sharedManager] setContentType:STContentTypeAll];
    [[ShareThis sharedManager] showShareOptionsToShareUrl:url title:title image:image onViewController:viewController];
}

+ (void)showShareOptionsToShareUrl:(NSURL *)url title:(NSString *)title image:(UIImage *)image onViewController:(UIViewController *)viewController forTypeOfContent:(STContentType)contentType
{
    [[ShareThis sharedManager] setContentType:contentType];
    [[ShareThis sharedManager] showShareOptionsToShareUrl:url title:title image:image onViewController:viewController];
}

- (void)showShareOptionsToShareUrl:(NSURL *)url title:(NSString *)title image:(UIImage *)image onViewController:(UIViewController *)viewController
{
    // Save the view to later use it to show/dismiss services
    [self saveViewController:viewController];
    // Save the params to share
    [self saveDictionaryWithUrl:url title:title image:image];
    // Show ios6+ activity view if available, if not then use action sheet
    if ([ShareThis isSocialAvailable]) {
        [self showActivityView];
    } else {
        [self showActionSheet];
    }
}

// Show activity view which will handle all services itself with the given parameters
- (void)showActivityView
{
    NSArray *activityItems = [[NSArray alloc] initWithObjects:[self.params objectForKey:@"title"], [self.params objectForKey:@"url"], [self.params objectForKey:@"image"], nil];
    InstapaperActivityItem *instapaperActivity = [[InstapaperActivityItem alloc] init];
    PocketActivityItem *pocketActivity = [[PocketActivityItem alloc] init];
    ReadabilityActivityItem *readabilityActivity = [[ReadabilityActivityItem alloc] init];
    
//    NSArray *applicationActivities;
    NSMutableArray *applicationActivities;
    switch (self.contentType) {
        case STContentTypeAll:
        case STContentTypeArticle:
            applicationActivities = [NSMutableArray arrayWithObject:instapaperActivity];
            
            if (self.pocketAPIKey) {
                [applicationActivities addObject:pocketActivity];
            }
            
            if (self.readabilityKey && self.readabilitySecret) {
                [applicationActivities addObject:readabilityActivity];
            }
            break;
        case STContentTypeVideo:
            applicationActivities = nil;
            break;
        default:
            break;
    }
    
    UIActivityViewController *activityVC =
    [[UIActivityViewController alloc] initWithActivityItems:activityItems
                                      applicationActivities:applicationActivities];
    activityVC.excludedActivityTypes = @[UIActivityTypeAssignToContact, UIActivityTypePostToWeibo, UIActivityTypePrint, UIActivityTypeSaveToCameraRoll];
    [self.viewControllerToShowServiceOn presentViewController:activityVC animated:YES completion:nil];
}

// Show action sheet
- (void)showActionSheet
{
    if (!self.actionSheet) {
        NSMutableArray *buttonTitles;
        
        if ([FacebookService facebookAvailable]) {
            buttonTitles = [[NSMutableArray alloc] initWithObjects:@"Facebook", @"Twitter", @"Email", @"Message", nil];
            if (!self.actionSheetServiceButtonList) {
                self.actionSheetServiceButtonList = [[NSMutableArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:STServiceTypeFacebook],
                                                     [[NSNumber alloc] initWithInt:STServiceTypeTwitter],
                                                     [[NSNumber alloc] initWithInt:STServiceTypeMail],
                                                     [[NSNumber alloc] initWithInt:STServiceTypeMessage], nil];
            }
        } else {
            buttonTitles = [[NSMutableArray alloc] initWithObjects:@"Twitter", @"Email", @"Message", nil];
            self.actionSheetServiceButtonList = [[NSMutableArray alloc] initWithObjects:[[NSNumber alloc] initWithInt:STServiceTypeTwitter],
                                                 [[NSNumber alloc] initWithInt:STServiceTypeMail],
                                                 [[NSNumber alloc] initWithInt:STServiceTypeMessage], nil];
        }
        
        switch (self.contentType) {
            case STContentTypeAll:
            case STContentTypeArticle:
                [buttonTitles addObject:@"Add to Instapaper"];
                if (self.pocketAPIKey) {
                    [buttonTitles addObject:@"Add to Pocket"];
                    [self.actionSheetServiceButtonList addObject:[[NSNumber alloc] initWithInt:STServiceTypePocket]];
                }
                
                if (self.readabilityKey && self.readabilitySecret) {
                    [buttonTitles addObject:@"Add to Readability"];
                    [self.actionSheetServiceButtonList addObject:[[NSNumber alloc] initWithInt:STServiceTypeInstapaper]];
                }
                break;
            case STContentTypeVideo:
                break;
            default:
                break;
        }
        
        self.actionSheet = [[UIActionSheet alloc] initWithTitle:@"Sharing Options"
                                                       delegate:self
                                              cancelButtonTitle:nil
                                         destructiveButtonTitle:nil
                                              otherButtonTitles:nil,
                                                                nil];
        
        for (int i = 0; i < [buttonTitles count]; i++) {
            [self.actionSheet addButtonWithTitle:[buttonTitles objectAtIndex:i]];
        }
        
        [self.actionSheet addButtonWithTitle:@"Close"];
        self.actionSheet.cancelButtonIndex = buttonTitles.count;
        [self.actionSheetServiceButtonList addObject:[[NSNumber alloc] initWithInt:STServiceTypeServiceCount]];
    }
    
    [self.actionSheet showInView:self.viewControllerToShowServiceOn.view];
}

// Call one of the services
- (void)actionSheet:(UIActionSheet *)actionSheet clickedButtonAtIndex:(NSInteger)buttonIndex
{
    STServiceType service = (STServiceType) [[self.actionSheetServiceButtonList objectAtIndex:buttonIndex] intValue];

    switch (service) {
        case STServiceTypeFacebook:
            [FacebookService shareWithParams:self.params onViewController:self.viewControllerToShowServiceOn];
            break;
        case STServiceTypeTwitter:
            [TwitterService shareWithParams:self.params onViewController:self.viewControllerToShowServiceOn];
            break;
        case STServiceTypeMail:
            [EmailService shareWithParams:self.params onViewController:self.viewControllerToShowServiceOn];
            break;
        case STServiceTypeMessage:
            [MessageService shareWithParams:self.params onViewController:self.viewControllerToShowServiceOn];
            break;
        case STServiceTypeInstapaper:
            if (self.contentType == STContentTypeArticle || self.contentType == STContentTypeAll) {
                [InstapaperService shareWithParams:self.params onViewController:self.viewControllerToShowServiceOn];
            }
            break;
        case STServiceTypePocket:
            if ((self.contentType == STContentTypeArticle || self.contentType == STContentTypeAll) && self.pocketAPIKey) {
                [PocketService shareWithParams:self.params onViewController:self.viewControllerToShowServiceOn];
            }
            break;
        case STServiceTypeReadability:
            if ((self.contentType == STContentTypeArticle || self.contentType == STContentTypeAll) && self.readabilityKey && self.readabilitySecret) {
                [ReadabilityService shareWithParams:self.params onViewController:self.viewControllerToShowServiceOn];
            }
            break;
        case STServiceTypeServiceCount:
        default:
            break;
    }
}

- (void)actionSheet:(UIActionSheet *)actionSheet didDismissWithButtonIndex:(NSInteger)buttonIndex
{
    self.actionSheet = nil;
}

+ (void)startSessionWithFacebookURLSchemeSuffix:(NSString *)suffix
                                      pocketAPI:(NSString *)pocketAPI
                                 readabilityKey:(NSString *)readabilityKey
                              readabilitySecret:(NSString *)readabilitySecret
{
    [FacebookService startSessionWithURLSchemeSuffix:suffix];
    [ShareThis sharedManager].pocketAPIKey = pocketAPI;
    [ShareThis sharedManager].readabilityKey = readabilityKey;
    [ShareThis sharedManager].readabilitySecret = readabilitySecret;
}

// Called from AppDelegate's application open url method
+ (BOOL)handleFacebookOpenUrl:(NSURL *) url
{
    // attempt to extract a token from the url
    return [FacebookService handleFacebookOpenUrl:url];
}

@end
