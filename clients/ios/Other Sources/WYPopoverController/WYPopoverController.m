/*
 Version 0.3.6

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

@interface WYKeyboardListener : NSObject

+ (BOOL)isVisible;
+ (CGRect)rect;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation WYKeyboardListener

static BOOL _isVisible;
static CGRect _keyboardRect;

+ (void)load {
  @autoreleasepool {
    _keyboardRect = CGRectZero;
    _isVisible = NO;

    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillShow:) name:UIKeyboardWillShowNotification object:nil];
    [NSNotificationCenter.defaultCenter addObserver:self selector:@selector(keyboardWillHide) name:UIKeyboardWillHideNotification object:nil];
  }
}

+ (void)keyboardWillShow:(NSNotification *)notification {
  NSDictionary *info = [notification userInfo];
  _keyboardRect = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue];

  _isVisible = YES;
}

+ (void)keyboardWillHide {
  _keyboardRect = CGRectZero;
  _isVisible = NO;
}

+ (BOOL)isVisible {
  return _isVisible;
}

+ (CGRect)rect {
  return _keyboardRect;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIColor (WYPopover)

- (BOOL)wy_getValueOfRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)apha;
- (NSString *)wy_hexString;
- (UIColor *)wy_colorByLighten:(float)d;
- (UIColor *)wy_colorByDarken:(float)d;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation UIColor (WYPopover)

- (BOOL)wy_getValueOfRed:(CGFloat *)red green:(CGFloat *)green blue:(CGFloat *)blue alpha:(CGFloat *)alpha {
  // model: kCGColorSpaceModelRGB, num_comps: 4
  // model: kCGColorSpaceModelMonochrome, num_comps: 2

  CGColorSpaceRef colorSpace = CGColorSpaceRetain(CGColorGetColorSpace([self CGColor]));
  CGColorSpaceModel colorSpaceModel = CGColorSpaceGetModel(colorSpace);
  CGColorSpaceRelease(colorSpace);

  CGFloat rFloat = 0.0, gFloat = 0.0, bFloat = 0.0, aFloat = 0.0;
  BOOL result = NO;

  if (colorSpaceModel == kCGColorSpaceModelRGB) {
    result = [self getRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];
  } else if (colorSpaceModel == kCGColorSpaceModelMonochrome) {
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

- (NSString *)wy_hexString {
  CGFloat rFloat, gFloat, bFloat, aFloat;
  int r, g, b, a;
  [self wy_getValueOfRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];

  r = (int)(255.0 * rFloat);
  g = (int)(255.0 * gFloat);
  b = (int)(255.0 * bFloat);
  a = (int)(255.0 * aFloat);

  return [NSString stringWithFormat:@"#%02x%02x%02x%02x", r, g, b, a];
}

- (UIColor *)wy_colorByLighten:(float)d {
  CGFloat rFloat, gFloat, bFloat, aFloat;
  [self wy_getValueOfRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];

  return [UIColor colorWithRed:MIN(rFloat + d, 1.0)
                         green:MIN(gFloat + d, 1.0)
                          blue:MIN(bFloat + d, 1.0)
                         alpha:1.0];
}

- (UIColor *)wy_colorByDarken:(float)d {
  CGFloat rFloat, gFloat, bFloat, aFloat;
  [self wy_getValueOfRed:&rFloat green:&gFloat blue:&bFloat alpha:&aFloat];

  return [UIColor colorWithRed:MAX(rFloat - d, 0.0)
                         green:MAX(gFloat - d, 0.0)
                          blue:MAX(bFloat - d, 0.0)
                         alpha:1.0];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UINavigationController (WYPopover)

@property(nonatomic, assign, getter = wy_isEmbedInPopover) BOOL wy_embedInPopover;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@implementation UINavigationController (WYPopover)

static char const * const UINavigationControllerEmbedInPopoverTagKey = "UINavigationControllerEmbedInPopoverTagKey";

@dynamic wy_embedInPopover;

+ (void)load {
  Method original, swizzle;

  original = class_getInstanceMethod(self, @selector(pushViewController:animated:));
  swizzle = class_getInstanceMethod(self, @selector(sizzled_pushViewController:animated:));

  method_exchangeImplementations(original, swizzle);

  original = class_getInstanceMethod(self, @selector(setViewControllers:animated:));
  swizzle = class_getInstanceMethod(self, @selector(sizzled_setViewControllers:animated:));

  method_exchangeImplementations(original, swizzle);
}

- (BOOL)wy_isEmbedInPopover {
  BOOL result = NO;

  NSNumber *value = objc_getAssociatedObject(self, UINavigationControllerEmbedInPopoverTagKey);

  if (value) {
    result = [value boolValue];
  }

  return result;
}

- (void)setWy_embedInPopover:(BOOL)value
{
  objc_setAssociatedObject(self, UINavigationControllerEmbedInPopoverTagKey, [NSNumber numberWithBool:value], OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

- (CGSize)contentSize:(UIViewController *)aViewController {
  CGSize result = CGSizeZero;

#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
  if ([aViewController respondsToSelector:@selector(contentSizeForViewInPopover)]) {
    result = aViewController.contentSizeForViewInPopover;
  }
#pragma clang diagnostic pop

#ifdef WY_BASE_SDK_7_ENABLED
  if ([aViewController respondsToSelector:@selector(preferredContentSize)]) {
    result = aViewController.preferredContentSize;
  }
#endif

  return result;
}

- (void)setContentSize:(CGSize)aContentSize {
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

- (void)sizzled_pushViewController:(UIViewController *)aViewController animated:(BOOL)aAnimated {
  if (self.wy_isEmbedInPopover) {
#ifdef WY_BASE_SDK_7_ENABLED
    if ([aViewController respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
      aViewController.edgesForExtendedLayout = UIRectEdgeNone;
    }
#endif
    CGSize contentSize = [self contentSize:aViewController];
    [self setContentSize:contentSize];
  }

  [self sizzled_pushViewController:aViewController animated:aAnimated];

  if (self.wy_isEmbedInPopover) {
    CGSize contentSize = [self contentSize:aViewController];
    [self setContentSize:contentSize];
  }
}

- (void)sizzled_setViewControllers:(NSArray *)aViewControllers animated:(BOOL)aAnimated {
  NSUInteger count = [aViewControllers count];

#ifdef WY_BASE_SDK_7_ENABLED
  if (self.wy_isEmbedInPopover && count > 0) {
    for (UIViewController *viewController in aViewControllers) {
      if ([viewController respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
        viewController.edgesForExtendedLayout = UIRectEdgeNone;
      }
    }
  }
#endif

  [self sizzled_setViewControllers:aViewControllers animated:aAnimated];

  if (self.wy_isEmbedInPopover && count > 0) {
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

+ (void)load {
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

- (void)sizzled_setContentSizeForViewInPopover:(CGSize)aSize {
  [self sizzled_setContentSizeForViewInPopover:aSize];

  if ([self isKindOfClass:[UINavigationController class]] == NO && self.navigationController != nil) {
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    [self.navigationController setContentSizeForViewInPopover:aSize];
#pragma clang diagnostic pop
  }
}

- (void)sizzled_setPreferredContentSize:(CGSize)aSize {
  [self sizzled_setPreferredContentSize:aSize];

  if ([self isKindOfClass:[UINavigationController class]] == NO && self.navigationController != nil)
  {
#ifdef WY_BASE_SDK_7_ENABLED
    if ([self.navigationController wy_isEmbedInPopover] == NO) {
      return;
    } else if ([self respondsToSelector:@selector(setPreferredContentSize:)]) {
      [self.navigationController sizzled_setPreferredContentSize:aSize];
    }
#endif
  }
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface WYPopoverArea : NSObject

@property (nonatomic, assign) WYPopoverArrowDirection arrowDirection;
@property (nonatomic, assign) CGSize areaSize;
@property (nonatomic, assign, readonly) float value;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - WYPopoverArea

@implementation WYPopoverArea

- (NSString*)description {
  const NSDictionary *directionMap = @{@(WYPopoverArrowDirectionUp)    : @"UP",
                                       @(WYPopoverArrowDirectionDown)  : @"DOWN",
                                       @(WYPopoverArrowDirectionLeft)  : @"LEFT",
                                       @(WYPopoverArrowDirectionRight) : @"RIGHT",
                                       @(WYPopoverArrowDirectionNone)  : @"NONE"};
  NSString *direction = directionMap[@(_arrowDirection)];
  return [NSString stringWithFormat:@"%@ [ %f x %f ]", direction, _areaSize.width, _areaSize.height];
}

- (float)value {
  float result = 0;

  if (_areaSize.width > 0 && _areaSize.height > 0) {
    float w1 = ceilf(_areaSize.width / 10.0);
    float h1 = ceilf(_areaSize.height / 10.0);

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

  result.usesRoundedArrow = NO;
  result.dimsBackgroundViewsTintColor = YES;
  result.tintColor = [UIColor colorWithRed:55./255. green:63./255. blue:71./255. alpha:1.0];
  result.outerStrokeColor = nil;
  result.innerStrokeColor = nil;
  result.fillTopColor = result.tintColor;
  result.fillBottomColor = [result.tintColor wy_colorByDarken:0.4];
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
  result.preferredAlpha = 1.0f;


  return result;
}

+ (id)themeForIOS7 {

  WYPopoverTheme *result = [[WYPopoverTheme alloc] init];

  result.usesRoundedArrow = YES;
  result.dimsBackgroundViewsTintColor = YES;
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
  result.preferredAlpha = 1.0f;


  return result;
}

- (NSUInteger)innerCornerRadius {
  float result = _innerCornerRadius;

  if (_borderWidth == 0) {
    result = 0;

    if (_outerCornerRadius > 0) {
      result = _outerCornerRadius;
    }
  }

  return result;
}

- (CGSize)outerShadowOffset {
  CGSize result = _outerShadowOffset;

  result.width = MIN(result.width, _outerShadowBlurRadius);
  result.height = MIN(result.height, _outerShadowBlurRadius);

  return result;
}

- (UIColor *)innerStrokeColor {
  return _innerStrokeColor?: [self.fillTopColor wy_colorByDarken:0.6];
}

- (UIColor *)outerStrokeColor {
  return _outerStrokeColor?: [self.fillTopColor wy_colorByDarken:0.6];
}

- (UIColor *)glossShadowColor {
  return _glossShadowColor?: [self.fillTopColor wy_colorByLighten:0.2];
}

- (UIColor *)fillTopColor {
  return _fillTopColor?: _tintColor;
}

- (UIColor *)fillBottomColor {
  return _fillBottomColor?: self.fillTopColor;
}

- (NSArray *)observableKeypaths {
  return [NSArray arrayWithObjects:@"tintColor", @"outerStrokeColor", @"innerStrokeColor", @"fillTopColor", @"fillBottomColor", @"glossShadowColor", @"glossShadowOffset", @"glossShadowBlurRadius", @"borderWidth", @"arrowBase", @"arrowHeight", @"outerShadowColor", @"outerShadowBlurRadius", @"outerShadowOffset", @"outerCornerRadius", @"innerShadowColor", @"innerShadowBlurRadius", @"innerShadowOffset", @"innerCornerRadius", @"viewContentInsets", @"overlayColor", nil];
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface UIImage (WYPopover)

+ (UIImage *)wy_imageWithColor:(UIColor *)color;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - UIImage (WYPopover)

@implementation UIImage (WYPopover)

static float edgeSizeFromCornerRadius(float cornerRadius) {
  return cornerRadius * 2 + 1;
}

+ (UIImage *)wy_imageWithColor:(UIColor *)color {
  return [self imageWithColor:color size:CGSizeMake(8, 8) cornerRadius:0];
}

+ (UIImage *)imageWithColor:(UIColor *)color
               cornerRadius:(float)cornerRadius {
  float min = edgeSizeFromCornerRadius(cornerRadius);

  CGSize minSize = CGSizeMake(min, min);

  return [self imageWithColor:color size:minSize cornerRadius:cornerRadius];
}

+ (UIImage *)imageWithColor:(UIColor *)color
                       size:(CGSize)aSize
               cornerRadius:(float)cornerRadius {
  CGRect rect = CGRectMake(0, 0, aSize.width, aSize.height);
  UIBezierPath *roundedRect = [UIBezierPath bezierPathWithRoundedRect:rect cornerRadius:cornerRadius];
  roundedRect.lineWidth = 0;
  UIGraphicsBeginImageContextWithOptions(rect.size, NO, 0.0f);
  [color setFill];
  [roundedRect fill];
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
@property (nonatomic, assign) float   gradientHeight;
@property (nonatomic, assign) float   gradientTopPosition;

@property (nonatomic, strong) UIColor *innerShadowColor;
@property (nonatomic, assign) CGSize  innerShadowOffset;
@property (nonatomic, assign) float   innerShadowBlurRadius;
@property (nonatomic, assign) float   innerCornerRadius;

@property (nonatomic, assign) float   navigationBarHeight;
@property (nonatomic, assign) BOOL    wantsDefaultContentAppearance;
@property (nonatomic, assign) float   borderWidth;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - WYPopoverInnerView

@implementation WYPopoverBackgroundInnerView

- (id)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self) {
    self.backgroundColor = [UIColor clearColor];
    self.userInteractionEnabled = NO;
  }
  return self;
}

- (void)drawRect:(CGRect)rect {
  CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
  CGContextRef context = UIGraphicsGetCurrentContext();

  //// Gradient Declarations
  NSArray* fillGradientColors = [NSArray arrayWithObjects:
                                 (id)_gradientTopColor.CGColor,
                                 (id)_gradientBottomColor.CGColor, nil];

  CGFloat fillGradientLocations[2] = { 0, 1 };

  CGGradientRef fillGradient = CGGradientCreateWithColors(colorSpace, (__bridge CFArrayRef)fillGradientColors, fillGradientLocations);

  //// innerRect Drawing
  float barHeight = (_wantsDefaultContentAppearance == NO) ? _navigationBarHeight : 0;
  float cornerRadius = (_wantsDefaultContentAppearance == NO) ? _innerCornerRadius : 0;

  CGRect innerRect = CGRectMake(CGRectGetMinX(rect), CGRectGetMinY(rect) + barHeight, CGRectGetWidth(rect) , CGRectGetHeight(rect) - barHeight);

  UIBezierPath* rectPath = [UIBezierPath bezierPathWithRect:innerRect];

  UIBezierPath* roundedRectPath = [UIBezierPath bezierPathWithRoundedRect:innerRect cornerRadius:cornerRadius + 1];

  if (_wantsDefaultContentAppearance == NO && _borderWidth > 0) {
    CGContextSaveGState(context);
    {
      [rectPath appendPath:roundedRectPath];
      rectPath.usesEvenOddFillRule = YES;
      [rectPath addClip];

      CGContextDrawLinearGradient(context, fillGradient,
                                  CGPointMake(0, -_gradientTopPosition),
                                  CGPointMake(0, -_gradientTopPosition + _gradientHeight),
                                  0);
    }
    CGContextRestoreGState(context);
  }

  CGContextSaveGState(context);
  {
    if (_wantsDefaultContentAppearance == NO && _borderWidth > 0) {
      [roundedRectPath addClip];
      CGContextSetShadowWithColor(context, _innerShadowOffset, _innerShadowBlurRadius, _innerShadowColor.CGColor);
    }

    UIBezierPath* inRoundedRectPath = [UIBezierPath bezierPathWithRoundedRect:CGRectInset(innerRect, 0.5, 0.5) cornerRadius:cornerRadius];

    if (_borderWidth == 0) {
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
  _innerShadowColor = nil;
  _innerStrokeColor = nil;
  _gradientTopColor = nil;
  _gradientBottomColor = nil;
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@protocol WYPopoverOverlayViewDelegate;

@interface WYPopoverOverlayView : UIView {
  BOOL _testHits;
}

@property(nonatomic, assign) id <WYPopoverOverlayViewDelegate> delegate;
@property(nonatomic, unsafe_unretained) NSArray *passthroughViews;

@end


////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - WYPopoverOverlayViewDelegate

@protocol WYPopoverOverlayViewDelegate <NSObject>

@optional
- (BOOL)dismissOnPassthroughViewTap;
- (void)popoverOverlayViewDidTouch:(WYPopoverOverlayView *)overlayView;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - WYPopoverOverlayView

@implementation WYPopoverOverlayView

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
  if (_testHits) {
    return nil;
  }

  UIView *view = [super hitTest:point withEvent:event];

  if (view == self) {
    _testHits = YES;
    UIView *superHitView = [self.superview hitTest:point withEvent:event];
    _testHits = NO;

    if ([self isPassthroughView:superHitView]) {
      if ([self.delegate dismissOnPassthroughViewTap]) {
        dispatch_async(dispatch_get_main_queue(), ^ {
                         if ([self.delegate respondsToSelector:@selector(popoverOverlayViewDidTouch:)]) {
                           [self.delegate popoverOverlayViewDidTouch:self];
                         }
                       });
      }
      return superHitView;
    }
  }
  return view;
}

- (BOOL)isPassthroughView:(UIView *)view {
  if (view == nil) {
    return NO;
  }
  if ([self.passthroughViews containsObject:view]) {
    return YES;
  }
  return [self isPassthroughView:view.superview];
}

/**
 * @note This empty method is meaningful.
 *       If the method is not defined, touch event isn't capture in iOS6.
 */
