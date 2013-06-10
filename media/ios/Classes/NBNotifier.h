//
//  NBNotifier.h
//  NewsBlur
//
//  Created by Samuel Clay on 6/6/13.
//  Copyright (c) 2013 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NBNotifier : UIView

typedef enum {
    NBOfflineStyle = 1,
    NBLoadingStyle = 2,
    NBSyncingStyle = 3
} NBNotifierStyle;

@property (assign, nonatomic) NSString *_text;
@property (assign, nonatomic) NBNotifierStyle _style;
@property (assign, nonatomic) UIView *_view;

- (id)drawInView:(UIView *)view withText:(NSString *)text style:(NBNotifierStyle)style;
- (void)hideWithAnimation:(BOOL)animate;

@end
