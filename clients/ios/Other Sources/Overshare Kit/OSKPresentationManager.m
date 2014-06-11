//
//  OSKPresentationManager.m
//  Overshare
//
//  Created by Jared Sinclair on 10/13/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKPresentationManager.h"

@import MessageUI;

#import "OSKColors.h"
#import "OSKActivity.h"
#import "OSKActivity_ManagedAccounts.h"
#import "OSKActivitySheetDelegate.h"
#import "OSKActivitiesManager.h"
#import "OSKActivitySheetViewController.h"
#import "OSKAirDropViewController.h"
#import "OSKAppDotNetAuthenticationViewController.h"
#import "OSKApplicationCredential.h"
#import "OSKFacebookPublishingViewController.h"
#import "OSKLogger.h"
#import "OSKMicroblogPublishingViewController.h"
#import "OSKPublishingViewController.h"
#import "OSKSessionController.h"
#import "OSKSessionController_Phone.h"
#import "OSKSessionController_Pad.h"
#import "OSKSession.h"
#import "OSKShareableContent.h"
#import "OSKShareableContentItem.h"
#import "OSKUsernamePasswordViewController.h"
#import "OSKMessageComposeViewController.h"
#import "OSKMailComposeViewController.h"
#import "OSKNavigationController.h"
#import "OSKPresentationManager_Protected.h"
#import "UIViewController+OSKUtilities.h"
#import "UIColor+OSKUtility.h"

NSString * const OSKPresentationOption_ActivityCompletionHandler = @"OSKPresentationOption_ActivityCompletionHandler";
NSString * const OSKPresentationOption_PresentationEndingHandler = @"OSKPresentationOption_PresentationEndingHandler";

static CGFloat OSKPresentationManagerActivitySheetPresentationDuration = 0.33f;
static CGFloat OSKPresentationManagerActivitySheetDismissalDuration = 0.16f;

static NSInteger OSKTextViewFontSize_Phone = 18.0f;
static NSInteger OSKTextViewFontSize_Pad = 20.0f;

@interface OSKPresentationManager ()
<
    OSKSessionControllerDelegate,
    OSKActivitySheetDelegate,
    UIPopoverControllerDelegate
>

// GENERAL
@property (strong, nonatomic, readwrite) NSMutableDictionary *sessionControllers;
@property (strong, nonatomic, readwrite) OSKActivitySheetViewController *activitySheetViewController;
@property (assign, nonatomic, readwrite) BOOL isAnimating;

// IPHONE
@property (strong, nonatomic) UIView *shadowView;
@property (strong, nonatomic) UIViewController *presentingViewController;
@property (strong, nonatomic) UIViewController *parentMostViewController;

// IPAD
@property (strong, nonatomic, readwrite) UIPopoverController *popoverController;
@property (assign, nonatomic, readonly) BOOL isPresentingViaPopover;

@end

#define USE_UNDOCUMENTED_ANIMATION_CURVE 0

@implementation OSKPresentationManager

+ (instancetype)sharedInstance {
    static dispatch_once_t once;
    static OSKPresentationManager * sharedInstance;
    dispatch_once(&once, ^ { sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _sessionControllers = [[NSMutableDictionary alloc] init];
    }
    return self;
}

#pragma mark - Public Methods

- (void)presentActivitySheetForContent:(OSKShareableContent *)content
              presentingViewController:(UIViewController *)presentingViewController
                               options:(NSDictionary *)options {
    
    [self setPresentingViewController:presentingViewController];
    
    NSArray *activities = nil;
    OSKActivitiesManager *manager = [OSKActivitiesManager sharedInstance];
    activities = [manager validActivitiesForContent:content options:options];
    
    OSKSession *session = [[OSKSession alloc] initWithPresentationEndingHandler:options[OSKPresentationOption_PresentationEndingHandler]
                                                      activityCompletionHandler:options[OSKPresentationOption_ActivityCompletionHandler]];
    OSKActivitySheetViewController *sheet = nil;
    sheet = [[OSKActivitySheetViewController alloc] initWithSession:session activities:activities delegate:self usePopoverLayout:NO];
    [sheet setTitle:content.title];
    
    [self presentSheet:sheet fromViewController:presentingViewController];
}

- (void)presentActivitySheetForContent:(OSKShareableContent *)content
              presentingViewController:(UIViewController *)presentingViewController
                       popoverFromRect:(CGRect)rect inView:(UIView *)view
              permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections
                              animated:(BOOL)animated
                               options:(NSDictionary *)options {
    
    [self setPresentingViewController:presentingViewController];
    
    NSArray *activities = nil;
    OSKActivitiesManager *manager = [OSKActivitiesManager sharedInstance];
    activities = [manager validActivitiesForContent:content options:options];
    
    OSKSession *session = [[OSKSession alloc] initWithPresentationEndingHandler:options[OSKPresentationOption_PresentationEndingHandler]
                                                      activityCompletionHandler:options[OSKPresentationOption_ActivityCompletionHandler]];
    
    OSKActivitySheetViewController *sheet = nil;
    sheet = [[OSKActivitySheetViewController alloc] initWithSession:session activities:activities delegate:self usePopoverLayout:YES];
    [sheet setTitle:content.title];
    
    [self setActivitySheetViewController:sheet];
    
    UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:sheet];
    [self setPopoverController:popover];
    [popover setDelegate:self];
    [popover setBackgroundColor:[self color_translucentBackground]];
    
    [popover presentPopoverFromRect:rect inView:view permittedArrowDirections:arrowDirections animated:animated];
}

