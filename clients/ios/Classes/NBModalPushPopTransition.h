//
//  NBModalPushPopTransition.h
//  NewsBlur
//
//  Created by David Sinclair on 2015-10-23.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NBModalPushPopTransition : UIPercentDrivenInteractiveTransition <UIViewControllerAnimatedTransitioning>

@property (nonatomic) BOOL dismissing;
@property (nonatomic) BOOL percentageDriven;

@end

