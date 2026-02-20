//
//  ThemeManager.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-12-06.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "ThemeManager.h"
#import "NewsBlurAppDelegate.h"
#import "ActivitiesViewController.h"
#import "OriginalStoryViewController.h"
#import <AudioToolbox/AudioToolbox.h>
#import "NewsBlur-Swift.h"

NSString * const ThemeStyleAuto = @"auto";
NSString * const ThemeStyleLight = @"light";
NSString * const ThemeStyleSepia = @"sepia";
NSString * const ThemeStyleMedium = @"medium";
NSString * const ThemeStyleDark = @"dark";

@interface UINavigationController (Theme)

@end

@implementation UINavigationController (Theme)

- (UIStatusBarStyle)preferredStatusBarStyle {
    if ([ThemeManager themeManager].isDarkTheme) {
        return UIStatusBarStyleLightContent;
    } else {
        return UIStatusBarStyleDarkContent;
    }
}

- (UIViewController *)childViewControllerForStatusBarStyle {
    return nil;
}

@end

@interface ThemeManager ()

@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) BOOL justToggledViaGesture;
@property (nonatomic) BOOL isAutoDark;

@end

@implementation ThemeManager

+ (instancetype)shared {
    return [self themeManager];
}

+ (instancetype)themeManager {
    static id themeManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
                      themeManager = [self new];
                  });
    
    return themeManager;
}

- (NSString *)theme {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *themeStyle = [prefs objectForKey:@"theme_style"];

    // Handle the new theme_style values: auto, light, dark
    // These represent the mode, and we look up the actual theme variant
    if ([themeStyle isEqualToString:@"light"]) {
        // User chose light mode - use their light theme variant
        NSString *lightVariant = [prefs objectForKey:@"theme_light"];
        if ([lightVariant isEqualToString:ThemeStyleSepia]) {
            return ThemeStyleSepia;
        }
        return ThemeStyleLight;
    } else if ([themeStyle isEqualToString:@"dark"]) {
        // User chose dark mode - use their dark theme variant
        NSString *darkVariant = [prefs objectForKey:@"theme_dark"];
        if ([darkVariant isEqualToString:ThemeStyleMedium]) {
            return ThemeStyleMedium;
        }
        return ThemeStyleDark;
    } else if ([themeStyle isEqualToString:ThemeStyleAuto] || themeStyle == nil) {
        // Auto mode - return "auto" and let other methods handle system appearance
        return ThemeStyleAuto;
    }

    // Legacy support: if theme_style contains an actual theme value, use it directly
    if ([self isValidTheme:themeStyle]) {
        return themeStyle;
    }

    return ThemeStyleAuto;
}

- (void)setTheme:(NSString *)theme {
    [self reallySetTheme:theme];

    NSLog(@"Manually changed to theme: %@", self.themeDisplayName);  // log
}

- (void)reallySetTheme:(NSString *)theme {
    if (![self isValidTheme:theme]) {
        return;
    }

    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    // Handle setting theme based on the actual theme value
    // This supports both the old direct-theme API and sets up the new system correctly
    if ([theme isEqualToString:ThemeStyleAuto]) {
        [prefs setObject:@"auto" forKey:@"theme_style"];
    } else if ([theme isEqualToString:ThemeStyleLight]) {
        [prefs setObject:@"light" forKey:@"theme_style"];
        [prefs setObject:ThemeStyleLight forKey:@"theme_light"];
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        [prefs setObject:@"light" forKey:@"theme_style"];
        [prefs setObject:ThemeStyleSepia forKey:@"theme_light"];
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        [prefs setObject:@"dark" forKey:@"theme_style"];
        [prefs setObject:ThemeStyleMedium forKey:@"theme_dark"];
    } else if ([theme isEqualToString:ThemeStyleDark]) {
        [prefs setObject:@"dark" forKey:@"theme_style"];
        [prefs setObject:ThemeStyleDark forKey:@"theme_dark"];
    }

    [prefs synchronize];
    [self updateTheme];
}

