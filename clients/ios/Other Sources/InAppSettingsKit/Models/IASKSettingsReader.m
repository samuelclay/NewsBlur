//
//	IASKSettingsReader.m
//	http://www.inappsettingskit.com
//
//	Copyright (c) 2009:
//	Luc Vandal, Edovia Inc., http://www.edovia.com
//	Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//	All rights reserved.
//
//	It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz,
//	as the original authors of this code. You can give credit in a blog post, a tweet or on
//	a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//	This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import "IASKSettingsReader.h"
#import "IASKSpecifier.h"

#pragma mark -
@interface IASKSettingsReader () {
}
@end

@implementation IASKSettingsReader

- (id) initWithSettingsFileNamed:(NSString*) fileName
               applicationBundle:(NSBundle*) bundle {
    self = [super init];
    if (self) {
        _applicationBundle = bundle;
        
        NSString* plistFilePath = [self locateSettingsFile: fileName];
        _settingsDictionary = [NSDictionary dictionaryWithContentsOfFile:plistFilePath];
        
        //store the bundle which we'll need later for getting localizations
        NSString* settingsBundlePath = [plistFilePath stringByDeletingLastPathComponent];
        _settingsBundle = [NSBundle bundleWithPath:settingsBundlePath];
        
        // Look for localization file
        self.localizationTable = [_settingsDictionary objectForKey:@"StringsTable"];
        if (!self.localizationTable)
        {
            // Look for localization file using filename
            self.localizationTable = [[[[plistFilePath stringByDeletingPathExtension] // removes '.plist'
                                        stringByDeletingPathExtension] // removes potential '.inApp'
                                       lastPathComponent] // strip absolute path
                                      stringByReplacingOccurrencesOfString:[self platformSuffixForInterfaceIdiom:UI_USER_INTERFACE_IDIOM()] withString:@""]; // removes potential '~device' (~ipad, ~iphone)
            if([self.settingsBundle pathForResource:self.localizationTable ofType:@"strings"] == nil){
                // Could not find the specified localization: use default
                self.localizationTable = @"Root";
            }
        }
		
		self.showPrivacySettings = NO;
		IASK_IF_IOS8_OR_GREATER
		(
		 NSArray *privacyRelatedInfoPlistKeys = @[@"NSBluetoothPeripheralUsageDescription", @"NSCalendarsUsageDescription", @"NSCameraUsageDescription", @"NSContactsUsageDescription", @"NSLocationAlwaysUsageDescription", @"NSLocationUsageDescription", @"NSLocationWhenInUseUsageDescription", @"NSMicrophoneUsageDescription", @"NSMotionUsageDescription", @"NSPhotoLibraryUsageDescription", @"NSRemindersUsageDescription", @"NSHealthShareUsageDescription", @"NSHealthUpdateUsageDescription"];
		 NSDictionary *infoDictionary = [[NSBundle mainBundle] infoDictionary];
		 if ([fileName isEqualToString:@"Root"]) {
			 for (NSString* key in privacyRelatedInfoPlistKeys) {
				 if (infoDictionary[key]) {
					 self.showPrivacySettings = YES;
					 break;
				 }
			 }
		 }
		 );
        if (self.settingsDictionary) {
            [self _reinterpretBundle:self.settingsDictionary];
        }
    }
    return self;
}

- (id)initWithFile:(NSString*)file {
    return [self initWithSettingsFileNamed:file applicationBundle:[NSBundle mainBundle]];
}

- (id)init {
    return [self initWithFile:@"Root"];
}

- (void)setHiddenKeys:(NSSet *)anHiddenKeys {
    if (_hiddenKeys != anHiddenKeys) {
        _hiddenKeys = anHiddenKeys;
        
        if (self.settingsDictionary) {
            [self _reinterpretBundle:self.settingsDictionary];
        }
    }
}

- (void)setShowPrivacySettings:(BOOL)showPrivacySettings {
	if (_showPrivacySettings != showPrivacySettings) {
		_showPrivacySettings = showPrivacySettings;
		[self _reinterpretBundle:self.settingsDictionary];
	}
}

