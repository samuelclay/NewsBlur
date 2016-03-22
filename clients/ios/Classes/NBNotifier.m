//
//  NBNotifier.m
//  NewsBlur
//
//  Created by Samuel Clay on 6/6/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

// Based on work by:

/*
 Copyright 2012 Jonah Siegle
 
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */

#import "NBNotifier.h"
#import "UIView+TKCategory.h"
#include <QuartzCore/QuartzCore.h>

#define _displaytime 4.f
#define NOTIFIER_HEIGHT 32
#define PROGRESS_BAR_SIZE 40

@implementation NBNotifier

@synthesize accessoryView = _accessoryView, title = _title, style = _style, view = _view;
@synthesize showing;
@synthesize progressBar;
@synthesize offset = _offset;

+ (void)initialize {
    if (self == [NBNotifier class]) {
        
    }
}

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        // Initialization code
        showing = NO;
    }
    return self;
}

- (id)initWithTitle:(NSString *)title {
    return [self initWithTitle:title inView:[[[UIApplication sharedApplication] delegate] window]];
}

- (id)initWithTitle:(NSString *)title inView:(UIView *)view {
    return [self initWithTitle:title inView:view style:NBLoadingStyle withOffset:CGPointZero];
}

- (id)initWithTitle:(NSString *)title inView:(UIView *)view withOffset:(CGPoint)offset {
    return [self initWithTitle:title inView:view style:NBLoadingStyle withOffset:offset];
}

- (id)initWithTitle:(NSString *)title inView:(UIView *)view style:(NBNotifierStyle)style {
    return [self initWithTitle:title inView:view style:NBLoadingStyle withOffset:CGPointZero];
}

- (id)initWithTitle:(NSString *)title inView:(UIView *)view style:(NBNotifierStyle)style withOffset:(CGPoint)offset{
    
    if (self = [super initWithFrame:CGRectMake(0, view.bounds.size.height - offset.y, view.bounds.size.width, NOTIFIER_HEIGHT)]){
        
        self.backgroundColor = [UIColor clearColor];
        
        self.style = style;
        self.offset = offset;
        
        _txtLabel = [[UILabel alloc]initWithFrame:CGRectMake(32, 12, self.frame.size.width - 32, 20)];
        [_txtLabel setFont:[UIFont fontWithName: @"Helvetica" size: 16]];
        [_txtLabel setBackgroundColor:[UIColor clearColor]];
        
        _txtLabel.textColor = [UIColor whiteColor];
        
        _txtLabel.layer.shadowOffset = CGSizeMake(0, -0.5);
        _txtLabel.layer.shadowColor = [UIColor blackColor].CGColor;
        _txtLabel.layer.shadowOpacity = 1.0;
        _txtLabel.layer.shadowRadius = 1;
        
        _txtLabel.layer.masksToBounds = NO;
        
        [self addSubview:_txtLabel];
        
        self.title = title;        
        
        self.view = view;
        
        self.progressBar = [[UIView alloc] initWithFrame:CGRectMake(0, 4, 0, 1)];
        self.progressBar.backgroundColor = UIColorFromRGB(0xD05046);
        self.progressBar.alpha = 0.6f;
        self.progressBar.hidden = YES;
        [self addSubview:self.progressBar];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didChangedOrientation:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
    }
    
    return self;
}

- (void) setNeedsLayout {
    [super setNeedsLayout];
    [self didChangedOrientation:nil];
}

- (void) didChangedOrientation:(NSNotification *)sender {
//    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
//    NSLog(@"Notifier changed orieintation to: %ld (%@/%@)", (long)orientation, NSStringFromCGRect(self.frame), NSStringFromCGRect(self.view.frame));
    [self setView:self.view];
    self.progressBar.frame = CGRectMake(0, 4, 0, 1);
}