- (void)presentActivitySheetForContent:(OSKShareableContent *)content
              presentingViewController:(UIViewController *)presentingViewController
              popoverFromBarButtonItem:(UIBarButtonItem *)item
              permittedArrowDirections:(UIPopoverArrowDirection)arrowDirections
                              animated:(BOOL)animated
                               options:(NSDictionary *)options {
    
    [self setPresentingViewController:presentingViewController];
    
    NSArray *activities = nil;
    OSKActivitiesManager *manager = [OSKActivitiesManager sharedInstance];
    activities = [manager validActivitiesForContent:content options:options];
    
    OSKSession *session = [[OSKSession alloc] initWithPresentationEndingHandler:options[OSKPresentationOption_PresentationEndingHandler]
                                                      activityCompletionHandler:options[OSKPresentationOption_ActivityCompletionHandler]];
    
    OSKActivitySheetViewController *sheet = nil;
    sheet = [[OSKActivitySheetViewController alloc] initWithSession:session activities:activities delegate:self usePopoverLayout:YES];
    [sheet setTitle:content.title];
    
    [self setActivitySheetViewController:sheet];
    
    UIPopoverController *popover = [[UIPopoverController alloc] initWithContentViewController:sheet];
    [self setPopoverController:popover];
    [popover setDelegate:self];
    [popover setBackgroundColor:[self color_translucentBackground]];
    
    [popover presentPopoverFromBarButtonItem:item permittedArrowDirections:arrowDirections animated:animated];
}

#pragma mark - Presentation & Dismissal

- (void)presentSheet:(OSKActivitySheetViewController *)sheet
  fromViewController:(UIViewController *)presentingViewController {
    
    if ([self isPresenting] == NO) {
        [self setActivitySheetViewController:sheet];
        [self setIsAnimating:YES];
        self.parentMostViewController = [UIViewController osk_parentMostViewControllerForPresentingViewController:presentingViewController];
        [self setupShadowView:self.parentMostViewController.view];
        
        CGFloat sheetHeight = [sheet visibleSheetHeightForCurrentLayout];
        CGRect targetFrame = self.parentMostViewController.view.bounds;
        CGRect initialFrame = targetFrame;
        initialFrame.origin.y += sheetHeight;
        
        [sheet.view setFrame:initialFrame];
        [sheet viewWillAppear:YES];
        [self.parentMostViewController.view addSubview:sheet.view];
        
#if USE_UNDOCUMENTED_ANIMATION_CURVE == 1
        
        [UIView beginAnimations:nil context:NULL];
        [UIView setAnimationDuration:OSKPresentationManagerActivitySheetPresentationDuration];
        [UIView setAnimationCurve:7]; // This is the curve used by action sheets and the keyboard on iOS 7.0 and later.
        [UIView setAnimationBeginsFromCurrentState:YES];
        [sheet.view setFrame:targetFrame];
        [UIView commitAnimations];
        
        [UIView
         animateWithDuration:OSKPresentationManagerActivitySheetPresentationDuration
         delay:0
         options:UIViewAnimationOptionCurveLinear
         animations:^{
             [self.shadowView setAlpha:1.0];
         } completion:^(BOOL finished) {
             [sheet viewDidAppear:YES];
             [self setIsAnimating:NO];
         }];
#else
        [UIView
         animateWithDuration:OSKPresentationManagerActivitySheetPresentationDuration
         delay:0
         options:UIViewAnimationOptionCurveEaseOut
         animations:^{
             [sheet.view setFrame:targetFrame];
             [self.shadowView setAlpha:1.0];
         } completion:^(BOOL finished) {
             [sheet viewDidAppear:YES];
             [self setIsAnimating:NO];
         }];
#endif
        
        
        
    } else {
        OSKLog(@"Attempting to present a second activity sheet while the first is still visible.");
    }
}

- (void)dismissActivitySheet:(void(^)(void))completion {
    
    if ([self isPresentingViaPopover]) {
        [self dismissActivitySheet_Pad:completion];
    } else {
        [self dismissActivitySheet_Phone:completion];
    }
}

- (void)dismissActivitySheet_Phone:(void(^)(void))completion {
    if ([self isAnimating] == NO && [self isPresenting] == YES) {
        [self setIsAnimating:YES];
        OSKActivitySheetViewController *sheet = self.activitySheetViewController;
        CGRect targetFrame = sheet.view.frame;
        targetFrame.origin.y += [sheet visibleSheetHeightForCurrentLayout];
        [sheet viewWillDisappear:YES];
        [UIView animateWithDuration:OSKPresentationManagerActivitySheetDismissalDuration delay:0 options:UIViewAnimationOptionCurveEaseIn animations:^{
            [sheet.view setFrame:targetFrame];
            [self.shadowView setAlpha:0];
        } completion:^(BOOL finished) {
            [sheet.view removeFromSuperview];
            [sheet viewDidDisappear:YES];
            [self tearDownShadowView];
            [self setActivitySheetViewController:nil];
            [self setPresentingViewController:nil];
            [self setIsAnimating:NO];
            if (completion) {
                completion();
            }
        }];
    }
}

