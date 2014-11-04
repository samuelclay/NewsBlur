/*
 Version 0.2.2
 
 WYPopoverController is available under the MIT license.
 
 Copyright © 2013 Nicolas CHENG
 
 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the "Software"), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:
 
 The above copyright notice and this permission notice shall be included
 in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED,
 INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A
 PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION
 OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */

#import "WYPopoverController.h"

#import <objc/runtime.h>

#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#define WY_BASE_SDK_7_ENABLED
#endif

#ifdef DEBUG
#define WY_LOG(fmt, ...)		NSLog((@"%s (%d) : " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define WY_LOG(...)
#endif

#define WY_IS_IOS_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)

#define WY_IS_IOS_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)

#define WY_IS_IOS_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)

#define WY_IS_IOS_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)


////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIColor (WYPopover)

- (BOOL)getValueOfRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)apha;
- (NSString *)hexString;
- (UIColor *)colorByLighten:(float)d;
- (UIColor *)colorByDarken:(float)d;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation UIColor (WYPopover)

- (BOOL)getValueOfRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha
{
    // model: kCGColorSpaceModelRGB, num_comps: 4
    // model: kCGColorSpaceModelMonochrome, num_comps: 2
    
    CGColorSpaceRef colorSpace = CGColorSpaceRetain(CGColorGetColorSpace([self CGColor]));
    CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpace);
    CGColorSpaceRelease(colorSpace);
    
    CGFloat rFloat = 0.0, gFloat = 0.0, bFloat = 0.0, aFloat = 0.0;
    BOOL result = NO;
    
    if (colorSpaceModel == kCGColorSpaceModelRGB)
    {
        result = [self getRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];
    }
    else if (colorSpaceModel == kCGColorSpaceModelMonochrome)
    {
        result = [self getWhite:&rFloat alpha:&aFloat];
        gFloat = rFloat;
        bFloat = rFloat;
    }
    
    if (red) *red = rFloat;
    if (green) *green = gFloat;
    if (blue) *blue = bFloat;
    if (alpha) *alpha = aFloat;
    
    return result;
}

- (NSString *)hexString
{
    CGFloat rFloat, gFloat, bFloat, aFloat;
    int r, g, b, a;
    [self getValueOfRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];
    
    r = (int)(255.0 * rFloat);
    g = (int)(255.0 * gFloat);
    b = (int)(255.0 * bFloat);
    a = (int)(255.0 * aFloat);
    
    return [NSString stringWithFormat:@"#%02x%02x%02x%02x", r, g, b, a];
}

- (UIColor *)colorByLighten:(float)d
{
    CGFloat rFloat, gFloat, bFloat, aFloat;
    [self getValueOfRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];
    
    return [UIColor colorWithRed:MIN(rFloat + d, 1.0)
                           green:MIN(gFloat + d, 1.0)
                            blue:MIN(bFloat + d, 1.0)
                           alpha:1.0];
}

- (UIColor *)colorByDarken:(float)d
{
    CGFloat rFloat, gFloat, bFloat, aFloat;
    [self getValueOfRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];
    
    return [UIColor colorWithRed:MAX(rFloat - d, 0.0)
                           green:MAX(gFloat - d, 0.0)
                            blue:MAX(bFloat - d, 0.0)
                           alpha:1.0];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UINavigationController (WYPopover)

@property(nonatomic, assign, getter = isEmbedInPopover) BOOL embedInPopover;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation UINavigationController (WYPopover)

static char const * const UINavigationControllerEmbedInPopoverTagKey = "UINavigationControllerEmbedInPopoverTagKey";

@dynamic embedInPopover;

+ (void)load
{
    Method original, swizzle;
    
    original = class_getInstanceMethod(self, @selector(pushViewController:animated:));
    swizzle = class_getInstanceMethod(self, @selector(sizzled_pushViewController:animated:));
    
    method_exchangeImplementations(original, swizzle);
    
    original = class_getInstanceMethod(self, @selector(setViewControllers:animated:));
    swizzle = class_getInstanceMethod(self, @selector(sizzled_setViewControllers:animated:));
    
    method_exchangeImplementations(original, swizzle);
}

- (BOOL)isEmbedInPopover
{
    BOOL result = NO;
    
    NSNumber *value = objc_getAssociatedObject(self, UINavigationControllerEmbedInPopoverTagKey);
    
    if (value)
    {
        result = [value boolValue];
    }
    
    return result;
}

- (void)setEmbedInPopover:(BOOL)value
{
    objc_setAssociatedObject(self, UINavigationControllerEmbedInPopoverTagKey, [NSNumber numberWithBool:value], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)contentSize:(UIViewController *)aViewController
{
    CGSize result = CGSizeZero;
    
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    if ([aViewController respondsToSelector:@selector(contentSizeForViewInPopover)])
    {
        result = aViewController.contentSizeForViewInPopover;
    }
#pragma clang diagnostic pop
    
#ifdef WY_BASE_SDK_7_ENABLED
    if ([aViewController respondsToSelector:@selector(preferredContentSize)])
    {
        result = aViewController.preferredContentSize;
    }
#endif
    
    return result;
}

- (void)setContentSize:(CGSize)aContentSize
{
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    [self setContentSizeForViewInPopover:aContentSize];
#pragma clang diagnostic pop
    
#ifdef WY_BASE_SDK_7_ENABLED
    if ([self respondsToSelector:@selector(setPreferredContentSize:)]) {
        [self setPreferredContentSize:aContentSize];
    }
#endif
}

- (void)sizzled_pushViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated
{
    if (self.isEmbedInPopover)
    {
#ifdef WY_BASE_SDK_7_ENABLED
        if ([aViewController respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
            aViewController.edgesForExtendedLayout = UIRectEdgeNone;
        }
#endif
        CGSize contentSize = [self contentSize:aViewController];
        [self setContentSize:contentSize];
    }
    
    [self sizzled_pushViewController:aViewController animated:aAnimated];
    
    if (self.isEmbedInPopover)
    {
        CGSize contentSize = [self contentSize:aViewController];
        [self setContentSize:contentSize];
    }
}

- (void)sizzled_setViewControllers:(NSArray *)aViewControllers animated:(BOOL)aAnimated
{
    NSUInteger count = [aViewControllers count];
    
#ifdef WY_BASE_SDK_7_ENABLED
    if (self.isEmbedInPopover && count > 0)
    {
        for (UIViewController *viewController in aViewControllers) {
            if ([viewController respondsToSelector:@selector(setEdgesForExtendedLayout:)])
            {
                viewController.edgesForExtendedLayout = UIRectEdgeNone;
            }
        }
    }
#endif
    
    [self sizzled_setViewControllers:aViewControllers animated:aAnimated];
    
    if (self.isEmbedInPopover && count > 0)
    {
        UIViewController *topViewController = [aViewControllers objectAtIndex:(count - 1)];
        CGSize contentSize = [self contentSize:topViewController];
        [self setContentSize:contentSize];
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIViewController (WYPopover)
@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation UIViewController (WYPopover)

+ (void)load
{
    Method original, swizzle;
    
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    original = class_getInstanceMethod(self, @selector(setContentSizeForViewInPopover:));
    swizzle = class_getInstanceMethod(self, @selector(sizzled_setContentSizeForViewInPopover:));
    method_exchangeImplementations(original, swizzle);
#pragma clang diagnostic pop
    
#ifdef WY_BASE_SDK_7_ENABLED
    original = class_getInstanceMethod(self, @selector(setPreferredContentSize:));
    swizzle = class_getInstanceMethod(self, @selector(sizzled_setPreferredContentSize:));
    
    if (original != NULL) {
        method_exchangeImplementations(original, swizzle);
    }
#endif
}

- (void)sizzled_setContentSizeForViewInPopover:(CGSize)aSize
{
    [self sizzled_setContentSizeForViewInPopover:aSize];
    
    if ([self isKindOfClass:[UINavigationController class]] == NO && self.navigationController != nil)
    {
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
        [self.navigationController setContentSizeForViewInPopover:aSize];
#pragma clang diagnostic pop
    }
}

- (void)sizzled_setPreferredContentSize:(CGSize)aSize
{
    [self sizzled_setPreferredContentSize:aSize];
    
    if ([self isKindOfClass:[UINavigationController class]] == NO && self.navigationController != nil)
    {
#ifdef WY_BASE_SDK_7_ENABLED
        if ([self respondsToSelector:@selector(setPreferredContentSize:)]) {
            [self.navigationController setPreferredContentSize:aSize];
        }
#endif
    }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface WYPopoverArea : NSObject
{
}

@property (nonatomic, assign) WYPopoverArrowDirection arrowDirection;
@property (nonatomic, assign) CGSize areaSize;
@property (nonatomic, assign, readonly) float value;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - WYPopoverArea

@implementation WYPopoverArea

@synthesize arrowDirection;
@synthesize areaSize;
@synthesize value;

- (NSString*)description
{
    NSString* direction = @"";
    
    if (arrowDirection == WYPopoverArrowDirectionUp)
    {
        direction = @"UP";
    }
    else if (arrowDirection == WYPopoverArrowDirectionDown)
    {
        direction = @"DOWN";
    }
    else if (arrowDirection == WYPopoverArrowDirectionLeft)
    {
        direction = @"LEFT";
    }
    else if (arrowDirection == WYPopoverArrowDirectionRight)
    {
        direction = @"RIGHT";
    }
    else if (arrowDirection == WYPopoverArrowDirectionNone)
    {
        direction = @"NONE";
    }
    
    return [NSString stringWithFormat:@"%@ [ %f x %f ]", direction, areaSize.width, areaSize.height];
}

- (float)value
{
    float result = 0;
    
    if (areaSize.width > 0 && areaSize.height > 0)
    {
        float w1 = ceilf(areaSize.width / 10.0);
        float h1 = ceilf(areaSize.height / 10.0);
        
        result = (w1 * h1);
    }
    
    return result;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface WYPopoverTheme ()

- (NSArray *)observableKeypaths;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation WYPopoverTheme

@synthesize usesRoundedArrow;
@synthesize adjustsTintColor;
@synthesize tintColor;
@synthesize fillTopColor;
@synthesize fillBottomColor;

@synthesize glossShadowColor;
@synthesize glossShadowOffset;
@synthesize glossShadowBlurRadius;

@synthesize borderWidth;
@synthesize arrowBase;
@synthesize arrowHeight;

@synthesize outerShadowColor;
@synthesize outerStrokeColor;
@synthesize outerShadowBlurRadius;
@synthesize outerShadowOffset;
@synthesize outerCornerRadius;
@synthesize minOuterCornerRadius;

@synthesize innerShadowColor;
@synthesize innerStrokeColor;
@synthesize innerShadowBlurRadius;
@synthesize innerShadowOffset;
@synthesize innerCornerRadius;

@synthesize viewContentInsets;

@synthesize overlayColor;

+ (id)theme {
    
    WYPopoverTheme *result = nil;
    
    if (WY_IS_IOS_LESS_THAN(@"7.0")) {
        result = [WYPopoverTheme themeForIOS6];
    } else {
        result = [WYPopoverTheme themeForIOS7];
    }
    
    return result;
}

+ (id)themeForIOS6 {
    
    WYPopoverTheme *result = [[WYPopoverTheme alloc] init];
    
    result.usesRoundedArrow = @NO;
    result.adjustsTintColor = @YES;
    result.tintColor = [UIColor colorWithRed:55./255. green:63./255. blue:71./255. alpha:1.0];
    result.outerStrokeColor = nil;
    result.innerStrokeColor = nil;
    result.fillTopColor = result.tintColor;
    result.fillBottomColor = [result.tintColor colorByDarken:0.4];
    result.glossShadowColor = nil;
    result.glossShadowOffset = CGSizeMake(0, 1.5);
    result.glossShadowBlurRadius = 0;
    result.borderWidth = 6;
    result.arrowBase = 42;
    result.arrowHeight = 18;
    result.outerShadowColor = [UIColor colorWithWhite:0 alpha:0.75];
    result.outerShadowBlurRadius = 8;
    result.outerShadowOffset = CGSizeMake(0, 2);
    result.outerCornerRadius = 8;
    result.minOuterCornerRadius = 0;
    result.innerShadowColor = [UIColor colorWithWhite:0 alpha:0.75];
    result.innerShadowBlurRadius = 2;
    result.innerShadowOffset = CGSizeMake(0, 1);
    result.innerCornerRadius = 6;
    result.viewContentInsets = UIEdgeInsetsMake(3, 0, 0, 0);
    result.overlayColor = [UIColor clearColor];
    
    return result;
}

+ (id)themeForIOS7 {
    
    WYPopoverTheme *result = [[WYPopoverTheme alloc] init];
    
    result.usesRoundedArrow = @YES;
    result.adjustsTintColor = @YES;
    result.tintColor = [UIColor colorWithRed:244./255. green:244./255. blue:244./255. alpha:1.0];
    result.outerStrokeColor = [UIColor clearColor];
    result.innerStrokeColor = [UIColor clearColor];
    result.fillTopColor = nil;
    result.fillBottomColor = nil;
    result.glossShadowColor = nil;
    result.glossShadowOffset = CGSizeZero;
    result.glossShadowBlurRadius = 0;
    result.borderWidth = 0;
    result.arrowBase = 25;
    result.arrowHeight = 13;
    result.outerShadowColor = [UIColor clearColor];
    result.outerShadowBlurRadius = 0;
    result.outerShadowOffset = CGSizeZero;
    result.outerCornerRadius = 5;
    result.minOuterCornerRadius = 0;
    result.innerShadowColor = [UIColor clearColor];
    result.innerShadowBlurRadius = 0;
    result.innerShadowOffset = CGSizeZero;
    result.innerCornerRadius = 0;
    result.viewContentInsets = UIEdgeInsetsZero;
    result.overlayColor = [UIColor colorWithWhite:0 alpha:0.15];
    
    return result;
}

- (NSUInteger)innerCornerRadius
{
    float result = innerCornerRadius;
    
    if (borderWidth == 0)
    {
        result = 0;
        
        if (outerCornerRadius > 0)
        {
            result = outerCornerRadius;
        }
    }
    
    return result;
}

- (CGSize)outerShadowOffset
{
    CGSize result = outerShadowOffset;
    
    result.width = MIN(result.width, outerShadowBlurRadius);
    result.height = MIN(result.height, outerShadowBlurRadius);
    
    return result;
}

- (UIColor *)innerStrokeColor
{
    UIColor *result = innerStrokeColor;
    
    if (result == nil)
    {
        result = [self.fillTopColor colorByDarken:0.6];
    }
    
    return result;
}

- (UIColor *)outerStrokeColor
{
    UIColor *result = outerStrokeColor;
    
    if (result == nil)
    {
        result = [self.fillTopColor colorByDarken:0.6];
    }
    
    return result;
}

- (UIColor *)glossShadowColor
{
    UIColor *result = glossShadowColor;
    
    if (result == nil)
    {
        result = [self.fillTopColor colorByLighten:0.2];
    }
    
    return result;
}

- (UIColor *)fillTopColor
{
    UIColor *result = fillTopColor;
    
    if (result == nil)
    {
        result = tintColor;
    }
    
    return result;
}

- (UIColor *)fillBottomColor
{
    UIColor *result = fillBottomColor;
    
    if (result == nil)
    {
        result = self.fillTopColor;
    }
    
    return result;
}

- (NSArray *)observableKeypaths {
    return [NSArray arrayWithObjects:@"tintColor", @"outerStrokeColor", @"innerStrokeColor", @"fillTopColor", @"fillBottomColor", @"glossShadowColor", @"glossShadowOffset", @"glossShadowBlurRadius", @"borderWidth", @"arrowBase", @"arrowHeight", @"outerShadowColor", @"outerShadowBlurRadius", @"outerShadowOffset", @"outerCornerRadius", @"innerShadowColor", @"innerShadowBlurRadius", @"innerShadowOffset", @"innerCornerRadius", @"viewContentInsets", @"overlayColor", nil];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIImage (WYPopover)

+ (UIImage *)imageWithColor:(UIColor *)color;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - UIImage (WYPopover)

@implementation UIImage (WYPopover)

static float edgeSizeFromCornerRadius(float cornerRadius) {
    return cornerRadius * 2 + 1;
}

+ (UIImage *)imageWithColor:(UIColor *)color
{
    return [self imageWithColor:color size:CGSizeMake(8, 8) cornerRadius:0];
}

+ (UIImage *)imageWithColor:(UIColor *)color
               cornerRadius:(float)cornerRadius
{
    float min = edgeSizeFromCornerRadius(cornerRadius);
    
    CGSize minSize = CGSizeMake(min, min);
    
    return [self imageWithColor:color size:minSize cornerRadius:cornerRadius];
}

+ (UIImage *)imageWithColor:(UIColor *)color
                       size:(CGSize)aSize
               cornerRadius:(float)cornerRadius
{
    CGRect rect = CGRectMake(0, 0, aSize.width, aSize.height);
    UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:cornerRadius];
    roundedRect.lineWidth = 0;
    UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0f);
    [color setFill];
    [roundedRect fill];
    //[roundedRect stroke];
    //[roundedRect addClip];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    return [image resizableImageWithCapInsets:UIEdgeInsetsMake(cornerRadius, cornerRadius, cornerRadius, cornerRadius)];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface WYPopoverBackgroundInnerView : UIView

@property (nonatomic, strong) UIColor *innerStrokeColor;

@property (nonatomic, strong) UIColor *gradientTopColor;
@property (nonatomic, strong) UIColor *gradientBottomColor;
@property (nonatomic, assign) float  gradientHeight;
@property (nonatomic, assign) float  gradientTopPosition;

@property (nonatomic, strong) UIColor *innerShadowColor;
@property (nonatomic, assign) CGSize   innerShadowOffset;
@property (nonatomic, assign) float  innerShadowBlurRadius;
@property (nonatomic, assign) float  innerCornerRadius;

@property (nonatomic, assign) float  navigationBarHeight;
@property (nonatomic, assign) BOOL     wantsDefaultContentAppearance;
@property (nonatomic, assign) float  borderWidth;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - WYPopoverInnerView

@implementation WYPopoverBackgroundInnerView

@synthesize innerStrokeColor;

@synthesize gradientTopColor;
@synthesize gradientBottomColor;
@synthesize gradientHeight;
@synthesize gradientTopPosition;

@synthesize innerShadowColor;
@synthesize innerShadowOffset;
@synthesize innerShadowBlurRadius;
@synthesize innerCornerRadius;

@synthesize navigationBarHeight;
@synthesize wantsDefaultContentAppearance;
@synthesize borderWidth;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self)
    {
        self.backgroundColor = [UIColor clearColor];
        self.userInteractionEnabled = NO;
    }
    return self;
}

- (void)drawRect:(CGRect)rect
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = UIGraphicsGetCurrentContext();
    
    //// Gradient Declarations
    NSArray* fillGradientColors = [NSArray arrayWithObjects:
                                   (id)gradientTopColor.CGColor,
                                   (id)gradientBottomColor.CGColor, nil];
    
    CGFloat fillGradientLocations[2] = { 0, 1 };
    
    CGGradientRef fillGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)fillGradientColors, fillGradientLocations);
    
    //// innerRect Drawing
    float barHeight = (wantsDefaultContentAppearance == NO) ? navigationBarHeight : 0;
    float cornerRadius = (wantsDefaultContentAppearance == NO) ? innerCornerRadius : 0;
    
    CGRect innerRect = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect) + barHeight, CGRectGetWidth(rect) , CGRectGetHeight(rect) - barHeight);
    
    UIBezierPath* rectPath = [UIBezierPath bezierPathWithRect:innerRect];
    
    UIBezierPath* roundedRectPath = [UIBezierPath bezierPathWithRoundedRect:innerRect cornerRadius:cornerRadius + 1];
    
    if (wantsDefaultContentAppearance == NO && borderWidth > 0)
    {
        CGContextSaveGState(context);
        {
            [rectPath appendPath:roundedRectPath];
            rectPath.usesEvenOddFillRule = YES;
            [rectPath addClip];
            
            CGContextDrawLinearGradient(context, fillGradient,
                                        CGPointMake(0, -gradientTopPosition),
                                        CGPointMake(0, -gradientTopPosition + gradientHeight),
                                        0);
        }
        CGContextRestoreGState(context);
    }
    
    CGContextSaveGState(context);
    {
        if (wantsDefaultContentAppearance == NO && borderWidth > 0)
        {
            [roundedRectPath addClip];
            CGContextSetShadowWithColor(context, innerShadowOffset, innerShadowBlurRadius, innerShadowColor.CGColor);
        }
        
        UIBezierPath* inRoundedRectPath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(innerRect, 0.5, 0.5) cornerRadius:cornerRadius];
        
        if (borderWidth == 0)
        {
            inRoundedRectPath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(innerRect, 0.5, 0.5) byRoundingCorners:UIRectCornerBottomLeft|UIRectCornerBottomRight cornerRadii:CGSizeMake(cornerRadius, cornerRadius)];
        }
        
        [self.innerStrokeColor setStroke];
        inRoundedRectPath.lineWidth = 1;
        [inRoundedRectPath stroke];
    }
    
    CGContextRestoreGState(context);
    
    CGGradientRelease(fillGradient);
    CGColorSpaceRelease(colorSpace);
}

