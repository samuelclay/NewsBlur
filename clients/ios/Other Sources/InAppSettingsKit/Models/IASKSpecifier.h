//
//  IASKSpecifier.h
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2009:
//  Luc Vandal, Edovia Inc., http://www.edovia.com
//  Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//  All rights reserved.
//
//  It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz,
//  as the original authors of this code. You can give credit in a blog post, a tweet or on
//  a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//  This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

@class IASKSettingsReader;

@interface IASKSpecifier : NSObject

@property (nonatomic, retain) NSDictionary  *specifierDict;
@property (nonatomic, weak) IASKSettingsReader *settingsReader;

- (id)initWithSpecifier:(NSDictionary*)specifier;
- (NSString*)localizedObjectForKey:(NSString*)key;
- (NSString*)title;
- (NSString*)key;
- (NSString*)type;
- (NSString*)titleForCurrentValue:(id)currentValue;
- (NSInteger)multipleValuesCount;
- (NSArray*)multipleValues;
- (NSArray*)multipleTitles;
- (NSString*)file;
- (id)defaultValue;
- (id)defaultStringValue;
- (BOOL)defaultBoolValue;
- (id)trueValue;
- (id)falseValue;
- (float)minimumValue;
- (float)maximumValue;
- (NSString*)minimumValueImage;
- (NSString*)maximumValueImage;
- (BOOL)isSecure;
- (UIKeyboardType)keyboardType;
- (UITextAutocapitalizationType)autocapitalizationType;
- (UITextAutocorrectionType)autoCorrectionType;
- (NSString*)footerText;
- (Class)viewControllerClass;
- (SEL)viewControllerSelector;
- (NSString*)viewControllerStoryBoardFile;
- (NSString*)viewControllerStoryBoardID;
- (Class)buttonClass;
- (SEL)buttonAction;
- (UIImage *)cellImage;
- (UIImage *)highlightedCellImage;
- (BOOL)adjustsFontSizeToFitWidth;
- (NSTextAlignment)textAlignment;
@end
