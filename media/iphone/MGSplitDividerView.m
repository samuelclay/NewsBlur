//
//  MGSplitDividerView.m
//  MGSplitView
//
//  Created by Matt Gemmell on 26/07/2010.
//  Copyright 2010 Instinctive Code.
//

#import "MGSplitDividerView.h"
#import "MGSplitViewController.h"


@implementation MGSplitDividerView


#pragma mark -
#pragma mark Setup and teardown


- (id)initWithFrame:(CGRect)frame
{
	if ((self = [super initWithFrame:frame])) {
		self.userInteractionEnabled = NO;
		self.allowsDragging = NO;
		self.contentMode = UIViewContentModeRedraw;
	}
	return self;
}


- (void)dealloc
{
	self.splitViewController = nil;
	[super dealloc];
}


#pragma mark -
#pragma mark Drawing


- (void)drawRect:(CGRect)rect
{
	if (splitViewController.dividerStyle == MGSplitViewDividerStyleThin) {
		[super drawRect:rect];
		
	} else if (splitViewController.dividerStyle == MGSplitViewDividerStylePaneSplitter) {
		// Draw gradient background.
		CGRect bounds = self.bounds;
		CGColorSpaceRef rgb = CGColorSpaceCreateDeviceRGB();
		CGFloat locations[2] = {0, 1};
		CGFloat components[8] = {	0.988, 0.988, 0.988, 1.0,  // light
									0.875, 0.875, 0.875, 1.0 };// dark
		CGGradientRef gradient = CGGradientCreateWithColorComponents (rgb, components, locations, 2);
		CGContextRef context = UIGraphicsGetCurrentContext();
		CGPoint start, end;
		if (splitViewController.vertical) {
			// Light left to dark right.
			start = CGPointMake(CGRectGetMinX(bounds), CGRectGetMidY(bounds));
			end = CGPointMake(CGRectGetMaxX(bounds), CGRectGetMidY(bounds));
		} else {
			// Light top to dark bottom.
			start = CGPointMake(CGRectGetMidX(bounds), CGRectGetMinY(bounds));
			end = CGPointMake(CGRectGetMidX(bounds), CGRectGetMaxY(bounds));
		}
		CGContextDrawLinearGradient(context, gradient, start, end, 0);
		CGColorSpaceRelease(rgb);
		CGGradientRelease(gradient);
		
		// Draw borders.
		float borderThickness = 1.0;
		[[UIColor colorWithWhite:0.7 alpha:1.0] set];
		CGRect borderRect = bounds;
		if (splitViewController.vertical) {
			borderRect.size.width = borderThickness;
			UIRectFill(borderRect);
			borderRect.origin.x = CGRectGetMaxX(bounds) - borderThickness;
			UIRectFill(borderRect);
			
		} else {
			borderRect.size.height = borderThickness;
			UIRectFill(borderRect);
			borderRect.origin.y = CGRectGetMaxY(bounds) - borderThickness;
			UIRectFill(borderRect);
		}
		
		// Draw grip.
		[self drawGripThumbInRect:bounds];
	}
}


- (void)drawGripThumbInRect:(CGRect)rect
{
	float width = 9.0;
	float height;
	if (splitViewController.vertical) {
		height = 30.0;
	} else {
		height = width;
		width = 30.0;
	}
	
	// Draw grip in centred in rect.
	CGRect gripRect = CGRectMake(0, 0, width, height);
	gripRect.origin.x = ((rect.size.width - gripRect.size.width) / 2.0);
	gripRect.origin.y = ((rect.size.height - gripRect.size.height) / 2.0);
	
	float stripThickness = 1.0;
	UIColor *stripColor = [UIColor colorWithWhite:0.35 alpha:1.0];
	UIColor *lightColor = [UIColor colorWithWhite:1.0 alpha:1.0];
	float space = 3.0;
	if (splitViewController.vertical) {
		gripRect.size.width = stripThickness;
		[stripColor set];
		UIRectFill(gripRect);
		
		gripRect.origin.x += stripThickness;
		gripRect.origin.y += 1;
		[lightColor set];
		UIRectFill(gripRect);
		gripRect.origin.x -= stripThickness;
		gripRect.origin.y -= 1;
		
		gripRect.origin.x += space + stripThickness;
		[stripColor set];
		UIRectFill(gripRect);
		
		gripRect.origin.x += stripThickness;
		gripRect.origin.y += 1;
		[lightColor set];
		UIRectFill(gripRect);
		gripRect.origin.x -= stripThickness;
		gripRect.origin.y -= 1;
		
		gripRect.origin.x += space + stripThickness;
		[stripColor set];
		UIRectFill(gripRect);
		
		gripRect.origin.x += stripThickness;
		gripRect.origin.y += 1;
		[lightColor set];
		UIRectFill(gripRect);
		
	} else {
		gripRect.size.height = stripThickness;
		[stripColor set];
		UIRectFill(gripRect);
		
		gripRect.origin.y += stripThickness;
		gripRect.origin.x -= 1;
		[lightColor set];
		UIRectFill(gripRect);
		gripRect.origin.y -= stripThickness;
		gripRect.origin.x += 1;
		
		gripRect.origin.y += space + stripThickness;
		[stripColor set];
		UIRectFill(gripRect);
		
		gripRect.origin.y += stripThickness;
		gripRect.origin.x -= 1;
		[lightColor set];
		UIRectFill(gripRect);
		gripRect.origin.y -= stripThickness;
		gripRect.origin.x += 1;
		
		gripRect.origin.y += space + stripThickness;
		[stripColor set];
		UIRectFill(gripRect);
		
		gripRect.origin.y += stripThickness;
		gripRect.origin.x -= 1;
		[lightColor set];
		UIRectFill(gripRect);
	}
}


#pragma mark -
#pragma mark Interaction


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event
{
	UITouch *touch = [touches anyObject];
	if (touch) {
		CGPoint lastPt = [touch previousLocationInView:self];
		CGPoint pt = [touch locationInView:self];
		float offset = (splitViewController.vertical) ? pt.x - lastPt.x : pt.y - lastPt.y;
		if (!splitViewController.masterBeforeDetail) {
			offset = -offset;
		}
		splitViewController.splitPosition = splitViewController.splitPosition + offset;
	}
}


#pragma mark -
#pragma mark Accessors and properties


- (void)setAllowsDragging:(BOOL)flag
{
	if (flag != allowsDragging) {
		allowsDragging = flag;
		self.userInteractionEnabled = allowsDragging;
	}
}


@synthesize splitViewController;
@synthesize allowsDragging;


@end
