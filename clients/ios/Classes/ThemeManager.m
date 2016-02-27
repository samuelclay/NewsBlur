//
//  ThemeManager.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-12-06.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "ThemeManager.h"
#import "NewsBlurAppDelegate.h"
#import "NBContainerViewController.h"
#import "NewsBlurViewController.h"
#import "DashboardViewController.h"
#import "FeedDetailViewController.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "OriginalStoryViewController.h"
#import <AudioToolbox/AudioToolbox.h>

NSString * const ThemeStyleLight = @"light";
NSString * const ThemeStyleSepia = @"sepia";
NSString * const ThemeStyleMedium = @"medium";
NSString * const ThemeStyleDark = @"dark";

@interface ThemeManager ()

@property (nonatomic, readonly) NewsBlurAppDelegate *appDelegate;
@property (nonatomic) BOOL justToggledViaGesture;

@end

@implementation ThemeManager

+ (instancetype)themeManager {
    static id themeManager = nil;
    static dispatch_once_t onceToken;
    
    dispatch_once(&onceToken, ^{
                      themeManager = [self new];
                  });
    
    return themeManager;
}

- (NSString *)theme {
    NSString *theme = [[NSUserDefaults standardUserDefaults] objectForKey:@"theme_style"];
    
    if (![self isValidTheme:theme]) {
        theme = ThemeStyleLight;
    }
    
    return theme;
}

- (void)setTheme:(NSString *)theme {
    if ([self isValidTheme:theme]) {
        [[NSUserDefaults standardUserDefaults] setObject:theme forKey:@"theme_style"];
        [self updateTheme];
    }
}

- (NSString *)themeDisplayName {
    NSString *theme = self.theme;
    
    if ([theme isEqualToString:ThemeStyleDark]) {
        return @"Dark";
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        return @"Sepia";
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        return @"Medium";
    } else {
        return @"Light";
    }
}

- (NSString *)themeCSSSuffix {
    NSString *theme = self.theme;
    
    if ([theme isEqualToString:ThemeStyleDark]) {
        return @"Dark";
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        return @"Sepia";
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        return @"Medium";
    } else {
        return @"";
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
    } else {
        return ThemeStyleSepia;
    }
}

- (BOOL)isDarkTheme {
    NSString *theme = self.theme;
    
    return [theme isEqualToString:ThemeStyleDark] || [theme isEqualToString:ThemeStyleMedium];
}

