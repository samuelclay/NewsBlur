//
//  THCircularProgressBar.h
//
//  Created by Tiago Henriques on 3/4/13.
//  Copyright (c) 2013 Tiago Henriques. All rights reserved.
//

#import <UIKit/UIKit.h>

#pragma mark - Enums

typedef enum
{
    THProgressBackgroundModeNone,
    THProgressBackgroundModeCircle,
    THProgressBackgroundModeCircumference
} THProgressBackgroundMode;

typedef enum
{
    THProgressModeFill,
    THProgressModeDeplete
} THProgressMode;

#pragma mark - Interface

@interface THCircularProgressView : UIView

@property (nonatomic) CGFloat lineWidth;
@property (nonatomic) CGFloat percentage;
@property (nonatomic, strong) UILabel *centerLabel;
@property (nonatomic, strong) UIColor *progressColor;
@property (nonatomic, strong) UIColor *progressBackgroundColor;
@property THProgressMode progressMode;
@property THProgressBackgroundMode progressBackgroundMode;

- (id)initWithCenter:(CGPoint)center
              radius:(CGFloat)radius
           lineWidth:(CGFloat)lineWidth
        progressMode:(THProgressMode)progressMode
       progressColor:(UIColor *)progressColor
progressBackgroundMode:(THProgressBackgroundMode)backgroundMode
progressBackgroundColor:(UIColor *)progressBackgroundColor
          percentage:(CGFloat)percentage;

@end