- (NSString *)themeDisplayName {
    NSString *theme = self.theme;

    if ([theme isEqualToString:ThemeStyleDark]) {
        return @"Black";
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        return @"Warm";
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        return @"Gray";
    } else if ([theme isEqualToString:ThemeStyleLight]) {
        return @"Light";
    } else {
        return @"Auto";
    }
}

- (NSString *)themeCSSSuffix {
    NSString *theme = self.theme;

    if ([theme isEqualToString:ThemeStyleDark]) {
        return @"Dark";
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        return @"Medium";
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        return @"Sepia";
    } else if ([theme isEqualToString:ThemeStyleLight]) {
        return @"Light";
    } else if ([theme isEqualToString:ThemeStyleAuto]) {
        // Auto mode: use system appearance to determine which variant to use
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        if (self.isSystemDark) {
            NSString *darkVariant = [prefs objectForKey:@"theme_dark"];
            if ([darkVariant isEqualToString:ThemeStyleMedium]) {
                return @"Medium";
            }
            return @"Dark";
        } else {
            NSString *lightVariant = [prefs objectForKey:@"theme_light"];
            if ([lightVariant isEqualToString:ThemeStyleSepia]) {
                return @"Sepia";
            }
            return @"Light";
        }
    } else {
        return @"Light";
    }
}

- (NSString *)similarTheme {
    NSString *theme = self.theme;
    
    if ([theme isEqualToString:ThemeStyleDark]) {
        return ThemeStyleMedium;
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        return ThemeStyleDark;
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        return ThemeStyleLight;
    } else if ([theme isEqualToString:ThemeStyleLight]) {
        return ThemeStyleSepia;
    } else {
        return ThemeStyleAuto;
    }
}

- (BOOL)isAutoTheme {
    NSString *themeStyle = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme_style"];
    return [themeStyle isEqualToString:ThemeStyleAuto] || themeStyle == nil;
}

- (BOOL)isDarkTheme {
    NSString *theme = self.theme;

    if ([theme isEqualToString:ThemeStyleAuto]) {
        return self.isSystemDark;
    }

    return [theme isEqualToString:ThemeStyleDark] || [theme isEqualToString:ThemeStyleMedium];
}

- (BOOL)isSystemDark {
    return self.appDelegate.window.windowScene.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark;
}

- (BOOL)isLikeSystem {
    return self.isDarkTheme == self.isSystemDark;
}

- (NSString *)effectiveTheme {
    // Returns the actual visual theme being displayed, resolving "auto" to the appropriate variant
    NSString *theme = self.theme;

    if ([theme isEqualToString:ThemeStyleAuto]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        if (self.isSystemDark) {
            NSString *darkVariant = [prefs objectForKey:@"theme_dark"];
            return ([darkVariant isEqualToString:ThemeStyleMedium]) ? ThemeStyleMedium : ThemeStyleDark;
        } else {
            NSString *lightVariant = [prefs objectForKey:@"theme_light"];
            return ([lightVariant isEqualToString:ThemeStyleSepia]) ? ThemeStyleSepia : ThemeStyleLight;
        }
    }

    return theme;
}

- (BOOL)isValidTheme:(NSString *)theme {
    return [theme isEqualToString:ThemeStyleAuto] || [theme isEqualToString:ThemeStyleLight] || [theme isEqualToString:ThemeStyleSepia] || [theme isEqualToString:ThemeStyleMedium] || [theme isEqualToString:ThemeStyleDark];
}

- (NewsBlurAppDelegate *)appDelegate {
    return (NewsBlurAppDelegate *)[UIApplication sharedApplication].delegate;
}

