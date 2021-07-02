//
//  NBNotifier.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/6/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

#define NOTIFIER_HEIGHT 32

@interface NBNotifier : UIView {
    
    UIView *progressBar;
    
    @protected
    UILabel *_txtLabel;
    NSLayoutConstraint *progressBarWidthConstraint;
    NSLayoutConstraint *txtLabelLeadingConstraint;
}

typedef enum {
    NBOfflineStyle = 1,
    NBLoadingStyle = 2,
    NBSyncingStyle = 3,
    NBSyncingProgressStyle = 4,
    NBDoneStyle = 5
} NBNotifierStyle;

@property (nonatomic, strong) NSString *_text;
@property (nonatomic) NBNotifierStyle style;
@property (nonatomic, strong) UIView *view;
@property (nonatomic) CGPoint offset;
@property (nonatomic, strong) UIView *accessoryView;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) BOOL showing;
@property (nonatomic, assign) BOOL pendingHide;
@property (nonatomic, retain) UIView *progressBar;
@property (nonatomic) NSLayoutConstraint *topOffsetConstraint;

- (id)initWithTitle:(NSString *)title;
- (id)initWithTitle:(NSString *)title withOffset:(CGPoint)offset;
- (id)initWithTitle:(NSString *)title style:(NBNotifierStyle)style;
- (id)initWithTitle:(NSString *)title style:(NBNotifierStyle)style withOffset:(CGPoint)offset;

- (void)setProgress:(CGFloat)value;

- (void)show;
- (void)showIn:(float)time;

- (void)hide;
- (void)hideNow;
- (void)hideIn:(float)seconds;

@end