- (void)dealloc
{
    innerShadowColor = nil;
    innerStrokeColor = nil;
    gradientTopColor = nil;
    gradientBottomColor = nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol WYPopoverOverlayViewDelegate;

@interface WYPopoverOverlayView : UIView
{
    BOOL testHits;
}

@property(nonatomic, assign) id <WYPopoverOverlayViewDelegate> delegate;
@property(nonatomic, unsafe_unretained) NSArray *passthroughViews;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - WYPopoverOverlayViewDelegate

@protocol WYPopoverOverlayViewDelegate <NSObject>

@optional
- (void)popoverOverlayViewDidTouch:(WYPopoverOverlayView *)overlayView;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - WYPopoverOverlayView

@implementation WYPopoverOverlayView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
    if (testHits) {
        return nil;
    }
    
    UIView *view = [super hitTest:point withEvent:event];
    
    if (view == self)
    {
        testHits = YES;
        UIView *superHitView = [self.superview hitTest:point withEvent:event];
        testHits = NO;
        
        if ([self isPassthroughView:superHitView])
        {
            return superHitView;
        }
    }
    
    return view;
}

- (BOOL)isPassthroughView:(UIView *)view
{
	if (view == nil)
    {
		return NO;
	}
	
	if ([self.passthroughViews containsObject:view])
    {
		return YES;
	}
	
	return [self isPassthroughView:view.superview];
}

#pragma mark - UIAccessibility