- (UIColor *)fixedColorFromRGB:(NSInteger)rgbValue {
    CGFloat red = ((rgbValue & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((rgbValue & 0xFF00) >> 8) / 255.0;
    CGFloat blue = ((rgbValue & 0xFF)) / 255.0;
    
    return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
}

- (UIColor *)colorFromLightRGB:(NSInteger)lightRGBValue darkRGB:(NSUInteger)darkRGBValue {
    NSInteger rgbValue = lightRGBValue;
    
    if (self.isDarkTheme) {
        rgbValue = darkRGBValue;
    }
    
    return [self fixedColorFromRGB:rgbValue];
}

- (UIColor *)colorFromLightRGB:(NSInteger)lightRGBValue sepiaRGB:(NSUInteger)sepiaRGBValue mediumRGB:(NSUInteger)mediumRGBValue darkRGB:(NSUInteger)darkRGBValue {
    NSInteger rgbValue = lightRGBValue;
    NSString *theme = self.theme;

    if ([theme isEqualToString:ThemeStyleAuto]) {
        // Auto mode: use system appearance and respect user's variant preferences
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        if (self.isSystemDark) {
            NSString *darkVariant = [prefs objectForKey:@"theme_dark"];
            if ([darkVariant isEqualToString:ThemeStyleMedium]) {
                rgbValue = mediumRGBValue;
            } else {
                rgbValue = darkRGBValue;
            }
        } else {
            NSString *lightVariant = [prefs objectForKey:@"theme_light"];
            if ([lightVariant isEqualToString:ThemeStyleSepia]) {
                rgbValue = sepiaRGBValue;
            } else {
                rgbValue = lightRGBValue;
            }
        }
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        rgbValue = sepiaRGBValue;
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        rgbValue = mediumRGBValue;
    } else if ([theme isEqualToString:ThemeStyleDark]) {
        rgbValue = darkRGBValue;
    }

    return [self fixedColorFromRGB:rgbValue];
}

- (UIColor *)themedColorFromRGB:(NSInteger)rgbValue {
    NSString *theme = self.theme;
    CGFloat red = ((rgbValue & 0xFF0000) >> 16) / 255.0;
    CGFloat green = ((rgbValue & 0xFF00) >> 8) / 255.0;
    CGFloat blue = ((rgbValue & 0xFF)) / 255.0;

    // Debug method to log all of the unique colors; leave commented out
//        [self debugColor:rgbValue];

    // For auto mode, determine which variant to use based on system appearance and user preferences
    NSString *effectiveTheme = theme;
    if ([theme isEqualToString:ThemeStyleAuto]) {
        NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
        if (self.isSystemDark) {
            effectiveTheme = [prefs objectForKey:@"theme_dark"] ?: ThemeStyleDark;
        } else {
            effectiveTheme = [prefs objectForKey:@"theme_light"] ?: ThemeStyleLight;
        }
    }

    if ([effectiveTheme isEqualToString:ThemeStyleDark]) {
        return [UIColor colorWithRed:1.0 - red green:1.0 - green blue:1.0 - blue alpha:1.0];
    } else if ([effectiveTheme isEqualToString:ThemeStyleMedium]) {
        if (rgbValue == 0x8F918B) {
            return [UIColor colorWithWhite:0.7 alpha:1.0];
        } else if (rgbValue == NEWSBLUR_LINK_COLOR) {
            return [UIColor colorWithRed:1.0 - red green:1.0 - green blue:1.0 - blue alpha:1.0];
        } else if (rgbValue == 0x999999) {
            return [UIColor colorWithWhite:0.6 alpha:1.0];
        } else if (red < 0.5 && green < 0.5 && blue < 0.5) {
            return [UIColor colorWithRed:1.2 - red green:1.2 - green blue:1.2 - blue alpha:1.0];
        } else {
            return [UIColor colorWithRed:red - 0.7 green:green - 0.7 blue:blue - 0.7 alpha:1.0];
        }
    } else if ([effectiveTheme isEqualToString:ThemeStyleSepia]) {
        // Special cases for common colors to ensure warm sepia tones
        if (rgbValue == 0xFFFFFF || rgbValue == 0xffffff) {
            // White -> warm cream (0xFAF5ED)
            return [UIColor colorWithRed:0xFA/255.0 green:0xF5/255.0 blue:0xED/255.0 alpha:1.0];
        } else if (rgbValue == 0xECEEEA) {
            // Light gray-green -> warm sepia (0xF3E2CB)
            return [UIColor colorWithRed:0xF3/255.0 green:0xE2/255.0 blue:0xCB/255.0 alpha:1.0];
        } else if (rgbValue == 0xf4f4f4 || rgbValue == 0xF4F4F4) {
            // Light gray -> warm light sepia (0xF3E2CB)
            return [UIColor colorWithRed:0xF3/255.0 green:0xE2/255.0 blue:0xCB/255.0 alpha:1.0];
        } else if (rgbValue == 0xE9E8E4) {
            // Separator gray -> warm sepia separator (0xD4C8B8)
            return [UIColor colorWithRed:0xD4/255.0 green:0xC8/255.0 blue:0xB8/255.0 alpha:1.0];
        } else if (rgbValue == 0xE3E6E0) {
            // Toolbar gray-green -> warm sepia (0xF3E2CB)
            return [UIColor colorWithRed:0xF3/255.0 green:0xE2/255.0 blue:0xCB/255.0 alpha:1.0];
        }
        // Warm sepia matrix - lighter and warmer, less yellow/green
        CGFloat outputRed = (red * 0.42) + (green * 0.75) + (blue * 0.17);
        CGFloat outputGreen = (red * 0.36) + (green * 0.68) + (blue * 0.14);
        CGFloat outputBlue = (red * 0.26) + (green * 0.52) + (blue * 0.10);

        return [UIColor colorWithRed:outputRed green:outputGreen blue:outputBlue alpha:1.0];
    } else {
        return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
    }
}

+ (UIColor *)colorFromRGB:(NSArray<NSNumber *> *)rgbValues {
    if (rgbValues.count == 1) {
        return [ThemeManager.shared themedColorFromRGB:rgbValues[0].integerValue];
    } else if (rgbValues.count == 2) {
        return [ThemeManager.shared colorFromLightRGB:rgbValues[0].integerValue darkRGB:rgbValues[1].integerValue];
    } else if (rgbValues.count == 4) {
        return [ThemeManager.shared colorFromLightRGB:rgbValues[0].integerValue sepiaRGB:rgbValues[1].integerValue mediumRGB:rgbValues[2].integerValue darkRGB:rgbValues[3].integerValue];
    } else {
        @throw [NSException exceptionWithName:@"Invalid parameter to Theme Manager" reason:@"Should be an array of 1, 2, or 4 RGB colors." userInfo:nil];
    }
}

- (UIImage *)themedImage:(UIImage *)image {
    if (self.isDarkTheme) {
        CIImage *coreImage = [CIImage imageWithCGImage:image.CGImage];
        CIFilter *filter = [CIFilter filterWithName:@"CIColorInvert"];
        [filter setValue:coreImage forKey:kCIInputImageKey];
        CIImage *result = [filter valueForKey:kCIOutputImageKey];
        
        return [UIImage imageWithCIImage:result scale:image.scale orientation:image.imageOrientation];
    } else if ([self.theme isEqualToString:ThemeStyleSepia]) {
        CIImage *coreImage = [CIImage imageWithCGImage:image.CGImage];
        CIFilter *filter = [CIFilter filterWithName:@"CISepiaTone" keysAndValues:kCIInputImageKey, coreImage, @"inputIntensity", @0.8, nil];
        CIImage *result = [filter outputImage];
        
        return [UIImage imageWithCIImage:result scale:image.scale orientation:image.imageOrientation];
    } else {
        return image;
    }
}

- (void)updateNavigationController:(UINavigationController *)navigationController {
    navigationController.navigationBar.tintColor = [UINavigationBar appearance].tintColor;
    navigationController.navigationBar.barTintColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xF3E2CB, 0x222222, 0x111111);
    navigationController.navigationBar.backgroundColor = [UINavigationBar appearance].backgroundColor;
}

- (void)updateBackgroundOfView:(UIView *)view {
    view.backgroundColor = UIColorFromLightDarkRGB(0xe0e0e0, 0x111111);
}

- (void)updateTextAttributesForSegmentedControl:(UISegmentedControl *)segmentedControl forState:(UIControlState)state foregroundColor:(UIColor *)foregroundColor {
    NSMutableDictionary *attributes = [NSMutableDictionary dictionary];
    NSDictionary *oldAttributes = [segmentedControl titleTextAttributesForState:state];
    
    if (oldAttributes != nil) {
        [attributes addEntriesFromDictionary:oldAttributes];
    }
    
    attributes[NSForegroundColorAttributeName] = foregroundColor;
    
    [segmentedControl setTitleTextAttributes:attributes forState:state];
}

- (void)updateSegmentedControl:(UISegmentedControl *)segmentedControl {
    segmentedControl.tintColor = UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8B7B6B, 0x505050, 0x8F918B);
#if !TARGET_OS_MACCATALYST
    segmentedControl.backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xe7e6e7, 0xE8DED0, 0x707070, 0x303030);
