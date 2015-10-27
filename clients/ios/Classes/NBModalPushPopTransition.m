//
//  NBModalPushPopTransition.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-10-23.
//  Copyright © 2015 NewsBlur. All rights reserved.
//
//  Based on Swift code from https://github.com/stringcode86/SCSafariViewController
//

#import "NBModalPushPopTransition.h"

@implementation NBModalPushPopTransition

- (id)init {
    if ((self = [super init])) {
        self.dismissing = NO;
        self.percentageDriven = NO;
    }
    
    return self;
}

- (CGFloat)transitionDuration:(id <UIViewControllerContextTransitioning>)transitionContext {
    return 0.35;
}

- (void)animateTransition:(id<UIViewControllerContextTransitioning>)transitionContext {
    UIViewController *fromViewController = [transitionContext viewControllerForKey:UITransitionContextFromViewControllerKey];
    UIViewController *toViewController = [transitionContext viewControllerForKey:UITransitionContextToViewControllerKey];
    
    UIView *topView = self.dismissing ? fromViewController.view : toViewController.view;
    UIViewController *bottomViewController = self.dismissing ? toViewController : fromViewController;
    UIView *bottomView = bottomViewController.view;
    CGFloat offset = bottomView.bounds.size.width;
    
    if ([bottomViewController isKindOfClass:[UINavigationController class]]) {
        bottomView = ((UINavigationController *)bottomViewController).topViewController.view;
    }
    
    [transitionContext.containerView insertSubview:toViewController.view aboveSubview:fromViewController.view];
    
    if (self.dismissing) {
        [transitionContext.containerView insertSubview:toViewController.view belowSubview:fromViewController.view];
    }
    
    topView.frame = fromViewController.view.frame;
    topView.transform = self.dismissing ? CGAffineTransformIdentity : CGAffineTransformMakeTranslation(offset, 0.0);
    
    UIImageView *shadowView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"safari_shadow"]];
    
    shadowView.contentMode = UIViewContentModeScaleAspectFill;
    shadowView.layer.anchorPoint = CGPointMake(0.0, 0.5);
    shadowView.frame = bottomView.bounds;
    [bottomView addSubview:shadowView];
    shadowView.transform = self.dismissing ? CGAffineTransformMakeScale(0.01, 1.0) : CGAffineTransformIdentity;
    shadowView.alpha = self.dismissing ? 1.0 : 0.0;
    
    [UIView animateWithDuration:[self transitionDuration:transitionContext] delay:0.0 options:[self animationOpts] animations:^{
        topView.transform = self.dismissing ? CGAffineTransformMakeTranslation(offset, 0.0) : CGAffineTransformIdentity;
        shadowView.transform = self.dismissing ? CGAffineTransformIdentity : CGAffineTransformMakeScale(0.01, 1.0);
        shadowView.alpha = self.dismissing ? 0.0 : 1.0;
    } completion:^(BOOL finished) {
        topView.transform = CGAffineTransformIdentity;
        [shadowView removeFromSuperview];
        [transitionContext completeTransition:!transitionContext.transitionWasCancelled];
    }];
}

- (UIViewAnimationOptions)animationOpts {
    UIViewAnimationOptions opts = self.percentageDriven ? UIViewAnimationOptionCurveLinear : UIViewAnimationOptionCurveEaseInOut;
    
    return opts | UIViewAnimationOptionAllowAnimatedContent | UIViewAnimationOptionBeginFromCurrentState | UIViewAnimationOptionLayoutSubviews;
}

@end

