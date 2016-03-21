//
//  ThemeManager.h
//  NewsBlur
//
//  Created by David Sinclair on 2015-12-06.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import <Foundation/Foundation.h>

#define UIColorFromFixedRGB(rgbValue) [[ThemeManager themeManager] fixedColorFromRGB:rgbValue]
#define UIColorFromLightDarkRGB(lightRGBValue, darkRGBValue) [[ThemeManager themeManager] colorFromLightRGB:lightRGBValue darkRGB:darkRGBValue]
#define UIColorFromLightSepiaMediumDarkRGB(lightRGBValue, sepiaRGBValue, mediumRGBValue, darkRGBValue) [[ThemeManager themeManager] colorFromLightRGB:lightRGBValue sepiaRGB:sepiaRGBValue mediumRGB:mediumRGBValue darkRGB:darkRGBValue]
#define UIColorFromRGB(rgbValue) [[ThemeManager themeManager] themedColorFromRGB:rgbValue]

#define NEWSBLUR_LINK_COLOR 0x405BA8
#define NEWSBLUR_HIGHLIGHT_COLOR 0xd2e6fd
#define NEWSBLUR_WHITE_COLOR 0xffffff
#define NEWSBLUR_BLACK_COLOR 0x0

extern NSString * const ThemeStyleLight;
extern NSString * const ThemeStyleSepia;
extern NSString * const ThemeStyleMedium;
extern NSString * const ThemeStyleDark;

@interface ThemeManager : NSObject

@property (nonatomic, strong) NSString *theme;
@property (nonatomic, readonly) NSString *themeDisplayName;
@property (nonatomic, readonly) NSString *themeCSSSuffix;
@property (nonatomic, readonly) BOOL isDarkTheme;

+ (instancetype)themeManager;

- (NSString *)similarTheme;
- (BOOL)isValidTheme:(NSString *)theme;

- (UIColor *)fixedColorFromRGB:(NSInteger)rgbValue;
- (UIColor *)colorFromLightRGB:(NSInteger)lightRGBValue darkRGB:(NSUInteger)darkRGBValue;
- (UIColor *)colorFromLightRGB:(NSInteger)lightRGBValue sepiaRGB:(NSUInteger)sepiaRGBValue mediumRGB:(NSUInteger)mediumRGBValue darkRGB:(NSUInteger)darkRGBValue;
- (UIColor *)themedColorFromRGB:(NSInteger)rgbValue;

- (UIImage *)themedImage:(UIImage *)image;

- (void)prepareForWindow:(UIWindow *)window;
- (void)updateTheme;
- (void)updatePreferencesTheme;
- (BOOL)autoChangeTheme;
- (UIGestureRecognizer *)addThemeGestureRecognizerToView:(UIView *)view;

@end