#endif
    segmentedControl.selectedSegmentTintColor = UIColorFromLightSepiaMediumDarkRGB(0xffffff, 0xFAF5ED, 0x555555, 0x6f6f75);

    [self updateTextAttributesForSegmentedControl:segmentedControl forState:UIControlStateNormal foregroundColor:UIColorFromLightSepiaMediumDarkRGB(0x909090, 0x8B7B6B, 0xcccccc, 0xaaaaaa)];
    [self updateTextAttributesForSegmentedControl:segmentedControl forState:UIControlStateSelected foregroundColor:UIColorFromLightSepiaMediumDarkRGB(0x0, 0x3C3226, 0xffffff, 0xffffff)];
    segmentedControl.layer.borderWidth = 1.0 / UIScreen.mainScreen.scale;
    segmentedControl.layer.borderColor = UIColorFromLightSepiaMediumDarkRGB(0xc0c0c0, 0xC8B8A8, 0x555555, 0x444444).CGColor;
}

- (void)updateThemeSegmentedControl:(UISegmentedControl *)segmentedControl {
    [self updateSegmentedControl:segmentedControl];
    
    segmentedControl.tintColor = [UIColor clearColor];
#if !TARGET_OS_MACCATALYST
    segmentedControl.backgroundColor = [UIColor clearColor];
#endif
    segmentedControl.selectedSegmentTintColor = [UIColor clearColor];
}

