//
//  NBNotifier.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/6/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NBNotifier : UIView {
    
    UIView *progressBar;
    
    @protected
    UILabel *_txtLabel;
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
@property (nonatomic, retain) UIView *progressBar;

- (id)initWithTitle:(NSString *)title;
- (id)initWithTitle:(NSString *)title inView:(UIView *)view;
- (id)initWithTitle:(NSString *)title inView:(UIView *)view withOffset:(CGPoint)offset;
- (id)initWithTitle:(NSString *)title inView:(UIView *)view style:(NBNotifierStyle)style;
- (id)initWithTitle:(NSString *)title inView:(UIView *)view style:(NBNotifierStyle)style withOffset:(CGPoint)offset;

- (void) didChangedOrientation:(NSNotification *)sender;
- (void)setAccessoryView:(UIView *)view animated:(BOOL)animated;
- (void)setProgress:(float)value;
- (void)setTitle:(id)title animated:(BOOL)animated;

- (void)show;
- (void)showIn:(float)time;

- (void)hide;
- (void)hideNow;
- (void)hideIn:(float)seconds;

@end
