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
#define kIASKDisplaySortedByTitle             @"DisplaySortedByTitle"
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
#define kIASKShortTitles                      @"ShortTitles"
#define kIASKSupportedUserInterfaceIdioms     @"SupportedUserInterfaceIdioms"
#define kIASKSubtitle                         @"IASKSubtitle"
#define kIASKViewControllerClass              @"IASKViewControllerClass"
#define kIASKViewControllerSelector           @"IASKViewControllerSelector"
#define kIASKViewControllerStoryBoardFile     @"IASKViewControllerStoryBoardFile"
#define kIASKViewControllerStoryBoardId       @"IASKViewControllerStoryBoardId"
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
#define kIASKPSRadioGroupSpecifier            @"PSRadioGroupSpecifier"
#define kIASKPSSliderSpecifier                @"PSSliderSpecifier"
#define kIASKPSTitleValueSpecifier            @"PSTitleValueSpecifier"
#define kIASKPSTextFieldSpecifier             @"PSTextFieldSpecifier"
#define kIASKPSChildPaneSpecifier             @"PSChildPaneSpecifier"
#define kIASKOpenURLSpecifier                 @"IASKOpenURLSpecifier"
#define kIASKButtonSpecifier                  @"IASKButtonSpecifier"
#define kIASKMailComposeSpecifier             @"IASKMailComposeSpecifier"
#define kIASKCustomViewSpecifier              @"IASKCustomViewSpecifier"

// IASKChildTitle can be set if IASKViewControllerClass is set to IASKAppSettingsWebViewController.
// If IASKChildTitle is set, the navigation title is fixed to it; otherwise, the title value is used and is overridden by the HTML title tag
// as soon as the web page is loaded; if IASKChildTitle is set to the empty string, the title is not shown on push but _will_ be replaced by
// the HTML title as soon as the page is loaded. The value of IASKChildTitle is localizable.
#define kIASKChildTitle                       @"IASKChildTitle"

#define kIASKAppSettingChanged                @"kAppSettingChanged"

#define kIASKSectionHeaderIndex               0

#define kIASKSliderImageGap                   10

#define kIASKSpacing                          8
#define kIASKMinLabelWidth                    97
#define kIASKMaxLabelWidth                    240
#define kIASKMinValueWidth                    35
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
#define kIASKPaddingLeft                      (floor(NSFoundationVersionNumber) > NSFoundationVersionNumber_iOS_6_1 ? 15 : 9)
#else
#define kIASKPaddingLeft                      9
#endif
#define kIASKPaddingRight                     10
#define kIASKHorizontalPaddingGroupTitles     19
#define kIASKVerticalPaddingGroupTitles       15

#define kIASKLabelFontSize                    17
#define kIASKgrayBlueColor                    [UIColor colorWithRed:0.318f green:0.4f blue:0.569f alpha:1.f]

#define kIASKMinimumFontSize                  12.0f

#ifndef kCFCoreFoundationVersionNumber_iOS_7_0
#define kCFCoreFoundationVersionNumber_iOS_7_0 843.00
#endif

#ifndef kCFCoreFoundationVersionNumber_iOS_8_0
#define kCFCoreFoundationVersionNumber_iOS_8_0 1129.150000
#endif

#ifdef __IPHONE_6_0
#define IASK_IF_IOS6_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_6_0) \
{ \
__VA_ARGS__ \
}
#else
#define IASK_IF_IOS6_OR_GREATER(...)
#endif

#ifdef __IPHONE_6_0
#define IASK_IF_PRE_IOS6(...) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_6_0) \
{ \
__VA_ARGS__ \
} \
_Pragma("clang diagnostic pop")
#else
#define IASK_IF_PRE_IOS6(...)  __VA_ARGS__
#endif

#ifdef __IPHONE_7_0
#define IASK_IF_IOS7_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_7_0) \
{ \
__VA_ARGS__ \
}
#else
#define IASK_IF_IOS7_OR_GREATER(...)
#endif

#ifdef __IPHONE_7_0
#define IASK_IF_PRE_IOS7(...) \
_Pragma("clang diagnostic push") \
_Pragma("clang diagnostic ignored \"-Wdeprecated-declarations\"") \
if (kCFCoreFoundationVersionNumber < kCFCoreFoundationVersionNumber_iOS_7_0) \
{ \
__VA_ARGS__ \
} \
_Pragma("clang diagnostic pop")
#else
#define IASK_IF_PRE_IOS7(...)  __VA_ARGS__
#endif

#ifdef __IPHONE_8_0
#define IASK_IF_IOS8_OR_GREATER(...) \
if (kCFCoreFoundationVersionNumber >= kCFCoreFoundationVersionNumber_iOS_8_0) \
{ \
__VA_ARGS__ \
}
#else
#define IASK_IF_IOS8_OR_GREATER(...)
#endif


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
- (IASKSpecifier *)headerSpecifierForSection:(NSInteger)section;
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
@property (nonatomic) BOOL					showPrivacySettings;


#pragma mark - internal use. public only for testing
- (NSString *)file:(NSString *)file
        withBundle:(NSString *)bundle
            suffix:(NSString *)suffix
         extension:(NSString *)extension;
- (NSString *)locateSettingsFile:(NSString *)file;

- (NSString *)platformSuffixForInterfaceIdiom:(UIUserInterfaceIdiom) interfaceIdiom;
@end