- (void)accessibilityElementDidBecomeFocused {
    self.accessibilityLabel = NSLocalizedString(@"Double-tap to dismiss pop-up window.", nil);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - WYPopoverBackgroundViewDelegate

@protocol WYPopoverBackgroundViewDelegate <NSObject>

@optional
- (void)popoverBackgroundViewDidTouchOutside:(WYPopoverBackgroundView *)backgroundView;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface WYPopoverBackgroundView ()
{
    WYPopoverBackgroundInnerView *innerView;
    CGSize contentSize;
}

@property(nonatomic, assign) id <WYPopoverBackgroundViewDelegate> delegate;

@property (nonatomic, assign) WYPopoverArrowDirection arrowDirection;

@property (nonatomic, strong, readonly) UIView *contentView;
@property (nonatomic, assign, readonly) float navigationBarHeight;
@property (nonatomic, assign, readonly) UIEdgeInsets outerShadowInsets;
@property (nonatomic, assign) float arrowOffset;
@property (nonatomic, assign) BOOL wantsDefaultContentAppearance;

@property (nonatomic, assign, getter = isAppearing) BOOL appearing;

- (void)tapOut;

- (void)setViewController:(UIViewController *)viewController;

- (CGRect)outerRect;
- (CGRect)innerRect;
- (CGRect)arrowRect;

- (CGRect)outerRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection;
- (CGRect)innerRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection;
- (CGRect)arrowRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection;

- (id)initWithContentSize:(CGSize)contentSize;

- (BOOL)isTouchedAtPoint:(CGPoint)point;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - WYPopoverBackgroundView

@implementation WYPopoverBackgroundView

@synthesize tintColor;

@synthesize fillTopColor;
@synthesize fillBottomColor;
@synthesize glossShadowColor;
@synthesize glossShadowOffset;
@synthesize glossShadowBlurRadius;
@synthesize borderWidth;
@synthesize arrowBase;
@synthesize arrowHeight;
@synthesize outerShadowColor;
@synthesize outerStrokeColor;
@synthesize outerShadowBlurRadius;
@synthesize outerShadowOffset;
@synthesize outerCornerRadius;
@synthesize minOuterCornerRadius;
@synthesize innerShadowColor;
@synthesize innerStrokeColor;
@synthesize innerShadowBlurRadius;
@synthesize innerShadowOffset;
@synthesize innerCornerRadius;
@synthesize viewContentInsets;

@synthesize arrowDirection;
@synthesize contentView;
@synthesize arrowOffset;
@synthesize navigationBarHeight;
@synthesize wantsDefaultContentAppearance;

@synthesize outerShadowInsets;

- (id)initWithContentSize:(CGSize)aContentSize
{
    self = [super initWithFrame:CGRectMake(0, 0, aContentSize.width, aContentSize.height)];
    
    if (self != nil)
    {
        contentSize = aContentSize;
        
        self.autoresizesSubviews = NO;
        self.backgroundColor = [UIColor clearColor];
        
        self.arrowDirection = WYPopoverArrowDirectionDown;
        self.arrowOffset = 0;
        
        self.layer.name = @"parent";
        
        if (WY_IS_IOS_GREATER_THAN_OR_EQUAL_TO(@"6.0"))
        {
            self.layer.drawsAsynchronously = YES;
        }
        
        self.layer.contentsScale = [UIScreen mainScreen].scale;
        //self.layer.edgeAntialiasingMask = kCALayerLeftEdge | kCALayerRightEdge | kCALayerBottomEdge | kCALayerTopEdge;
        self.layer.delegate = self;
    }
    
    return self;
}

- (void)tapOut
{
    [self.delegate popoverBackgroundViewDidTouchOutside:self];
}

/*
- (BOOL)pointInside:(CGPoint)point withEvent:(UIEvent *)event
{
    BOOL result = [super pointInside:point withEvent:event];
    
    if (self.isAppearing == NO)
    {
        BOOL isTouched = [self isTouchedAtPoint:point];
        
        if (isTouched == NO && UIAccessibilityIsVoiceOverRunning())
        {
            UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
            UIAccessibilityPostNotification(UIAccessibilityAnnouncementNotification, NSLocalizedString(@"Double-tap to dismiss pop-up window.", nil));
        }
    }
    
    return result;
}
*/

- (UIEdgeInsets)outerShadowInsets
{
    UIEdgeInsets result = UIEdgeInsetsMake(outerShadowBlurRadius, outerShadowBlurRadius, outerShadowBlurRadius, outerShadowBlurRadius);
    
    result.top -= self.outerShadowOffset.height;
    result.bottom += self.outerShadowOffset.height;
    result.left -= self.outerShadowOffset.width;
    result.right += self.outerShadowOffset.width;
    
    return result;
}

- (void)setArrowOffset:(float)value
{
    float coef = 1;
    
    if (value != 0)
    {
        coef = value / ABS(value);
        
        value = ABS(value);
        
        CGRect outerRect = [self outerRect];
        
        float delta = self.arrowBase / 2. + .5;
        
        delta  += MIN(minOuterCornerRadius, outerCornerRadius);
        
        outerRect = CGRectInset(outerRect, delta, delta);
        
        if (arrowDirection == WYPopoverArrowDirectionUp || arrowDirection == WYPopoverArrowDirectionDown)
        {
            value += coef * self.outerShadowOffset.width;
            value = MIN(value, CGRectGetWidth(outerRect) / 2);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionLeft || arrowDirection == WYPopoverArrowDirectionRight)
        {
            value += coef * self.outerShadowOffset.height;
            value = MIN(value, CGRectGetHeight(outerRect) / 2);
        }
    }
    else
    {
        if (arrowDirection == WYPopoverArrowDirectionUp || arrowDirection == WYPopoverArrowDirectionDown)
        {
            value += self.outerShadowOffset.width;
        }
        
        if (arrowDirection == WYPopoverArrowDirectionLeft || arrowDirection == WYPopoverArrowDirectionRight)
        {
            value += self.outerShadowOffset.height;
        }
    }
    
    arrowOffset = value * coef;
}

- (void)setViewController:(UIViewController *)viewController
{
    contentView = viewController.view;
    
    contentView.frame = CGRectIntegral(CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));
    
    [self addSubview:contentView];
    
    navigationBarHeight = 0;
    
    if ([viewController isKindOfClass:[UINavigationController class]])
    {
        UINavigationController* navigationController = (UINavigationController*)viewController;
        navigationBarHeight = navigationController.navigationBarHidden? 0 : navigationController.navigationBar.bounds.size.height;
    }
    
    contentView.frame = CGRectIntegral([self innerRect]);
    
    if (innerView == nil)
    {
        innerView = [[WYPopoverBackgroundInnerView alloc] initWithFrame:contentView.frame];
        innerView.userInteractionEnabled = NO;
        
        innerView.gradientTopColor = self.fillTopColor;
        innerView.gradientBottomColor = self.fillBottomColor;
        innerView.innerShadowColor = innerShadowColor;
        innerView.innerStrokeColor = self.innerStrokeColor;
        innerView.innerShadowOffset = innerShadowOffset;
        innerView.innerCornerRadius = self.innerCornerRadius;
        innerView.innerShadowBlurRadius = innerShadowBlurRadius;
        innerView.borderWidth = self.borderWidth;
    }
    
    innerView.navigationBarHeight = navigationBarHeight;
    innerView.gradientHeight = self.frame.size.height - 2 * outerShadowBlurRadius;
    innerView.gradientTopPosition = contentView.frame.origin.y - self.outerShadowInsets.top;
    innerView.wantsDefaultContentAppearance = wantsDefaultContentAppearance;
    
    [self insertSubview:innerView aboveSubview:contentView];
    
    innerView.frame = CGRectIntegral(contentView.frame);
    
    [self.layer setNeedsDisplay];
}

- (CGSize)sizeThatFits:(CGSize)size
{
    CGSize result = size;
    
    result.width += 2 * (borderWidth + outerShadowBlurRadius);
    result.height += borderWidth + 2 * outerShadowBlurRadius;
    
    if (navigationBarHeight == 0)
    {
        result.height += borderWidth;
    }
    
    if (arrowDirection == WYPopoverArrowDirectionUp || arrowDirection == WYPopoverArrowDirectionDown)
    {
        result.height += arrowHeight;
    }
    
    if (arrowDirection == WYPopoverArrowDirectionLeft || arrowDirection == WYPopoverArrowDirectionRight)
    {
        result.width += arrowHeight;
    }
    
    return result;
}

- (void)sizeToFit
{
    CGSize size = [self sizeThatFits:contentSize];
    self.bounds = CGRectMake(0, 0, size.width, size.height);
}

#pragma mark Drawing

- (void)setNeedsDisplay
{
    [super setNeedsDisplay];
    
    [self.layer setNeedsDisplay];
    
    if (innerView)
    {
        innerView.gradientTopColor = self.fillTopColor;
        innerView.gradientBottomColor = self.fillBottomColor;
        innerView.innerShadowColor = innerShadowColor;
        innerView.innerStrokeColor = self.innerStrokeColor;
        innerView.innerShadowOffset = innerShadowOffset;
        innerView.innerCornerRadius = self.innerCornerRadius;
        innerView.innerShadowBlurRadius = innerShadowBlurRadius;
        innerView.borderWidth = self.borderWidth;
        
        innerView.navigationBarHeight = navigationBarHeight;
        innerView.gradientHeight = self.frame.size.height - 2 * outerShadowBlurRadius;
        innerView.gradientTopPosition = contentView.frame.origin.y - self.outerShadowInsets.top;
        innerView.wantsDefaultContentAppearance = wantsDefaultContentAppearance;
        
        [innerView setNeedsDisplay];
    }
}

