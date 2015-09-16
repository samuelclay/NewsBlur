//
//  IASKSpecifier.m
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

#import "IASKSpecifier.h"
#import "IASKSettingsReader.h"
#import "IASKAppSettingsWebViewController.h"

@interface IASKSpecifier ()

@property (nonatomic, retain) NSDictionary  *multipleValuesDict;
@property (nonatomic, copy) NSString *radioGroupValue;

@end

@implementation IASKSpecifier

- (id)initWithSpecifier:(NSDictionary*)specifier {
    if ((self = [super init])) {
        [self setSpecifierDict:specifier];

        if ([self isMultiValueSpecifierType]) {
            [self updateMultiValuesDict];
        }
    }
    return self;
}

- (BOOL)isMultiValueSpecifierType {
    static NSArray *types = nil;
    if (!types) {
        types = @[kIASKPSMultiValueSpecifier, kIASKPSTitleValueSpecifier, kIASKPSRadioGroupSpecifier];
    }
    return [types containsObject:[self type]];
}

- (id)initWithSpecifier:(NSDictionary *)specifier
        radioGroupValue:(NSString *)radioGroupValue {

    self = [self initWithSpecifier:specifier];
    if (self) {
        self.radioGroupValue = radioGroupValue;
    }
    return self;
}
- (void)updateMultiValuesDict {
    NSArray *values = [_specifierDict objectForKey:kIASKValues];
    NSArray *titles = [_specifierDict objectForKey:kIASKTitles];
    NSArray *shortTitles = [_specifierDict objectForKey:kIASKShortTitles];
    NSMutableDictionary *multipleValuesDict = [NSMutableDictionary new];
    
    if (values) {
		[multipleValuesDict setObject:values forKey:kIASKValues];
	}
	
    if (titles) {
		[multipleValuesDict setObject:titles forKey:kIASKTitles];
	}
    
    if (shortTitles.count) {
		[multipleValuesDict setObject:shortTitles forKey:kIASKShortTitles];
	}
    
    [self setMultipleValuesDict:multipleValuesDict];
}

- (void)sortIfNeeded {
    if (self.displaySortedByTitle) {
        NSArray *values = [_specifierDict objectForKey:kIASKValues];
        NSArray *titles = [_specifierDict objectForKey:kIASKTitles];
        NSArray *shortTitles = [_specifierDict objectForKey:kIASKShortTitles];

        NSAssert(values.count == titles.count, @"Malformed multi-value specifier found in settings bundle. Number of values and titles differ.");
        NSAssert(shortTitles == nil || shortTitles.count == values.count, @"Malformed multi-value specifier found in settings bundle. Number of short titles and values differ.");

        NSMutableDictionary *multipleValuesDict = [NSMutableDictionary new];

        NSMutableArray *temporaryMappingsForSort = [NSMutableArray arrayWithCapacity:titles.count];

        static NSString *const titleKey = @"title";
        static NSString *const shortTitleKey = @"shortTitle";
        static NSString *const localizedTitleKey = @"localizedTitle";
        static NSString *const valueKey = @"value";
        IASKSettingsReader *strongSettingsReader = self.settingsReader;
        [titles enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSString *localizedTitle = [strongSettingsReader titleForStringId:obj];
            [temporaryMappingsForSort addObject:@{titleKey : obj,
                                                  valueKey : values[idx],
                                                  localizedTitleKey : localizedTitle,
                                                  shortTitleKey : (shortTitles[idx] ?: [NSNull null]),
                                                  }];
        }];
        
        NSArray *sortedTemporaryMappings = [temporaryMappingsForSort sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
            NSString *localizedTitle1 = obj1[localizedTitleKey];
            NSString *localizedTitle2 = obj2[localizedTitleKey];

            if ([localizedTitle1 isKindOfClass:[NSString class]] && [localizedTitle2 isKindOfClass:[NSString class]]) {
                return [localizedTitle1 localizedCompare:localizedTitle2];
            } else {
                return NSOrderedSame;
            }
        }];
        
        NSMutableArray *sortedTitles = [NSMutableArray arrayWithCapacity:sortedTemporaryMappings.count];
        NSMutableArray *sortedShortTitles = [NSMutableArray arrayWithCapacity:sortedTemporaryMappings.count];
        NSMutableArray *sortedValues = [NSMutableArray arrayWithCapacity:sortedTemporaryMappings.count];

        [sortedTemporaryMappings enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
            NSDictionary *mapping = obj;
            sortedTitles[idx] = mapping[titleKey];
            sortedValues[idx] = mapping[valueKey];
            if (mapping[shortTitleKey] != [NSNull null]) {
                sortedShortTitles[idx] = mapping[shortTitleKey];
            }
        }];
        titles = [sortedTitles copy];
        values = [sortedValues copy];
        shortTitles = [sortedShortTitles copy];
        
        if (values) {
            [multipleValuesDict setObject:values forKey:kIASKValues];
        }
        
        if (titles) {
            [multipleValuesDict setObject:titles forKey:kIASKTitles];
        }
        
        if (shortTitles.count) {
            [multipleValuesDict setObject:shortTitles forKey:kIASKShortTitles];
        }
        
        [self setMultipleValuesDict:multipleValuesDict];
    }
}