- (void)setAccessoryView:(UIView *)accessoryView{
    if (_accessoryView) {
        [_accessoryView removeFromSuperview];
    }
    _accessoryView = accessoryView;
    int offset = 0;
    if (self.style == NBSyncingStyle || self.style == NBSyncingProgressStyle) {
        offset = 1;
    }
    accessoryView.tag = 1;
    [accessoryView setFrame:CGRectMake((32 - accessoryView.frame.size.width) / 2 + offset, ((self.frame.size.height -accessoryView.frame.size.height)/2)+2, accessoryView.frame.size.width, accessoryView.frame.size.height)];
    
    [self addSubview:accessoryView];
    if (self.style == NBSyncingStyle || self.style == NBSyncingProgressStyle) {
        [_txtLabel setFrame:CGRectMake(34, (NOTIFIER_HEIGHT / 2) - 8, self.frame.size.width - 32, 20)];
    } else {
        [_txtLabel setFrame:CGRectMake(30, (NOTIFIER_HEIGHT / 2) - 8, self.frame.size.width - 32, 20)];
    }
}

- (void)setProgress:(float)value {
    self.progressBar.frame = CGRectMake(0, 4, value * self.frame.size.width, 1);
}

- (void)setTitle:(NSString *)title {
    _title = title;
    [_txtLabel setText:title];
    
    [self setNeedsDisplay];
}

- (void)setStyle:(NBNotifierStyle)style {
    _style = style;
    self.progressBar.hidden = YES;

    if (style == NBLoadingStyle) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [activityIndicator startAnimating];
        self.accessoryView = activityIndicator;
    } else if (style == NBOfflineStyle) {
        UIImage *offlineImage = [UIImage imageNamed:@"g_icn_offline.png"];
        self.accessoryView = [[UIImageView alloc] initWithImage:offlineImage];
    } else if (style == NBSyncingProgressStyle) {
        UIImage *offlineImage = [UIImage imageNamed:@"g_icn_offline.png"];
        self.accessoryView = [[UIImageView alloc] initWithImage:offlineImage];
        self.progressBar.hidden = NO;
    } else if (style == NBSyncingStyle) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite];
        [activityIndicator startAnimating];
        self.accessoryView = activityIndicator;        
    } else if (style == NBDoneStyle) {
        UIImage *doneImage = [UIImage imageNamed:@"checkmark.png"];
        self.accessoryView = [[UIImageView alloc] initWithImage:doneImage];
    }
    
    [self setNeedsDisplay];
}

- (void)setView:(UIView *)view {
    _view = view;

    if (self.showing) {
        self.frame = CGRectMake(0, view.bounds.size.height - self.offset.y - self.frame.size.height, view.bounds.size.width, NOTIFIER_HEIGHT);
    } else {
        self.frame = CGRectMake(0, view.bounds.size.height - self.offset.y, view.bounds.size.width, NOTIFIER_HEIGHT);
    }
}

- (void)show {
    [self showIn:(float)0.3f];
}

- (void)showIn:(float)time {
    showing = YES;
    CGRect frame = self.frame;
    frame.size.width = self.view.bounds.size.width;
    self.frame = frame;
    self.hidden = NO;
    
    [UIView animateWithDuration:time animations:^{
        CGRect move = self.frame;
        move.origin.y = self.view.bounds.size.height - NOTIFIER_HEIGHT - self.offset.y;
        self.frame = move;
    } completion:nil];
}

- (void)hide {
    [self hideIn:0.3f];
}

- (void)hideNow {
    [self hideIn:0.0f];
}

- (void)hideIn:(float)seconds {
    
//    if (!showing) return;
    
    [UIView animateWithDuration:seconds animations:^{
        CGRect move = self.frame;
        move.origin.y = self.view.bounds.size.height - self.offset.y;
        self.frame = move;
    } completion:^(BOOL finished) {
        self.hidden = YES;
    }];
    
    showing = NO;
}