#pragma mark CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context
{
    if ([layer.name isEqualToString:@"parent"])
    {
        UIGraphicsPushContext(context);
        //CGContextSetShouldAntialias(context, YES);
        //CGContextSetAllowsAntialiasing(context, YES);
        
        //// General Declarations
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
        
        //// Gradient Declarations
        NSArray* fillGradientColors = [NSArray arrayWithObjects:
                                       (id)self.fillTopColor.CGColor,
                                       (id)self.fillBottomColor.CGColor, nil];
        
        CGFloat fillGradientLocations[2] = {0, 1};
        CGGradientRef fillGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)fillGradientColors, fillGradientLocations);
        
        // Frames
        CGRect rect = self.bounds;
        
        CGRect outerRect = [self outerRect:rect arrowDirection:self.arrowDirection];
        outerRect = CGRectInset(outerRect, 0.5, 0.5);
        
        // Inner Path
        CGMutablePathRef outerPathRef = CGPathCreateMutable();
        
        UIBezierPath* outerRectPath = [UIBezierPath bezierPath];
        
        CGPoint origin = CGPointZero;
        
        float reducedOuterCornerRadius = 0;
        
        if (arrowDirection == WYPopoverArrowDirectionUp || arrowDirection == WYPopoverArrowDirectionDown)
        {
            if (arrowOffset >= 0)
            {
                reducedOuterCornerRadius = CGRectGetMaxX(outerRect) - (CGRectGetMidX(outerRect) + arrowOffset + arrowBase / 2);
            }
            else
            {
                reducedOuterCornerRadius = (CGRectGetMidX(outerRect) + arrowOffset - arrowBase / 2) - CGRectGetMinX(outerRect);
            }
        }
        else if (arrowDirection == WYPopoverArrowDirectionLeft || arrowDirection == WYPopoverArrowDirectionRight)
        {
            if (arrowOffset >= 0)
            {
                reducedOuterCornerRadius = CGRectGetMaxY(outerRect) - (CGRectGetMidY(outerRect) + arrowOffset + arrowBase / 2);
            }
            else
            {
                reducedOuterCornerRadius = (CGRectGetMidY(outerRect) + arrowOffset - arrowBase / 2) - CGRectGetMinY(outerRect);
            }
        }
        
        reducedOuterCornerRadius = MIN(reducedOuterCornerRadius, outerCornerRadius);
        
        if (arrowDirection == WYPopoverArrowDirectionUp)
        {
            origin = CGPointMake(CGRectGetMidX(outerRect) + arrowOffset - arrowBase / 2, CGRectGetMinY(outerRect));
            
            CGPathMoveToPoint(outerPathRef, NULL, origin.x, origin.y);
            
            if (self.usesRoundedArrow.boolValue) {
                CGPoint roundedOrigin = CGPointMake(CGRectGetMidX(outerRect) + arrowOffset - (arrowBase / 2), CGRectGetMinY(outerRect) - arrowHeight);
                CGFloat controlLength = arrowBase / 5.f;
                
                UIBezierPath* arrowPath = UIBezierPath.bezierPath;
                [arrowPath moveToPoint: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + arrowHeight)];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + (arrowBase / 2), roundedOrigin.y + 0) controlPoint1: CGPointMake(roundedOrigin.x + controlLength, roundedOrigin.y + 12) controlPoint2: CGPointMake(roundedOrigin.x + ((arrowBase / 2) - (controlLength * 0.75f)), roundedOrigin.y + 0)];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + arrowBase, roundedOrigin.y + arrowHeight) controlPoint1: CGPointMake(roundedOrigin.x + ((arrowBase / 2) + (controlLength * 0.75f)), roundedOrigin.y + 0) controlPoint2: CGPointMake(roundedOrigin.x + (arrowBase - controlLength), roundedOrigin.y + arrowHeight)];
                [UIColor.whiteColor setFill];
                [arrowPath fill];
                
                outerRectPath = arrowPath;
            } else {
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMidX(outerRect) + arrowOffset, CGRectGetMinY(outerRect) - arrowHeight);
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMidX(outerRect) + arrowOffset + arrowBase / 2, CGRectGetMinY(outerRect));
            }
            
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), (arrowOffset >= 0) ? reducedOuterCornerRadius : outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), (arrowOffset < 0) ? reducedOuterCornerRadius : outerCornerRadius);
            
            CGPathAddLineToPoint(outerPathRef, NULL, origin.x, origin.y);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionDown)
        {
            origin = CGPointMake(CGRectGetMidX(outerRect) + arrowOffset + arrowBase / 2, CGRectGetMaxY(outerRect));
            
            CGPathMoveToPoint(outerPathRef, NULL, origin.x, origin.y);
            
            if (self.usesRoundedArrow.boolValue) {
                CGPoint roundedOrigin = CGPointMake(CGRectGetMidX(outerRect) + arrowOffset - (arrowBase / 2), CGRectGetMaxY(outerRect));
                CGFloat controlLength = arrowBase / 5.f;
                
                UIBezierPath* arrowPath = UIBezierPath.bezierPath;
                [arrowPath moveToPoint: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + 0)];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + (arrowBase / 2), roundedOrigin.y + arrowHeight) controlPoint1: CGPointMake(roundedOrigin.x + controlLength, roundedOrigin.y + 0) controlPoint2: CGPointMake(roundedOrigin.x + ((arrowBase / 2) - (controlLength * 0.75f)), roundedOrigin.y + arrowHeight)];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + arrowBase, roundedOrigin.y + 0) controlPoint1: CGPointMake(roundedOrigin.x + ((arrowBase / 2) + (controlLength * 0.75f)), roundedOrigin.y + arrowHeight) controlPoint2: CGPointMake(roundedOrigin.x + (arrowBase - controlLength), roundedOrigin.y + 0)];
                [UIColor.whiteColor setFill];
                [arrowPath fill];
                
                outerRectPath = arrowPath;
            } else {
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMidX(outerRect) + arrowOffset, CGRectGetMaxY(outerRect) + arrowHeight);
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMidX(outerRect) + arrowOffset - arrowBase / 2, CGRectGetMaxY(outerRect));
            }
            
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), (arrowOffset < 0) ? reducedOuterCornerRadius : outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), (arrowOffset >= 0) ? reducedOuterCornerRadius : outerCornerRadius);
            
            CGPathAddLineToPoint(outerPathRef, NULL, origin.x, origin.y);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionLeft)
        {
            origin = CGPointMake(CGRectGetMinX(outerRect), CGRectGetMidY(outerRect) + arrowOffset + arrowBase / 2);
            
            CGPathMoveToPoint(outerPathRef, NULL, origin.x, origin.y);
            
            if (self.usesRoundedArrow.boolValue) {
                CGPoint roundedOrigin = CGPointMake(CGRectGetMinX(outerRect) - arrowHeight, CGRectGetMidY(outerRect) + arrowOffset - ( arrowBase / 2));
                CGFloat controlLength = arrowBase / 5.f;
                
                UIBezierPath* arrowPath = UIBezierPath.bezierPath;
                [arrowPath moveToPoint: CGPointMake(roundedOrigin.x + arrowHeight, roundedOrigin.y + arrowBase)];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + (arrowBase / 2)) controlPoint1: CGPointMake(roundedOrigin.x + arrowHeight, roundedOrigin.y + (arrowBase - controlLength)) controlPoint2: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + ((arrowBase / 2) + controlLength))];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + arrowHeight, roundedOrigin.y + 0) controlPoint1: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + ((arrowBase / 2) - controlLength)) controlPoint2: CGPointMake(roundedOrigin.x + arrowHeight, roundedOrigin.y + controlLength)];
                [UIColor.whiteColor setFill];
                [arrowPath fill];
                
                outerRectPath = arrowPath;
            } else {
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect) - arrowHeight, CGRectGetMidY(outerRect) + arrowOffset);
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMidY(outerRect) + arrowOffset - arrowBase / 2);
            }
            
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), (arrowOffset < 0) ? reducedOuterCornerRadius : outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), (arrowOffset >= 0) ? reducedOuterCornerRadius : outerCornerRadius);
            
            CGPathAddLineToPoint(outerPathRef, NULL, origin.x, origin.y);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionRight)
        {
            origin = CGPointMake(CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect) + arrowOffset - arrowBase / 2);
            
            CGPathMoveToPoint(outerPathRef, NULL, origin.x, origin.y);
            
            if (self.usesRoundedArrow.boolValue) {
                CGPoint roundedOrigin = CGPointMake(CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect) + arrowOffset - ( arrowBase / 2));
                CGFloat controlLength = arrowBase / 5.f;
                
                UIBezierPath* arrowPath = UIBezierPath.bezierPath;
                [arrowPath moveToPoint: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + arrowBase)];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + arrowHeight, roundedOrigin.y + (arrowBase / 2)) controlPoint1: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + (arrowBase - controlLength)) controlPoint2: CGPointMake(roundedOrigin.x + arrowHeight, roundedOrigin.y + ((arrowBase / 2) + controlLength))];
                [arrowPath addCurveToPoint: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + 0) controlPoint1: CGPointMake(roundedOrigin.x + arrowHeight, roundedOrigin.y + ((arrowBase / 2) - controlLength)) controlPoint2: CGPointMake(roundedOrigin.x + 0, roundedOrigin.y + controlLength)];
                [UIColor.whiteColor setFill];
                [arrowPath fill];
                
                outerRectPath = arrowPath;
            } else {
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect) + arrowHeight, CGRectGetMidY(outerRect) + arrowOffset);
                CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect) + arrowOffset + arrowBase / 2);
            }
            
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), (arrowOffset >= 0) ? reducedOuterCornerRadius : outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), (arrowOffset < 0) ? reducedOuterCornerRadius : outerCornerRadius);
            
            CGPathAddLineToPoint(outerPathRef, NULL, origin.x, origin.y);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionNone)
        {
            origin = CGPointMake(CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect));
            
            CGPathMoveToPoint(outerPathRef, NULL, origin.x, origin.y);
            
            CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect));
            CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect));
            
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect), CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), outerCornerRadius);
            CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect), CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect), outerCornerRadius);
            
            CGPathAddLineToPoint(outerPathRef, NULL, origin.x, origin.y);
        }
        
        CGPathCloseSubpath(outerPathRef);
        [outerRectPath appendPath:[UIBezierPath bezierPathWithCGPath:outerPathRef]];
        
        CGContextSaveGState(context);
        {
            CGContextSetShadowWithColor(context, self.outerShadowOffset, outerShadowBlurRadius, outerShadowColor.CGColor);
            CGContextBeginTransparencyLayer(context, NULL);
            [outerRectPath addClip];
            CGRect outerRectBounds = CGPathGetPathBoundingBox(outerRectPath.CGPath);
            CGContextDrawLinearGradient(context, fillGradient,
                                        CGPointMake(CGRectGetMidX(outerRectBounds), CGRectGetMinY(outerRectBounds)),
                                        CGPointMake(CGRectGetMidX(outerRectBounds), CGRectGetMaxY(outerRectBounds)),
                                        0);
            CGContextEndTransparencyLayer(context);
        }
        CGContextRestoreGState(context);
        
        ////// outerRect Inner Shadow
        CGRect outerRectBorderRect = CGRectInset([outerRectPath bounds], -glossShadowBlurRadius, -glossShadowBlurRadius);
        outerRectBorderRect = CGRectOffset(outerRectBorderRect, -glossShadowOffset.width, -glossShadowOffset.height);
        outerRectBorderRect = CGRectInset(CGRectUnion(outerRectBorderRect, [outerRectPath bounds]), -1, -1);
        
        UIBezierPath* outerRectNegativePath = [UIBezierPath bezierPathWithRect: outerRectBorderRect];
        [outerRectNegativePath appendPath: outerRectPath];
        outerRectNegativePath.usesEvenOddFillRule = YES;
        
        CGContextSaveGState(context);
        {
            float xOffset = glossShadowOffset.width + round(outerRectBorderRect.size.width);
            float yOffset = glossShadowOffset.height;
            CGContextSetShadowWithColor(context,
                                        CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                        glossShadowBlurRadius,
                                        self.glossShadowColor.CGColor);
            
            [outerRectPath addClip];
            CGAffineTransform transform = CGAffineTransformMakeTranslation(-round(outerRectBorderRect.size.width), 0);
            [outerRectNegativePath applyTransform: transform];
            [[UIColor grayColor] setFill];
            [outerRectNegativePath fill];
        }
        CGContextRestoreGState(context);
        
        [self.outerStrokeColor setStroke];
        outerRectPath.lineWidth = 1;
        [outerRectPath stroke];
        
        //// Cleanup
        CFRelease(outerPathRef);
        CGGradientRelease(fillGradient);
        CGColorSpaceRelease(colorSpace);
        
        UIGraphicsPopContext();
    }
}

#pragma mark Private

- (CGRect)outerRect
{
    return [self outerRect:self.bounds arrowDirection:self.arrowDirection];
}

- (CGRect)innerRect
{
    return [self innerRect:self.bounds arrowDirection:self.arrowDirection];
}

- (CGRect)arrowRect
{
    return [self arrowRect:self.bounds arrowDirection:self.arrowDirection];
}

- (CGRect)outerRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection
{
    CGRect result = rect;
    
    if (aArrowDirection == WYPopoverArrowDirectionUp || arrowDirection == WYPopoverArrowDirectionDown)
    {
        result.size.height -= arrowHeight;
        
        if (aArrowDirection == WYPopoverArrowDirectionUp)
        {
            result = CGRectOffset(result, 0, arrowHeight);
        }
    }
    
    if (aArrowDirection == WYPopoverArrowDirectionLeft || arrowDirection == WYPopoverArrowDirectionRight)
    {
        result.size.width -= arrowHeight;
        
        if (aArrowDirection == WYPopoverArrowDirectionLeft)
        {
            result = CGRectOffset(result, arrowHeight, 0);
        }
    }
    
    result = CGRectInset(result, outerShadowBlurRadius, outerShadowBlurRadius);
    result.origin.x -= self.outerShadowOffset.width;
    result.origin.y -= self.outerShadowOffset.height;
    
    return result;
}

- (CGRect)innerRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection
{
    CGRect result = [self outerRect:rect arrowDirection:aArrowDirection];
    
    result.origin.x += borderWidth;
    result.origin.y += 0;
    result.size.width -= 2 * borderWidth;
    result.size.height -= borderWidth;
    
    if (navigationBarHeight == 0 || wantsDefaultContentAppearance)
    {
        result.origin.y += borderWidth;
        result.size.height -= borderWidth;
    }
    
    result.origin.x += viewContentInsets.left;
    result.origin.y += viewContentInsets.top;
    result.size.width = result.size.width - viewContentInsets.left - viewContentInsets.right;
    result.size.height = result.size.height - viewContentInsets.top - viewContentInsets.bottom;
    
    if (borderWidth > 0)
    {
        result = CGRectInset(result, -1, -1);
    }
    
    return result;
}

- (CGRect)arrowRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection
{
    CGRect result = CGRectZero;
    
    if (arrowHeight > 0)
    {
        result.size = CGSizeMake(arrowBase, arrowHeight);
        
        if (aArrowDirection == WYPopoverArrowDirectionLeft || arrowDirection == WYPopoverArrowDirectionRight)
        {
            result.size = CGSizeMake(arrowHeight, arrowBase);
        }
        
        CGRect outerRect = [self outerRect:rect arrowDirection:aArrowDirection];
        
        if (aArrowDirection == WYPopoverArrowDirectionDown)
        {
            result.origin.x = CGRectGetMidX(outerRect) - result.size.width / 2 + arrowOffset;
            result.origin.y = CGRectGetMaxY(outerRect);
        }
        
        if (aArrowDirection == WYPopoverArrowDirectionUp)
        {
            result.origin.x = CGRectGetMidX(outerRect) - result.size.width / 2 + arrowOffset;
            result.origin.y = CGRectGetMinY(outerRect) - result.size.height;
        }
        
        if (aArrowDirection == WYPopoverArrowDirectionRight)
        {
            result.origin.x = CGRectGetMaxX(outerRect);
            result.origin.y = CGRectGetMidY(outerRect) - result.size.height / 2 + arrowOffset;
        }
        
        if (aArrowDirection == WYPopoverArrowDirectionLeft)
        {
            result.origin.x = CGRectGetMinX(outerRect) - result.size.width;
            result.origin.y = CGRectGetMidY(outerRect) - result.size.height / 2 + arrowOffset;
        }
    }
    
    return result;
}

- (BOOL)isTouchedAtPoint:(CGPoint)point
{
    BOOL result = NO;
    
    CGRect outerRect = [self outerRect];
    CGRect arrowRect = [self arrowRect];
    
    result = (CGRectContainsPoint(outerRect, point) || CGRectContainsPoint(arrowRect, point));
    
    return result;
}

#pragma mark Memory Management

- (void)dealloc
{
    contentView = nil;
    innerView = nil;
    tintColor = nil;
    outerStrokeColor = nil;
    innerStrokeColor = nil;
    fillTopColor = nil;
    fillBottomColor = nil;
    glossShadowColor = nil;
    outerShadowColor = nil;
    innerShadowColor = nil;
}

@end

////////////////////////////////////////////////////////////////////////////

@interface WYPopoverController () <WYPopoverOverlayViewDelegate, WYPopoverBackgroundViewDelegate>
{
    UIViewController        *viewController;
    CGRect                   rect;
    UIView                  *inView;
    WYPopoverOverlayView    *overlayView;
    WYPopoverBackgroundView *backgroundView;
    WYPopoverArrowDirection  permittedArrowDirections;
    BOOL                     animated;
    BOOL                     isListeningNotifications;
    BOOL                     isObserverAdded;
    BOOL                     isInterfaceOrientationChanging;
    BOOL                     ignoreOrientation;
    __weak UIBarButtonItem  *barButtonItem;
    CGRect                   keyboardRect;
    
    WYPopoverAnimationOptions options;
    
