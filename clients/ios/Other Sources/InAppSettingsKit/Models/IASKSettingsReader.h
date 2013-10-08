//
//  IASKSettingsReader.h
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

#define kIASKPreferenceSpecifiers             @"PreferenceSpecifiers"
#define kIASKCellImage                        @"IASKCellImage"

#define kIASKType                             @"Type"
#define kIASKTitle                            @"Title"
#define kIASKFooterText                       @"FooterText"
#define kIASKKey                              @"Key"
#define kIASKFile                             @"File"
#define kIASKDefaultValue                     @"DefaultValue"
#define kIASKMinimumValue                     @"MinimumValue"
#define kIASKMaximumValue                     @"MaximumValue"
#define kIASKTrueValue                        @"TrueValue"
#define kIASKFalseValue                       @"FalseValue"
#define kIASKIsSecure                         @"IsSecure"
#define KIASKKeyboardType                     @"KeyboardType"
#define kIASKAutocapitalizationType           @"AutocapitalizationType"
#define kIASKAutoCorrectionType               @"AutocorrectionType"
#define kIASKValues                           @"Values"
#define kIASKTitles                           @"Titles"
#define kIASKViewControllerClass              @"IASKViewControllerClass"
#define kIASKViewControllerSelector           @"IASKViewControllerSelector"
#define kIASKButtonClass                      @"IASKButtonClass"
#define kIASKButtonAction                     @"IASKButtonAction"
#define kIASKMailComposeToRecipents           @"IASKMailComposeToRecipents"
#define kIASKMailComposeCcRecipents           @"IASKMailComposeCcRecipents"
#define kIASKMailComposeBccRecipents          @"IASKMailComposeBccRecipents"
#define kIASKMailComposeSubject               @"IASKMailComposeSubject"
#define kIASKMailComposeBody                  @"IASKMailComposeBody"
#define kIASKMailComposeBodyIsHTML            @"IASKMailComposeBodyIsHTML"
#define kIASKKeyboardAlphabet                 @"Alphabet"
#define kIASKKeyboardNumbersAndPunctuation    @"NumbersAndPunctuation"
#define kIASKKeyboardNumberPad                @"NumberPad"
#define kIASKKeyboardDecimalPad               @"DecimalPad"
#define kIASKKeyboardPhonePad                 @"PhonePad"
#define kIASKKeyboardNamePhonePad             @"NamePhonePad"
#define kIASKKeyboardASCIICapable             @"AsciiCapable"

#define KIASKKeyboardURL                      @"URL"
#define kIASKKeyboardEmailAddress             @"EmailAddress"
#define kIASKAutoCapNone                      @"None"
#define kIASKAutoCapSentences                 @"Sentences"
#define kIASKAutoCapWords                     @"Words"
#define kIASKAutoCapAllCharacters             @"AllCharacters"
#define kIASKAutoCorrDefault                  @"Default"
#define kIASKAutoCorrNo                       @"No"
#define kIASKAutoCorrYes                      @"Yes"
#define kIASKMinimumValueImage                @"MinimumValueImage"
#define kIASKMaximumValueImage                @"MaximumValueImage"
#define kIASKAdjustsFontSizeToFitWidth        @"IASKAdjustsFontSizeToFitWidth"
#define kIASKTextLabelAlignment               @"IASKTextAlignment"
#define kIASKTextLabelAlignmentLeft           @"IASKUITextAlignmentLeft"
#define kIASKTextLabelAlignmentCenter         @"IASKUITextAlignmentCenter"
#define kIASKTextLabelAlignmentRight          @"IASKUITextAlignmentRight"

#define kIASKPSGroupSpecifier                 @"PSGroupSpecifier"
#define kIASKPSToggleSwitchSpecifier          @"PSToggleSwitchSpecifier"
#define kIASKPSMultiValueSpecifier            @"PSMultiValueSpecifier"
#define kIASKPSSliderSpecifier                @"PSSliderSpecifier"
#define kIASKPSTitleValueSpecifier            @"PSTitleValueSpecifier"
#define kIASKPSTextFieldSpecifier             @"PSTextFieldSpecifier"
#define kIASKPSChildPaneSpecifier             @"PSChildPaneSpecifier"
#define kIASKOpenURLSpecifier                 @"IASKOpenURLSpecifier"
#define kIASKButtonSpecifier                  @"IASKButtonSpecifier"
#define kIASKMailComposeSpecifier             @"IASKMailComposeSpecifier"
#define kIASKCustomViewSpecifier              @"IASKCustomViewSpecifier"