- (void)setAccessoryView:(UIView *)view animated:(BOOL)animated{
    
    if (!animated){
        [[self viewWithTag:1]removeFromSuperview];
        view.tag = 1;
    }
    
    [view setFrame:CGRectMake(12, ((self.frame.size.height -view.frame.size.height)/2)+1, view.frame.size.width, view.frame.size.height)];
    [self addSubview:view];
    
    if (animated) {
        view.alpha = 0.0;
        
        if ([self viewWithTag:1])
            view.tag = 0;
        else
            view.tag = 2;
        [UIView animateWithDuration:0.5
                         animations:^{
                             if ([self viewWithTag:1])
                                 [self viewWithTag:1].alpha = 0.0;
                             else
                                 view.alpha = 1.0;
                         }
                         completion:^(BOOL finished){
                             
                             [[self viewWithTag:1]removeFromSuperview];
                             
                             [UIView animateWithDuration:0.5
                                              animations:^{
                                                  view.alpha = 1.0;
                                                  
                                              }
                                              completion:^(BOOL finished){
                                                  
                                                  view.tag = 1;
                                              }];
                             
                         }];
    }
    
    if (self.style == NBSyncingStyle || self.style == NBSyncingProgressStyle) {
        [_txtLabel setFrame:CGRectMake(34, (NOTIFIER_HEIGHT / 2) - 8, self.frame.size.width - 32, 20)];
    } else {
        [_txtLabel setFrame:CGRectMake(30, (NOTIFIER_HEIGHT / 2) - 8, self.frame.size.width - 32, 20)];
    }
    
    
}

- (void)setTitle:(id)title animated:(BOOL)animated{
    
    float duration = 0.0;
    
    if (animated)
        duration = 0.5;
    
    [UIView animateWithDuration:duration
                     animations:^{
                         
                         _txtLabel.alpha = 0.0f;
                         
                     }
                     completion:^(BOOL finished){
                         
                         _txtLabel.text = title;
                         
                         [UIView animateWithDuration:duration
                                          animations:^{
                                              _txtLabel.alpha = 1.0f;
                                              
                                              
                                          }
                                          completion:^(BOOL finished){
                                              
                                          }];
                         
                     }];
    
}