- (void)debugColor:(NSInteger)rgbValue {
    static NSMutableSet *colors = nil;
    
    if (!colors) {
        colors = [NSMutableSet set];
    }
    
    [colors addObject:[NSString stringWithFormat:@"0x%06lX", (long)rgbValue]];
    
    NSLog(@"all unique colors: %@", [[colors allObjects] sortedArrayUsingSelector:@selector(compare:)]);  // log
}

- (void)prepareForWindow:(UIWindow *)window {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    // Can remove this once everyone has updated to version 13.1.2 or later.
    if ([prefs boolForKey:@"theme_follow_system"]) {
        self.theme = ThemeStyleAuto;
        [prefs setBool:NO forKey:@"theme_follow_system"];
    }
    
    [self autoChangeTheme];
    [self setupTheme];
    [self addThemeGestureRecognizerToView:window];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenBrightnessChangedNotification:) name:UIScreenBrightnessDidChangeNotification object:nil];
}

- (void)setupTheme {
    [UINavigationBar appearance].tintColor = UIColorFromLightSepiaMediumDarkRGB(0x0, 0x0, 0x9a8f73, 0x9a8f73);
    [UINavigationBar appearance].barTintColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222);
    [UINavigationBar appearance].backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222);
    [UINavigationBar appearance].titleTextAttributes = @{NSForegroundColorAttributeName : UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8B7B6B, 0x8F918B, 0x8F918B)};
    [UIToolbar appearance].barTintColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222);
    [UISegmentedControl appearance].tintColor = UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8B7B6B, 0x8F918B, 0x8F918B);

    UIBarStyle style = self.isDarkTheme ? UIBarStyleBlack : UIBarStyleDefault;

    [UINavigationBar appearance].barStyle = style;
    [UINavigationBar appearance].translucent = YES;
    self.appDelegate.feedsNavigationController.navigationBar.barStyle = style;
    if (self.appDelegate.detailNavigationController) {
        self.appDelegate.detailNavigationController.navigationBar.barStyle = style;
    }

    // Set window background color for status bar area (match toolbar colors)
    self.appDelegate.window.backgroundColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xF3E2CB, 0x333333, 0x222222);

    // Override the system interface style so UIKit-managed views (split view column
    // backgrounds, navigation controller views, etc.) match the app's theme even when
    // the system appearance differs.
    if (self.isDarkTheme) {
        self.appDelegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
    } else {
        self.appDelegate.window.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;
    }

    UIViewController *topViewController = self.appDelegate.window.rootViewController;
    while (topViewController.presentedViewController) {
        topViewController = topViewController.presentedViewController;
    }
    [topViewController setNeedsStatusBarAppearanceUpdate];
    [self.appDelegate.feedsNavigationController setNeedsStatusBarAppearanceUpdate];
    [self.appDelegate.detailNavigationController setNeedsStatusBarAppearanceUpdate];
    [self.appDelegate.feedDetailNavigationController setNeedsStatusBarAppearanceUpdate];
    [self.appDelegate.detailViewController setNeedsStatusBarAppearanceUpdate];
    [self.appDelegate.feedDetailViewController setNeedsStatusBarAppearanceUpdate];
    [self.appDelegate.storyPagesViewController setNeedsStatusBarAppearanceUpdate];
    [self.appDelegate.splitViewController setNeedsStatusBarAppearanceUpdate];
}