- (void)dismissActivitySheet_Pad:(void(^)(void))completion {
    if (self.isAnimating == NO) {
        [self setIsAnimating:YES];
        [self.popoverController dismissPopoverAnimated:YES];
        [self setActivitySheetViewController:nil];
        [self setPopoverController:nil];
        [self setPresentingViewController:nil];
        __weak OSKPresentationManager *weakSelf = self;
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 0.35 * NSEC_PER_SEC), dispatch_get_main_queue(), ^{
            [weakSelf setIsAnimating:NO];
            if (completion) {
                completion();
            }
        });
    }
}

#pragma mark - Sessions

- (void)beginSessionWithSelectedActivity:(OSKActivity *)activity
                presentingViewController:(UIViewController *)presentingViewController
                                 options:(NSDictionary *)options {
    
    OSKSession *session = [[OSKSession alloc] initWithPresentationEndingHandler:options[OSKPresentationOption_PresentationEndingHandler]
                                                      activityCompletionHandler:options[OSKPresentationOption_ActivityCompletionHandler]];
    [self _proceedWithSession:session
             selectedActivity:activity
     presentingViewController:presentingViewController
            popoverController:nil];
}

- (void)_proceedWithSession:(OSKSession *)session
           selectedActivity:(OSKActivity *)activity
   presentingViewController:(UIViewController *)presentingViewController
          popoverController:(UIPopoverController *)popoverController {
    
    OSKSessionController *sessionController = nil;
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        sessionController = [[OSKSessionController_Phone alloc] initWithActivity:activity
                                                                      session:session
                                                                     delegate:self
                                                     presentingViewController:presentingViewController];
    }
    else {
        sessionController = [[OSKSessionController_Pad alloc] initWithActivity:activity
                                                                    session:session
                                                                   delegate:self
                                                          popoverController:popoverController
                                                   presentingViewController:presentingViewController];
    }
    
    if ([self isPresentingViaPopover]) {
        if ([[activity.class activityType] isEqualToString:OSKActivityType_iOS_AirDrop] == NO) {
            [self dismissActivitySheet:nil];
        }
    }
    
    [self.sessionControllers setObject:sessionController forKey:session.sessionIdentifier];
    [sessionController start];
}

#pragma mark - Popover Delegate

- (void)popoverControllerDidDismissPopover:(UIPopoverController *)popoverController {
    
    OSKPresentationEndingHandler handler = [self.activitySheetViewController.session.presentationEndingHandler copy];
    [self setPopoverController:nil];
    [self setActivitySheetViewController:nil];
    [self setIsAnimating:NO]; // just in case
    if (handler) {
        handler(OSKPresentationEnding_Cancelled, nil);
    }
}

- (void)popoverController:(UIPopoverController *)popoverController
willRepositionPopoverToRect:(inout CGRect *)rect
                   inView:(inout UIView *__autoreleasing *)view {
    
    if ([self.viewControllerDelegate respondsToSelector:@selector(presentationManager:willRepositionPopoverToRect:inView:)]) {
        [self.viewControllerDelegate presentationManager:self willRepositionPopoverToRect:rect inView:view];
    }
}

#pragma mark - Convenience

- (BOOL)isPresentingViaPopover {
    return (self.popoverController != nil);
}

- (BOOL)isPresenting {
    return (self.activitySheetViewController != nil);
}

- (void)setupShadowView:(UIView *)superview {
    if (self.shadowView == nil) {
        self.shadowView = [[UIView alloc] initWithFrame:superview.bounds];
        self.shadowView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.shadowView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.25];
        self.shadowView.alpha = 0;
        [superview addSubview:self.shadowView];
    }
}

- (void)tearDownShadowView {
    [self.shadowView removeFromSuperview];
    self.shadowView = nil;
}

#pragma mark - Activity Sheet Delegate

- (void)activitySheet:(OSKActivitySheetViewController *)viewController didSelectActivity:(OSKActivity *)activity {

    [self _proceedWithSession:viewController.session
             selectedActivity:activity
     presentingViewController:self.presentingViewController
            popoverController:self.popoverController];
}

- (void)activitySheetDidCancel:(OSKActivitySheetViewController *)viewController {
    
    OSKSession *session = viewController.session;
    OSKSessionController *sessionController = [self.sessionControllers objectForKey:session.sessionIdentifier];
    if (sessionController) {
        [sessionController dismissViewControllers];
        [self.sessionControllers removeObjectForKey:session.sessionIdentifier];
    }
    [self dismissActivitySheet:^{
        if (session.presentationEndingHandler) {
            session.presentationEndingHandler(OSKPresentationEnding_Cancelled, nil);
        }
    }];
}