    BOOL themeUpdatesEnabled;
    BOOL themeIsUpdating;
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aAptions
                    completion:(void (^)(void))aCompletion
                  callDelegate:(BOOL)aCallDelegate;

- (WYPopoverArrowDirection)arrowDirectionForRect:(CGRect)aRect
                                          inView:(UIView*)aView
                                     contentSize:(CGSize)aContentSize
                                     arrowHeight:(float)aArrowHeight
                        permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections;

- (CGSize)sizeForRect:(CGRect)aRect
               inView:(UIView *)aView
          arrowHeight:(float)aArrowHeight
       arrowDirection:(WYPopoverArrowDirection)aArrowDirection;

- (void)registerTheme;
- (void)unregisterTheme;
- (void)updateThemeUI;

- (CGSize)topViewControllerContentSize;

@end

////////////////////////////////////////////////////////////////////////////

#pragma mark
#pragma mark - WYPopoverController

@implementation WYPopoverController

@synthesize delegate;
@synthesize passthroughViews;
@synthesize wantsDefaultContentAppearance;
@synthesize popoverVisible;
@synthesize popoverLayoutMargins;
@synthesize popoverContentSize = popoverContentSize_;
@synthesize animationDuration;
@synthesize theme;

static WYPopoverTheme *defaultTheme_ = nil;

+ (void)setDefaultTheme:(WYPopoverTheme *)aTheme
{
    defaultTheme_ = aTheme;
    
    @autoreleasepool {
        WYPopoverBackgroundView *appearance = [WYPopoverBackgroundView appearance];
        appearance.usesRoundedArrow = aTheme.usesRoundedArrow;
        appearance.adjustsTintColor = aTheme.adjustsTintColor;
        appearance.tintColor = aTheme.tintColor;
        appearance.outerStrokeColor = aTheme.outerStrokeColor;
        appearance.innerStrokeColor = aTheme.innerStrokeColor;
        appearance.fillTopColor = aTheme.fillTopColor;
        appearance.fillBottomColor = aTheme.fillBottomColor;
        appearance.glossShadowColor = aTheme.glossShadowColor;
        appearance.glossShadowOffset = aTheme.glossShadowOffset;
        appearance.glossShadowBlurRadius = aTheme.glossShadowBlurRadius;
        appearance.borderWidth = aTheme.borderWidth;
        appearance.arrowBase = aTheme.arrowBase;
        appearance.arrowHeight = aTheme.arrowHeight;
        appearance.outerShadowColor = aTheme.outerShadowColor;
        appearance.outerShadowBlurRadius = aTheme.outerShadowBlurRadius;
        appearance.outerShadowOffset = aTheme.outerShadowOffset;
        appearance.outerCornerRadius = aTheme.outerCornerRadius;
        appearance.minOuterCornerRadius = aTheme.minOuterCornerRadius;
        appearance.innerShadowColor = aTheme.innerShadowColor;
        appearance.innerShadowBlurRadius = aTheme.innerShadowBlurRadius;
        appearance.innerShadowOffset = aTheme.innerShadowOffset;
        appearance.innerCornerRadius = aTheme.innerCornerRadius;
        appearance.viewContentInsets = aTheme.viewContentInsets;
        appearance.overlayColor = aTheme.overlayColor;
    }
}

+ (WYPopoverTheme *)defaultTheme
{
    return defaultTheme_;
}

+ (void)load
{
    [WYPopoverController setDefaultTheme:[WYPopoverTheme theme]];
}

- (id)init
{
    self = [super init];
    
    if (self)
    {
        // ignore orientation in iOS8
        ignoreOrientation = (compileUsingIOS8SDK() && [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]);
        popoverLayoutMargins = UIEdgeInsetsMake(10, 10, 10, 10);
        keyboardRect = CGRectZero;
        animationDuration = WY_POPOVER_DEFAULT_ANIMATION_DURATION;
        
        themeUpdatesEnabled = NO;
        
        [self setTheme:[WYPopoverController defaultTheme]];
        
        themeIsUpdating = YES;
        
        WYPopoverBackgroundView *appearance = [WYPopoverBackgroundView appearance];
        theme.usesRoundedArrow = appearance.usesRoundedArrow;
        theme.adjustsTintColor = appearance.adjustsTintColor;
        theme.tintColor = appearance.tintColor;
        theme.outerStrokeColor = appearance.outerStrokeColor;
        theme.innerStrokeColor = appearance.innerStrokeColor;
        theme.fillTopColor = appearance.fillTopColor;
        theme.fillBottomColor = appearance.fillBottomColor;
        theme.glossShadowColor = appearance.glossShadowColor;
        theme.glossShadowOffset = appearance.glossShadowOffset;
        theme.glossShadowBlurRadius = appearance.glossShadowBlurRadius;
        theme.borderWidth = appearance.borderWidth;
        theme.arrowBase = appearance.arrowBase;
        theme.arrowHeight = appearance.arrowHeight;
        theme.outerShadowColor = appearance.outerShadowColor;
        theme.outerShadowBlurRadius = appearance.outerShadowBlurRadius;
        theme.outerShadowOffset = appearance.outerShadowOffset;
        theme.outerCornerRadius = appearance.outerCornerRadius;
        theme.minOuterCornerRadius = appearance.minOuterCornerRadius;
        theme.innerShadowColor = appearance.innerShadowColor;
        theme.innerShadowBlurRadius = appearance.innerShadowBlurRadius;
        theme.innerShadowOffset = appearance.innerShadowOffset;
        theme.innerCornerRadius = appearance.innerCornerRadius;
        theme.viewContentInsets = appearance.viewContentInsets;
        theme.overlayColor = appearance.overlayColor;

        themeIsUpdating = NO;
        themeUpdatesEnabled = YES;
        
        popoverContentSize_ = CGSizeZero;
    }
    
    return self;
}

- (id)initWithContentViewController:(UIViewController *)aViewController
{
    self = [self init];
    
    if (self)
    {
        viewController = aViewController;
    }
    
    return self;
}

- (void)setTheme:(WYPopoverTheme *)value
{
    [self unregisterTheme];
    theme = value;
    [self registerTheme];
    [self updateThemeUI];
    
    themeIsUpdating = NO;
}

- (void)registerTheme
{
    if (theme == nil) return;
    
    NSArray *keypaths = [theme observableKeypaths];
    for (NSString *keypath in keypaths) {
		[theme addObserver:self forKeyPath:keypath options:NSKeyValueObservingOptionNew context:NULL];
	}
}

- (void)unregisterTheme
{
    if (theme == nil) return;
    
    @try {
        NSArray *keypaths = [theme observableKeypaths];
        for (NSString *keypath in keypaths) {
            [theme removeObserver:self forKeyPath:keypath];
        }
    }
    @catch (NSException * __unused exception) {}
}

- (void)updateThemeUI
{
    if (theme == nil || themeUpdatesEnabled == NO || themeIsUpdating == YES) return;
    
    if (backgroundView != nil) {
        backgroundView.usesRoundedArrow = theme.usesRoundedArrow;
        backgroundView.adjustsTintColor = theme.adjustsTintColor;
        backgroundView.tintColor = theme.tintColor;
        backgroundView.outerStrokeColor = theme.outerStrokeColor;
        backgroundView.innerStrokeColor = theme.innerStrokeColor;
        backgroundView.fillTopColor = theme.fillTopColor;
        backgroundView.fillBottomColor = theme.fillBottomColor;
        backgroundView.glossShadowColor = theme.glossShadowColor;
        backgroundView.glossShadowOffset = theme.glossShadowOffset;
        backgroundView.glossShadowBlurRadius = theme.glossShadowBlurRadius;
        backgroundView.borderWidth = theme.borderWidth;
        backgroundView.arrowBase = theme.arrowBase;
        backgroundView.arrowHeight = theme.arrowHeight;
        backgroundView.outerShadowColor = theme.outerShadowColor;
        backgroundView.outerShadowBlurRadius = theme.outerShadowBlurRadius;
        backgroundView.outerShadowOffset = theme.outerShadowOffset;
        backgroundView.outerCornerRadius = theme.outerCornerRadius;
        backgroundView.minOuterCornerRadius = theme.minOuterCornerRadius;
        backgroundView.innerShadowColor = theme.innerShadowColor;
        backgroundView.innerShadowBlurRadius = theme.innerShadowBlurRadius;
        backgroundView.innerShadowOffset = theme.innerShadowOffset;
        backgroundView.innerCornerRadius = theme.innerCornerRadius;
        backgroundView.viewContentInsets = theme.viewContentInsets;
        [backgroundView setNeedsDisplay];
    }
    
    if (overlayView != nil) {
        overlayView.backgroundColor = theme.overlayColor;
    }
    
    [self positionPopover:NO];
    
    [self setPopoverNavigationBarBackgroundImage];
}

- (void)beginThemeUpdates
{
    themeIsUpdating = YES;
}

- (void)endThemeUpdates
{
    themeIsUpdating = NO;
    [self updateThemeUI];
}

- (BOOL)isPopoverVisible
{
    BOOL result = (overlayView != nil);
    return result;
}

- (UIViewController *)contentViewController
{
    return viewController;
}

- (CGSize)topViewControllerContentSize
{
    CGSize result = CGSizeZero;
    
    UIViewController *topViewController = viewController;
    
    if ([viewController isKindOfClass:[UINavigationController class]] == YES)
    {
        UINavigationController *navigationController = (UINavigationController *)viewController;
        topViewController = [navigationController topViewController];
    }
    
#ifdef WY_BASE_SDK_7_ENABLED
    if ([topViewController respondsToSelector:@selector(preferredContentSize)])
    {
        result = topViewController.preferredContentSize;
    }
#endif
    
    if (CGSizeEqualToSize(result, CGSizeZero))
    {
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
        result = topViewController.contentSizeForViewInPopover;
#pragma clang diagnostic pop
    }
    
    if (CGSizeEqualToSize(result, CGSizeZero))
    {
        CGSize windowSize = [[UIApplication sharedApplication] keyWindow].bounds.size;
        
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
        
        result = CGSizeMake(320, UIDeviceOrientationIsLandscape(orientation) ? windowSize.width : windowSize.height);
    }
    
    return result;
}

- (CGSize)popoverContentSize
{
    CGSize result = popoverContentSize_;
    
    if (CGSizeEqualToSize(result, CGSizeZero))
    {
        result = [self topViewControllerContentSize];
    }
    
    return result;
}

- (void)setPopoverContentSize:(CGSize)size
{
    popoverContentSize_ = size;
    [self positionPopover:YES];
}

- (void)presentPopoverFromRect:(CGRect)aRect
                        inView:(UIView *)aView
      permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                      animated:(BOOL)aAnimated
{
    [self presentPopoverFromRect:aRect
                          inView:aView
        permittedArrowDirections:aArrowDirections
                        animated:aAnimated
                      completion:nil];
}

- (void)presentPopoverFromRect:(CGRect)aRect
                        inView:(UIView *)aView
      permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                      animated:(BOOL)aAnimated
                    completion:(void (^)(void))completion
{
    [self presentPopoverFromRect:aRect
                          inView:aView
        permittedArrowDirections:aArrowDirections
                        animated:aAnimated
                         options:WYPopoverAnimationOptionFade
                      completion:completion];
}

- (void)presentPopoverFromRect:(CGRect)aRect
                        inView:(UIView *)aView
      permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                      animated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions
{
    [self presentPopoverFromRect:aRect
                          inView:aView
        permittedArrowDirections:aArrowDirections
                        animated:aAnimated
                         options:aOptions
                      completion:nil];
}

- (void)presentPopoverFromRect:(CGRect)aRect
                        inView:(UIView *)aView
      permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                      animated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions
                    completion:(void (^)(void))completion
{
    NSAssert((aArrowDirections != WYPopoverArrowDirectionUnknown), @"WYPopoverArrowDirection must not be UNKNOWN");
    
    rect = aRect;
    inView = aView;
    permittedArrowDirections = aArrowDirections;
    animated = aAnimated;
    options = aOptions;
    
    if (!inView)
    {
        inView = [UIApplication sharedApplication].keyWindow.rootViewController.view;
        if (CGRectIsEmpty(rect))
        {
            rect = CGRectMake((int)inView.bounds.size.width / 2 - 5, (int)inView.bounds.size.height / 2 - 5, 10, 10);
        }
    }
    
    CGSize contentViewSize = self.popoverContentSize;
    
    if (overlayView == nil)
    {
        overlayView = [[WYPopoverOverlayView alloc] initWithFrame:inView.window.bounds];
        overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        overlayView.autoresizesSubviews = NO;
        overlayView.delegate = self;
        overlayView.passthroughViews = passthroughViews;
        
        backgroundView = [[WYPopoverBackgroundView alloc] initWithContentSize:contentViewSize];
        backgroundView.appearing = YES;
        
        backgroundView.delegate = self;
        backgroundView.hidden = YES;
        
        UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:backgroundView action:@selector(tapOut)];
        tap.cancelsTouchesInView = NO;
        [overlayView addGestureRecognizer:tap];
        
        [inView.window addSubview:backgroundView];
        [inView.window insertSubview:overlayView belowSubview:backgroundView];
    }
    
    [self updateThemeUI];
    
    __weak __typeof__(self) weakSelf = self;
    
