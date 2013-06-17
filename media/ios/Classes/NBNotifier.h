//
//  NBNotifier.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/6/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NBNotifier : UIView {
    
    UIProgressView *progressBar;
    
    @protected
    UILabel *_txtLabel;
}

typedef enum {
    NBOfflineStyle = 1,
    NBLoadingStyle = 2,
    NBSyncingStyle = 3,
    NBSyncingProgressStyle = 4
} NBNotifierStyle;

@property (nonatomic, strong) NSString *_text;
@property (nonatomic) NBNotifierStyle style;
@property (nonatomic, strong) UIView *view;
@property (nonatomic, strong) UIView *accessoryView;
@property (nonatomic, strong) NSString *title;
@property (nonatomic, assign) BOOL showing;
@property (nonatomic, retain) UIProgressView *progressBar;

- (id)initWithTitle:(NSString *)title;
- (id)initWithTitle:(NSString *)title inView:(UIView *)view;
- (id)initWithTitle:(NSString *)title inView:(UIView *)view style:(NBNotifierStyle)style;

- (void)setAccessoryView:(UIView *)view animated:(BOOL)animated;
- (void)setProgress:(float)value;
- (void)setTitle:(id)title animated:(BOOL)animated;

- (void)show;
- (void)showIn:(float)time;
- (void)showFor:(float)time;

- (void)hide;
- (void)hideAfter:(float)seconds;
- (void)hideIn:(float)seconds;

@end