#pragma mark - Styles

- (OSKActivitySheetViewControllerStyle)sheetStyle {
    OSKActivitySheetViewControllerStyle style;
    if ([self.styleDelegate respondsToSelector:@selector(osk_activitySheetStyle)]) {
        style = [self.styleDelegate osk_activitySheetStyle];
    } else {
        style = OSKActivitySheetViewControllerStyle_Light;
    }
    return style;
}

- (BOOL)toolbarsUseUnjustifiablyBorderlessButtons {
    BOOL useBorders = YES;
    if ([self.styleDelegate respondsToSelector:@selector(osk_toolbarsUseUnjustifiablyBorderlessButtons)]) {
        useBorders = [self.styleDelegate osk_toolbarsUseUnjustifiablyBorderlessButtons];
    }
    return useBorders;
}

- (UIImage *)alternateIconForActivityType:(NSString *)type idiom:(UIUserInterfaceIdiom)idiom {
    UIImage *image = nil;
    if ([self.styleDelegate respondsToSelector:@selector(osk_alternateIconForActivityType:idiom:)]) {
        image = [self.styleDelegate osk_alternateIconForActivityType:type idiom:idiom];
    }
    return image;
}

- (BOOL)allowLinkShorteningButton {
    BOOL shorten = YES;
    if ([self.styleDelegate respondsToSelector:@selector(osk_allowLinkShorteningButton)]) {
        shorten = [self.styleDelegate osk_allowLinkShorteningButton];
    }
    return shorten;
}

- (UIFontDescriptor *)normalFontDescriptor {
    UIFontDescriptor *descriptor = nil;
    if ([self.styleDelegate respondsToSelector:@selector(osk_normalFontDescriptor)]) {
        descriptor = [self.styleDelegate osk_normalFontDescriptor];
    }
    return descriptor;
}

- (UIFontDescriptor *)boldFontDescriptor {
    UIFontDescriptor *descriptor = nil;
    if ([self.styleDelegate respondsToSelector:@selector(osk_boldFontDescriptor)]) {
        descriptor = [self.styleDelegate osk_boldFontDescriptor];
    }
    return descriptor;
}

- (CGFloat)textViewFontSize {
    CGFloat fontSize;
    if ([self.styleDelegate respondsToSelector:@selector(osk_textViewFontSize)]) {
        fontSize = [self.styleDelegate osk_textViewFontSize];
    } else {
        if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
            fontSize = OSKTextViewFontSize_Phone;
        } else {
            fontSize = OSKTextViewFontSize_Pad;
        }
    }
    return fontSize;
}

#pragma mark - Colors

- (UIColor *)color_activitySheetTopLine {
    UIColor *lineColor = nil;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_activitySheetTopLine)]) {
        lineColor = [self.colorDelegate osk_color_activitySheetTopLine];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            lineColor = [UIColor colorWithWhite:0.0 alpha:0.25];
        } else {
            lineColor = [UIColor colorWithWhite:1.0 alpha:0.125];
        }
    }
    return lineColor;
}

- (UIColor *)color_opaqueBackground {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_opaqueBackground)]) {
        color = [self.colorDelegate osk_color_opaqueBackground];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_OpaqueBGColor;
        } else {
            color = OSKDefaultColor_DarkStyle_OpaqueBGColor;
        }
    }
    return color;
}

- (UIColor *)color_translucentBackground {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_translucentBackground)]) {
        color = [self.colorDelegate osk_color_translucentBackground];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_SheetColor;
        } else {
            color = OSKDefaultColor_DarkStyle_SheetColor;
        }
    }
    return color;
}

- (UIColor *)color_toolbarBackground {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_toolbarBackground)]) {
        color = [self.colorDelegate osk_color_toolbarBackground];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_BarColor;
        } else {
            color = OSKDefaultColor_DarkStyle_BarColor;
        }
    }
    return color;
}

- (UIColor *)color_toolbarText {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_toolbarText)]) {
        color = [self.colorDelegate osk_color_toolbarText];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_TextColor;
        } else {
            color = OSKDefaultColor_DarkStyle_TextColor;
        }
    }
    return color;
}

- (UIColor *)color_toolbarBorders {
    UIColor *lineColor = nil;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_toolbarBorders)]) {
        lineColor = [self.colorDelegate osk_color_toolbarBorders];
    } else {
        UIColor *backgroundColor = [self color_toolbarBackground];
        UIColor *contrastingColor = [backgroundColor osk_contrastingColor]; // either b or w
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            lineColor = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.90];
        } else {
            lineColor = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.90];
        }
    }
    return lineColor;
}

- (UIColor *)color_groupedTableViewBackground {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_groupedTableViewBackground)]) {
        color = [self.colorDelegate osk_color_groupedTableViewBackground];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_GroupedTableViewBGColor;
        } else {
            color = OSKDefaultColor_DarkStyle_GroupedTableViewBGColor;
        }
    }
    return color;
}