- (void)updateTheme {
    // Keep the dark & light themes in sync, so toggling uses the most recent themes for each
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *theme = self.theme;
    NewsBlurAppDelegate *appDelegate = self.appDelegate;
    
    if (self.isAutoTheme) {
        self.isAutoDark = self.isSystemDark;
    } else {
        if (self.isDarkTheme) {
            [prefs setObject:theme forKey:@"theme_dark"];
        } else {
            [prefs setObject:theme forKey:@"theme_light"];
        }
    }
    
    [self setupTheme];
    
    [appDelegate.splitViewController updateTheme];
    [appDelegate.feedsViewController updateTheme];
    [appDelegate.activitiesViewController updateTheme];
    [appDelegate.feedDetailViewController updateTheme];
    [appDelegate.detailViewController updateTheme];
    [appDelegate.storyPagesViewController updateTheme];
    [appDelegate.originalStoryViewController updateTheme];
    
    [self updatePreferencesTheme];
}

- (void)updatePreferencesTheme {
    // SwiftUI PreferencesView handles its own theming
}

- (BOOL)autoChangeTheme {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    
    if (![prefs boolForKey:@"theme_auto_toggle"]) {
        return NO;
    }
    
    CGFloat screenBrightness = [UIScreen mainScreen].brightness;
    CGFloat themeBrightness = [prefs floatForKey:@"theme_auto_brightness"];
    BOOL wantDark = (screenBrightness < themeBrightness);
    BOOL isDark = self.isDarkTheme;
    
    if (wantDark != isDark) {
        NSString *theme = nil;
        
        if (wantDark) {
            theme = [prefs objectForKey:@"theme_dark"];
        } else {
            theme = [prefs objectForKey:@"theme_light"];
        }
        
        NSLog(@"Automatically changing to theme: %@", self.themeDisplayName);  // log
        
        self.theme = theme;
        
        return YES;
    }
    
    return NO;
}

- (void)screenBrightnessChangedNotification:(NSNotification *)note {
    if ([self autoChangeTheme]) {
        [self updateTheme];
    }
}

- (UIGestureRecognizer *)addThemeGestureRecognizerToView:(UIView *)view {
    UIPanGestureRecognizer *recognizer = [[UIPanGestureRecognizer alloc] initWithTarget:self action:@selector(handleThemeGesture:)];
    
    recognizer.minimumNumberOfTouches = 2;
    recognizer.maximumNumberOfTouches = 2;
    
    [view addGestureRecognizer:recognizer];
    
    return recognizer;
}