#define kIASKAppSettingChanged                @"kAppSettingChanged"

#define kIASKSectionHeaderIndex               0

#define kIASKSliderNoImagesPadding            11
#define kIASKSliderImagesPadding              43

#define kIASKSpacing                          5
#define kIASKMinLabelWidth                    97
#define kIASKMaxLabelWidth                    240
#define kIASKMinValueWidth                    35
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#define kIASKPaddingLeft                      (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1 ? 14 : 9)
#else
#define kIASKPaddingLeft                      9
#endif
#define kIASKPaddingRight                     10
#define kIASKHorizontalPaddingGroupTitles     19
#define kIASKVerticalPaddingGroupTitles       15

#define kIASKLabelFontSize                    17
#define kIASKgrayBlueColor                    [UIColor colorWithRed:0.318f green:0.4f blue:0.569f alpha:1.f]

#define kIASKMinimumFontSize                  12.0f

#ifndef kCFCoreFoundationVersionNumber_iPhoneOS_4_0
#define kCFCoreFoundationVersionNumber_iPhoneOS_4_0 550.32
#endif

#ifndef kCFCoreFoundationVersionNumber_iPhoneOS_4_1
#define kCFCoreFoundationVersionNumber_iPhoneOS_4_1 550.38
#endif


#define IASK_IF_IOS4_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iPhoneOS_4_0) \
{ \
__VA_ARGS__ \
}

@class IASKSpecifier;

/** settings reader transform iOS's settings plist files
 to the IASKSpecifier model objects.
 Besides that, it also hides the complexity of finding
 the 'proper' Settings.bundle
 */
@interface IASKSettingsReader : NSObject

/** designated initializer
 searches for a settings bundle that contains
 a plist with the specified fileName that must
 be contained in the given bundle
 
 calls initWithFile where applicationBundle is
 set to [NSBundle mainBundle]
 */
- (id) initWithSettingsFileNamed:(NSString*) fileName
               applicationBundle:(NSBundle*) bundle;

- (id) initWithFile:(NSString*)file;

- (NSInteger)numberOfSections;
- (NSInteger)numberOfRowsForSection:(NSInteger)section;
- (IASKSpecifier*)specifierForIndexPath:(NSIndexPath*)indexPath;
- (NSIndexPath*)indexPathForKey:(NSString*)key;
- (IASKSpecifier*)specifierForKey:(NSString*)key;
- (NSString*)titleForSection:(NSInteger)section;
- (NSString*)keyForSection:(NSInteger)section;
- (NSString*)footerTextForSection:(NSInteger)section;
- (NSString*)titleForStringId:(NSString*)stringId;
- (NSString*)pathForImageNamed:(NSString*)image;

///the main application bundle. most often [NSBundle mainBundle]
@property (nonatomic, readonly) NSBundle      *applicationBundle;

///the actual settings bundle
@property (nonatomic, readonly) NSBundle    *settingsBundle;

///the actual settings plist, parsed into a dictionary
@property (nonatomic, readonly) NSDictionary  *settingsDictionary;


@property (nonatomic, retain) NSString      *localizationTable;
@property (nonatomic, retain) NSArray       *dataSource;
@property (nonatomic, retain) NSSet         *hiddenKeys;


#pragma mark - internal use. public only for testing
- (NSString *)file:(NSString *)file
        withBundle:(NSString *)bundle
            suffix:(NSString *)suffix
         extension:(NSString *)extension;
- (NSString *)locateSettingsFile:(NSString *)file;

- (NSString *)platformSuffixForInterfaceIdiom:(UIUserInterfaceIdiom) interfaceIdiom;
@end