- (UIColor *)color_groupedTableViewCells {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_groupedTableViewCells)]) {
        color = [self.colorDelegate osk_color_groupedTableViewCells];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_GroupedTableViewCellColor;
        } else {
            color = OSKDefaultColor_DarkStyle_GroupedTableViewCellColor;
        }
    }
    return color;
}

- (UIColor *)color_separators {
    UIColor *lineColor = nil;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_separators)]) {
        lineColor = [self.colorDelegate osk_color_separators];
    } else {
        UIColor *backgroundColor = [self color_opaqueBackground];
        UIColor *contrastingColor = [backgroundColor osk_contrastingColor]; // either b or w
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            lineColor = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.83];
        } else {
            lineColor = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.83];
        }
    }
    return lineColor;
}

- (UIColor *)color_action {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_action)]) {
        color = [self.colorDelegate osk_color_action];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_ActionColor;
        } else {
            color = OSKDefaultColor_DarkStyle_ActionColor;
        }
    }
    return color;
}

- (UIColor *)color_text {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_text)]) {
        color = [self.colorDelegate osk_color_text];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_TextColor;
        } else {
            color = OSKDefaultColor_DarkStyle_TextColor;
        }
    }
    return color;
}

- (UIColor *)color_textViewBackground {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_textViewBackground)]) {
        color = [self.colorDelegate osk_color_textViewBackground];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = OSKDefaultColor_LightStyle_OpaqueBGColor;
        } else {
            color = OSKDefaultColor_DarkStyle_OpaqueBGColor;
        }
    }
    return color;
}

- (UIColor *)color_pageIndicatorColor_current {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_pageIndicatorColor_current)]) {
        color = [self.colorDelegate osk_color_pageIndicatorColor_current];
    } else {
        UIColor *backgroundColor = [self color_opaqueBackground];
        UIColor *contrastingColor = [backgroundColor osk_contrastingColor]; // either b or w
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.33];
        } else {
            color = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.33];
        }
    }
    return color;
}

- (UIColor *)color_pageIndicatorColor_other {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_pageIndicatorColor_other)]) {
        color = [self.colorDelegate osk_color_pageIndicatorColor_other];
    } else {
        UIColor *backgroundColor = [self color_opaqueBackground];
        UIColor *contrastingColor = [backgroundColor osk_contrastingColor]; // either b or w
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.75];
        } else {
            color = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.75];
        }
    }
    return color;
}

- (UIColor *)color_cancelButtonColor_BackgroundHighlighted {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_cancelButtonColor_BackgroundHighlighted)]) {
        color = [self.colorDelegate osk_color_cancelButtonColor_BackgroundHighlighted];
    } else {
        OSKActivitySheetViewControllerStyle style = [self sheetStyle];
        if (style == OSKActivitySheetViewControllerStyle_Light) {
            color = [UIColor colorWithWhite:0.5 alpha:0.25];
        } else {
            color = [UIColor colorWithWhite:0.5 alpha:0.25];
        }
    }
    return color;
}

- (UIColor *)color_hashtags {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_hashtags)]) {
        color = [self.colorDelegate osk_color_hashtags];
    } else {
        UIColor *backgroundColor = [self color_opaqueBackground];
        UIColor *contrastingColor = [backgroundColor osk_contrastingColor]; // either b or w
        color = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.5];
    }
    return color;
}

- (UIColor *)color_mentions {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_mentions)]) {
        color = [self.colorDelegate osk_color_mentions];
    } else {
        color = [self color_action];
    }
    return color;
}

- (UIColor *)color_links {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_links)]) {
        color = [self.colorDelegate osk_color_links];
    } else {
        color = [self color_action];
    }
    return color;
}

- (UIColor *)color_characterCounter_normal {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_characterCounter_normal)]) {
        color = [self.colorDelegate osk_color_characterCounter_normal];
    } else {
        UIColor *backgroundColor = [self color_opaqueBackground];
        UIColor *contrastingColor = [backgroundColor osk_contrastingColor]; // either b or w
        color = [contrastingColor osk_colorByInterpolatingToColor:backgroundColor byFraction:0.5];
    }
    return color;
}

- (UIColor *)color_characterCounter_warning {
    UIColor *color;
    if ([self.colorDelegate respondsToSelector:@selector(osk_color_characterCounter_warning)]) {
        color = [self.colorDelegate osk_color_characterCounter_warning];
    } else {
        color = [UIColor redColor];
    }
    return color;
}

#pragma mark - Localization

- (NSString *)localizedText_ActionButtonTitleForPublishingActivity:(NSString *)activityType {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_ActionButtonTitleForPublishingActivity:)]) {
        text = [self.localizationDelegate osk_localizedText_ActionButtonTitleForPublishingActivity:activityType];
    }
    if (text == nil) {
        if ([activityType isEqualToString:OSKActivityType_API_AppDotNet]) {
            text = @"Post";
        }
        else if ([activityType isEqualToString:OSKActivityType_iOS_Twitter]) {
            text = @"Tweet";
        }
        else if ([activityType isEqualToString:OSKActivityType_iOS_Facebook]) {
            text = @"Post";
        }
        else {
            text = @"Send";
        }
    }
    return text;
}

