//
//  NBContainerViewController.h
//  NewsBlur
//
//  Created by Roy Yang on 7/24/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <SafariServices/SafariServices.h>

@class NewsBlurAppDelegate;

@interface NBContainerViewController : UIViewController
<UIPopoverControllerDelegate, UIPopoverPresentationControllerDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    BOOL interactiveOriginalTransition;
}

@property (readonly) BOOL storyTitlesOnLeft;
@property (readwrite) BOOL interactiveOriginalTransition;
@property (readonly) int storyTitlesYCoordinate;
@property (readwrite) BOOL originalViewIsVisible;
@property (nonatomic) CALayer *leftBorder;
@property (nonatomic) CALayer *rightBorder;
@property (atomic, strong) IBOutlet NewsBlurAppDelegate *appDelegate;


- (void)syncNextPreviousButtons;

- (void)layoutDashboardScreen;
- (void)layoutFeedDetailScreen;
- (void)adjustFeedDetailScreenForStoryTitles;

- (void)transitionToFeedDetail;
- (void)transitionToFeedDetail:(BOOL)resetLayout;
- (void)transitionToOriginalView;
- (void)transitionToOriginalView:(BOOL)resetLayout;
- (void)transitionFromOriginalView;
- (void)interactiveTransitionFromOriginalView:(CGFloat)percentage;
- (void)interactiveTransitionFromFeedDetail:(CGFloat)percentage;
- (void)transitionFromFeedDetail;
- (void)transitionFromFeedDetail:(BOOL)resetLayout;
- (void)transitionToShareView;
- (void)transitionFromShareView;

- (void)dragStoryToolbar:(int)yCoordinate;
- (void)showUserProfilePopover:(id)sender;
- (void)showFeedMenuPopover:(id)sender;
- (void)showFeedDetailMenuPopover:(id)sender;
- (void)showFontSettingsPopover:(id)sender;
- (void)showTrainingPopover:(id)sender;
- (void)showUserTagsPopover:(id)sender;
- (void)showSitePopover:(id)sender;
- (BOOL)hidePopoverAnimated:(BOOL)animated;
- (void)hidePopover;
@end