- (BOOL)displaySortedByTitle {
    return [[_specifierDict objectForKey:kIASKDisplaySortedByTitle] boolValue];
}

- (NSString*)localizedObjectForKey:(NSString*)key {
	IASKSettingsReader *settingsReader = self.settingsReader;
	return [settingsReader titleForStringId:[_specifierDict objectForKey:key]];
}

- (NSString*)title {
    return [self localizedObjectForKey:kIASKTitle];
}

- (NSString*)subtitle {
	return [self localizedObjectForKey:kIASKSubtitle];
}

- (NSString*)footerText {
    return [self localizedObjectForKey:kIASKFooterText];
}

- (Class)viewControllerClass {
    [IASKAppSettingsWebViewController class]; // make sure this is linked into the binary/library
    return [self classFromString:([_specifierDict objectForKey:kIASKViewControllerClass])];
}

- (Class)classFromString:(NSString *)className {
    Class class = NSClassFromString(className);
    if (!class) {
        // if the class doesn't exist as a pure Obj-C class then try to retrieve it as a Swift class.
        NSString *appName = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"CFBundleName"];
        NSString *classStringName = [NSString stringWithFormat:@"_TtC%lu%@%lu%@", (unsigned long)appName.length, appName, (unsigned long)className.length, className];
        class = NSClassFromString(classStringName);
    }
    return class;
}

- (SEL)viewControllerSelector {
    return NSSelectorFromString([_specifierDict objectForKey:kIASKViewControllerSelector]);
}

- (NSString*)viewControllerStoryBoardFile {
	return [_specifierDict objectForKey:kIASKViewControllerStoryBoardFile];
}

- (NSString*)viewControllerStoryBoardID {
	return [_specifierDict objectForKey:kIASKViewControllerStoryBoardId];
}

- (Class)buttonClass {
    return NSClassFromString([_specifierDict objectForKey:kIASKButtonClass]);
}

- (SEL)buttonAction {
    return NSSelectorFromString([_specifierDict objectForKey:kIASKButtonAction]);
}

- (NSString*)key {
    return [_specifierDict objectForKey:kIASKKey];
}

- (NSString*)type {
    return [_specifierDict objectForKey:kIASKType];
}

- (NSString*)titleForCurrentValue:(id)currentValue {
	NSArray *values = [self multipleValues];
	NSArray *titles = [self multipleShortTitles];
	if (!titles) {
        titles = [self multipleTitles];
	}
	if (values.count != titles.count) {
		return nil;
	}
    NSInteger keyIndex = [values indexOfObject:currentValue];
	if (keyIndex == NSNotFound) {
		return nil;
	}
	@try {
		IASKSettingsReader *strongSettingsReader = self.settingsReader;
		return [strongSettingsReader titleForStringId:[titles objectAtIndex:keyIndex]];
	}
	@catch (NSException * e) {}
	return nil;
}

- (NSInteger)multipleValuesCount {
    return [[_multipleValuesDict objectForKey:kIASKValues] count];
}

- (NSArray*)multipleValues {
    return [_multipleValuesDict objectForKey:kIASKValues];
}

- (NSArray*)multipleTitles {
    return [_multipleValuesDict objectForKey:kIASKTitles];
}

- (NSArray*)multipleShortTitles {
    return [_multipleValuesDict objectForKey:kIASKShortTitles];
}

- (NSString*)file {
    return [_specifierDict objectForKey:kIASKFile];
}

- (id)defaultValue {
    return [_specifierDict objectForKey:kIASKDefaultValue];
}

- (id)defaultStringValue {
    return [[_specifierDict objectForKey:kIASKDefaultValue] description];
}

- (BOOL)defaultBoolValue {
	id defaultValue = [self defaultValue];
	if ([defaultValue isEqual:[self trueValue]]) {
		return YES;
	}
	if ([defaultValue isEqual:[self falseValue]]) {
		return NO;
	}
	return [defaultValue boolValue];
}

- (id)trueValue {
    return [_specifierDict objectForKey:kIASKTrueValue];
}

- (id)falseValue {
    return [_specifierDict objectForKey:kIASKFalseValue];
}

- (float)minimumValue {
    return [[_specifierDict objectForKey:kIASKMinimumValue] floatValue];
}

- (float)maximumValue {
    return [[_specifierDict objectForKey:kIASKMaximumValue] floatValue];
}

- (NSString*)minimumValueImage {
    return [_specifierDict objectForKey:kIASKMinimumValueImage];
}

- (NSString*)maximumValueImage {
    return [_specifierDict objectForKey:kIASKMaximumValueImage];
}

- (BOOL)isSecure {
    return [[_specifierDict objectForKey:kIASKIsSecure] boolValue];
}