- (NSArray*)privacySettingsSpecifiers {
	NSMutableDictionary *dict = [@{kIASKTitle: NSLocalizedStringFromTable(@"Privacy", @"IASKLocalizable", @"iOS 8+ Privacy cell: title"),
								   kIASKKey: @"IASKPrivacySettingsCellKey",
								   kIASKType: kIASKOpenURLSpecifier,
								   kIASKFile: UIApplicationOpenSettingsURLString,
								   } mutableCopy];
	NSString *subtitle = NSLocalizedStringWithDefaultValue(@"Open in Settings app", @"IASKLocalizable", [NSBundle mainBundle], @"", @"iOS 8+ Privacy cell: subtitle");
	if (subtitle.length) {
		dict [kIASKSubtitle] = subtitle;
	}
	
	return @[@[[[IASKSpecifier alloc] initWithSpecifier:@{kIASKKey: @"IASKPrivacySettingsHeaderKey", kIASKType: kIASKPSGroupSpecifier}],
			   [[IASKSpecifier alloc] initWithSpecifier:dict]]];
}

- (void)_reinterpretBundle:(NSDictionary*)settingsBundle {
    NSArray *preferenceSpecifiers	= [settingsBundle objectForKey:kIASKPreferenceSpecifiers];
    NSMutableArray *dataSource		= [NSMutableArray array];
	
	if (self.showPrivacySettings) {
		IASK_IF_IOS8_OR_GREATER
		(
		 [dataSource addObjectsFromArray:self.privacySettingsSpecifiers];
		 );
	}

    for (NSDictionary *specifierDictionary in preferenceSpecifiers) {
        IASKSpecifier *newSpecifier = [[IASKSpecifier alloc] initWithSpecifier:specifierDictionary];
        newSpecifier.settingsReader = self;
        [newSpecifier sortIfNeeded];

        if ([self.hiddenKeys containsObject:newSpecifier.key]) {
            continue;
        }
        NSString *type = newSpecifier.type;
        if ([type isEqualToString:kIASKPSGroupSpecifier]
            || [type isEqualToString:kIASKPSRadioGroupSpecifier]) {

            NSMutableArray *newArray = [NSMutableArray array];
            [newArray addObject:newSpecifier];
            [dataSource addObject:newArray];

            if ([type isEqualToString:kIASKPSRadioGroupSpecifier]) {
                for (NSString *value in newSpecifier.multipleValues) {
                    IASKSpecifier *valueSpecifier =
                        [[IASKSpecifier alloc] initWithSpecifier:specifierDictionary radioGroupValue:value];
                    valueSpecifier.settingsReader = self;
                    [valueSpecifier sortIfNeeded];
                    [newArray addObject:valueSpecifier];
                }
            }
        }
        else {
            if (dataSource.count == 0 || (dataSource.count == 1 && self.showPrivacySettings)) {
                [dataSource addObject:[NSMutableArray array]];
            }
            
            if ([newSpecifier.userInterfaceIdioms containsObject:@(UI_USER_INTERFACE_IDIOM())]) {
                [(NSMutableArray*)dataSource.lastObject addObject:newSpecifier];
            }
        }
    }
    [self setDataSource:dataSource];
}

- (BOOL)_sectionHasHeading:(NSInteger)section {
    return [self headerSpecifierForSection:section] != nil;
}

/// Returns the specifier describing the section's header, or nil if there is no header.
- (IASKSpecifier *)headerSpecifierForSection:(NSInteger)section {
    IASKSpecifier *specifier = self.dataSource[section][kIASKSectionHeaderIndex];
    if ([specifier.type isEqualToString:kIASKPSGroupSpecifier]
        || [specifier.type isEqualToString:kIASKPSRadioGroupSpecifier]) {
        return specifier;
    }
    return nil;
}

- (NSInteger)numberOfSections {
    return self.dataSource.count;
}

- (NSInteger)numberOfRowsForSection:(NSInteger)section {
    int headingCorrection = [self _sectionHasHeading:section] ? 1 : 0;
    return [(NSArray*)[[self dataSource] objectAtIndex:section] count] - headingCorrection;
}

- (IASKSpecifier*)specifierForIndexPath:(NSIndexPath*)indexPath {
    int headingCorrection = [self _sectionHasHeading:indexPath.section] ? 1 : 0;
    
    IASKSpecifier *specifier = [[[self dataSource] objectAtIndex:indexPath.section] objectAtIndex:(indexPath.row+headingCorrection)];
    specifier.settingsReader = self;
    return specifier;
}

- (NSIndexPath*)indexPathForKey:(NSString *)key {
    for (NSUInteger sectionIndex = 0; sectionIndex < self.dataSource.count; sectionIndex++) {
        NSArray *section = [self.dataSource objectAtIndex:sectionIndex];
        for (NSUInteger rowIndex = 0; rowIndex < section.count; rowIndex++) {
            IASKSpecifier *specifier = (IASKSpecifier*)[section objectAtIndex:rowIndex];
            if ([specifier isKindOfClass:[IASKSpecifier class]] && [specifier.key isEqualToString:key]) {
                NSUInteger correctedRowIndex = rowIndex - [self _sectionHasHeading:sectionIndex];
                return [NSIndexPath indexPathForRow:correctedRowIndex inSection:sectionIndex];
            }
        }
    }
    return nil;
}