    void (^completionBlock)(BOOL) = ^(BOOL animated) {
        
        __typeof__(self) strongSelf = weakSelf;
        
        if (strongSelf)
        {
            if ([strongSelf->viewController isKindOfClass:[UINavigationController class]] == NO)
            {
                [strongSelf->viewController viewDidAppear:YES];
            }
            
            if (isObserverAdded == NO)
            {
                isObserverAdded = YES;

                if ([strongSelf->viewController respondsToSelector:@selector(preferredContentSize)])
                {
                    [strongSelf->viewController addObserver:self forKeyPath:NSStringFromSelector(@selector(preferredContentSize)) options:0 context:nil];
                }
                else
                {
                    [strongSelf->viewController addObserver:self forKeyPath:NSStringFromSelector(@selector(contentSizeForViewInPopover)) options:0 context:nil];
                }
            }
            
            strongSelf->backgroundView.appearing = NO;
        }
        
        if (completion)
        {
            completion();
        }
        else if (strongSelf && strongSelf->delegate && [strongSelf->delegate respondsToSelector:@selector(popoverControllerDidPresentPopover:)])
        {
            [strongSelf->delegate popoverControllerDidPresentPopover:strongSelf];
        }
        
        
    };
    
    void (^adjustTintDimmed)() = ^() {
#ifdef WY_BASE_SDK_7_ENABLED
        if ([backgroundView.adjustsTintColor boolValue] && [inView.window respondsToSelector:@selector(setTintAdjustmentMode:)]) {
            for (UIView *subview in inView.window.subviews) {
                if (subview != backgroundView) {
                    [subview setTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
                }
            }
        }
#endif
    };
    
    backgroundView.hidden = NO;
    
    if (animated)
    {
        if ((options & WYPopoverAnimationOptionFade) == WYPopoverAnimationOptionFade)
        {
            overlayView.alpha = 0;
            backgroundView.alpha = 0;
        }
        
        [viewController viewWillAppear:YES];
        
        CGAffineTransform endTransform = backgroundView.transform;
        
        if ((options & WYPopoverAnimationOptionScale) == WYPopoverAnimationOptionScale)
        {
            CGAffineTransform startTransform = [self transformForArrowDirection:backgroundView.arrowDirection];
            backgroundView.transform = startTransform;
        }
        
        [UIView animateWithDuration:animationDuration animations:^{
            __typeof__(self) strongSelf = weakSelf;
            
            if (strongSelf)
            {
                strongSelf->overlayView.alpha = 1;
                strongSelf->backgroundView.alpha = 1;
                strongSelf->backgroundView.transform = endTransform;
            }
            adjustTintDimmed();
        } completion:^(BOOL finished) {
            completionBlock(YES);
        }];
    }
    else
    {
        adjustTintDimmed();
        [viewController viewWillAppear:NO];
        completionBlock(NO);
    }
    
    if (isListeningNotifications == NO)
    {
        isListeningNotifications = YES;
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didChangeStatusBarOrientation:)
                                                     name:UIApplicationDidChangeStatusBarOrientationNotification
                                                   object:nil];
        
