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
#define PROGRESS_BAR_SIZE 40

@implementation NBNotifier

@synthesize accessoryView = _accessoryView, title = _title, style = _style, view = _view;
@synthesize showing;
@synthesize progressBar;
@synthesize offset = _offset;
@synthesize topOffsetConstraint;

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
        self.translatesAutoresizingMaskIntoConstraints = NO;
    }
    return self;
}

- (id)initWithTitle:(NSString *)title {
    return [self initWithTitle:title style:NBLoadingStyle withOffset:CGPointZero];
}

- (id)initWithTitle:(NSString *)title withOffset:(CGPoint)offset {
    return [self initWithTitle:title style:NBLoadingStyle withOffset:offset];
}

- (id)initWithTitle:(NSString *)title style:(NBNotifierStyle)style {
    return [self initWithTitle:title style:NBLoadingStyle withOffset:CGPointZero];
}

- (id)initWithTitle:(NSString *)title style:(NBNotifierStyle)style withOffset:(CGPoint)offset{
    
//    if (self = [super initWithFrame:CGRectMake(0, view.bounds.size.height - offset.y, view.bounds.size.width, NOTIFIER_HEIGHT)]){
    if (self = [super init]) {
        self.backgroundColor = [UIColor clearColor];
        
        self.style = style;
        self.offset = offset;
        
//        _txtLabel = [[UILabel alloc] initWithFrame:CGRectMake(32, 12, self.frame.size.width - 32, 20)];
        _txtLabel = [[UILabel alloc] init];
        _txtLabel.translatesAutoresizingMaskIntoConstraints = NO;
        [_txtLabel setFont:[UIFont fontWithName: @"WhitneySSm-Book" size: 17]];
        [_txtLabel setBackgroundColor:[UIColor clearColor]];
        
        _txtLabel.textColor = [UIColor whiteColor];
        
        _txtLabel.layer.shadowOffset = CGSizeMake(0, -0.5);
        _txtLabel.layer.shadowColor = [UIColor blackColor].CGColor;
        _txtLabel.layer.shadowOpacity = 1.0;
        _txtLabel.layer.shadowRadius = 1;
        
        _txtLabel.layer.masksToBounds = NO;
        
        [self addSubview:_txtLabel];
        
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_txtLabel attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:1.0 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_txtLabel attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:20]];
        txtLabelLeadingConstraint = [NSLayoutConstraint constraintWithItem:_txtLabel attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0 constant:32];
        [self addConstraint:txtLabelLeadingConstraint];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:_txtLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:2]];
        
        self.title = title;        
        
//        self.progressBar = [[UIView alloc] initWithFrame:CGRectMake(0, 4, 0, 1)];
        self.progressBar = [[UIView alloc] init];
        self.progressBar.translatesAutoresizingMaskIntoConstraints = NO;
        self.progressBar.backgroundColor = UIColorFromRGB(0xD05046);
        self.progressBar.alpha = 0.6f;
        self.progressBar.hidden = YES;
        [self addSubview:self.progressBar];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:self.progressBar attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeTop multiplier:1.0 constant:4]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:self.progressBar attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0 constant:0]];
        [self addConstraint:[NSLayoutConstraint constraintWithItem:self.progressBar attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem: nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:1]];
        progressBarWidthConstraint = [NSLayoutConstraint constraintWithItem:self.progressBar attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:0.0 constant:0];
        [self addConstraint:progressBarWidthConstraint];

        
//        [[NSNotificationCenter defaultCenter] addObserver:self
//                                                 selector:@selector(didChangedOrientation:)
//                                                     name:UIDeviceOrientationDidChangeNotification
//                                                   object:nil];
    }
    
    return self;
}