- (NSString *)localizedText_Cancel {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Cancel)]) {
        text = [self.localizationDelegate osk_localizedText_Cancel];
    }
    if (text == nil) {
        text = @"Cancel";
    }
    return text;
}

- (NSString *)localizedText_Done {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Done)]) {
        text = [self.localizationDelegate osk_localizedText_Done];
    }
    if (text == nil) {
        text = @"Done";
    }
    return text;
}

- (NSString *)localizedText_Add {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Add)]) {
        text = [self.localizationDelegate osk_localizedText_Add];
    }
    if (text == nil) {
        text = @"Add";
    }
    return text;
}

- (NSString *)localizedText_Username {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Username)]) {
        text = [self.localizationDelegate osk_localizedText_Username];
    }
    if (text == nil) {
        text = @"username";
    }
    return text;
}

- (NSString *)localizedText_Email {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Email)]) {
        text = [self.localizationDelegate osk_localizedText_Email];
    }
    if (text == nil) {
        text = @"email";
    }
    return text;
}

- (NSString *)localizedText_Password {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Password)]) {
        text = [self.localizationDelegate osk_localizedText_Password];
    }
    if (text == nil) {
        text = @"password";
    }
    return text;
}

- (NSString *)localizedText_SignOut {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_SignOut)]) {
        text = [self.localizationDelegate osk_localizedText_SignOut];
    }
    if (text == nil) {
        text = @"Sign Out";
    }
    return text;
}

- (NSString *)localizedText_SignIn {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_SignIn)]) {
        text = [self.localizationDelegate osk_localizedText_SignIn];
    }
    if (text == nil) {
        text = @"Sign In";
    }
    return text;
}

- (NSString *)localizedText_Accounts {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Accounts)]) {
        text = [self.localizationDelegate osk_localizedText_Accounts];
    }
    if (text == nil) {
        text = @"Accounts";
    }
    return text;
}

- (NSString *)localizedText_AreYouSure {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_AreYouSure)]) {
        text = [self.localizationDelegate osk_localizedText_AreYouSure];
    }
    if (text == nil) {
        text = @"Are You Sure?";
    }
    return text;
}

- (NSString *)localizedText_NoAccountsFound {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_NoAccountsFound)]) {
        text = [self.localizationDelegate osk_localizedText_NoAccountsFound];
    }
    if (text == nil) {
        text = @"No Accounts Found";
    }
    return text;
}

- (NSString *)localizedText_YouCanSignIntoYourAccountsViaTheSettingsApp {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_YouCanSignIntoYourAccountsViaTheSettingsApp)]) {
        text = [self.localizationDelegate osk_localizedText_YouCanSignIntoYourAccountsViaTheSettingsApp];
    }
    if (text == nil) {
        text = @"You can sign into system accounts like Twitter and Facebook via the settings app.";
    }
    return text;
}

- (NSString *)localizedText_Okay {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Okay)]) {
        text = [self.localizationDelegate osk_localizedText_Okay];
    }
    if (text == nil) {
        text = @"Okay";
    }
    return text;
}

- (NSString *)localizedText_AccessNotGrantedForSystemAccounts_Title {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_AccessNotGrantedForSystemAccounts_Title)]) {
        text = [self.localizationDelegate osk_localizedText_AccessNotGrantedForSystemAccounts_Title];
    }
    if (text == nil) {
        text = @"Couldn’t Access Your Accounts";
    }
    return text;
}

- (NSString *)localizedText_AccessNotGrantedForSystemAccounts_Message {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_AccessNotGrantedForSystemAccounts_Message)]) {
        text = [self.localizationDelegate osk_localizedText_AccessNotGrantedForSystemAccounts_Message];
    }
    if (text == nil) {
        text = @"You have previously denied this app access to your accounts. Please head to the Settings app’s Privacy options to enable sharing.";
    }
    return text;
}

- (NSString *)localizedText_UnableToSignIn {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_UnableToSignIn)]) {
        text = [self.localizationDelegate osk_localizedText_UnableToSignIn];
    }
    if (text == nil) {
        text = @"Unable to Sign In";
    }
    return text;
}

- (NSString *)localizedText_PleaseDoubleCheckYourUsernameAndPasswordAndTryAgain {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_PleaseDoubleCheckYourUsernameAndPasswordAndTryAgain)]) {
        text = [self.localizationDelegate osk_localizedText_PleaseDoubleCheckYourUsernameAndPasswordAndTryAgain];
    }
    if (text == nil) {
        text = @"Please double check your username and password and try again.";
    }
    return text;
}

- (NSString *)localizedText_FacebookAudience_Public {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_FacebookAudience_Public)]) {
        text = [self.localizationDelegate osk_localizedText_FacebookAudience_Public];
    }
    if (text == nil) {
        text = @"Public";
    }
    return text;
}

- (NSString *)localizedText_FacebookAudience_Friends {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_FacebookAudience_Friends)]) {
        text = [self.localizationDelegate osk_localizedText_FacebookAudience_Friends];
    }
    if (text == nil) {
        text = @"Friends";
    }
    return text;
}

