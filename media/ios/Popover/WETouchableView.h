//
//  WETouchableView.h
//  WEPopover
//
//  Created by Werner Altewischer on 12/21/10.
//  Copyright 2010 Werner IT Consultancy. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class WETouchableView;

/**
  * @brief delegate to receive touch events
  */
@protocol WETouchableViewDelegate<NSObject>

- (void)viewWasTouched:(WETouchableView *)view;

@end

/**
 * @brief View that can handle touch events and/or disable touch forwording to child views
 */
@interface WETouchableView : UIView {
	BOOL touchForwardingDisabled;
	id <WETouchableViewDelegate> delegate;
	NSArray *passthroughViews;
	BOOL testHits;
}

@property (nonatomic, assign) BOOL touchForwardingDisabled;
@property (nonatomic, assign) id <WETouchableViewDelegate> delegate;
@property (nonatomic, copy) NSArray *passthroughViews;

@end
