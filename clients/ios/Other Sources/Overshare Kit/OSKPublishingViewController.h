//
//  OSKPublishingViewController.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKActivity;
@protocol OSKPublishingViewController;

// DELEGATE PROTOCOL =====================================================================================

@protocol OSKPublishingViewControllerDelegate <NSObject>

/*
 - (void)publishingViewController:(UIViewController <OSKPublishingViewController> *)viewController
            didTapPublishActivity:(OSKActivity *)activity;
 Call this method when the publishing view controller has finished preparing the content item for 
 publishing, e.g., edited the text property of an OSKMicroblogPostContentItem for OSKTwitterActivity.
*/
- (void)publishingViewController:(UIViewController <OSKPublishingViewController> *)viewController
           didTapPublishActivity:(OSKActivity *)activity;

/*
  - (void)publishingViewControllerDidCancel:(UIViewController <OSKPublishingViewController> *)viewController; 
 Call this method if the publishing view controller cancels.
*/
- (void)publishingViewControllerDidCancel:(UIViewController <OSKPublishingViewController> *)viewController
                             withActivity:(OSKActivity *)activity;

@end

// VIEW CONTROLLER PROTOCOL ==============================================================================

@protocol OSKPublishingViewController <NSObject>

@property (weak, nonatomic) id <OSKPublishingViewControllerDelegate> oskPublishingDelegate;

- (void)preparePublishingViewForActivity:(OSKActivity *)activity delegate:(id <OSKPublishingViewControllerDelegate>)oskPublishingDelegate;

@end