- (void)handleThemeGesture:(UIPanGestureRecognizer *)recognizer {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];

    if (recognizer.state != UIGestureRecognizerStateChanged || [prefs boolForKey:@"theme_auto_toggle"] || ![prefs boolForKey:@"theme_gesture"]) {
        self.justToggledViaGesture = NO;
        return;
    }

    CGPoint translation = [recognizer translationInView:recognizer.view];

    if (self.justToggledViaGesture || fabs(translation.x) > 50.0 || fabs(translation.y) < 50.0) {
        return;
    }

    BOOL isUpward = translation.y > 0.0;
    NSString *themeStyle = [prefs objectForKey:@"theme_style"];
    NSString *currentTheme = self.theme;

    // Swipe up = darker, swipe down = lighter
    if ([themeStyle isEqualToString:@"light"]) {
        // In light mode: toggle between light and sepia
        NSString *newVariant = [currentTheme isEqualToString:ThemeStyleSepia] ? ThemeStyleLight : ThemeStyleSepia;
        [prefs setObject:newVariant forKey:@"theme_light"];
    } else if ([themeStyle isEqualToString:@"dark"]) {
        // In dark mode: toggle between gray (medium) and black (dark)
        NSString *newVariant = [currentTheme isEqualToString:ThemeStyleMedium] ? ThemeStyleDark : ThemeStyleMedium;
        [prefs setObject:newVariant forKey:@"theme_dark"];
    } else {
        // Auto mode or legacy: swipe switches between light and dark theme families
        if (isUpward) {
            // Swipe up = go darker
            NSString *darkVariant = [prefs objectForKey:@"theme_dark"];
            if (!darkVariant) darkVariant = ThemeStyleDark;
            if ([currentTheme isEqualToString:darkVariant]) {
                // Already on dark variant, toggle to other dark variant
                darkVariant = [currentTheme isEqualToString:ThemeStyleMedium] ? ThemeStyleDark : ThemeStyleMedium;
                [prefs setObject:darkVariant forKey:@"theme_dark"];
            }
            [self reallySetTheme:darkVariant];
        } else {
            // Swipe down = go lighter
            NSString *lightVariant = [prefs objectForKey:@"theme_light"];
            if (!lightVariant) lightVariant = ThemeStyleLight;
            if ([currentTheme isEqualToString:lightVariant]) {
                // Already on light variant, toggle to other light variant
                lightVariant = [currentTheme isEqualToString:ThemeStyleSepia] ? ThemeStyleLight : ThemeStyleSepia;
                [prefs setObject:lightVariant forKey:@"theme_light"];
            }
            [self reallySetTheme:lightVariant];
        }
    }

    self.justToggledViaGesture = YES;

    NSLog(@"Swiped to theme: %@", self.themeDisplayName);  // log

    [self updateTheme];

    // Play a click sound, like a light switch
    AudioServicesPlaySystemSound(1105);
}

- (void)updateForSystemAppearance {
    [self systemAppearanceDidChange:self.isSystemDark];
}

- (void)systemAppearanceDidChange:(BOOL)isDark {
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *wantTheme = nil;
    
    if (!self.isAutoTheme) {
        return;
    }
    
    if (self.isAutoTheme) {
        if (isDark != self.isAutoDark) {
            [self updateTheme];
            
            NSLog(@"System changed to %@ appearance", isDark ? @"dark" : @"light");  // log
        }
        
        return;
    } else {
        if (isDark) {
            wantTheme = [prefs objectForKey:@"theme_dark"];
        } else {
            wantTheme = [prefs objectForKey:@"theme_light"];
        }
    }
    
    if (self.theme != wantTheme) {
        [self reallySetTheme:wantTheme];
        
        NSLog(@"System changed to theme: %@", self.themeDisplayName);  // log
    }
}

@end