- (BOOL)isValidTheme:(NSString *)theme {
    return [theme isEqualToString:ThemeStyleLight] || [theme isEqualToString:ThemeStyleSepia] || [theme isEqualToString:ThemeStyleMedium] || [theme isEqualToString:ThemeStyleDark];
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
    
    if ([self.theme isEqualToString:ThemeStyleSepia]) {
        rgbValue = sepiaRGBValue;
    } else if ([self.theme isEqualToString:ThemeStyleMedium]) {
        rgbValue = mediumRGBValue;
    } else if ([self.theme isEqualToString:ThemeStyleDark]) {
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
    
    if ([theme isEqualToString:ThemeStyleDark]) {
        return [UIColor colorWithRed:1.0 - red green:1.0 - green blue:1.0 - blue alpha:1.0];
    } else if ([theme isEqualToString:ThemeStyleMedium]) {
        if (rgbValue == 0x8F918B) {
            return [UIColor colorWithWhite:0.7 alpha:1.0];
        } else if (red < 0.5 && green < 0.5 && blue < 0.5) {
            return [UIColor colorWithRed:1.0 - red green:1.0 - green blue:1.0 - blue alpha:1.0];
        } else {
            return [UIColor colorWithRed:red - 0.5 green:green - 0.5 blue:blue - 0.5 alpha:1.0];
        }
    } else if ([theme isEqualToString:ThemeStyleSepia]) {
        CGFloat outputRed = (red * 0.393) + (green * 0.769) + (blue * 0.189);
        CGFloat outputGreen = (red * 0.349) + (green * 0.686) + (blue * 0.168);
        CGFloat outputBlue = (red * 0.272) + (green * 0.534) + (blue * 0.131);
        
        return [UIColor colorWithRed:outputRed green:outputGreen blue:outputBlue alpha:1.0];
    } else {
        return [UIColor colorWithRed:red green:green blue:blue alpha:1.0];
    }
}

- (UIImage *)themedImage:(UIImage *)image {
    if ([self.theme isEqualToString:ThemeStyleDark]) {
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

- (void)debugColor:(NSInteger)rgbValue {
    static NSMutableSet *colors = nil;
    
    if (!colors) {
        colors = [NSMutableSet set];
    }
    
    [colors addObject:[NSString stringWithFormat:@"0x%06lX", rgbValue]];
    
    NSLog(@"all unique colors: %@", [[colors allObjects] sortedArrayUsingSelector:@selector(compare:)]);  // log
}

- (void)prepareForWindow:(UIWindow *)window {
    [self autoChangeTheme];
    [self setupTheme];
    [self addThemeGestureRecognizerToView:window];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(screenBrightnessChangedNotification:) name:UIScreenBrightnessDidChangeNotification object:nil];
}

- (void)setupTheme {
    [UINavigationBar appearance].tintColor = UIColorFromLightSepiaMediumDarkRGB(0x0, 0x0, 0x9a8f73, 0x9a8f73);
    [UINavigationBar appearance].barTintColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xFFFFC5, 0x6A6A6A, 0x424242);
    [UIToolbar appearance].barTintColor = UIColorFromLightSepiaMediumDarkRGB(0xE3E6E0, 0xFFFFC5, 0x6A6A6A, 0x424242);
    [UISegmentedControl appearance].tintColor = UIColorFromLightSepiaMediumDarkRGB(0x8F918B, 0x8F918B, 0x8F918B, 0x8F918B);
    
    UIBarStyle style = self.isDarkTheme ? UIBarStyleBlack : UIBarStyleDefault;
    
    [UINavigationBar appearance].barStyle = style;
    [UINavigationBar appearance].translucent = YES;
    self.appDelegate.navigationController.navigationBar.barStyle = style;
}

- (void)updateTheme {
    // Keep the dark & light themes in sync, so toggling uses the most recent themes for each
    NSUserDefaults *prefs = [NSUserDefaults standardUserDefaults];
    NSString *theme = self.theme;
    NewsBlurAppDelegate *appDelegate = self.appDelegate;
    
    if (self.isDarkTheme) {
        [prefs setObject:theme forKey:@"theme_dark"];
    } else {
        [prefs setObject:theme forKey:@"theme_light"];
    }
    
    [self setupTheme];
    
    [appDelegate.masterContainerViewController updateTheme];
    [appDelegate.feedsViewController updateTheme];
    [appDelegate.dashboardViewController updateTheme];
    [appDelegate.feedDetailViewController updateTheme];
    [appDelegate.storyPageControl updateTheme];
    [appDelegate.originalStoryViewController updateTheme];
    
    [self updatePreferencesTheme];
}

- (void)updatePreferencesTheme {
    NewsBlurAppDelegate *appDelegate = self.appDelegate;
    UIBarButtonItem *item = [appDelegate.preferencesViewController.navigationController.navigationBar.items.firstObject rightBarButtonItem];
    
    item.tintColor = UIColorFromRGB(0x333333);
    appDelegate.preferencesViewController.navigationController.navigationBar.titleTextAttributes = @{NSForegroundColorAttributeName : UIColorFromRGB(NEWSBLUR_BLACK_COLOR)};
    appDelegate.preferencesViewController.navigationController.navigationBar.tintColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    appDelegate.preferencesViewController.navigationController.navigationBar.barTintColor = UIColorFromRGB(0xE3E6E0);
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
    NSString *isTheme = self.theme;
    NSString *wantTheme = nil;
    
    if (isUpward) {
        wantTheme = [prefs objectForKey:@"theme_dark"];
    } else {
        wantTheme = [prefs objectForKey:@"theme_light"];
    }
    
    if ([isTheme isEqualToString:wantTheme]) {
        wantTheme = [self similarTheme];
    }
    
    self.theme = wantTheme;
    self.justToggledViaGesture = YES;
    
    NSLog(@"Swiped to theme: %@", self.themeDisplayName);  // log
    
    [self updateTheme];
    
    // Play a click sound, like a light switch; might want to use a custom sound instead?
    AudioServicesPlaySystemSound(1105);
}

@end