- (IASKSpecifier*)specifierForKey:(NSString*)key {
    for (NSArray *specifiers in _dataSource) {
        for (id sp in specifiers) {
            if ([sp isKindOfClass:[IASKSpecifier class]]) {
                if ([[sp key] isEqualToString:key]) {
                    return sp;
                }
            }
        }
    }
    return nil;
}

- (NSString*)titleForSection:(NSInteger)section {
    return [self titleForStringId:[self headerSpecifierForSection:section].title];
}

- (NSString*)keyForSection:(NSInteger)section {
    return [self headerSpecifierForSection:section].key;
}

- (NSString*)footerTextForSection:(NSInteger)section {
    return [self titleForStringId:[self headerSpecifierForSection:section].footerText];
}

- (NSString*)titleForStringId:(NSString*)stringId {
    return [self.settingsBundle localizedStringForKey:stringId value:stringId table:self.localizationTable];
}

- (NSString*)pathForImageNamed:(NSString*)image {
    return [[self.settingsBundle bundlePath] stringByAppendingPathComponent:image];
}

- (NSString *)platformSuffixForInterfaceIdiom:(UIUserInterfaceIdiom) interfaceIdiom {
    switch (interfaceIdiom) {
        case UIUserInterfaceIdiomPad: return @"~ipad";
        case UIUserInterfaceIdiomPhone: return @"~iphone";
		default: return @"~iphone";
    }
}

- (NSString *)file:(NSString *)file
        withBundle:(NSString *)bundle
            suffix:(NSString *)suffix
         extension:(NSString *)extension {
    
	bundle = [self.applicationBundle pathForResource:bundle ofType:nil];
    file = [file stringByAppendingFormat:@"%@%@", suffix, extension];
    return [bundle stringByAppendingPathComponent:file];
}

- (NSString *)locateSettingsFile: (NSString *)file {
    static NSString* const kIASKBundleFolder = @"Settings.bundle";
    static NSString* const kIASKBundleFolderAlt = @"InAppSettings.bundle";
    
    static NSString* const kIASKBundleLocaleFolderExtension = @".lproj";

    // The file is searched in the following order:
    //
    // InAppSettings.bundle/FILE~DEVICE.inApp.plist
    // InAppSettings.bundle/FILE.inApp.plist
    // InAppSettings.bundle/FILE~DEVICE.plist
    // InAppSettings.bundle/FILE.plist
    // Settings.bundle/FILE~DEVICE.inApp.plist
    // Settings.bundle/FILE.inApp.plist
    // Settings.bundle/FILE~DEVICE.plist
    // Settings.bundle/FILE.plist
    //
    // where DEVICE is either "iphone" or "ipad" depending on the current
    // interface idiom.
    //
    // Settings.app uses the ~DEVICE suffixes since iOS 4.0.  There are some
    // differences from this implementation:
    // - For an iPhone-only app running on iPad, Settings.app will not use the
    //	 ~iphone suffix.  There is no point in using these suffixes outside
    //	 of universal apps anyway.
    // - This implementation uses the device suffixes on iOS 3.x as well.
    // - also check current locale (short only)
    
    NSArray *settingsBundleNames = @[kIASKBundleFolderAlt, kIASKBundleFolder];
    
    NSArray *extensions = @[@".inApp.plist", @".plist"];
    
    NSArray *plattformSuffixes = @[[self platformSuffixForInterfaceIdiom:UI_USER_INTERFACE_IDIOM()],
                                   @""];
    
    NSArray *preferredLanguages = [NSLocale preferredLanguages];
    NSArray *languageFolders = @[[ (preferredLanguages.count ? [preferredLanguages objectAtIndex:0] : @"en") stringByAppendingString:kIASKBundleLocaleFolderExtension],
                                 @""];

    
    NSString *path = nil;
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    for (NSString *settingsBundleName in settingsBundleNames) {
        for (NSString *extension in extensions) {
            for (NSString *platformSuffix in plattformSuffixes) {
                for (NSString *languageFolder in languageFolders) {
                    path = [self file:file
                           withBundle:[settingsBundleName stringByAppendingPathComponent:languageFolder]
                               suffix:platformSuffix
                            extension:extension];
                    if ([fileManager fileExistsAtPath:path]) {
                        goto exitFromNestedLoop;
                    }
                }
            }
        }
    }
    
exitFromNestedLoop:
    return path;
}

@end