- (NSString *)localizedText_FacebookAudience_OnlyMe {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_FacebookAudience_OnlyMe)]) {
        text = [self.localizationDelegate osk_localizedText_FacebookAudience_OnlyMe];
    }
    if (text == nil) {
        text = @"Only Me";
    }
    return text;
}

- (NSString *)localizedText_FacebookAudience_Audience {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_FacebookAudience_Audience)]) {
        text = [self.localizationDelegate osk_localizedText_FacebookAudience_Audience];
    }
    if (text == nil) {
        text = @"Audience";
    }
    return text;
}

- (NSString *)localizedText_OptionalActivities {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_OptionalActivities)]) {
        text = [self.localizationDelegate osk_localizedText_OptionalActivities];
    }
    if (text == nil) {
        text = @"Visible Activities";
    }
    return text;
}

- (NSString *)localizedText_ShortenLinks {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_ShortenLinks)]) {
        text = [self.localizationDelegate osk_localizedText_ShortenLinks];
    }
    if (text == nil) {
        text = @"Shorten Links";
    }
    return text;
}

- (NSString *)localizedText_LinksShortened {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_LinksShortened)]) {
        text = [self.localizationDelegate osk_localizedText_LinksShortened];
    }
    if (text == nil) {
        text = @"Long links shortened.";
    }
    return text;
}

- (NSString *)localizedText_Remove {
    NSString *text = nil;
    if ([self.localizationDelegate respondsToSelector:@selector(osk_localizedText_Remove)]) {
        text = [self.localizationDelegate osk_localizedText_Remove];
    }
    if (text == nil) {
        text = @"Remove";
    }
    return text;
}

#pragma mark - View Controllers

- (UIViewController <OSKPurchasingViewController> *)purchasingViewControllerForActivity:(OSKActivity *)activity {
    UIViewController <OSKPurchasingViewController> *viewController = nil;
    if ([self.viewControllerDelegate respondsToSelector:@selector(osk_purchasingViewControllerForActivity:)]) {
        viewController = [self.viewControllerDelegate osk_purchasingViewControllerForActivity:activity];
    }
    NSAssert((viewController != nil), @"Purchasing view controllers *must* be vended by the ActivitiesManager's viewControllerDelegate and cannot be nil");
    return viewController;
}

- (UIViewController <OSKAuthenticationViewController> *)authenticationViewControllerForActivity:(OSKActivity *)activity {
    UIViewController <OSKAuthenticationViewController> *viewController = nil;
    if ([self.viewControllerDelegate respondsToSelector:@selector(osk_authenticationViewControllerForActivity:)]) {
        viewController = [self.viewControllerDelegate osk_authenticationViewControllerForActivity:activity];
    }
    if (viewController == nil) {
        if ([activity.class authenticationViewControllerType] == OSKManagedAccountAuthenticationViewControllerType_DefaultUsernamePasswordViewController) {
            viewController = [[OSKUsernamePasswordViewController alloc] initWithStyle:UITableViewStyleGrouped];
        }
        else if ([[activity.class activityType] isEqualToString:OSKActivityType_API_AppDotNet]) {
            OSKActivitiesManager *manager = [OSKActivitiesManager sharedInstance];
            OSKApplicationCredential *appCredential = [manager applicationCredentialForActivityType:[activity.class activityType]];
            viewController = [[OSKAppDotNetAuthenticationViewController alloc] initWithApplicationCredential:appCredential];
        }
    }
    return viewController;
}

- (UIViewController <OSKPublishingViewController> *)publishingViewControllerForActivity:(OSKActivity *)activity {
    UIViewController <OSKPublishingViewController> *viewController = nil;
    if ([self.viewControllerDelegate respondsToSelector:@selector(osk_publishingViewControllerForActivity:)]) {
        viewController = [self.viewControllerDelegate osk_publishingViewControllerForActivity:activity];
    }
    if (viewController == nil) {
        switch ([activity.class publishingMethod]) {
            case OSKPublishingMethod_ViewController_Microblogging: {
                NSString *nibName = NSStringFromClass([OSKMicroblogPublishingViewController class]);
                viewController = [[OSKMicroblogPublishingViewController alloc] initWithNibName:nibName bundle:nil];
            } break;
            case OSKPublishingMethod_ViewController_Blogging: {
                // alloc/init a blogging view controller
            } break;
            case OSKPublishingMethod_ViewController_System: {
                if ([activity.contentItem.itemType isEqualToString:OSKShareableContentItemType_Email]) {
                    viewController = [[OSKMailComposeViewController alloc] initWithNibName:nil bundle:nil];
                }
                else if ([activity.contentItem.itemType isEqualToString:OSKShareableContentItemType_SMS]) {
                    viewController = [[OSKMessageComposeViewController alloc] initWithNibName:nil bundle:nil];
                }
                else if ([activity.contentItem.itemType isEqualToString:OSKShareableContentItemType_AirDrop]) {
                    viewController = [[OSKAirDropViewController alloc] initWithAirDropItem:(OSKAirDropContentItem *)activity.contentItem];
                }
            } break;
            case OSKPublishingMethod_ViewController_Facebook: {
                NSString *nibName = NSStringFromClass([OSKFacebookPublishingViewController class]);
                viewController = [[OSKFacebookPublishingViewController alloc] initWithNibName:nibName bundle:nil];
            } break;
            case OSKPublishingMethod_ViewController_Bespoke: {
                NSAssert(NO, @"OSKPresentationManager: Activities with a bespoke publishing view controller require the OSKPresentationManager's delegate to vend the appropriate publishing view controller via osk_publishingViewControllerForActivity:");
            } break;
            case OSKPublishingMethod_URLScheme:
            case OSKPublishingMethod_None: {
                NSAssert(NO, @"OSKPresentationManager: Attempting to present a publishing view controller for an activity that does not require one.");
            } break;
            default:
                break;
        }
    }
    return viewController;
}