- (void)drawRect:(CGRect)rect {}

#pragma mark - UIAccessibility

- (void)accessibilityElementDidBecomeFocused {
  self.accessibilityLabel = NSLocalizedString(@"Double-tap to dismiss pop-up window.", nil);
}

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - WYPopoverBackgroundViewDelegate

@protocol WYPopoverBackgroundViewDelegate <NSObject>

@optional
- (void)popoverBackgroundViewDidTouchOutside:(WYPopoverBackgroundView *)backgroundView;

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

@interface WYPopoverBackgroundView () {
  WYPopoverBackgroundInnerView *_innerView;
  CGSize _contentSize;
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

@end

////////////////////////////////////////////////////////////////////////////////////////////////////////

#pragma mark - WYPopoverBackgroundView

@implementation WYPopoverBackgroundView

- (id)initWithContentSize:(CGSize)aContentSize {
  self = [super initWithFrame:CGRectMake(0, 0, aContentSize.width, aContentSize.height)];

  if (self != nil) {
    _contentSize = aContentSize;

    self.autoresizesSubviews = NO;
    self.backgroundColor = [UIColor clearColor];

    self.arrowDirection = WYPopoverArrowDirectionDown;
    self.arrowOffset = 0;

    self.layer.name = @"parent";

    if (WY_IS_IOS_GREATER_THAN_OR_EQUAL_TO(@"6.0")) {
      self.layer.drawsAsynchronously = YES;
    }

    self.layer.contentsScale = [UIScreen mainScreen].scale;
    //self.layer.edgeAntialiasingMask = kCALayerLeftEdge | kCALayerRightEdge | kCALayerBottomEdge | kCALayerTopEdge;
    self.layer.delegate = self;
  }

  return self;
}

- (void)tapOut {
  [self.delegate popoverBackgroundViewDidTouchOutside:self];
}

- (UIEdgeInsets)outerShadowInsets {
  UIEdgeInsets result = UIEdgeInsetsMake(_outerShadowBlurRadius, _outerShadowBlurRadius, _outerShadowBlurRadius, _outerShadowBlurRadius);

  result.top -= self.outerShadowOffset.height;
  result.bottom += self.outerShadowOffset.height;
  result.left -= self.outerShadowOffset.width;
  result.right += self.outerShadowOffset.width;

  return result;
}

- (void)setArrowOffset:(float)value {
  float coef = 1;

  if (value != 0) {
    coef = value / ABS(value);

    value = ABS(value);

    CGRect outerRect = [self outerRect];

    float delta = self.arrowBase / 2. + .5;

    delta  += MIN(_minOuterCornerRadius, _outerCornerRadius);

    outerRect = CGRectInset(outerRect, delta, delta);

    if (_arrowDirection == WYPopoverArrowDirectionUp || _arrowDirection == WYPopoverArrowDirectionDown) {
      value += coef * self.outerShadowOffset.width;
      value = MIN(value, CGRectGetWidth(outerRect) / 2);
    }

    if (_arrowDirection == WYPopoverArrowDirectionLeft || _arrowDirection == WYPopoverArrowDirectionRight) {
      value += coef * self.outerShadowOffset.height;
      value = MIN(value, CGRectGetHeight(outerRect) / 2);
    }
  } else {
    if (_arrowDirection == WYPopoverArrowDirectionUp || _arrowDirection == WYPopoverArrowDirectionDown) {
      value += self.outerShadowOffset.width;
    }

    if (_arrowDirection == WYPopoverArrowDirectionLeft || _arrowDirection == WYPopoverArrowDirectionRight) {
      value += self.outerShadowOffset.height;
    }
  }
  _arrowOffset = value * coef;
}

- (void)setViewController:(UIViewController *)viewController {
  _contentView = viewController.view;

  _contentView.frame = CGRectIntegral(CGRectMake(0, 0, self.bounds.size.width, self.bounds.size.height));

  [self addSubview:_contentView];

  _navigationBarHeight = 0;

  if ([viewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController* navigationController = (UINavigationController*)viewController;
    _navigationBarHeight = navigationController.navigationBarHidden? 0 : navigationController.navigationBar.bounds.size.height;
  }

  _contentView.frame = CGRectIntegral([self innerRect]);

  if (_innerView == nil) {
    _innerView = [[WYPopoverBackgroundInnerView alloc] initWithFrame:_contentView.frame];
    _innerView.userInteractionEnabled = NO;

    _innerView.gradientTopColor = self.fillTopColor;
    _innerView.gradientBottomColor = self.fillBottomColor;
    _innerView.innerShadowColor = _innerShadowColor;
    _innerView.innerStrokeColor = self.innerStrokeColor;
    _innerView.innerShadowOffset = _innerShadowOffset;
    _innerView.innerCornerRadius = self.innerCornerRadius;
    _innerView.innerShadowBlurRadius = _innerShadowBlurRadius;
    _innerView.borderWidth = self.borderWidth;
  }

  _innerView.navigationBarHeight = _navigationBarHeight;
  _innerView.gradientHeight = self.frame.size.height - 2 * _outerShadowBlurRadius;
  _innerView.gradientTopPosition = _contentView.frame.origin.y - self.outerShadowInsets.top;
  _innerView.wantsDefaultContentAppearance = _wantsDefaultContentAppearance;

  [self insertSubview:_innerView aboveSubview:_contentView];

  _innerView.frame = CGRectIntegral(_contentView.frame);

  [self.layer setNeedsDisplay];
}

- (CGSize)sizeThatFits:(CGSize)size {
  CGSize result = size;

  result.width += 2 * (_borderWidth + _outerShadowBlurRadius);
  result.height += _borderWidth + 2 * _outerShadowBlurRadius;

  if (_navigationBarHeight == 0) {
    result.height += _borderWidth;
  }

  if (_arrowDirection == WYPopoverArrowDirectionUp || _arrowDirection == WYPopoverArrowDirectionDown) {
    result.height += _arrowHeight;
  }

  if (_arrowDirection == WYPopoverArrowDirectionLeft || _arrowDirection == WYPopoverArrowDirectionRight) {
    result.width += _arrowHeight;
  }

  return result;
}

- (void)sizeToFit {
  CGSize size = [self sizeThatFits:_contentSize];
  self.bounds = CGRectMake(0, 0, size.width, size.height);
}

#pragma mark Drawing

- (void)setNeedsDisplay {
  [super setNeedsDisplay];

  [self.layer setNeedsDisplay];
    
  self.alpha = self.preferredAlpha;
    
  if (_innerView) {
    _innerView.gradientTopColor = self.fillTopColor;
    _innerView.gradientBottomColor = self.fillBottomColor;
    _innerView.innerShadowColor = _innerShadowColor;
    _innerView.innerStrokeColor = self.innerStrokeColor;
    _innerView.innerShadowOffset = _innerShadowOffset;
    _innerView.innerCornerRadius = self.innerCornerRadius;
    _innerView.innerShadowBlurRadius = _innerShadowBlurRadius;
    _innerView.borderWidth = self.borderWidth;

    _innerView.navigationBarHeight = _navigationBarHeight;
    _innerView.gradientHeight = self.frame.size.height - 2 * _outerShadowBlurRadius;
    _innerView.gradientTopPosition = _contentView.frame.origin.y - self.outerShadowInsets.top;
    _innerView.wantsDefaultContentAppearance = _wantsDefaultContentAppearance;

    [_innerView setNeedsDisplay];
  }
}

#pragma mark CALayerDelegate

- (void)drawLayer:(CALayer *)layer inContext:(CGContextRef)context {
  if ([layer.name isEqualToString:@"parent"]) {
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
    CGRect insetRect = CGRectInset(outerRect, 0.5, 0.5);
    if (!CGRectIsEmpty(insetRect) && !CGRectIsInfinite(insetRect)) {
      outerRect = insetRect;
    }

    // Inner Path
    CGMutablePathRef outerPathRef = CGPathCreateMutable();

    CGPoint arrowTipPoint = CGPointZero;
    CGPoint arrowBasePointA = CGPointZero;
    CGPoint arrowBasePointB = CGPointZero;

    float reducedOuterCornerRadius = 0;

    if (_arrowDirection == WYPopoverArrowDirectionUp || _arrowDirection == WYPopoverArrowDirectionDown) {
      if (_arrowOffset >= 0) {
        reducedOuterCornerRadius = CGRectGetMaxX(outerRect) - (CGRectGetMidX(outerRect) + _arrowOffset + _arrowBase / 2);
      } else {
        reducedOuterCornerRadius = (CGRectGetMidX(outerRect) + _arrowOffset - _arrowBase / 2) - CGRectGetMinX(outerRect);
      }
    } else if (_arrowDirection == WYPopoverArrowDirectionLeft || _arrowDirection == WYPopoverArrowDirectionRight) {
      if (_arrowOffset >= 0) {
        reducedOuterCornerRadius = CGRectGetMaxY(outerRect) - (CGRectGetMidY(outerRect) + _arrowOffset + _arrowBase / 2);
      } else {
        reducedOuterCornerRadius = (CGRectGetMidY(outerRect) + _arrowOffset - _arrowBase / 2) - CGRectGetMinY(outerRect);
      }
    }

    reducedOuterCornerRadius = MIN(reducedOuterCornerRadius, _outerCornerRadius);

    CGFloat roundedArrowControlLength = _arrowBase / 5.0f;
    if (_arrowDirection == WYPopoverArrowDirectionUp) {
      arrowTipPoint = CGPointMake(CGRectGetMidX(outerRect) + _arrowOffset,
                                  CGRectGetMinY(outerRect) - _arrowHeight);
      arrowBasePointA = CGPointMake(arrowTipPoint.x - _arrowBase / 2,
                                    arrowTipPoint.y + _arrowHeight);
      arrowBasePointB = CGPointMake(arrowTipPoint.x + _arrowBase / 2,
                                    arrowTipPoint.y + _arrowHeight);

      CGPathMoveToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);

      if (self.usesRoundedArrow) {
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowBasePointA.x + roundedArrowControlLength, arrowBasePointA.y,
                              arrowTipPoint.x - (roundedArrowControlLength * 0.75f), arrowTipPoint.y,
                              arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowTipPoint.x + (roundedArrowControlLength * 0.75f), arrowTipPoint.y,
                              arrowBasePointB.x - roundedArrowControlLength, arrowBasePointB.y,
                              arrowBasePointB.x, arrowBasePointB.y);
      } else {
        CGPathAddLineToPoint(outerPathRef, NULL, arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointB.x, arrowBasePointB.y);
      }

      CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          (_arrowOffset >= 0) ? reducedOuterCornerRadius : _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL, CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          (_arrowOffset < 0) ? reducedOuterCornerRadius : _outerCornerRadius);

      CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);
    } else if (_arrowDirection == WYPopoverArrowDirectionDown) {
      arrowTipPoint = CGPointMake(CGRectGetMidX(outerRect) + _arrowOffset,
                                  CGRectGetMaxY(outerRect) + _arrowHeight);
      arrowBasePointA = CGPointMake(arrowTipPoint.x + _arrowBase / 2,
                                    arrowTipPoint.y - _arrowHeight);
      arrowBasePointB = CGPointMake(arrowTipPoint.x - _arrowBase / 2,
                                    arrowTipPoint.y - _arrowHeight);

      CGPathMoveToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);

      if (self.usesRoundedArrow) {
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowBasePointA.x - roundedArrowControlLength, arrowBasePointA.y,
                              arrowTipPoint.x + (roundedArrowControlLength * 0.75f), arrowTipPoint.y,
                              arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowTipPoint.x - (roundedArrowControlLength * 0.75f), arrowTipPoint.y,
                              arrowBasePointB.x + roundedArrowControlLength, arrowBasePointA.y,
                              arrowBasePointB.x, arrowBasePointB.y);
      } else {
        CGPathAddLineToPoint(outerPathRef, NULL, arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointB.x, arrowBasePointB.y);
      }

      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          (_arrowOffset < 0) ? reducedOuterCornerRadius : _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          (_arrowOffset >= 0) ? reducedOuterCornerRadius : _outerCornerRadius);

      CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);
    } else if (_arrowDirection == WYPopoverArrowDirectionLeft) {
      arrowTipPoint = CGPointMake(CGRectGetMinX(outerRect) - _arrowHeight,
                                  CGRectGetMidY(outerRect) + _arrowOffset);
      arrowBasePointA = CGPointMake(arrowTipPoint.x + _arrowHeight,
                                    arrowTipPoint.y + _arrowBase / 2);
      arrowBasePointB = CGPointMake(arrowTipPoint.x + _arrowHeight,
                                    arrowTipPoint.y - _arrowBase / 2);

      CGPathMoveToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);

      if (self.usesRoundedArrow) {
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowBasePointA.x, arrowBasePointA.y - roundedArrowControlLength,
                              arrowTipPoint.x, arrowTipPoint.y + (roundedArrowControlLength * 0.75f),
                              arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowTipPoint.x, arrowTipPoint.y - (roundedArrowControlLength * 0.75f),
                              arrowBasePointB.x, arrowBasePointB.y + roundedArrowControlLength,
                              arrowBasePointB.x, arrowBasePointB.y);
      } else {
        CGPathAddLineToPoint(outerPathRef, NULL, arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointB.x, arrowBasePointB.y);
      }

      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          (_arrowOffset < 0) ? reducedOuterCornerRadius : _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          (_arrowOffset >= 0) ? reducedOuterCornerRadius : _outerCornerRadius);

      CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);
    } else if (_arrowDirection == WYPopoverArrowDirectionRight) {
      arrowTipPoint = CGPointMake(CGRectGetMaxX(outerRect) + _arrowHeight,
                                  CGRectGetMidY(outerRect) + _arrowOffset);
      arrowBasePointA = CGPointMake(arrowTipPoint.x - _arrowHeight,
                                    arrowTipPoint.y - _arrowBase / 2);
      arrowBasePointB = CGPointMake(arrowTipPoint.x - _arrowHeight,
                                    arrowTipPoint.y + _arrowBase / 2);

      CGPathMoveToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);

      if (self.usesRoundedArrow) {
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowBasePointA.x, arrowBasePointA.y + roundedArrowControlLength,
                              arrowTipPoint.x, arrowTipPoint.y - (roundedArrowControlLength * 0.75f),
                              arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddCurveToPoint(outerPathRef, NULL,
                              arrowTipPoint.x, arrowTipPoint.y + (roundedArrowControlLength * 0.75f),
                              arrowBasePointB.x, arrowBasePointB.y - roundedArrowControlLength,
                              arrowBasePointB.x, arrowBasePointB.y);
      } else {
        CGPathAddLineToPoint(outerPathRef, NULL, arrowTipPoint.x, arrowTipPoint.y);
        CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointB.x, arrowBasePointB.y);
      }

      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          (_arrowOffset >= 0) ? reducedOuterCornerRadius : _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          (_arrowOffset < 0) ? reducedOuterCornerRadius : _outerCornerRadius);

      CGPathAddLineToPoint(outerPathRef, NULL, arrowBasePointA.x, arrowBasePointA.y);
    } else if (_arrowDirection == WYPopoverArrowDirectionNone) {
      CGPoint origin = CGPointMake(CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect));

      CGPathMoveToPoint(outerPathRef, NULL, origin.x, origin.y);

      CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect));
      CGPathAddLineToPoint(outerPathRef, NULL, CGRectGetMaxX(outerRect), CGRectGetMidY(outerRect));

      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMaxY(outerRect),
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMinX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          _outerCornerRadius);
      CGPathAddArcToPoint(outerPathRef, NULL,
                          CGRectGetMaxX(outerRect), CGRectGetMinY(outerRect),
                          CGRectGetMaxX(outerRect), CGRectGetMaxY(outerRect),
                          _outerCornerRadius);

      CGPathAddLineToPoint(outerPathRef, NULL, origin.x, origin.y);
    }

    CGPathCloseSubpath(outerPathRef);
    UIBezierPath* outerRectPath = [UIBezierPath bezierPathWithCGPath:outerPathRef];

    CGContextSaveGState(context);
    {
      CGContextSetShadowWithColor(context, self.outerShadowOffset, _outerShadowBlurRadius, _outerShadowColor.CGColor);
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
    CGRect outerRectBorderRect = CGRectInset([outerRectPath bounds], -_glossShadowBlurRadius, -_glossShadowBlurRadius);
    outerRectBorderRect = CGRectOffset(outerRectBorderRect, -_glossShadowOffset.width, -_glossShadowOffset.height);
    outerRectBorderRect = CGRectInset(CGRectUnion(outerRectBorderRect, [outerRectPath bounds]), -1, -1);

    UIBezierPath* outerRectNegativePath = [UIBezierPath bezierPathWithRect: outerRectBorderRect];
    [outerRectNegativePath appendPath: outerRectPath];
    outerRectNegativePath.usesEvenOddFillRule = YES;

    CGContextSaveGState(context);
    {
      float xOffset = _glossShadowOffset.width + round(outerRectBorderRect.size.width);
      float yOffset = _glossShadowOffset.height;
      CGContextSetShadowWithColor(context,
                                  CGSizeMake(xOffset + copysign(0.1, xOffset), yOffset + copysign(0.1, yOffset)),
                                  _glossShadowBlurRadius,
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

- (CGRect)outerRect {
  return [self outerRect:self.bounds arrowDirection:self.arrowDirection];
}

- (CGRect)innerRect {
  return [self innerRect:self.bounds arrowDirection:self.arrowDirection];
}

- (CGRect)arrowRect {
  return [self arrowRect:self.bounds arrowDirection:self.arrowDirection];
}

- (CGRect)outerRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection{
  CGRect result = rect;

  if (aArrowDirection == WYPopoverArrowDirectionUp || _arrowDirection == WYPopoverArrowDirectionDown) {
    result.size.height -= _arrowHeight;

    if (aArrowDirection == WYPopoverArrowDirectionUp) {
      result = CGRectOffset(result, 0, _arrowHeight);
    }
  }

  if (aArrowDirection == WYPopoverArrowDirectionLeft || _arrowDirection == WYPopoverArrowDirectionRight) {
    result.size.width -= _arrowHeight;

    if (aArrowDirection == WYPopoverArrowDirectionLeft) {
      result = CGRectOffset(result, _arrowHeight, 0);
    }
  }

  result = CGRectInset(result, _outerShadowBlurRadius, _outerShadowBlurRadius);
  result.origin.x -= self.outerShadowOffset.width;
  result.origin.y -= self.outerShadowOffset.height;

  return result;
}

- (CGRect)innerRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection {
  CGRect result = [self outerRect:rect arrowDirection:aArrowDirection];

  result.origin.x += _borderWidth;
  result.origin.y += 0;
  result.size.width -= 2 * _borderWidth;
  result.size.height -= _borderWidth;

  if (_navigationBarHeight == 0 || _wantsDefaultContentAppearance) {
    result.origin.y += _borderWidth;
    result.size.height -= _borderWidth;
  }

  result.origin.x += _viewContentInsets.left;
  result.origin.y += _viewContentInsets.top;
  result.size.width = result.size.width - _viewContentInsets.left - _viewContentInsets.right;
  result.size.height = result.size.height - _viewContentInsets.top - _viewContentInsets.bottom;

  if (_borderWidth > 0) {
    result = CGRectInset(result, -1, -1);
  }

  return result;
}

- (CGRect)arrowRect:(CGRect)rect arrowDirection:(WYPopoverArrowDirection)aArrowDirection {
  CGRect result = CGRectZero;

  if (_arrowHeight > 0) {
    result.size = CGSizeMake(_arrowBase, _arrowHeight);

    if (aArrowDirection == WYPopoverArrowDirectionLeft || _arrowDirection == WYPopoverArrowDirectionRight) {
      result.size = CGSizeMake(_arrowHeight, _arrowBase);
    }

    CGRect outerRect = [self outerRect:rect arrowDirection:aArrowDirection];

    if (aArrowDirection == WYPopoverArrowDirectionDown) {
      result.origin.x = CGRectGetMidX(outerRect) - result.size.width / 2 + _arrowOffset;
      result.origin.y = CGRectGetMaxY(outerRect);
    }

    if (aArrowDirection == WYPopoverArrowDirectionUp) {
      result.origin.x = CGRectGetMidX(outerRect) - result.size.width / 2 + _arrowOffset;
      result.origin.y = CGRectGetMinY(outerRect) - result.size.height;
    }

    if (aArrowDirection == WYPopoverArrowDirectionRight) {
      result.origin.x = CGRectGetMaxX(outerRect);
      result.origin.y = CGRectGetMidY(outerRect) - result.size.height / 2 + _arrowOffset;
    }

    if (aArrowDirection == WYPopoverArrowDirectionLeft) {
      result.origin.x = CGRectGetMinX(outerRect) - result.size.width;
      result.origin.y = CGRectGetMidY(outerRect) - result.size.height / 2 + _arrowOffset;
    }
  }

  return result;
}

#pragma mark Memory Management

- (void)dealloc {
  _contentView      = nil;
  _innerView         = nil;
  _tintColor        = nil;
  _outerStrokeColor = nil;
  _innerStrokeColor = nil;
  _fillTopColor     = nil;
  _fillBottomColor  = nil;
  _glossShadowColor = nil;
  _outerShadowColor = nil;
  _innerShadowColor = nil;
}

@end

////////////////////////////////////////////////////////////////////////////

@interface WYPopoverController () <WYPopoverOverlayViewDelegate, WYPopoverBackgroundViewDelegate> {
  UIViewController        *_viewController;
  CGRect                   _rect;
  UIView                  *_inView;
  WYPopoverOverlayView    *_overlayView;
  WYPopoverBackgroundView *_backgroundView;
  WYPopoverArrowDirection  _permittedArrowDirections;
  BOOL                     _animated;
  BOOL                     _isListeningNotifications;
  BOOL                     _isObserverAdded;
  BOOL                     _isInterfaceOrientationChanging;
  BOOL                     _ignoreOrientation;
  __weak UIBarButtonItem  *_barButtonItem;

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

#pragma mark - WYPopoverController

@implementation WYPopoverController

static WYPopoverTheme *defaultTheme_ = nil;

@synthesize popoverContentSize = popoverContentSize_;

+ (void)setDefaultTheme:(WYPopoverTheme *)aTheme {
  defaultTheme_ = aTheme;

  @autoreleasepool {
    WYPopoverBackgroundView *appearance = [WYPopoverBackgroundView appearance];
    appearance.usesRoundedArrow = aTheme.usesRoundedArrow;
    appearance.dimsBackgroundViewsTintColor = aTheme.dimsBackgroundViewsTintColor;
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
    appearance.preferredAlpha = aTheme.preferredAlpha;
  }
}

+ (WYPopoverTheme *)defaultTheme {
  return defaultTheme_;
}

+ (void)load {
  [WYPopoverController setDefaultTheme:[WYPopoverTheme theme]];
}

- (id)init {
  self = [super init];

  if (self) {
    // ignore orientation in iOS8
    _ignoreOrientation = (compileUsingIOS8SDK() && [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]);
    _popoverLayoutMargins = UIEdgeInsetsMake(10, 10, 10, 10);
    _animationDuration = WY_POPOVER_DEFAULT_ANIMATION_DURATION;

    themeUpdatesEnabled = NO;

    [self setTheme:[WYPopoverController defaultTheme]];

    themeIsUpdating = YES;

    WYPopoverBackgroundView *appearance = [WYPopoverBackgroundView appearance];
    _theme.usesRoundedArrow = appearance.usesRoundedArrow;
    _theme.dimsBackgroundViewsTintColor = appearance.dimsBackgroundViewsTintColor;
    _theme.tintColor = appearance.tintColor;
    _theme.outerStrokeColor = appearance.outerStrokeColor;
    _theme.innerStrokeColor = appearance.innerStrokeColor;
    _theme.fillTopColor = appearance.fillTopColor;
    _theme.fillBottomColor = appearance.fillBottomColor;
    _theme.glossShadowColor = appearance.glossShadowColor;
    _theme.glossShadowOffset = appearance.glossShadowOffset;
    _theme.glossShadowBlurRadius = appearance.glossShadowBlurRadius;
    _theme.borderWidth = appearance.borderWidth;
    _theme.arrowBase = appearance.arrowBase;
    _theme.arrowHeight = appearance.arrowHeight;
    _theme.outerShadowColor = appearance.outerShadowColor;
    _theme.outerShadowBlurRadius = appearance.outerShadowBlurRadius;
    _theme.outerShadowOffset = appearance.outerShadowOffset;
    _theme.outerCornerRadius = appearance.outerCornerRadius;
    _theme.minOuterCornerRadius = appearance.minOuterCornerRadius;
    _theme.innerShadowColor = appearance.innerShadowColor;
    _theme.innerShadowBlurRadius = appearance.innerShadowBlurRadius;
    _theme.innerShadowOffset = appearance.innerShadowOffset;
    _theme.innerCornerRadius = appearance.innerCornerRadius;
    _theme.viewContentInsets = appearance.viewContentInsets;
    _theme.overlayColor = appearance.overlayColor;
    _theme.preferredAlpha = appearance.preferredAlpha;


    themeIsUpdating = NO;
    themeUpdatesEnabled = YES;

    popoverContentSize_ = CGSizeZero;
  }

  return self;
}

- (id)initWithContentViewController:(UIViewController *)aViewController {
  self = [self init];

  if (self) {
    _viewController = aViewController;
  }

  return self;
}

- (void)setTheme:(WYPopoverTheme *)value {
  [self unregisterTheme];
  _theme = value;
  [self registerTheme];
  [self updateThemeUI];

  themeIsUpdating = NO;
}

- (void)registerTheme {
  if (_theme == nil) return;

  NSArray *keypaths = [_theme observableKeypaths];
  for (NSString *keypath in keypaths) {
    [_theme addObserver:self forKeyPath:keypath options:NSKeyValueObservingOptionNew context:NULL];
  }
}

- (void)unregisterTheme {
  if (_theme == nil) return;

  @try {
    NSArray *keypaths = [_theme observableKeypaths];
    for (NSString *keypath in keypaths) {
      [_theme removeObserver:self forKeyPath:keypath];
    }
  }
  @catch (NSException * __unused exception) {}
}

- (void)updateThemeUI {
  if (_theme == nil || themeUpdatesEnabled == NO || themeIsUpdating == YES) return;

  if (_backgroundView != nil) {
    _backgroundView.usesRoundedArrow = _theme.usesRoundedArrow;
    _backgroundView.dimsBackgroundViewsTintColor = _theme.dimsBackgroundViewsTintColor;
    _backgroundView.tintColor = _theme.tintColor;
    _backgroundView.outerStrokeColor = _theme.outerStrokeColor;
    _backgroundView.innerStrokeColor = _theme.innerStrokeColor;
    _backgroundView.fillTopColor = _theme.fillTopColor;
    _backgroundView.fillBottomColor = _theme.fillBottomColor;
    _backgroundView.glossShadowColor = _theme.glossShadowColor;
    _backgroundView.glossShadowOffset = _theme.glossShadowOffset;
    _backgroundView.glossShadowBlurRadius = _theme.glossShadowBlurRadius;
    _backgroundView.borderWidth = _theme.borderWidth;
    _backgroundView.arrowBase = _theme.arrowBase;
    _backgroundView.arrowHeight = _theme.arrowHeight;
    _backgroundView.outerShadowColor = _theme.outerShadowColor;
    _backgroundView.outerShadowBlurRadius = _theme.outerShadowBlurRadius;
    _backgroundView.outerShadowOffset = _theme.outerShadowOffset;
    _backgroundView.outerCornerRadius = _theme.outerCornerRadius;
    _backgroundView.minOuterCornerRadius = _theme.minOuterCornerRadius;
    _backgroundView.innerShadowColor = _theme.innerShadowColor;
    _backgroundView.innerShadowBlurRadius = _theme.innerShadowBlurRadius;
    _backgroundView.innerShadowOffset = _theme.innerShadowOffset;
    _backgroundView.innerCornerRadius = _theme.innerCornerRadius;
    _backgroundView.viewContentInsets = _theme.viewContentInsets;
    _backgroundView.preferredAlpha = _theme.preferredAlpha;
    [_backgroundView setNeedsDisplay];
  }

  if (_overlayView != nil) {
    _overlayView.backgroundColor = _theme.overlayColor;
  }

  [self positionPopover:NO];

  [self setPopoverNavigationBarBackgroundImage];
}

- (void)beginThemeUpdates {
  themeIsUpdating = YES;
}

- (void)endThemeUpdates {
  themeIsUpdating = NO;
  [self updateThemeUI];
}

- (BOOL)isPopoverVisible {
  BOOL result = (_overlayView != nil);
  return result;
}

- (UIViewController *)contentViewController {
  return _viewController;
}

- (CGSize)topViewControllerContentSize {
  CGSize result = CGSizeZero;

  UIViewController *topViewController = _viewController;

  if ([_viewController isKindOfClass:[UINavigationController class]] == YES) {
    UINavigationController *navigationController = (UINavigationController *)_viewController;
    topViewController = [navigationController topViewController];
  }

#ifdef WY_BASE_SDK_7_ENABLED
  if ([topViewController respondsToSelector:@selector(preferredContentSize)]) {
    result = topViewController.preferredContentSize;
  }
#endif

  if (CGSizeEqualToSize(result, CGSizeZero)) {
#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    result = topViewController.contentSizeForViewInPopover;
#pragma clang diagnostic pop
  }

  if (CGSizeEqualToSize(result, CGSizeZero)) {
    CGSize windowSize = [[UIApplication sharedApplication] keyWindow].bounds.size;

    UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

    result = CGSizeMake(UIInterfaceOrientationIsPortrait(orientation) ? windowSize.width : windowSize.height, UIInterfaceOrientationIsLandscape(orientation) ? windowSize.width : windowSize.height);
  }

  return result;
}

- (CGSize)popoverContentSize {
  CGSize result = popoverContentSize_;
  if (CGSizeEqualToSize(result, CGSizeZero)) {
    result = [self topViewControllerContentSize];
  }
  return result;
}

- (void)setPopoverContentSize:(CGSize)size {
  popoverContentSize_ = size;
  [self positionPopover:YES];
}

- (void)setPopoverContentSize:(CGSize)size animated:(BOOL)animated {
  popoverContentSize_ = size;
  [self positionPopover:animated];
}

- (void)performWithoutAnimation:(void (^)(void))aBlock {
  if (aBlock) {
    self.implicitAnimationsDisabled = YES;
    aBlock();
    self.implicitAnimationsDisabled = NO;
  }
}

- (void)presentPopoverFromRect:(CGRect)aRect
                        inView:(UIView *)aView
      permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                      animated:(BOOL)aAnimated {
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
                    completion:(void (^)(void))completion {
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
                       options:(WYPopoverAnimationOptions)aOptions {
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
                    completion:(void (^)(void))completion {
  NSAssert((aArrowDirections != WYPopoverArrowDirectionUnknown), @"WYPopoverArrowDirection must not be UNKNOWN");

  _rect = aRect;
  _inView = aView;
  _permittedArrowDirections = aArrowDirections;
  _animated = aAnimated;
  options = aOptions;

  if (!_inView) {
    _inView = [UIApplication sharedApplication].keyWindow.rootViewController.view;
    if (CGRectIsEmpty(_rect)) {
      _rect = CGRectMake((int)_inView.bounds.size.width / 2 - 5, (int)_inView.bounds.size.height / 2 - 5, 10, 10);
    }
  }

  CGSize contentViewSize = self.popoverContentSize;

  if (_overlayView == nil) {
    _overlayView = [[WYPopoverOverlayView alloc] initWithFrame:_inView.window.bounds];
    _overlayView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    _overlayView.autoresizesSubviews = NO;
    _overlayView.delegate = self;
    _overlayView.passthroughViews = _passthroughViews;

    _backgroundView = [[WYPopoverBackgroundView alloc] initWithContentSize:contentViewSize];
    _backgroundView.appearing = YES;

    _backgroundView.delegate = self;
    _backgroundView.hidden = YES;

    UITapGestureRecognizer *tap = [[UITapGestureRecognizer alloc] initWithTarget:_backgroundView action:@selector(tapOut)];
    tap.cancelsTouchesInView = NO;
    [_overlayView addGestureRecognizer:tap];

    if (self.dismissOnTap) {
      tap = [[UITapGestureRecognizer alloc] initWithTarget:_backgroundView action:@selector(tapOut)];
      tap.cancelsTouchesInView = NO;
      [_backgroundView addGestureRecognizer:tap];
    }

    [_inView.window addSubview:_backgroundView];
    [_inView.window insertSubview:_overlayView belowSubview:_backgroundView];
  }

  [self updateThemeUI];

  __weak __typeof__(self) weakSelf = self;

  void (^completionBlock)(BOOL) = ^(BOOL animated) {

    __typeof__(self) strongSelf = weakSelf;

    if (strongSelf) {
      if (_isObserverAdded == NO) {
        _isObserverAdded = YES;

        if ([strongSelf->_viewController respondsToSelector:@selector(preferredContentSize)]) {
          [strongSelf->_viewController addObserver:self forKeyPath:NSStringFromSelector(@selector(preferredContentSize)) options:0 context:nil];
        } else {
          [strongSelf->_viewController addObserver:self forKeyPath:NSStringFromSelector(@selector(contentSizeForViewInPopover)) options:0 context:nil];
        }
      }
      strongSelf->_backgroundView.appearing = NO;
    }

    if (completion) {
      completion();
    } else if (strongSelf && strongSelf->_delegate && [strongSelf->_delegate respondsToSelector:@selector(popoverControllerDidPresentPopover:)]) {
      [strongSelf->_delegate popoverControllerDidPresentPopover:strongSelf];
    }
  };

  void (^adjustTintDimmed)() = ^() {
#ifdef WY_BASE_SDK_7_ENABLED
    if (_backgroundView.dimsBackgroundViewsTintColor && [_inView.window respondsToSelector:@selector(setTintAdjustmentMode:)]) {
      for (UIView *subview in _inView.window.subviews) {
        if (subview != _backgroundView) {
          [subview setTintAdjustmentMode:UIViewTintAdjustmentModeDimmed];
        }
      }
    }
#endif
  };

  _backgroundView.hidden = NO;

  if (_animated) {
    if ((options & WYPopoverAnimationOptionFade) == WYPopoverAnimationOptionFade) {
      _overlayView.alpha = 0;
      _backgroundView.alpha = 0;
    }

    CGAffineTransform endTransform = _backgroundView.transform;

    if ((options & WYPopoverAnimationOptionScale) == WYPopoverAnimationOptionScale) {
      CGAffineTransform startTransform = [self transformForArrowDirection:_backgroundView.arrowDirection];
      _backgroundView.transform = startTransform;
    }

    [UIView animateWithDuration:_animationDuration animations:^{
      __typeof__(self) strongSelf = weakSelf;

      if (strongSelf) {
        strongSelf->_overlayView.alpha = 1;
        strongSelf->_backgroundView.alpha = strongSelf->_backgroundView.preferredAlpha;
        strongSelf->_backgroundView.transform = endTransform;
      }
      adjustTintDimmed();
    } completion:^(BOOL finished) {
      completionBlock(YES);
    }];
  } else {
    adjustTintDimmed();
    completionBlock(NO);
  }

  if (_isListeningNotifications == NO) {
    _isListeningNotifications = YES;

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
                               animated:(BOOL)aAnimated {
  [self presentPopoverFromBarButtonItem:aItem
               permittedArrowDirections:aArrowDirections
                               animated:aAnimated
                             completion:nil];
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)aItem
               permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                               animated:(BOOL)aAnimated
                             completion:(void (^)(void))completion {
  [self presentPopoverFromBarButtonItem:aItem
               permittedArrowDirections:aArrowDirections
                               animated:aAnimated
                                options:WYPopoverAnimationOptionFade
                             completion:completion];
}

- (void)presentPopoverFromBarButtonItem:(UIBarButtonItem *)aItem
               permittedArrowDirections:(WYPopoverArrowDirection)aArrowDirections
                               animated:(BOOL)aAnimated
                                options:(WYPopoverAnimationOptions)aOptions {
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
                             completion:(void (^)(void))completion {
  _barButtonItem = aItem;
  UIView *itemView = [_barButtonItem valueForKey:@"view"];
  aArrowDirections = WYPopoverArrowDirectionDown | WYPopoverArrowDirectionUp;
  [self presentPopoverFromRect:itemView.bounds
                        inView:itemView
      permittedArrowDirections:aArrowDirections
                      animated:aAnimated
                       options:aOptions
                    completion:completion];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated {
  [self presentPopoverAsDialogAnimated:aAnimated
                            completion:nil];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated
                            completion:(void (^)(void))completion {
  [self presentPopoverAsDialogAnimated:aAnimated
                               options:WYPopoverAnimationOptionFade
                            completion:completion];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated
                               options:(WYPopoverAnimationOptions)aOptions {
  [self presentPopoverAsDialogAnimated:aAnimated
                               options:aOptions
                            completion:nil];
}

- (void)presentPopoverAsDialogAnimated:(BOOL)aAnimated
                               options:(WYPopoverAnimationOptions)aOptions
                            completion:(void (^)(void))completion {
  [self presentPopoverFromRect:CGRectZero
                        inView:nil
      permittedArrowDirections:WYPopoverArrowDirectionNone
                      animated:aAnimated
                       options:aOptions
                    completion:completion];
}

- (CGAffineTransform)transformForArrowDirection:(WYPopoverArrowDirection)arrowDirection {
  CGAffineTransform transform = _backgroundView.transform;

  UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

  CGSize containerViewSize = _backgroundView.frame.size;

  if (_backgroundView.arrowHeight > 0) {
    if (UIInterfaceOrientationIsLandscape(orientation)) {
      containerViewSize.width = _backgroundView.frame.size.height;
      containerViewSize.height = _backgroundView.frame.size.width;
    }

    //WY_LOG(@"containerView.arrowOffset = %f", containerView.arrowOffset);
    //WY_LOG(@"containerViewSize = %@", NSStringFromCGSize(containerViewSize));
    //WY_LOG(@"orientation = %@", WYStringFromOrientation(orientation));

    if (arrowDirection == WYPopoverArrowDirectionDown) {
      transform = CGAffineTransformTranslate(transform, _backgroundView.arrowOffset, containerViewSize.height / 2);
    }

    if (arrowDirection == WYPopoverArrowDirectionUp) {
      transform = CGAffineTransformTranslate(transform, _backgroundView.arrowOffset, -containerViewSize.height / 2);
    }

    if (arrowDirection == WYPopoverArrowDirectionRight) {
      transform = CGAffineTransformTranslate(transform, containerViewSize.width / 2, _backgroundView.arrowOffset);
    }

    if (arrowDirection == WYPopoverArrowDirectionLeft) {
      transform = CGAffineTransformTranslate(transform, -containerViewSize.width / 2, _backgroundView.arrowOffset);
    }
  }

  transform = CGAffineTransformScale(transform, 0.01, 0.01);

  return transform;
}

- (void)setPopoverNavigationBarBackgroundImage {
  if ([_viewController isKindOfClass:[UINavigationController class]] == YES) {
    UINavigationController *navigationController = (UINavigationController *)_viewController;
    navigationController.wy_embedInPopover = YES;

#ifdef WY_BASE_SDK_7_ENABLED
    if ([navigationController respondsToSelector:@selector(setEdgesForExtendedLayout:)]) {
      UIViewController *topViewController = [navigationController topViewController];
      [topViewController setEdgesForExtendedLayout:UIRectEdgeNone];
    }
#endif

    if (_wantsDefaultContentAppearance == NO) {
      [navigationController.navigationBar setBackgroundImage:[UIImage wy_imageWithColor:[UIColor clearColor]] forBarMetrics:UIBarMetricsDefault];
    }
  }

  _viewController.view.clipsToBounds = YES;

  if (_backgroundView.borderWidth == 0) {
    _viewController.view.layer.cornerRadius = _backgroundView.outerCornerRadius;
  }
}

- (void)positionPopover:(BOOL)aAnimated {
  CGRect savedContainerFrame = _backgroundView.frame;
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

  if (_ignoreOrientation) {
    overlayWidth = _overlayView.window.frame.size.width;
    overlayHeight = _overlayView.window.frame.size.height;

    CGRect convertedFrame = [_overlayView.window convertRect:WYKeyboardListener.rect toView:_overlayView];
    keyboardHeight = convertedFrame.size.height;
  } else {
    overlayWidth = UIInterfaceOrientationIsPortrait(orientation) ? _overlayView.bounds.size.width : _overlayView.bounds.size.height;
    overlayHeight = UIInterfaceOrientationIsPortrait(orientation) ? _overlayView.bounds.size.height : _overlayView.bounds.size.width;

    keyboardHeight = UIInterfaceOrientationIsPortrait(orientation) ? WYKeyboardListener.rect.size.height : WYKeyboardListener.rect.size.width;
  }

  if (_delegate && [_delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
    BOOL shouldIgnore = [_delegate popoverControllerShouldIgnoreKeyboardBounds:self];

    if (shouldIgnore) {
      keyboardHeight = 0;
    }
  }

  WYPopoverArrowDirection arrowDirection = _permittedArrowDirections;

  _overlayView.bounds = _inView.window.bounds;
  _backgroundView.transform = CGAffineTransformIdentity;

  viewFrame = [_inView convertRect:_rect toView:nil];

  viewFrame = WYRectInWindowBounds(viewFrame, orientation);

  minX = _popoverLayoutMargins.left;
  maxX = overlayWidth - _popoverLayoutMargins.right;
  minY = WYStatusBarHeight() + _popoverLayoutMargins.top;
  maxY = overlayHeight - _popoverLayoutMargins.bottom - keyboardHeight;

  // Which direction ?
  //
  arrowDirection = [self arrowDirectionForRect:_rect
                                        inView:_inView
                                   contentSize:contentViewSize
                                   arrowHeight:_backgroundView.arrowHeight
                      permittedArrowDirections:arrowDirection];

  // Position of the popover
  //

  minX -= _backgroundView.outerShadowInsets.left;
  maxX += _backgroundView.outerShadowInsets.right;
  minY -= _backgroundView.outerShadowInsets.top;
  maxY += _backgroundView.outerShadowInsets.bottom;

  if (arrowDirection == WYPopoverArrowDirectionDown) {
    _backgroundView.arrowDirection = WYPopoverArrowDirectionDown;
    containerViewSize = [_backgroundView sizeThatFits:contentViewSize];

    containerFrame = CGRectZero;
    containerFrame.size = containerViewSize;
    containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
    containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);

    _backgroundView.frame = CGRectIntegral(containerFrame);

    _backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);

    containerFrame = _backgroundView.frame;

    offset = 0;

    if (containerFrame.origin.x < minX) {
      offset = minX - containerFrame.origin.x;
      containerFrame.origin.x = minX;
      offset = -offset;
    } else if (containerFrame.origin.x + containerFrame.size.width > maxX) {
      offset = (_backgroundView.frame.origin.x + _backgroundView.frame.size.width) - maxX;
      containerFrame.origin.x -= offset;
    }

    _backgroundView.arrowOffset = offset;
    offset = _backgroundView.frame.size.height / 2 + viewFrame.size.height / 2 - _backgroundView.outerShadowInsets.bottom;

    containerFrame.origin.y -= offset;

    if (containerFrame.origin.y < minY) {
      offset = minY - containerFrame.origin.y;
      containerFrame.size.height -= offset;

      if (containerFrame.size.height < minContainerSize.height) {
        // popover is overflowing
        offset -= (minContainerSize.height - containerFrame.size.height);
        containerFrame.size.height = minContainerSize.height;
      }

      containerFrame.origin.y += offset;
    }
  }

  if (arrowDirection == WYPopoverArrowDirectionUp) {
    _backgroundView.arrowDirection = WYPopoverArrowDirectionUp;
    containerViewSize = [_backgroundView sizeThatFits:contentViewSize];

    containerFrame = CGRectZero;
    containerFrame.size = containerViewSize;
    containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
    containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);

    _backgroundView.frame = containerFrame;

    _backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);

    containerFrame = _backgroundView.frame;

    offset = 0;

    if (containerFrame.origin.x < minX) {
      offset = minX - containerFrame.origin.x;
      containerFrame.origin.x = minX;
      offset = -offset;
    }
    else if (containerFrame.origin.x + containerFrame.size.width > maxX) {
      offset = (_backgroundView.frame.origin.x + _backgroundView.frame.size.width) - maxX;
      containerFrame.origin.x -= offset;
    }

    _backgroundView.arrowOffset = offset;
    offset = _backgroundView.frame.size.height / 2 + viewFrame.size.height / 2 - _backgroundView.outerShadowInsets.top;

    containerFrame.origin.y += offset;

    if (containerFrame.origin.y + containerFrame.size.height > maxY) {
      offset = (containerFrame.origin.y + containerFrame.size.height) - maxY;
      containerFrame.size.height -= offset;

      if (containerFrame.size.height < minContainerSize.height) {
        // popover is overflowing
        containerFrame.size.height = minContainerSize.height;
      }
    }
  }

  if (arrowDirection == WYPopoverArrowDirectionRight) {
    _backgroundView.arrowDirection = WYPopoverArrowDirectionRight;
    containerViewSize = [_backgroundView sizeThatFits:contentViewSize];

    containerFrame = CGRectZero;
    containerFrame.size = containerViewSize;
    containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
    containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);

    _backgroundView.frame = CGRectIntegral(containerFrame);

    _backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);

    containerFrame = _backgroundView.frame;

    offset = _backgroundView.frame.size.width / 2 + viewFrame.size.width / 2 - _backgroundView.outerShadowInsets.right;

    containerFrame.origin.x -= offset;

    if (containerFrame.origin.x < minX) {
      offset = minX - containerFrame.origin.x;
      containerFrame.size.width -= offset;

      if (containerFrame.size.width < minContainerSize.width) {
        // popover is overflowing
        offset -= (minContainerSize.width - containerFrame.size.width);
        containerFrame.size.width = minContainerSize.width;
      }

      containerFrame.origin.x += offset;
    }

    offset = 0;

    if (containerFrame.origin.y < minY) {
      offset = minY - containerFrame.origin.y;
      containerFrame.origin.y = minY;
      offset = -offset;
    } else if (containerFrame.origin.y + containerFrame.size.height > maxY) {
      offset = (_backgroundView.frame.origin.y + _backgroundView.frame.size.height) - maxY;
      containerFrame.origin.y -= offset;
    }

    _backgroundView.arrowOffset = offset;
  }

  if (arrowDirection == WYPopoverArrowDirectionLeft) {
    _backgroundView.arrowDirection = WYPopoverArrowDirectionLeft;
    containerViewSize = [_backgroundView sizeThatFits:contentViewSize];

    containerFrame = CGRectZero;
    containerFrame.size = containerViewSize;
    containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
    containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);
    _backgroundView.frame = containerFrame;

    _backgroundView.center = CGPointMake(viewFrame.origin.x + viewFrame.size.width / 2, viewFrame.origin.y + viewFrame.size.height / 2);

    containerFrame = CGRectIntegral(_backgroundView.frame);

    offset = _backgroundView.frame.size.width / 2 + viewFrame.size.width / 2 - _backgroundView.outerShadowInsets.left;

    containerFrame.origin.x += offset;

    if (containerFrame.origin.x + containerFrame.size.width > maxX) {
      offset = (containerFrame.origin.x + containerFrame.size.width) - maxX;
      containerFrame.size.width -= offset;

      if (containerFrame.size.width < minContainerSize.width) {
        // popover is overflowing
        containerFrame.size.width = minContainerSize.width;
      }
    }

    offset = 0;

    if (containerFrame.origin.y < minY) {
      offset = minY - containerFrame.origin.y;
      containerFrame.origin.y = minY;
      offset = -offset;
    } else if (containerFrame.origin.y + containerFrame.size.height > maxY) {
      offset = (_backgroundView.frame.origin.y + _backgroundView.frame.size.height) - maxY;
      containerFrame.origin.y -= offset;
    }

    _backgroundView.arrowOffset = offset;
  }

  if (arrowDirection == WYPopoverArrowDirectionNone) {
    _backgroundView.arrowDirection = WYPopoverArrowDirectionNone;
    containerViewSize = [_backgroundView sizeThatFits:contentViewSize];

    containerFrame = CGRectZero;
    containerFrame.size = containerViewSize;
    containerFrame.size.width = MIN(maxX - minX, containerFrame.size.width);
    containerFrame.size.height = MIN(maxY - minY, containerFrame.size.height);
    _backgroundView.frame = CGRectIntegral(containerFrame);

    _backgroundView.center = CGPointMake(minX + (maxX - minX) / 2, minY + (maxY - minY) / 2);

    containerFrame = _backgroundView.frame;

    _backgroundView.arrowOffset = offset;
  }

  containerFrame = CGRectIntegral(containerFrame);

  _backgroundView.frame = containerFrame;

  _backgroundView.wantsDefaultContentAppearance = _wantsDefaultContentAppearance;

  [_backgroundView setViewController:_viewController];

  // keyboard support
  if (keyboardHeight > 0) {

    float keyboardY = UIInterfaceOrientationIsPortrait(orientation) ? WYKeyboardListener.rect.origin.y : WYKeyboardListener.rect.origin.x;

    float yOffset = containerFrame.origin.y + containerFrame.size.height - keyboardY;

    if (yOffset > 0) {

      if (containerFrame.origin.y - yOffset < minY) {
        yOffset -= minY - (containerFrame.origin.y - yOffset);
      }

      if ([_delegate respondsToSelector:@selector(popoverController:willTranslatePopoverWithYOffset:)]) {
        [_delegate popoverController:self willTranslatePopoverWithYOffset:&yOffset];
      }

      containerFrame.origin.y -= yOffset;
    }
  }

  CGPoint containerOrigin = containerFrame.origin;

  _backgroundView.transform = CGAffineTransformMakeRotation(WYInterfaceOrientationAngleOfOrientation(orientation));

  containerFrame = _backgroundView.frame;

  containerFrame.origin = WYPointRelativeToOrientation(containerOrigin, containerFrame.size, orientation);

  if (aAnimated == YES && !self.implicitAnimationsDisabled) {
    _backgroundView.frame = savedContainerFrame;
    __weak __typeof__(self) weakSelf = self;
    [UIView animateWithDuration:0.10f animations:^{
      __typeof__(self) strongSelf = weakSelf;
      strongSelf->_backgroundView.frame = containerFrame;
    }];
  } else {
    _backgroundView.frame = containerFrame;
  }

  [_backgroundView setNeedsDisplay];

//  WY_LOG(@"popoverContainerView.frame = %@", NSStringFromCGRect(_backgroundView.frame));
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated {
  [self dismissPopoverAnimated:aAnimated
                       options:options
                    completion:nil];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                    completion:(void (^)(void))completion {
  [self dismissPopoverAnimated:aAnimated
                       options:options
                    completion:completion];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions {
  [self dismissPopoverAnimated:aAnimated
                       options:aOptions
                    completion:nil];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions
                    completion:(void (^)(void))completion {
  [self dismissPopoverAnimated:aAnimated
                       options:aOptions
                    completion:completion
                  callDelegate:NO];
}

- (void)dismissPopoverAnimated:(BOOL)aAnimated
                       options:(WYPopoverAnimationOptions)aOptions
                    completion:(void (^)(void))completion
                  callDelegate:(BOOL)callDelegate {
  float duration = self.animationDuration;
  WYPopoverAnimationOptions style = aOptions;

  __weak __typeof__(self) weakSelf = self;


  void (^adjustTintAutomatic)() = ^() {
#ifdef WY_BASE_SDK_7_ENABLED
    if ([_inView.window respondsToSelector:@selector(setTintAdjustmentMode:)]) {
      for (UIView *subview in _inView.window.subviews) {
        if (subview != _backgroundView) {
          [subview setTintAdjustmentMode:UIViewTintAdjustmentModeAutomatic];
        }
      }
    }
#endif
  };

  void (^completionBlock)() = ^() {
    __typeof__(self) strongSelf = weakSelf;

    if (strongSelf) {
      [strongSelf->_backgroundView removeFromSuperview];

      strongSelf->_backgroundView = nil;

      [strongSelf->_overlayView removeFromSuperview];
      strongSelf->_overlayView = nil;

      // inView is captured strongly in presentPopoverInRect:... method, so it needs to be released in dismiss method to avoid potential retain cycles
      strongSelf->_inView = nil;
    }

    if (completion) {
      completion();
    }
    else if (callDelegate && strongSelf && strongSelf->_delegate && [strongSelf->_delegate respondsToSelector:@selector(popoverControllerDidDismissPopover:)]) {
      [strongSelf->_delegate popoverControllerDidDismissPopover:strongSelf];
    }

    if (self.dismissCompletionBlock) {
      self.dismissCompletionBlock(strongSelf);
    }
  };

  if (_isListeningNotifications == YES) {
    _isListeningNotifications = NO;

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

  @try {
    if (_isObserverAdded == YES) {
      _isObserverAdded = NO;

      if ([_viewController respondsToSelector:@selector(preferredContentSize)]) {
        [_viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(preferredContentSize))];
      } else {
        [_viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(contentSizeForViewInPopover))];
      }
    }
  }
  @catch (NSException * __unused exception) {}

  if (aAnimated && !self.implicitAnimationsDisabled) {
    [UIView animateWithDuration:duration animations:^{
      __typeof__(self) strongSelf = weakSelf;
      if (strongSelf) {
        if ((style & WYPopoverAnimationOptionFade) == WYPopoverAnimationOptionFade) {
          strongSelf->_backgroundView.alpha = 0;
        }

        if ((style & WYPopoverAnimationOptionScale) == WYPopoverAnimationOptionScale) {
          CGAffineTransform endTransform = [self transformForArrowDirection:strongSelf->_backgroundView.arrowDirection];
          strongSelf->_backgroundView.transform = endTransform;
        }
        strongSelf->_overlayView.alpha = 0;
      }
      adjustTintAutomatic();
    } completion:^(BOOL finished) {
      completionBlock();
    }];
  } else {
    adjustTintAutomatic();
    completionBlock();
  }
}

#pragma mark KVO

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
  if (object == _viewController) {
    if ([keyPath isEqualToString:NSStringFromSelector(@selector(preferredContentSize))]
        || [keyPath isEqualToString:NSStringFromSelector(@selector(contentSizeForViewInPopover))]) {
      CGSize contentSize = [self topViewControllerContentSize];
      [self setPopoverContentSize:contentSize];
    }
  } else if (object == _theme) {
    [self updateThemeUI];
  }
}

#pragma mark WYPopoverOverlayViewDelegate

- (void)popoverOverlayViewDidTouch:(WYPopoverOverlayView *)aOverlayView {
  BOOL shouldDismiss = !_viewController.modalInPopover;

  if (shouldDismiss && _delegate && [_delegate respondsToSelector:@selector(popoverControllerShouldDismissPopover:)]) {
    shouldDismiss = [_delegate popoverControllerShouldDismissPopover:self];
  }

  if (shouldDismiss) {
    [self dismissPopoverAnimated:_animated options:options completion:nil callDelegate:YES];
  }
}

#pragma mark WYPopoverBackgroundViewDelegate

- (void)popoverBackgroundViewDidTouchOutside:(WYPopoverBackgroundView *)aBackgroundView {
  [self popoverOverlayViewDidTouch:nil];
}

#pragma mark Private
- (WYPopoverArrowDirection)arrowDirectionForRect:(CGRect)aRect
                                          inView:(UIView *)aView
                                     contentSize:(CGSize)contentSize
                                     arrowHeight:(float)arrowHeight
                        permittedArrowDirections:(WYPopoverArrowDirection)arrowDirections {
  WYPopoverArrowDirection arrowDirection = WYPopoverArrowDirectionUnknown;

  NSMutableArray *areas = [NSMutableArray arrayWithCapacity:0];
  WYPopoverArea *area;

  if ((arrowDirections & WYPopoverArrowDirectionDown) == WYPopoverArrowDirectionDown) {
    area = [[WYPopoverArea alloc] init];
    area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionDown];
    area.arrowDirection = WYPopoverArrowDirectionDown;
    [areas addObject:area];
  }

  if ((arrowDirections & WYPopoverArrowDirectionUp) == WYPopoverArrowDirectionUp) {
    area = [[WYPopoverArea alloc] init];
    area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionUp];
    area.arrowDirection = WYPopoverArrowDirectionUp;
    [areas addObject:area];
  }

  if ((arrowDirections & WYPopoverArrowDirectionLeft) == WYPopoverArrowDirectionLeft) {
    area = [[WYPopoverArea alloc] init];
    area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionLeft];
    area.arrowDirection = WYPopoverArrowDirectionLeft;
    [areas addObject:area];
  }

  if ((arrowDirections & WYPopoverArrowDirectionRight) == WYPopoverArrowDirectionRight) {
    area = [[WYPopoverArea alloc] init];
    area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionRight];
    area.arrowDirection = WYPopoverArrowDirectionRight;
    [areas addObject:area];
  }

  if ((arrowDirections & WYPopoverArrowDirectionNone) == WYPopoverArrowDirectionNone) {
    area = [[WYPopoverArea alloc] init];
    area.areaSize = [self sizeForRect:aRect inView:aView arrowHeight:arrowHeight arrowDirection:WYPopoverArrowDirectionNone];
    area.arrowDirection = WYPopoverArrowDirectionNone;
    [areas addObject:area];
  }

  if ([areas count] > 1) {
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

    if (val1 > val2) {
      result = NSOrderedAscending;
    } else if (val1 < val2) {
      result = NSOrderedDescending;
    }

    return result;
  }];

  for (NSUInteger i = 0; i < [areas count]; i++) {
    WYPopoverArea *popoverArea = (WYPopoverArea *)[areas objectAtIndex:i];

    if (popoverArea.areaSize.width >= contentSize.width) {
      arrowDirection = popoverArea.arrowDirection;
      break;
    }
  }

  if (arrowDirection == WYPopoverArrowDirectionUnknown) {
    if ([areas count] > 0) {
      arrowDirection = ((WYPopoverArea *)[areas objectAtIndex:0]).arrowDirection;
    } else {
      if ((arrowDirections & WYPopoverArrowDirectionDown) == WYPopoverArrowDirectionDown) {
        arrowDirection = WYPopoverArrowDirectionDown;
      } else if ((arrowDirections & WYPopoverArrowDirectionUp) == WYPopoverArrowDirectionUp) {
        arrowDirection = WYPopoverArrowDirectionUp;
      } else if ((arrowDirections & WYPopoverArrowDirectionLeft) == WYPopoverArrowDirectionLeft) {
        arrowDirection = WYPopoverArrowDirectionLeft;
      } else {
        arrowDirection = WYPopoverArrowDirectionRight;
      }
    }
  }

  return arrowDirection;
}

- (CGSize)sizeForRect:(CGRect)aRect
               inView:(UIView *)aView
          arrowHeight:(float)arrowHeight
       arrowDirection:(WYPopoverArrowDirection)arrowDirection {
  UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];

  CGRect viewFrame = [aView convertRect:aRect toView:nil];
  viewFrame = WYRectInWindowBounds(viewFrame, orientation);

  float minX, maxX, minY, maxY = 0;

  float keyboardHeight = WYKeyboardListener.rect.size.height;
  float overlayWidth = _overlayView.bounds.size.width;
  float overlayHeight = _overlayView.bounds.size.height;
  
  if (!_ignoreOrientation && UIInterfaceOrientationIsLandscape(orientation)) {
    keyboardHeight = WYKeyboardListener.rect.size.width;
    overlayWidth = _overlayView.bounds.size.height;
    overlayHeight = _overlayView.bounds.size.width;
  }

  if (_delegate && [_delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
    BOOL shouldIgnore = [_delegate popoverControllerShouldIgnoreKeyboardBounds:self];

    if (shouldIgnore) {
      keyboardHeight = 0;
    }
  }

  minX = _popoverLayoutMargins.left;
  maxX = overlayWidth - _popoverLayoutMargins.right;
  minY = WYStatusBarHeight() + _popoverLayoutMargins.top;
  maxY = overlayHeight - _popoverLayoutMargins.bottom - keyboardHeight;

  CGSize result = CGSizeZero;

  if (arrowDirection == WYPopoverArrowDirectionLeft) {
    result.width = maxX - (viewFrame.origin.x + viewFrame.size.width);
    result.width -= arrowHeight;
    result.height = maxY - minY;
  } else if (arrowDirection == WYPopoverArrowDirectionRight) {
    result.width = viewFrame.origin.x - minX;
    result.width -= arrowHeight;
    result.height = maxY - minY;
  } else if (arrowDirection == WYPopoverArrowDirectionDown) {
    result.width = maxX - minX;
    result.height = viewFrame.origin.y - minY;
    result.height -= arrowHeight;
  } else if (arrowDirection == WYPopoverArrowDirectionUp) {
    result.width = maxX - minX;
    result.height = maxY - (viewFrame.origin.y + viewFrame.size.height);
    result.height -= arrowHeight;
  } else if (arrowDirection == WYPopoverArrowDirectionNone) {
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
    CGRect statusBarFrame = [[UIApplication sharedApplication] statusBarFrame];
    statusBarHeight = statusBarFrame.size.height;

    if (UIInterfaceOrientationIsLandscape(orientation))
    {
      statusBarHeight = statusBarFrame.size.width;
    }

    return statusBarHeight;
  }
}

static float WYInterfaceOrientationAngleOfOrientation(UIInterfaceOrientation orientation) {
  float angle;
  // no transformation needed in iOS 8
  if (compileUsingIOS8SDK() && [[NSProcessInfo processInfo] respondsToSelector:@selector(operatingSystemVersion)]) {
    angle = 0.0;
  } else {
    switch (orientation) {
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

- (void)didChangeStatusBarOrientation:(NSNotification *)notification {
  _isInterfaceOrientationChanging = YES;
}

- (void)didChangeDeviceOrientation:(NSNotification *)notification {
  if (_isInterfaceOrientationChanging == NO) return;

  _isInterfaceOrientationChanging = NO;

  if ([_viewController isKindOfClass:[UINavigationController class]]) {
    UINavigationController* navigationController = (UINavigationController*)_viewController;

    if (navigationController.navigationBarHidden == NO) {
      navigationController.navigationBarHidden = YES;
      navigationController.navigationBarHidden = NO;
    }
  }

  if (_barButtonItem) {
    _inView = [_barButtonItem valueForKey:@"view"];
    _rect = _inView.bounds;
  } else if ([_delegate respondsToSelector:@selector(popoverController:willRepositionPopoverToRect:inView:)]) {
    CGRect anotherRect;
    UIView *anotherInView;

    [_delegate popoverController:self willRepositionPopoverToRect:&anotherRect inView:&anotherInView];

#pragma clang diagnostic push
#pragma GCC diagnostic ignored "-Wtautological-pointer-compare"
    if (&anotherRect != NULL) {
      _rect = anotherRect;
    }

    if (&anotherInView != NULL) {
      _inView = anotherInView;
    }
#pragma GCC diagnostic pop
  }

  [self positionPopover:NO];
}

- (void)keyboardWillShow:(NSNotification *)notification {
  //UIInterfaceOrientation orientation = [[UIApplication sharedApplication] statusBarOrientation];
  //WY_LOG(@"orientation = %@", WYStringFromOrientation(orientation));
  //WY_LOG(@"WYKeyboardListener.rect = %@", NSStringFromCGRect(WYKeyboardListener.rect));

  BOOL shouldIgnore = NO;

  if (_delegate && [_delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
    shouldIgnore = [_delegate popoverControllerShouldIgnoreKeyboardBounds:self];
  }

  if (shouldIgnore == NO) {
    [self positionPopover:YES];
  }
}

- (void)keyboardWillHide:(NSNotification *)notification {
  BOOL shouldIgnore = NO;

  if (_delegate && [_delegate respondsToSelector:@selector(popoverControllerShouldIgnoreKeyboardBounds:)]) {
    shouldIgnore = [_delegate popoverControllerShouldIgnoreKeyboardBounds:self];
  }

  if (shouldIgnore == NO) {
    [self positionPopover:YES];
  }
}

#pragma mark Memory management

- (void)dealloc {
  [[NSNotificationCenter defaultCenter] removeObserver:self];

  [_backgroundView removeFromSuperview];
  [_backgroundView setDelegate:nil];

  [_overlayView removeFromSuperview];
  [_overlayView setDelegate:nil];
  @try {
    if (_isObserverAdded == YES) {
      _isObserverAdded = NO;

      if ([_viewController respondsToSelector:@selector(preferredContentSize)]) {
        [_viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(preferredContentSize))];
      } else {
        [_viewController removeObserver:self forKeyPath:NSStringFromSelector(@selector(contentSizeForViewInPopover))];
      }
    }
  }
  @catch (NSException *exception) {
  }
  @finally {
    _viewController = nil;
  }

  [self unregisterTheme];

  _barButtonItem = nil;
  _passthroughViews = nil;
  _inView = nil;
  _overlayView = nil;
  _backgroundView = nil;

  _theme = nil;
}

@end