- (UIKeyboardType)keyboardType {
    if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardAlphabet]) {
        return UIKeyboardTypeDefault;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardNumbersAndPunctuation]) {
        return UIKeyboardTypeNumbersAndPunctuation;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardNumberPad]) {
        return UIKeyboardTypeNumberPad;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardPhonePad]) {
        return UIKeyboardTypePhonePad;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardNamePhonePad]) {
        return UIKeyboardTypeNamePhonePad;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardASCIICapable]) {
        return UIKeyboardTypeASCIICapable;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardDecimalPad]) {
		return UIKeyboardTypeDecimalPad;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:KIASKKeyboardURL]) {
        return UIKeyboardTypeURL;
    }
    else if ([[_specifierDict objectForKey:KIASKKeyboardType] isEqualToString:kIASKKeyboardEmailAddress]) {
        return UIKeyboardTypeEmailAddress;
    }
    return UIKeyboardTypeDefault;
}

- (UITextAutocapitalizationType)autocapitalizationType {
    if ([[_specifierDict objectForKey:kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapNone]) {
        return UITextAutocapitalizationTypeNone;
    }
    else if ([[_specifierDict objectForKey:kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapSentences]) {
        return UITextAutocapitalizationTypeSentences;
    }
    else if ([[_specifierDict objectForKey:kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapWords]) {
        return UITextAutocapitalizationTypeWords;
    }
    else if ([[_specifierDict objectForKey:kIASKAutocapitalizationType] isEqualToString:kIASKAutoCapAllCharacters]) {
        return UITextAutocapitalizationTypeAllCharacters;
    }
    return UITextAutocapitalizationTypeNone;
}

- (UITextAutocorrectionType)autoCorrectionType {
    if ([[_specifierDict objectForKey:kIASKAutoCorrectionType] isEqualToString:kIASKAutoCorrDefault]) {
        return UITextAutocorrectionTypeDefault;
    }
    else if ([[_specifierDict objectForKey:kIASKAutoCorrectionType] isEqualToString:kIASKAutoCorrNo]) {
        return UITextAutocorrectionTypeNo;
    }
    else if ([[_specifierDict objectForKey:kIASKAutoCorrectionType] isEqualToString:kIASKAutoCorrYes]) {
        return UITextAutocorrectionTypeYes;
    }
    return UITextAutocorrectionTypeDefault;
}

- (UIImage *)cellImage
{
    NSString *imageName = [_specifierDict objectForKey:kIASKCellImage];
    if( imageName.length == 0 )
        return nil;
    
    return [UIImage imageNamed:imageName];
}

- (UIImage *)highlightedCellImage
{
    NSString *imageName = [[_specifierDict objectForKey:kIASKCellImage ] stringByAppendingString:@"Highlighted"];
    if( imageName.length == 0 )
        return nil;

    return [UIImage imageNamed:imageName];
}

- (BOOL)adjustsFontSizeToFitWidth {
	NSNumber *boxedResult = [_specifierDict objectForKey:kIASKAdjustsFontSizeToFitWidth];
	return !boxedResult || [boxedResult boolValue];
}

- (NSTextAlignment)textAlignment
{
    if (self.subtitle.length || [[_specifierDict objectForKey:kIASKTextLabelAlignment] isEqualToString:kIASKTextLabelAlignmentLeft]) {
        return NSTextAlignmentLeft;
    } else if ([[_specifierDict objectForKey:kIASKTextLabelAlignment] isEqualToString:kIASKTextLabelAlignmentCenter]) {
        return NSTextAlignmentCenter;
    } else if ([[_specifierDict objectForKey:kIASKTextLabelAlignment] isEqualToString:kIASKTextLabelAlignmentRight]) {
        return NSTextAlignmentRight;
    }
    if ([self.type isEqualToString:kIASKButtonSpecifier] && !self.cellImage) {
		return NSTextAlignmentCenter;
	} else if ([self.type isEqualToString:kIASKPSMultiValueSpecifier] || [self.type isEqualToString:kIASKPSTitleValueSpecifier]) {
		return NSTextAlignmentRight;
	}
	return NSTextAlignmentLeft;
}

- (NSArray *)userInterfaceIdioms {
    NSArray *idiomStrings = _specifierDict[kIASKSupportedUserInterfaceIdioms];
    if (idiomStrings.count == 0) {
        return @[@(UIUserInterfaceIdiomPhone), @(UIUserInterfaceIdiomPad)];
    }
    NSMutableArray *idioms = [NSMutableArray new];
    for (NSString *idiomString in idiomStrings) {
        if ([idiomString isEqualToString:@"Phone"]) {
            [idioms addObject:@(UIUserInterfaceIdiomPhone)];
        } else if ([idiomString isEqualToString:@"Pad"]) {
            [idioms addObject:@(UIUserInterfaceIdiomPad)];
        }
    }
    return idioms;
}

- (id)valueForKey:(NSString *)key {
	return [_specifierDict objectForKey:key];
}
@end