#pragma mark - Flow Controller Delegate

- (void)sessionController:(OSKSessionController *)controller
willPresentViewController:(UIViewController *)viewController
   inNavigationController:(OSKNavigationController *)navigationController {
    
    if ([self.viewControllerDelegate respondsToSelector:@selector(presentationManager:willPresentViewController:inNavigationController:)]) {
        [self.viewControllerDelegate presentationManager:self willPresentViewController:viewController inNavigationController:navigationController];
    }
}

- (void)sessionController:(OSKSessionController *)controller willPresentSystemViewController:(UIViewController *)systemViewController {
    if ([self.viewControllerDelegate respondsToSelector:@selector(presentationManager:willPresentSystemViewController:)]) {
        [self.viewControllerDelegate presentationManager:self willPresentSystemViewController:systemViewController];
    }
}

- (void)sessionControllerDidBeginPerformingActivity:(OSKSessionController *)controller hasDismissedAllViewControllers:(BOOL)hasDismissed {
    
    if (hasDismissed) {
        OSKSession *session = controller.session;
        OSKActivity *selectedActivity = controller.activity;
        if ([self isPresenting]) {
            [self dismissActivitySheet:^{
                if (session.presentationEndingHandler) {
                    session.presentationEndingHandler(OSKPresentationEnding_ProceededWithActivity, selectedActivity);
                }
            }];
        } else {
            if (session.presentationEndingHandler) {
                session.presentationEndingHandler(OSKPresentationEnding_ProceededWithActivity, selectedActivity);
            }
        }
    }
}

- (void)sessionControllerDidFinish:(OSKSessionController *)controller successful:(BOOL)successful error:(NSError *)error {
    
    OSKSession *session = controller.session;
    OSKActivity *selectedActivity = controller.activity;
    
    [self.sessionControllers removeObjectForKey:session.sessionIdentifier];
    
    if (session.activityCompletionHandler) {
        session.activityCompletionHandler(selectedActivity, successful, error);
    }

    // This check is not strictly necessary, since in practice the activity sheets are
    // always dismissed when the activity *begins* to perform, or earlier (on iPad).
    // In the interests of future changes, we'll check for a need to dismiss the activity
    // sheet here.
    if ([self isPresenting] && [session.sessionIdentifier isEqualToString:self.activitySheetViewController.session.sessionIdentifier]) {
        [self dismissActivitySheet:^{
            if (session.presentationEndingHandler) {
                session.presentationEndingHandler(OSKPresentationEnding_ProceededWithActivity, selectedActivity);
            }
        }];
    }
}

- (void)sessionControllerDidCancel:(OSKSessionController *)controller {
    [self.sessionControllers removeObjectForKey:controller.session.sessionIdentifier];
    
    /*
     On iPhone: Do NOT dismiss the activity sheet here. The user may have cancelled the session controller
     because they tapped the wrong activity. If they want to dismiss the activity sheet,
     they will indicate this intention directly via the "Cancel" button on the activity sheet.
     
     On iPad: The activity sheet popover will already have been dismissed by the time we get here, so there's
     no need to dismiss it.
     */
    
    if ([self isPresenting] == NO) {
        // Don't perform the presentation ending block unless the activity sheet
        // has already been dismissed. E.g., on iPad, the session controller
        // continues to present authentication and publishing view controllers after
        // the activity sheet popover has been dismissed.
        OSKSession *session = controller.session;
        if (session.presentationEndingHandler) {
            OSKActivity *selectedActivity = controller.activity;
            session.presentationEndingHandler(OSKPresentationEnding_Cancelled, selectedActivity);
        }
    }
}

#pragma mark - Protected

- (BOOL)_navigationControllersShouldManageTheirOwnAppearanceCustomization {
    return ![self.styleDelegate respondsToSelector:@selector(osk_customizeNavigationControllerAppearance:)];
}

- (void)_customizeNavigationControllerAppearance:(OSKNavigationController *)navigationController {
    if ([self.styleDelegate respondsToSelector:@selector(osk_customizeNavigationControllerAppearance:)]) {
        [self.styleDelegate osk_customizeNavigationControllerAppearance:navigationController];
    }
}

@end




