//
//  MGSplitCornersView.m
//  MGSplitView
//
//  Created by Matt Gemmell on 28/07/2010.
//  Copyright 2010 Instinctive Code.
//

#import "MGSplitCornersView.h"


@implementation MGSplitCornersView


#pragma mark -
#pragma mark Setup and teardown


- (id)initWithFrame:(CGRect)frame
{
    if ((self = [super initWithFrame:frame])) {
		self.contentMode = UIViewContentModeRedraw;
		self.userInteractionEnabled = NO;
		self.opaque = NO;
		self.backgroundColor = [UIColor clearColor];
		cornerRadius = 0.0; // actual value is set by the splitViewController.
		cornersPosition = MGCornersPositionLeadingVertical;
    }
	
    return self;
}


- (void)dealloc
{
	self.cornerBackgroundColor = nil;
	
	[super dealloc];
}


#pragma mark -
#pragma mark Geometry helpers


double deg2Rad(double degrees)
{
	// Converts degrees to radians.
	return degrees * (M_PI / 180.0);
}


double rad2Deg(double radians)
{
	// Converts radians to degrees.
	return radians * (180 / M_PI);
}


#pragma mark -
#pragma mark Drawing


- (void)drawRect:(CGRect)rect
{
	// Draw two appropriate corners, with cornerBackgroundColor behind them.
	if (cornerRadius > 0) {
		if (NO) { // just for debugging.
			[[UIColor redColor] set];
			UIRectFill(self.bounds);
		}
		
		float maxX = CGRectGetMaxX(self.bounds);
		float maxY = CGRectGetMaxY(self.bounds);
		UIBezierPath *path = [UIBezierPath bezierPath];
		CGPoint pt = CGPointZero;
		switch (cornersPosition) {
			case MGCornersPositionLeadingVertical: // top of screen for a left/right split
				[path moveToPoint:pt];
				pt.y += cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(90) endAngle:0 clockwise:YES]];
				pt.x += cornerRadius;
				pt.y -= cornerRadius;
				[path addLineToPoint:pt];
				[path addLineToPoint:CGPointZero];
				[path closePath];
				
				pt.x = maxX - cornerRadius;
				pt.y = 0;
				[path moveToPoint:pt];
				pt.y = maxY;
				[path addLineToPoint:pt];
				pt.x += cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(180) endAngle:deg2Rad(90) clockwise:YES]];
				pt.y -= cornerRadius;
				[path addLineToPoint:pt];
				pt.x -= cornerRadius;
				[path addLineToPoint:pt];
				[path closePath];
				
				break;
				
			case MGCornersPositionTrailingVertical: // bottom of screen for a left/right split
				pt.y = maxY;
				[path moveToPoint:pt];
				pt.y -= cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(270) endAngle:deg2Rad(360) clockwise:NO]];
				pt.x += cornerRadius;
				pt.y += cornerRadius;
				[path addLineToPoint:pt];
				pt.x -= cornerRadius;
				[path addLineToPoint:pt];
				[path closePath];
				
				pt.x = maxX - cornerRadius;
				pt.y = maxY;
				[path moveToPoint:pt];
				pt.y -= cornerRadius;
				[path addLineToPoint:pt];
				pt.x += cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(180) endAngle:deg2Rad(270) clockwise:NO]];
				pt.y += cornerRadius;
				[path addLineToPoint:pt];
				pt.x -= cornerRadius;
				[path addLineToPoint:pt];
				[path closePath];
				
				break;
				
			case MGCornersPositionLeadingHorizontal: // left of screen for a top/bottom split
				pt.x = 0;
				pt.y = cornerRadius;
				[path moveToPoint:pt];
				pt.y -= cornerRadius;
				[path addLineToPoint:pt];
				pt.x += cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(180) endAngle:deg2Rad(270) clockwise:NO]];
				pt.y += cornerRadius;
				[path addLineToPoint:pt];
				pt.x -= cornerRadius;
				[path addLineToPoint:pt];
				[path closePath];
				
				pt.x = 0;
				pt.y = maxY - cornerRadius;
				[path moveToPoint:pt];
				pt.y = maxY;
				[path addLineToPoint:pt];
				pt.x += cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(180) endAngle:deg2Rad(90) clockwise:YES]];
				pt.y -= cornerRadius;
				[path addLineToPoint:pt];
				pt.x -= cornerRadius;
				[path addLineToPoint:pt];
				[path closePath];
				
				break;
				
			case MGCornersPositionTrailingHorizontal: // right of screen for a top/bottom split
				pt.y = cornerRadius;
				[path moveToPoint:pt];
				pt.y -= cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(270) endAngle:deg2Rad(360) clockwise:NO]];
				pt.x += cornerRadius;
				pt.y += cornerRadius;
				[path addLineToPoint:pt];
				pt.x -= cornerRadius;
				[path addLineToPoint:pt];
				[path closePath];
				
				pt.y = maxY - cornerRadius;
				[path moveToPoint:pt];
				pt.y += cornerRadius;
				[path appendPath:[UIBezierPath bezierPathWithArcCenter:pt radius:cornerRadius startAngle:deg2Rad(90) endAngle:0 clockwise:YES]];
				pt.x += cornerRadius;
				pt.y -= cornerRadius;
				[path addLineToPoint:pt];
				pt.x -= cornerRadius;
				[path addLineToPoint:pt];
				[path closePath];
				
				break;
				
			default:
				break;
		}
		
		[self.cornerBackgroundColor set];
		[path fill];
	}
}


#pragma mark -
#pragma mark Accessors and properties


- (void)setCornerRadius:(float)newRadius
{
	if (newRadius != cornerRadius) {
		cornerRadius = newRadius;
		[self setNeedsDisplay];
	}
}


- (void)setSplitViewController:(MGSplitViewController *)theController
{
	if (theController != splitViewController) {
		splitViewController = theController;
		[self setNeedsDisplay];
	}
}


- (void)setCornersPosition:(MGCornersPosition)posn
{
	if (cornersPosition != posn) {
		cornersPosition = posn;
		[self setNeedsDisplay];
	}
}


- (void)setCornerBackgroundColor:(UIColor *)color
{
	if (color != cornerBackgroundColor) {
		[cornerBackgroundColor release];
		cornerBackgroundColor = [color retain];
		[self setNeedsDisplay];
	}
}


@synthesize cornerRadius;
@synthesize splitViewController;
@synthesize cornersPosition;
@synthesize cornerBackgroundColor;


@end
