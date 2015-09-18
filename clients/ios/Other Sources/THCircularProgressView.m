//
//  THCircularProgressBar.m
//
//  Created by Tiago Henriques on 3/4/13.
//  Copyright (c) 2013 Tiago Henriques. All rights reserved.
//

#import "THCircularProgressView.h"

@interface THCircularProgressView ()

@property CGPoint centerPoint;
@property CGFloat radius;

@end

@implementation THCircularProgressView

- (id)initWithCenter:(CGPoint)center
              radius:(CGFloat)radius
           lineWidth:(CGFloat)lineWidth
        progressMode:(THProgressMode)progressMode
       progressColor:(UIColor *)progressColor
progressBackgroundMode:(THProgressBackgroundMode)backgroundMode
progressBackgroundColor:(UIColor *)progressBackgroundColor
          percentage:(CGFloat)percentage
{
    CGRect rect = CGRectMake(center.x - radius, center.y - radius, 2 * radius, 2 * radius);
    self = [super initWithFrame:rect];
    if (self) {
        self.backgroundColor = [UIColor clearColor];
 
        self.centerPoint = CGPointMake(radius, radius);
        self.radius = radius;
        self.lineWidth = lineWidth;
        
        self.progressMode = progressMode;
        self.progressColor = progressColor;
        self.progressBackgroundMode = backgroundMode;
        self.progressBackgroundColor = progressBackgroundColor;
        
        self.percentage = percentage;
        
        self.centerLabel = [[UILabel alloc] initWithFrame:rect];
        self.centerLabel.center = CGPointMake(radius, radius);
        self.centerLabel.textAlignment = NSTextAlignmentCenter;
        self.centerLabel.backgroundColor = [UIColor clearColor];
        
        [self addSubview:self.centerLabel];
    }

    return self;
}

- (void)drawRect:(CGRect)rect
{
    [self drawBackground:rect];
    [self drawProgress];
}

- (void)drawBackground:(CGRect)rect
{
    switch (self.progressBackgroundMode) {
        case THProgressBackgroundModeCircle: {
            CGContextRef ctx = UIGraphicsGetCurrentContext();
            CGContextAddEllipseInRect(ctx, rect);
            CGContextSetFillColor(ctx, CGColorGetComponents([self.progressBackgroundColor CGColor]));
            CGContextFillPath(ctx);
            break;
        }
        case THProgressBackgroundModeCircumference: {
            CGFloat radiusMinusLineWidth = self.radius - self.lineWidth / 2;
            UIBezierPath *progressCircle = [UIBezierPath bezierPathWithArcCenter:self.centerPoint
                                                                          radius:radiusMinusLineWidth
                                                                      startAngle:0
                                                                        endAngle:2 * M_PI
                                                                       clockwise:YES];
            [self.progressBackgroundColor setStroke];
            progressCircle.lineWidth = self.lineWidth;
            [progressCircle stroke];
            break;
        }
        case THProgressBackgroundModeNone:
        default:
            break;
    }
}

- (void)drawProgress
{
    CGFloat radiusMinusLineWidth = self.radius - self.lineWidth / 2;
    
    if (self.progressMode == THProgressModeFill && self.percentage > 0) {
        CGFloat startAngle = -M_PI / 2;
        CGFloat endAngle = startAngle + self.percentage * 2 * M_PI;
        [self drawProgressArcWithStartAngle:startAngle endAngle:endAngle radius:radiusMinusLineWidth];
    }
    else if (self.progressMode == THProgressModeDeplete && self.percentage < 1) {
        CGFloat startAngle = -M_PI / 2 + self.percentage * 2 * M_PI;
        CGFloat endAngle = 1.5 * M_PI;
        [self drawProgressArcWithStartAngle:startAngle endAngle:endAngle radius:radiusMinusLineWidth];
    }
}

- (void)drawProgressArcWithStartAngle:(CGFloat)startAngle endAngle:(CGFloat)endAngle radius:(CGFloat)radius
{
    UIBezierPath *progressCircle = [UIBezierPath bezierPathWithArcCenter:self.centerPoint
                                                                  radius:radius
                                                              startAngle:startAngle
                                                                endAngle:endAngle
                                                               clockwise:YES];
    
    [self.progressColor setStroke];
    progressCircle.lineWidth = self.lineWidth;
    [progressCircle stroke];
}

#pragma mark - Public

- (void)setProgressBackgroundColor:(UIColor *)progressBackgroundColor
{
    _progressBackgroundColor = progressBackgroundColor;
    [self setNeedsDisplay];
}

- (void)setProgressColor:(UIColor *)progressColor
{
    _progressColor = progressColor;
    [self setNeedsDisplay];
}

- (void)setPercentage:(CGFloat)percentage
{
    _percentage = fminf(fmax(percentage, 0), 1);
    [self setNeedsDisplay];
}

@end