        [[UIDevice currentDevice] beginGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(didChangeDeviceOrientation:)
                                                     name:UIDeviceOrientationDidChangeNotification
                                                   object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillShow:)
                                                     name:UIKeyboardWillShowNotification object:nil];
        
        [[NSNotificationCenter defaultCenter] addObserver:self
                                                 selector:@selector(keyboardWillHide:)
                                                     name:UIKeyboardWillHideNotification object:nil];
    }
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)aItem
               permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                               animated:(BOOL)aAnimated
{
    [self presentPopoverFromBarButtonItem:aItem
                 permittedArrowDirections:aArrowDirections
                                 animated:aAnimated
                               completion:nil];
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)aItem
               permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                               animated:(BOOL)aAnimated
                             completion:(void (^)(void))completion
{
    [self presentPopoverFromBarButtonItem:aItem
                 permittedArrowDirections:aArrowDirections
                                 animated:aAnimated
                                  options:WYPopoverAnimationOptionFade
                               completion:completion];
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)aItem
               permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                               animated:(BOOL)aAnimated
                                options:(WYPopoverAnimationOptions)aOptions
{
    [self presentPopoverFromBarButtonItem:aItem
                 permittedArrowDirections:aArrowDirections
                                 animated:aAnimated
                                  options:aOptions
                               completion:nil];
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)aItem
               permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                               animated:(BOOL)aAnimated
                                options:(WYPopoverAnimationOptions)aOptions
                             completion:(void (^)(void))completion
{
    barButtonItem = aItem;
    UIView *itemView = [barButtonItem valueForKey:@"view"];
    aArrowDirections = WYPopoverArrowDirectionDown | WYPopoverArrowDirectionUp;
    [self presentPopoverFromRect:itemView.bounds
                          inView:itemView
        permittedArrowDirections:aArrowDirections
                        animated:aAnimated
                         options:aOptions
                      completion:completion];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated
{
    [self presentPopoverAsDialogAnimated:aAnimated
                              completion:nil];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated
                            completion:(void (^)(void))completion
{
    [self presentPopoverAsDialogAnimated:aAnimated
                                 options:WYPopoverAnimationOptionFade
                              completion:completion];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated
                               options:(WYPopoverAnimationOptions)aOptions
{
    [self presentPopoverAsDialogAnimated:aAnimated
                                 options:aOptions
                              completion:nil];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated
                               options:(WYPopoverAnimationOptions)aOptions
                            completion:(void (^)(void))completion
{
    [self presentPopoverFromRect:CGRectZero
                          inView:nil
        permittedArrowDirections:WYPopoverArrowDirectionNone
                        animated:aAnimated
                         options:aOptions
                      completion:completion];
}

- (CGAffineTransform)transformForArrowDirection:(WYPopoverArrowDirection)arrowDirection
{
    CGAffineTransform transform = backgroundView.transform;
    
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

    CGSize containerViewSize = backgroundView.frame.size;
    
    if (backgroundView.arrowHeight > 0)
    {
        if (UIDeviceOrientationIsLandscape(orientation)) {
            containerViewSize.width = backgroundView.frame.size.height;
            containerViewSize.height = backgroundView.frame.size.width;
        }
        
        //WY_LOG(@"containerView.arrowOffset = %f", containerView.arrowOffset);
        //WY_LOG(@"containerViewSize = %@", NSStringFromCGSize(containerViewSize));
        //WY_LOG(@"orientation = %@", WYStringFromOrientation(orientation));
        
        if (arrowDirection == WYPopoverArrowDirectionDown)
        {
            transform = CGAffineTransformTranslate(transform, backgroundView.arrowOffset, containerViewSize.height / 2);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionUp)
        {
            transform = CGAffineTransformTranslate(transform, backgroundView.arrowOffset, -containerViewSize.height / 2);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionRight)
        {
            transform = CGAffineTransformTranslate(transform, containerViewSize.width / 2, backgroundView.arrowOffset);
        }
        
        if (arrowDirection == WYPopoverArrowDirectionLeft)
        {
            transform = CGAffineTransformTranslate(transform, -containerViewSize.width / 2, backgroundView.arrowOffset);
        }
    }
    
    transform = CGAffineTransformScale(transform, 0.01, 0.01);
    
    return transform;
}

- (void)setPopoverNavigationBarBackgroundImage
{
    if ([viewController isKindOfClass:[UINavigationController class]] == YES)
    {
        UINavigationController *navigationController = (UINavigationController *)viewController;
        navigationController.embedInPopover = YES;
        
#ifdef WY_BASE_SDK_7_ENABLED
        if ([navigationController respondsToSelector:@selector(setEdgesForExtendedLayout:)])
        {
            UIViewController *topViewController = [navigationController topViewController];
            [topViewController setEdgesForExtendedLayout:UIRectEdgeNone];
        }
#endif
        
        if (wantsDefaultContentAppearance == NO)
        {
            [navigationController.navigationBar setBackgroundImage:[UIImage imageWithColor:[UIColor clearColor]] forBarMetrics:UIBarMetricsDefault];
        }
    }
    
    viewController.view.clipsToBounds = YES;
    
    if (backgroundView.borderWidth == 0)
    {
        viewController.view.layer.cornerRadius = backgroundView.outerCornerRadius;
    }
}

- (void)positionPopover:(BOOL)aAnimated
{
    CGRect savedContainerFrame = backgroundView.frame;
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    CGSize contentViewSize = self.popoverContentSize;
    CGSize minContainerSize = WY_POPOVER_MIN_SIZE;
    
    CGRect viewFrame;
    CGRect containerFrame = CGRectZero;
    float minX, maxX, minY, maxY, offset = 0;
    CGSize containerViewSize = CGSizeZero;
    
    float overlayWidth;
    float overlayHeight;
    
    float keyboardHeight;

    if (ignoreOrientation)
    {
        overlayWidth = overlayView.window.frame.size.width;
        overlayHeight = overlayView.window.frame.size.height;

        CGRect convertedFrame = [overlayView.window convertRect:keyboardRect toView:overlayView];
        keyboardHeight = convertedFrame.size.height;
    }
    else
    {
        overlayWidth = UIInterfaceOrientationIsPortrait(orientation) ? overlayView.bounds.size.width : overlayView.bounds.size.height;
        overlayHeight = UIInterfaceOrientationIsPortrait(orientation) ? overlayView.bounds.size.height : overlayView.bounds.size.width;

        keyboardHeight = UIInterfaceOrientationIsPortrait(orientation) ? keyboardRect.size.height : keyboardRect.size.width;
    }
    
    if (delegate && [delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
        BOOL shouldIgnore = [delegate popoverControllerShouldIgnoreKeyboardBounds:self];
        
        if (shouldIgnore) {
            keyboardHeight = 0;
        }
    }
    
    WYPopoverArrowDirection arrowDirection = permittedArrowDirections;
    
    overlayView.bounds = inView.window.bounds;
    backgroundView.transform = CGAffineTransformIdentity;
    
    viewFrame = [inView convertRect:rect toView:nil];
    
    viewFrame = WYRectInWindowBounds(viewFrame, orientation);
    
    minX = popoverLayoutMargins.left;
    maxX = overlayWidth - popoverLayoutMargins.right;
    minY = WYStatusBarHeight() + popoverLayoutMargins.top;
    maxY = overlayHeight - popoverLayoutMargins.bottom - keyboardHeight;
    
    // Which direction ?
    //
    arrowDirection = [self arrowDirectionForRect:rect
                                          inView:inView
                                     contentSize:contentViewSize
                                     arrowHeight:backgroundView.arrowHeight
                        permittedArrowDirections:arrowDirection];
    
    // Position of the popover
    //
    
    minX -= backgroundView.outerShadowInsets.left;
    maxX += backgroundView.outerShadowInsets.right;
    minY -= backgroundView.outerShadowInsets.top;
    maxY += backgroundView.outerShadowInsets.bottom;
    
    if (arrowDirection == WYPopoverArrowDirectionDown)
    {
        backgroundView.arrowDirection = WYPopoverArrowDirectionDown;
        containerViewSize = [backgroundView sizeThatFits:contentViewSize];
        
        containerFrame = CGRectZero;
        containerFrame.size = containerViewSize;
        containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
        containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);
        
        backgroundView.frame = CGRectIntegral(containerFrame);
        
        backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);
        
        containerFrame = backgroundView.frame;
        
        offset = 0;
        
        if (containerFrame.origin.x < minX)
        {
            offset = minX - containerFrame.origin.x;
            containerFrame.origin.x = minX;
            offset = -offset;
        }
        else if (containerFrame.origin.x + containerFrame.size.width > maxX)
        {
            offset = (backgroundView.frame.origin.x + backgroundView.frame.size.width) - maxX;
            containerFrame.origin.x -= offset;
        }
        
        backgroundView.arrowOffset = offset;
        offset = backgroundView.frame.size.height / 2 + viewFrame.size.height / 2 - backgroundView.outerShadowInsets.bottom;
        
        containerFrame.origin.y -= offset;
        
        if (containerFrame.origin.y < minY)
        {
            offset = minY - containerFrame.origin.y;
            containerFrame.size.height -= offset;
            
            if (containerFrame.size.height < minContainerSize.height)
            {
                // popover is overflowing
                offset -= (minContainerSize.height - containerFrame.size.height);
                containerFrame.size.height = minContainerSize.height;
            }
            
            containerFrame.origin.y += offset;
        }
    }
    
    if (arrowDirection == WYPopoverArrowDirectionUp)
    {
        backgroundView.arrowDirection = WYPopoverArrowDirectionUp;
        containerViewSize = [backgroundView sizeThatFits:contentViewSize];
        
        containerFrame = CGRectZero;
        containerFrame.size = containerViewSize;
        containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
        containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);
        
        backgroundView.frame = containerFrame;
        
        backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);
        
        containerFrame = backgroundView.frame;
        
        offset = 0;
        
        if (containerFrame.origin.x < minX)
        {
            offset = minX - containerFrame.origin.x;
            containerFrame.origin.x = minX;
            offset = -offset;
        }
        else if (containerFrame.origin.x + containerFrame.size.width > maxX)
        {
            offset = (backgroundView.frame.origin.x + backgroundView.frame.size.width) - maxX;
            containerFrame.origin.x -= offset;
        }
        
        backgroundView.arrowOffset = offset;
        offset = backgroundView.frame.size.height / 2 + viewFrame.size.height / 2 - backgroundView.outerShadowInsets.top;
        
        containerFrame.origin.y += offset;
        
        if (containerFrame.origin.y + containerFrame.size.height > maxY)
        {
            offset = (containerFrame.origin.y + containerFrame.size.height) - maxY;
            containerFrame.size.height -= offset;
            
            if (containerFrame.size.height < minContainerSize.height)
            {
                // popover is overflowing
                containerFrame.size.height = minContainerSize.height;
            }
        }
    }
    
    if (arrowDirection == WYPopoverArrowDirectionRight)
    {
        backgroundView.arrowDirection = WYPopoverArrowDirectionRight;
        containerViewSize = [backgroundView sizeThatFits:contentViewSize];
        
        containerFrame = CGRectZero;
        containerFrame.size = containerViewSize;
        containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
        containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);
        
        backgroundView.frame = CGRectIntegral(containerFrame);
        
        backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);
        
        containerFrame = backgroundView.frame;
        
        offset = backgroundView.frame.size.width / 2 + viewFrame.size.width / 2 - backgroundView.outerShadowInsets.right;
        
        containerFrame.origin.x -= offset;
        
        if (containerFrame.origin.x < minX)
        {
            offset = minX - containerFrame.origin.x;
            containerFrame.size.width -= offset;
            
            if (containerFrame.size.width < minContainerSize.width)
            {
                // popover is overflowing
                offset -= (minContainerSize.width - containerFrame.size.width);
                containerFrame.size.width = minContainerSize.width;
            }
            
            containerFrame.origin.x += offset;
        }
        
        offset = 0;
        
        if (containerFrame.origin.y < minY)
        {
            offset = minY - containerFrame.origin.y;
            containerFrame.origin.y = minY;
            offset = -offset;
        }
        else if (containerFrame.origin.y + containerFrame.size.height > maxY)
        {
            offset = (backgroundView.frame.origin.y + backgroundView.frame.size.height) - maxY;
            containerFrame.origin.y -= offset;
        }
        
        backgroundView.arrowOffset = offset;
    }
    
    if (arrowDirection == WYPopoverArrowDirectionLeft)
    {
        backgroundView.arrowDirection = WYPopoverArrowDirectionLeft;
        containerViewSize = [backgroundView sizeThatFits:contentViewSize];
        
        containerFrame = CGRectZero;
        containerFrame.size = containerViewSize;
        containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
        containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);
        backgroundView.frame = containerFrame;
        
        backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);
        
        containerFrame = CGRectIntegral(backgroundView.frame);
        
        offset = backgroundView.frame.size.width / 2 + viewFrame.size.width / 2 - backgroundView.outerShadowInsets.left;
        
        containerFrame.origin.x += offset;
        
        if (containerFrame.origin.x + containerFrame.size.width > maxX)
        {
            offset = (containerFrame.origin.x + containerFrame.size.width) - maxX;
            containerFrame.size.width -= offset;
            
            if (containerFrame.size.width < minContainerSize.width)
            {
                // popover is overflowing
                containerFrame.size.width = minContainerSize.width;
            }
        }
        
        offset = 0;
        
        if (containerFrame.origin.y < minY)
        {
            offset = minY - containerFrame.origin.y;
            containerFrame.origin.y = minY;
            offset = -offset;
        }
        else if (containerFrame.origin.y + containerFrame.size.height > maxY)
        {
            offset = (backgroundView.frame.origin.y + backgroundView.frame.size.height) - maxY;
            containerFrame.origin.y -= offset;
        }
        
        backgroundView.arrowOffset = offset;
    }
    
    if (arrowDirection == WYPopoverArrowDirectionNone)
    {
        backgroundView.arrowDirection = WYPopoverArrowDirectionNone;
        containerViewSize = [backgroundView sizeThatFits:contentViewSize];
        
        containerFrame = CGRectZero;
        containerFrame.size = containerViewSize;
        containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
        containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);
        backgroundView.frame = CGRectIntegral(containerFrame);
        
        backgroundView.center = CGPointMake(minX + (maxX - minX) / 2, minY + (maxY - minY) / 2);
        
        containerFrame = backgroundView.frame;
        
        backgroundView.arrowOffset = offset;
    }
    
    containerFrame = CGRectIntegral(containerFrame);
    
    backgroundView.frame = containerFrame;
    
    backgroundView.wantsDefaultContentAppearance = wantsDefaultContentAppearance;
    
    [backgroundView setViewController:viewController];
    
    // keyboard support
    //
    if (keyboardHeight > 0) {
        
        float keyboardY = UIInterfaceOrientationIsPortrait(orientation) ? keyboardRect.origin.y : keyboardRect.origin.x;
        
        float yOffset = containerFrame.origin.y + containerFrame.size.height - keyboardY;
        
        if (yOffset > 0) {
            
            if (containerFrame.origin.y - yOffset < minY) {
                yOffset -= minY - (containerFrame.origin.y - yOffset);
            }
            
            if ([delegate respondsToSelector:@selector(popoverController:willTranslatePopoverWithYOffset:)])
            {
                [delegate popoverController:self willTranslatePopoverWithYOffset:&yOffset];
            }
            
            containerFrame.origin.y -= yOffset;
        }
    }
    
    CGPoint containerOrigin = containerFrame.origin;
    
    backgroundView.transform = CGAffineTransformMakeRotation(WYInterfaceOrientationAngleOfOrientation(orientation));
    
    containerFrame = backgroundView.frame;
    
    containerFrame.origin = WYPointRelativeToOrientation(containerOrigin, containerFrame.size, orientation);

    if (aAnimated == YES) {
        backgroundView.frame = savedContainerFrame;
        __weak __typeof__(self) weakSelf = self;
        [UIView animateWithDuration:0.10f animations:^{
            __typeof__(self) strongSelf = weakSelf;
            strongSelf->backgroundView.frame = containerFrame;
        }];
    } else {
        backgroundView.frame = containerFrame;
    }
    
    [backgroundView setNeedsDisplay];
    
    WY_LOG(@"popoverContainerView.frame = %@", NSStringFromCGRect(backgroundView.frame));
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
{
    [self dismissPopoverAnimated:aAnimated
                         options:options
                      completion:nil];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                    completion:(void (^)(void))completion
{
    [self dismissPopoverAnimated:aAnimated
                         options:options
                      completion:completion];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions
{
    [self dismissPopoverAnimated:aAnimated
                         options:aOptions
                      completion:nil];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions
                    completion:(void (^)(void))completion
{
    [self dismissPopoverAnimated:aAnimated
                         options:aOptions
                      completion:completion
                    callDelegate:NO];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions
                    completion:(void (^)(void))completion
                  callDelegate:(BOOL)callDelegate
{
    float duration = self.animationDuration;
    WYPopoverAnimationOptions style = aOptions;
    
    __weak __typeof__(self) weakSelf = self;
    
    
    void (^adjustTintAutomatic)() = ^() {
#ifdef WY_BASE_SDK_7_ENABLED
        if ([inView.window respondsToSelector:@selector(setTintAdjustmentMode:)]) {
            for (UIView *subview in inView.window.subviews) {
                if (subview != backgroundView) {
                    [subview setTintAdjustmentMode:UIViewTintAdjustmentModeAutomatic];
                }
            }
        }
#endif
    };
    
    void (^completionBlock)() = ^() {
        
        __typeof__(self) strongSelf = weakSelf;
        
        if (strongSelf) {
            [strongSelf->backgroundView removeFromSuperview];
            
            strongSelf->backgroundView = nil;
            
            [strongSelf->overlayView removeFromSuperview];
            strongSelf->overlayView = nil;
            
            if ([strongSelf->viewController isKindOfClass:[UINavigationController class]] == NO)
            {
                [strongSelf->viewController viewDidDisappear:aAnimated];
            }
        }
        
        if (completion)
        {
            completion();
        }
        else if (callDelegate && strongSelf && strongSelf->delegate && [strongSelf->delegate respondsToSelector:@selector(popoverControllerDidDismissPopover:)])
        {
            [strongSelf->delegate popoverControllerDidDismissPopover:strongSelf];
        }
    };
    
    if (isListeningNotifications == YES)
    {
        isListeningNotifications = NO;
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIApplicationDidChangeStatusBarOrientationNotification
                                                      object:nil];
        
        [[UIDevice currentDevice] endGeneratingDeviceOrientationNotifications];
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIDeviceOrientationDidChangeNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIKeyboardWillShowNotification
                                                      object:nil];
        
        [[NSNotificationCenter defaultCenter] removeObserver:self
                                                        name:UIKeyboardWillHideNotification
                                                      object:nil];
    }
    
    if ([viewController isKindOfClass:[UINavigationController class]] == NO)
    {
        [viewController viewWillDisappear:aAnimated];
    }
    
    @try {
        if (isObserverAdded == YES)
        {
            isObserverAdded = NO;
            
            if ([viewController respondsToSelector:@selector(preferredContentSize)]) {
                [viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(preferredContentSize))];
            } else {
                [viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(contentSizeForViewInPopover))];
            }
        }
    }
    @catch (NSException * __unused exception) {}
    
    if (aAnimated)
    {
        [UIView animateWithDuration:duration animations:^{
            __typeof__(self) strongSelf = weakSelf;
            
            if (strongSelf)
            {
                if ((style & WYPopoverAnimationOptionFade) == WYPopoverAnimationOptionFade)
                {
                    strongSelf->backgroundView.alpha = 0;
                }
                
                if ((style & WYPopoverAnimationOptionScale) == WYPopoverAnimationOptionScale)
                {
                    CGAffineTransform endTransform = [self transformForArrowDirection:strongSelf->backgroundView.arrowDirection];
                    strongSelf->backgroundView.transform = endTransform;
                }
                strongSelf->overlayView.alpha = 0;
            }
            adjustTintAutomatic();
        } completion:^(BOOL finished) {
            completionBlock();
        }];
    }
    else
    {
        adjustTintAutomatic();
        completionBlock();
    }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context
{
    if (object == viewController)
    {
        if ([keyPath isEqualToString:NSStringFromSelector(@selector(preferredContentSize))]
            || [keyPath isEqualToString:NSStringFromSelector(@selector(contentSizeForViewInPopover))])
        {
            CGSize contentSize = [self topViewControllerContentSize];
            [self setPopoverContentSize:contentSize];
        }
    }
    else if (object == theme)
    {
        [self updateThemeUI];
    }
}

#pragma mark WYPopoverOverlayViewDelegate

- (void)popoverOverlayViewDidTouch:(WYPopoverOverlayView *)aOverlayView
{
    //BOOL isTouched = [containerView isTouchedAtPoint:[containerView convertPoint:aPoint fromView:aOverlayView]];
    
    //if (!isTouched)
    //{
        BOOL shouldDismiss = !viewController.modalInPopover;
        
        if (shouldDismiss && delegate && [delegate respondsToSelector:@selector(popoverControllerShouldDismissPopover:)])
        {
            shouldDismiss = [delegate popoverControllerShouldDismissPopover:self];
        }
        
        if (shouldDismiss)
        {
            [self dismissPopoverAnimated:animated options:options completion:nil callDelegate:YES];
        }
    //}
}

#pragma mark WYPopoverBackgroundViewDelegate

- (void)popoverBackgroundViewDidTouchOutside:(WYPopoverBackgroundView *)aBackgroundView
{
    [self popoverOverlayViewDidTouch:nil];
}

#pragma mark Private

- (WYPopoverArrowDirection)arrowDirectionForRect:(CGRect)aRect
                                          inView:(UIView *)aView
                                     contentSize:(CGSize)contentSize
                                     arrowHeight:(float)arrowHeight
                        permittedArrowDirections:(WYPopoverArrowDirection)arrowDirections
{
    WYPopoverArrowDirection arrowDirection = WYPopoverArrowDirectionUnknown;
    
    NSMutableArray *areas = [NSMutableArray arrayWithCapacity:0];
    WYPopoverArea *area;
    
    if ((arrowDirections & WYPopoverArrowDirectionDown) == WYPopoverArrowDirectionDown)
    {
        area = [[WYPopoverArea alloc] init];
        area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionDown];
        area.arrowDirection = WYPopoverArrowDirectionDown;
        [areas addObject:area];
    }
    
    if ((arrowDirections & WYPopoverArrowDirectionUp) == WYPopoverArrowDirectionUp)
    {
        area = [[WYPopoverArea alloc] init];
        area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionUp];
        area.arrowDirection = WYPopoverArrowDirectionUp;
        [areas addObject:area];
    }
    
    if ((arrowDirections & WYPopoverArrowDirectionLeft) == WYPopoverArrowDirectionLeft)
    {
        area = [[WYPopoverArea alloc] init];
        area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionLeft];
        area.arrowDirection = WYPopoverArrowDirectionLeft;
        [areas addObject:area];
    }
    
    if ((arrowDirections & WYPopoverArrowDirectionRight) == WYPopoverArrowDirectionRight)
    {
        area = [[WYPopoverArea alloc] init];
        area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionRight];
        area.arrowDirection = WYPopoverArrowDirectionRight;
        [areas addObject:area];
    }
    
    if ((arrowDirections & WYPopoverArrowDirectionNone) == WYPopoverArrowDirectionNone)
    {
        area = [[WYPopoverArea alloc] init];
        area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionNone];
        area.arrowDirection = WYPopoverArrowDirectionNone;
        [areas addObject:area];
    }
    
    if ([areas count] > 1)
    {
        NSIndexSet* indexes = [areas indexesOfObjectsPassingTest:^BOOL(id obj, NSUInteger idx, BOOL *stop) {
            WYPopoverArea* popoverArea = (WYPopoverArea*)obj;
            
            BOOL result = (popoverArea.areaSize.width > 0 && popoverArea.areaSize.height > 0);
            
            return result;
        }];
        
        areas = [NSMutableArray arrayWithArray:[areas objectsAtIndexes:indexes]];
    }
    
    [areas sortUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        WYPopoverArea *area1 = (WYPopoverArea *)obj1;
        WYPopoverArea *area2 = (WYPopoverArea *)obj2;
        
        float val1 = area1.value;
        float val2 = area2.value;
        
        NSComparisonResult result = NSOrderedSame;
        
        if (val1 > val2)
        {
            result = NSOrderedAscending;
        }
        else if (val1 < val2)
        {
            result = NSOrderedDescending;
        }
        
        return result;
    }];
    
    for (NSUInteger i = 0; i < [areas count]; i++)
    {
        WYPopoverArea *popoverArea = (WYPopoverArea *)[areas objectAtIndex:i];
        
        if (popoverArea.areaSize.width >= contentSize.width)
        {
            arrowDirection = popoverArea.arrowDirection;
            break;
        }
    }
    
    if (arrowDirection == WYPopoverArrowDirectionUnknown)
    {
        if ([areas count] > 0)
        {
            arrowDirection = ((WYPopoverArea *)[areas objectAtIndex:0]).arrowDirection;
        }
        else
        {
            if ((arrowDirections & WYPopoverArrowDirectionDown) == WYPopoverArrowDirectionDown)
            {
                arrowDirection = WYPopoverArrowDirectionDown;
            }
            else if ((arrowDirections & WYPopoverArrowDirectionUp) == WYPopoverArrowDirectionUp)
            {
                arrowDirection = WYPopoverArrowDirectionUp;
            }
            else if ((arrowDirections & WYPopoverArrowDirectionLeft) == WYPopoverArrowDirectionLeft)
            {
                arrowDirection = WYPopoverArrowDirectionLeft;
            }
            else
            {
                arrowDirection = WYPopoverArrowDirectionRight;
            }
        }
    }
    
    return arrowDirection;
}