- (void)drawRect:(CGRect)rect{
    
    CGContextRef context = UIGraphicsGetCurrentContext();
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    
    //Background color
    CGRect rectangle = CGRectMake(0,4,rect.size.width,NOTIFIER_HEIGHT - 4);
    CGContextAddRect(context, rectangle);
    if (self.style == NBLoadingStyle) {
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.6f].CGColor);
    } else if (self.style == NBOfflineStyle) {
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.4 green:0.15 blue:0.1 alpha:0.6f].CGColor);
    } else if (self.style == NBSyncingStyle) {
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.6f].CGColor);
    } else if (self.style == NBSyncingProgressStyle || self.style == NBDoneStyle) {
        CGContextSetFillColorWithColor(context, [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.4f].CGColor);
    }
    CGContextFillRect(context, rectangle);
    
    // Top black line
    CGContextSetLineWidth(context, 1.0);
    CGColorRef blackcolor;
    if (self.style == NBSyncingProgressStyle || self.style == NBDoneStyle) {
        CGFloat componentsBlackLine[] = {0.0, 0.0, 0.0, 0.6f};
        blackcolor = CGColorCreate(colorspace, componentsBlackLine);
    } else {
        CGFloat componentsBlackLine[] = {0.0, 0.0, 0.0, 1.0};
        blackcolor = CGColorCreate(colorspace, componentsBlackLine);
    }
    CGContextSetStrokeColorWithColor(context, blackcolor);
    
    CGContextMoveToPoint(context, 0, 3.5);
    CGContextAddLineToPoint(context, rect.size.width, 3.5);
    
    CGContextStrokePath(context);
    CGColorRelease(blackcolor);
    
    // Second white line
    CGContextSetLineWidth(context, 1.0);
    CGColorRef whitecolor;
    if (self.style == NBSyncingProgressStyle || self.style == NBDoneStyle) {
        CGFloat componentsWhiteLine[] = {1.0, 1.0, 1.0, 0.65};
        whitecolor = CGColorCreate(colorspace, componentsWhiteLine);
    } else {
        CGFloat componentsWhiteLine[] = {1.0, 1.0, 1.0, 0.35};
        whitecolor = CGColorCreate(colorspace, componentsWhiteLine);
    }
    CGContextSetStrokeColorWithColor(context, whitecolor);
    
    CGContextMoveToPoint(context, 0, 4.5);
    CGContextAddLineToPoint(context, rect.size.width, 4.5);
    
    CGContextStrokePath(context);
    CGColorRelease(whitecolor);
    
    //Draw Shadow
    
    CGRect imageBounds = CGRectMake(0.0f, 0.0f, rect.size.width, 3.f);
	CGRect bounds = CGRectMake(0, 0, rect.size.width, 3);
	CGFloat alignStroke;
	CGFloat resolution;
	CGMutablePathRef path;
	CGRect drawRect;
	CGGradientRef gradient;
	NSMutableArray *colors;
	UIColor *color;
	CGColorSpaceRef space = CGColorSpaceCreateDeviceRGB();
	CGPoint point;
	CGPoint point2;
	CGAffineTransform transform;
	CGMutablePathRef tempPath;
	CGRect pathBounds;
	CGFloat locations[2];
	resolution = 0.5f * (bounds.size.width / imageBounds.size.width + bounds.size.height / imageBounds.size.height);
	
	CGContextSaveGState(context);
	CGContextTranslateCTM(context, bounds.origin.x, bounds.origin.y);
	CGContextScaleCTM(context, (bounds.size.width / imageBounds.size.width), (bounds.size.height / imageBounds.size.height));
	
	// Layer 1
	
	alignStroke = 0.0f;
	path = CGPathCreateMutable();
	drawRect = CGRectMake(0.0f, 0.0f, rect.size.width, 3.0f);
	drawRect.origin.x = (roundf(resolution * drawRect.origin.x + alignStroke) - alignStroke) / resolution;
	drawRect.origin.y = (roundf(resolution * drawRect.origin.y + alignStroke) - alignStroke) / resolution;
	drawRect.size.width = roundf(resolution * drawRect.size.width) / resolution;
	drawRect.size.height = roundf(resolution * drawRect.size.height) / resolution;
	CGPathAddRect(path, NULL, drawRect);
	colors = [NSMutableArray arrayWithCapacity:2];
	color = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.0f];
	[colors addObject:(id)[color CGColor]];
	locations[0] = 0.0f;
	color = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.18f];
	[colors addObject:(id)[color CGColor]];
	locations[1] = 1.0f;
	gradient = CGGradientCreateWithColors(space, (__bridge CFArrayRef)colors, locations);
	CGContextAddPath(context, path);
	CGContextSaveGState(context);
	CGContextEOClip(context);
	transform = CGAffineTransformMakeRotation(-1.571f);
	tempPath = CGPathCreateMutable();
	CGPathAddPath(tempPath, &transform, path);
	pathBounds = CGPathGetPathBoundingBox(tempPath);
	point = pathBounds.origin;
	point2 = CGPointMake(CGRectGetMaxX(pathBounds), CGRectGetMinY(pathBounds));
	transform = CGAffineTransformInvert(transform);
	point = CGPointApplyAffineTransform(point, transform);
	point2 = CGPointApplyAffineTransform(point2, transform);
	CGPathRelease(tempPath);
	CGContextDrawLinearGradient(context, gradient, point, point2, (kCGGradientDrawsBeforeStartLocation | kCGGradientDrawsAfterEndLocation));
	CGContextRestoreGState(context);
	CGGradientRelease(gradient);
	CGPathRelease(path);
	
	CGContextRestoreGState(context);
	CGColorSpaceRelease(space);
    
    CGColorSpaceRelease(colorspace);
}

@end
