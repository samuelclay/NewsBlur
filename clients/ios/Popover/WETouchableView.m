//
//  WETouchableView.m
//  WEPopover
//
//  Created by Werner Altewischer on 12/21/10.
//  Copyright 2010 Werner IT Consultancy. All rights reserved.
//

#import "WETouchableView.h"

@interface WETouchableView(Private)

- (BOOL)isPassthroughView:(UIView *)v;

@end

@implementation WETouchableView

@synthesize touchForwardingDisabled, delegate, passthroughViews;

- (void)dealloc {
	[passthroughViews release];
	[super dealloc];
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
	if (testHits) {
		return nil;
	} else if (touchForwardingDisabled) {
		return self;
	} else {
		UIView *hitView = [super hitTest:point withEvent:event];
		
		if (hitView == self) {
			//Test whether any of the passthrough views would handle this touch
			testHits = YES;
			UIView *superHitView = [self.superview hitTest:point withEvent:event];
			testHits = NO;
			
			if ([self isPassthroughView:superHitView]) {
				hitView = superHitView;
			}
		}
		
		return hitView;
	}
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event {
	[self.delegate viewWasTouched:self];
}

@end

@implementation WETouchableView(Private)

- (BOOL)isPassthroughView:(UIView *)v {
	
	if (v == nil) {
		return NO;
	}
	
	if ([passthroughViews containsObject:v]) {
		return YES;
	}
	
	return [self isPassthroughView:v.superview];
}

@end