- (CGSize)sizeForRect:(CGRect)aRect
               inView:(UIView *)aView
          arrowHeight:(float)arrowHeight
       arrowDirection:(WYPopoverArrowDirection)arrowDirection
{
    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    
    CGRect viewFrame = [aView convertRect:aRect toView:nil];
    viewFrame = WYRectInWindowBounds(viewFrame, orientation);
    
    float minX, maxX, minY, maxY = 0;
    
    float keyboardHeight = UIInterfaceOrientationIsPortrait(orientation) ? keyboardRect.size.height : keyboardRect.size.width;
    
    if (delegate && [delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
        BOOL shouldIgnore = [delegate popoverControllerShouldIgnoreKeyboardBounds:self];
        
        if (shouldIgnore) {
            keyboardHeight = 0;
        }
    }
    
    float overlayWidth = UIInterfaceOrientationIsPortrait(orientation) ? overlayView.bounds.size.width : overlayView.bounds.size.height;
    
    float overlayHeight = UIInterfaceOrientationIsPortrait(orientation) ? overlayView.bounds.size.height : overlayView.bounds.size.width;
    
    minX = popoverLayoutMargins.left;
    maxX = overlayWidth - popoverLayoutMargins.right;
    minY = WYStatusBarHeight() + popoverLayoutMargins.top;
    maxY = overlayHeight - popoverLayoutMargins.bottom - keyboardHeight;
    
    CGSize result = CGSizeZero;
    
    if (arrowDirection == WYPopoverArrowDirectionLeft)
    {
        result.width = maxX - (viewFrame.origin.x + viewFrame.size.width);
        result.width -= arrowHeight;
        result.height = maxY - minY;
    }
    else if (arrowDirection == WYPopoverArrowDirectionRight)
    {
        result.width = viewFrame.origin.x - minX;
        result.width -= arrowHeight;
        result.height = maxY - minY;
    }
    else if (arrowDirection == WYPopoverArrowDirectionDown)
    {
        result.width = maxX - minX;
        result.height = viewFrame.origin.y - minY;
        result.height -= arrowHeight;
    }
    else if (arrowDirection == WYPopoverArrowDirectionUp)
    {
        result.width = maxX - minX;
        result.height = maxY - (viewFrame.origin.y + viewFrame.size.height);
        result.height -= arrowHeight;
    }
    else if (arrowDirection == WYPopoverArrowDirectionNone)
    {
        result.width = maxX - minX;
        result.height = maxY - minY;
    }
    
    return result;
}

#pragma mark Inline functions

static BOOL compileUsingIOS8SDK() {
    
    #if __IPHONE_OS_VERSION_MAX_ALLOWED >= 80000
        return YES;
    #endif
    
    return NO;
}

__unused static NSString* WYStringFromOrientation(NSInteger orientation) {
    NSString *result = @"Unknown";
    
    switch (orientation) {
        case UIInterfaceOrientationPortrait:
            result = @"Portrait";
            break;
        case UIInterfaceOrientationPortraitUpsideDown:
            result = @"Portrait UpsideDown";
            break;
        case UIInterfaceOrientationLandscapeLeft:
            result = @"Landscape Left";
            break;
        case UIInterfaceOrientationLandscapeRight:
            result = @"Landscape Right";
            break;
        default:
            break;
    }
    
    return result;
}

static float WYStatusBarHeight() {

    if (compileUsingIOS8SDK() && [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]) {
        CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
        return statusBarFrame.size.height;
    } else {
        UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

        float statusBarHeight = 0;
        {
            CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
            statusBarHeight = statusBarFrame.size.height;

            if (UIDeviceOrientationIsLandscape(orientation))
            {
                statusBarHeight = statusBarFrame.size.width;
            }
        }

        return statusBarHeight;
    }
}

static float WYInterfaceOrientationAngleOfOrientation(UIInterfaceOrientation orientation)
{
    float angle;
    // no transformation needed in iOS 8
    if (compileUsingIOS8SDK() && [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]) {
        angle = 0.0;
    } else {
        switch (orientation)
        {
            case UIInterfaceOrientationPortraitUpsideDown:
                angle = M_PI;
                break;
            case UIInterfaceOrientationLandscapeLeft:
                angle = -M_PI_2;
                break;
            case UIInterfaceOrientationLandscapeRight:
                angle = M_PI_2;
                break;
            default:
                angle = 0.0;
                break;
        }
    }
    
    return angle;
}

static CGRect WYRectInWindowBounds(CGRect rect, UIInterfaceOrientation orientation) {
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
    float windowWidth = keyWindow.bounds.size.width;
    float windowHeight = keyWindow.bounds.size.height;
    
    CGRect result = rect;
    if (!(compileUsingIOS8SDK() && [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)])) {
        
        if (orientation == UIInterfaceOrientationLandscapeRight) {
            
            result.origin.x = rect.origin.y;
            result.origin.y = windowWidth - rect.origin.x - rect.size.width;
            result.size.width = rect.size.height;
            result.size.height = rect.size.width;
        }
        
        if (orientation == UIInterfaceOrientationLandscapeLeft) {
            
            result.origin.x = windowHeight - rect.origin.y - rect.size.height;
            result.origin.y = rect.origin.x;
            result.size.width = rect.size.height;
            result.size.height = rect.size.width;
        }
        
        if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            
            result.origin.x = windowWidth - rect.origin.x - rect.size.width;
            result.origin.y = windowHeight - rect.origin.y - rect.size.height;
        }
    }
    
    return result;
}

static CGPoint WYPointRelativeToOrientation(CGPoint origin, CGSize size, UIInterfaceOrientation orientation) {
    
    UIWindow *keyWindow = [UIApplication sharedApplication].keyWindow;
    
    float windowWidth = keyWindow.bounds.size.width;
    float windowHeight = keyWindow.bounds.size.height;
    
    CGPoint result = origin;
    if (!(compileUsingIOS8SDK() && [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)])) {
        
        if (orientation == UIInterfaceOrientationLandscapeRight) {
            result.x = windowWidth - origin.y - size.width;
            result.y = origin.x;
        }
        
        if (orientation == UIInterfaceOrientationLandscapeLeft) {
            result.x = origin.y;
            result.y = windowHeight - origin.x - size.height;
        }
        
        if (orientation == UIInterfaceOrientationPortraitUpsideDown) {
            result.x = windowWidth - origin.x - size.width;
            result.y = windowHeight - origin.y - size.height;
        }
    }
    
    return result;
}

#pragma mark Selectors

- (void)didChangeStatusBarOrientation:(NSNotification *)notification
{
    isInterfaceOrientationChanging = YES;
}

- (void)didChangeDeviceOrientation:(NSNotification *)notification
{
    if (isInterfaceOrientationChanging == NO) return;
    
    isInterfaceOrientationChanging = NO;
    
    if ([viewController isKindOfClass:[UINavigationController class]])
    {
        UINavigationController* navigationController = (UINavigationController*)viewController;
        
        if (navigationController.navigationBarHidden == NO)
        {
            navigationController.navigationBarHidden = YES;
            navigationController.navigationBarHidden = NO;
        }
    }
    
    if (barButtonItem)
    {
        inView = [barButtonItem valueForKey:@"view"];
        rect = inView.bounds;
    }
    else if ([delegate respondsToSelector:@selector(popoverController:willRepositionPopoverToRect:inView:)])
    {
        CGRect anotherRect;
        UIView *anotherInView;
        
        [delegate popoverController:self willRepositionPopoverToRect:&anotherRect inView:&anotherInView];
        
        if (&anotherRect != NULL)
        {
            rect = anotherRect;
        }
        
        if (&anotherInView != NULL)
        {
            inView = anotherInView;
        }
    }
    
    [self positionPopover:NO];
}

- (void)keyboardWillShow:(NSNotification *)notification
{
    NSDictionary *info = [notification userInfo];
    keyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];
    
    //UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
    //WY_LOG(@"orientation = %@", WYStringFromOrientation(orientation));
    //WY_LOG(@"keyboardRect = %@", NSStringFromCGRect(keyboardRect));
    
    BOOL shouldIgnore = NO;
    
    if (delegate && [delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
        shouldIgnore = [delegate popoverControllerShouldIgnoreKeyboardBounds:self];
    }
    
    if (shouldIgnore == NO) {
        [self positionPopover:YES];
    }
}

- (void)keyboardWillHide:(NSNotification *)notification
{
    keyboardRect = CGRectZero;
    
    BOOL shouldIgnore = NO;
    
    if (delegate && [delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
        shouldIgnore = [delegate popoverControllerShouldIgnoreKeyboardBounds:self];
    }
    
    if (shouldIgnore == NO) {
        [self positionPopover:YES];
    }
}

#pragma mark Memory management

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
    
    [backgroundView removeFromSuperview];
    [backgroundView setDelegate:nil];
    
    [overlayView removeFromSuperview];
    [overlayView setDelegate:nil];
    @try {
        if (isObserverAdded == YES) {
            isObserverAdded = NO;
            
            if ([viewController respondsToSelector:@selector(preferredContentSize)]) {
                [viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(preferredContentSize))];
            } else {
                [viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(contentSizeForViewInPopover))];
            }
        }
    }
    @catch (NSException *exception) {
    }
    @finally {
        viewController = nil;
    }

    [self unregisterTheme];
  
    barButtonItem = nil;
    passthroughViews = nil;
    inView = nil;
    overlayView = nil;
    backgroundView = nil;
    
    theme = nil;
}

@end