- (void)setAccessoryView:(UIView *)accessoryView {
    if (_accessoryView) {
        for (NSLayoutConstraint *constraint in [self constraints]) {
            if (constraint.firstItem == _accessoryView) {
                [self removeConstraint:constraint];
            }
        }

        [_accessoryView removeFromSuperview];
    }
    _accessoryView = accessoryView;
    accessoryView.translatesAutoresizingMaskIntoConstraints = NO;
    int offset = 0;
    if (self.style == NBSyncingStyle || self.style == NBSyncingProgressStyle) {
        offset = 1;
    }

//    NSInteger leadingOffset = 30;
    txtLabelLeadingConstraint.constant = 30;
    if (self.style == NBSyncingStyle || self.style == NBSyncingProgressStyle) {
//        leadingOffset = 34;
        txtLabelLeadingConstraint.constant = 34;
//        [_txtLabel setFrame:CGRectMake(34, (NOTIFIER_HEIGHT / 2) - 8, self.frame.size.width - 32, 20)];
//    } else {
//        [_txtLabel setFrame:CGRectMake(30, (NOTIFIER_HEIGHT / 2) - 8, self.frame.size.width - 32, 20)];
    }

    accessoryView.tag = 1;
//    [accessoryView setFrame:CGRectMake((32 - accessoryView.frame.size.width) / 2 + offset, ((self.frame.size.height -accessoryView.frame.size.height)/2)+2, accessoryView.frame.size.width, accessoryView.frame.size.height)];
    
    [self addSubview:accessoryView];
    
    [self addConstraint:[NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:32]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:20]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:2]];
    [self addConstraint:[NSLayoutConstraint constraintWithItem:accessoryView attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeLeading multiplier:1.0 constant:offset]];
    
    [self layoutIfNeeded];
}

- (void)setProgress:(CGFloat)value {
    [self removeConstraint:progressBarWidthConstraint];
    progressBarWidthConstraint = [NSLayoutConstraint constraintWithItem:self.progressBar attribute:NSLayoutAttributeWidth relatedBy:NSLayoutRelationEqual toItem:self attribute:NSLayoutAttributeWidth multiplier:value constant:0];
    [self addConstraint:progressBarWidthConstraint];
    
    [UIView animateWithDuration:0.5 animations:^{
        [self layoutIfNeeded];
    } completion:nil];
//    self.progressBar.frame = CGRectMake(0, 4, value * self.frame.size.width, 1);
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
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        activityIndicator.color = UIColor.whiteColor;
        [activityIndicator startAnimating];
        self.accessoryView = activityIndicator;
    } else if (style == NBOfflineStyle) {
        UIImage *offlineImage = [UIImage imageNamed:@"g_icn_offline.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:offlineImage];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.accessoryView = imageView;
    } else if (style == NBSyncingProgressStyle) {
        UIImage *offlineImage = [UIImage imageNamed:@"g_icn_offline.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:offlineImage];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.accessoryView = imageView;
        self.progressBar.hidden = NO;
    } else if (style == NBSyncingStyle) {
        UIActivityIndicatorView *activityIndicator = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
        activityIndicator.color = UIColor.whiteColor;
        [activityIndicator startAnimating];
        self.accessoryView = activityIndicator;        
    } else if (style == NBDoneStyle) {
        UIImage *doneImage = [UIImage imageNamed:@"checkmark.png"];
        UIImageView *imageView = [[UIImageView alloc] initWithImage:doneImage];
        imageView.contentMode = UIViewContentModeScaleAspectFit;
        self.accessoryView = imageView;
    }
}

- (void)show {
    [self showIn:(float)0.3f];
}

- (void)showIn:(float)time {
    if (!self.window) {
        return;
    }
    
    self.showing = YES;
    self.pendingHide = NO;
//    CGRect frame = self.frame;
//    frame.size.width = self.view.frame.size.width;
//    self.frame = frame;
    self.hidden = NO;
    
    topOffsetConstraint.constant = -1 * NOTIFIER_HEIGHT;
    
    [self.superview layoutIfNeeded];
    
    [UIView animateWithDuration:time animations:^{
//        CGRect move = self.frame;
//        move.origin.x = self.view.frame.origin.x + self.offset.x;
//        move.origin.y = self.view.frame.size.height - NOTIFIER_HEIGHT - self.offset.y;
//        self.frame = move;
        [self.superview layoutIfNeeded];
    } completion:nil];
}

- (void)hide {
    [self hideIn:0.3f];
}

- (void)hideNow {
    [self hideIn:0.0f];
}

- (void)hideIn:(float)seconds {
    if (!self.window) {
        self.pendingHide = YES;
        return;
    }
    
//    if (!showing) return;
    topOffsetConstraint.constant = 0;
    
    [UIView animateWithDuration:seconds animations:^{
//        CGRect move = self.frame;
//        move.origin.y = self.view.bounds.size.height - self.offset.y;
//        self.frame = move;
        [self.superview layoutIfNeeded];
    } completion:^(BOOL finished) {
//        self.hidden = YES;
    }];
    
    self.showing = NO;
    self.pendingHide = NO;
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

