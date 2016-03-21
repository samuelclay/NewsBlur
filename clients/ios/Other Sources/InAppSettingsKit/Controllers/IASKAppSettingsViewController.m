//
//  IASKAppSettingsViewController.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2009-2010:
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


#import "IASKAppSettingsViewController.h"
#import "IASKSettingsReader.h"
#import "IASKSettingsStoreUserDefaults.h"
#import "IASKPSSliderSpecifierViewCell.h"
#import "IASKPSTextFieldSpecifierViewCell.h"
#import "IASKSwitch.h"
#import "IASKSlider.h"
#import "IASKSpecifier.h"
#import "IASKSpecifierValuesViewController.h"
#import "IASKTextField.h"
#import "IASKMultipleValueSelection.h"

#if !__has_feature(objc_arc)
#error "IASK needs ARC"
#endif

static NSString *kIASKCredits = @"Powered by InAppSettingsKit"; // Leave this as-is!!!

#define kIASKSpecifierValuesViewControllerIndex       0
#define kIASKSpecifierChildViewControllerIndex        1

#define kIASKCreditsViewWidth                         285

CGRect IASKCGRectSwap(CGRect rect);

@interface IASKAppSettingsViewController () {
    IASKSettingsReader		*_settingsReader;
    id<IASKSettingsStore>  _settingsStore;
    
    id                      _currentFirstResponder;
    __weak UIViewController *_currentChildViewController;
    BOOL _reloadDisabled;
	/// The selected index for every group (in case it's a radio group).
	NSArray *_selections;
}

@property (nonatomic, strong) id currentFirstResponder;

- (void)_textChanged:(id)sender;
- (void)synchronizeSettings;
- (void)userDefaultsDidChange;
- (void)reload;
@end

@implementation IASKAppSettingsViewController
//synthesize properties from protocol
@synthesize settingsReader = _settingsReader;
@synthesize settingsStore = _settingsStore;
@synthesize file = _file;

#pragma mark accessors
- (IASKSettingsReader*)settingsReader {
	if (!_settingsReader) {
		_settingsReader = [[IASKSettingsReader alloc] initWithFile:self.file];
		if (self.neverShowPrivacySettings) {
			_settingsReader.showPrivacySettings = NO;
		}
	}
	return _settingsReader;
}

- (id<IASKSettingsStore>)settingsStore {
	if (!_settingsStore) {
		_settingsStore = [[IASKSettingsStoreUserDefaults alloc] init];
	}
	return _settingsStore;
}

- (NSString*)file {
	if (!_file) {
		self.file = @"Root";
	}
	return _file;
}

- (void)setFile:(NSString *)file {
    _file = [file copy];
    self.tableView.contentOffset = CGPointMake(0, -self.tableView.contentInset.top);
    self.settingsReader = nil; // automatically initializes itself
    if (!_reloadDisabled) {
		[self.tableView reloadData];
		[self createSelections];
	}
}

- (void)createSelections {
	NSMutableArray *sectionSelection = [NSMutableArray new];
	for (int i = 0; i < _settingsReader.numberOfSections; i++) {
		IASKSpecifier *specifier = [self.settingsReader headerSpecifierForSection:i];
		if ([specifier.type isEqualToString:kIASKPSRadioGroupSpecifier]) {
			IASKMultipleValueSelection *selection = [IASKMultipleValueSelection new];
			selection.tableView = self.tableView;
			selection.specifier = specifier;
			selection.section = i;
			selection.settingsStore = self.settingsStore;
			[sectionSelection addObject:selection];
		} else {
			[sectionSelection addObject:[NSNull null]];
		}
	}
	_selections = sectionSelection;
}

- (BOOL)isPad {
	BOOL isPad = NO;
#if (__IPHONE_OS_VERSION_MAX_ALLOWED >= 30200)
	isPad = UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad;
#endif
	return isPad;
}

#pragma mark standard view controller methods
- (id)init {
    return [self initWithStyle:UITableViewStyleGrouped];
}

- (id)initWithStyle:(UITableViewStyle)style {
    if (style != UITableViewStyleGrouped) {
        NSLog(@"WARNING: only UITableViewStyleGrouped style is supported by InAppSettingsKit.");
    }
    if ((self = [super initWithStyle:style])) {
		[self configure];
    }
    return self;
}

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if (nibNameOrNil) {
		NSLog (@"%@ is now deprecated, we are moving away from nibs.", NSStringFromSelector(_cmd));
		self = [super initWithStyle:UITableViewStyleGrouped];
	} else {
		self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
	}
	if (self) {
		[self configure];
	}
	return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder {
	if ((self = [super initWithCoder:aDecoder])) {
		[self configure];
		_showDoneButton = NO;
	}
	return self;
}

- (void)configure {
	_reloadDisabled = NO;
	_showDoneButton = YES;
	_showCreditsFooter = YES; // display credits for InAppSettingsKit creators
}

- (void)viewDidLoad {
    [super viewDidLoad];
    if ([self isPad]) {
#if __IPHONE_OS_VERSION_MAX_ALLOWED >= 70000
        if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1)	// don't use etched style on iOS 7
#endif
            self.tableView.separatorStyle = UITableViewCellSeparatorStyleSingleLineEtched;
    }
    UITapGestureRecognizer *tapGesture = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(singleTapToEndEdit:)];   
    tapGesture.cancelsTouchesInView = NO;
    [self.tableView addGestureRecognizer:tapGesture];
}

- (void)viewWillAppear:(BOOL)animated {
	// if there's something selected, the value might have changed
	// so reload that row
	NSIndexPath *selectedIndexPath = [self.tableView indexPathForSelectedRow];
	if(selectedIndexPath) {
		[self.tableView reloadRowsAtIndexPaths:[NSArray arrayWithObject:selectedIndexPath] 
							  withRowAnimation:UITableViewRowAnimationNone];
		// and reselect it, so we get the nice default deselect animation from UITableViewController
		[self.tableView selectRowAtIndexPath:selectedIndexPath animated:NO scrollPosition:UITableViewScrollPositionNone];
	}
	
	if (_showDoneButton) {
		UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone 
																					target:self 
																					action:@selector(dismiss:)];
		self.navigationItem.rightBarButtonItem = buttonItem;
	} 
	if (!self.title) {
		self.title = NSLocalizedString(@"Settings", @"");
	}
	
	if ([self.settingsStore isKindOfClass:[IASKSettingsStoreUserDefaults class]]) {
		NSNotificationCenter *dc = NSNotificationCenter.defaultCenter;
		IASKSettingsStoreUserDefaults *udSettingsStore = (id)self.settingsStore;
		[dc addObserver:self selector:@selector(userDefaultsDidChange) name:NSUserDefaultsDidChangeNotification object:udSettingsStore.defaults];
		[dc addObserver:self selector:@selector(didChangeSettingViaIASK:) name:kIASKAppSettingChanged object:nil];
		[self userDefaultsDidChange]; // force update in case of changes while we were hidden
	}
    
    if (self.delegate && [self.delegate conformsToProtocol:@protocol(IASKSettingsDelegate)]) {
        [self.delegate settingsViewControllerWillAppear:self];
    }
    
	[super viewWillAppear:animated];
}

- (CGSize)contentSizeForViewInPopover {
    return [[self view] sizeThatFits:CGSizeMake(320, 2000)];
}

- (void)viewDidAppear:(BOOL)animated {
	[super viewDidAppear:animated];

	NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
	[dc addObserver:self selector:@selector(synchronizeSettings) name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
	[dc addObserver:self selector:@selector(reload) name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
	[dc addObserver:self selector:@selector(synchronizeSettings) name:UIApplicationWillTerminateNotification object:[UIApplication sharedApplication]];

	[self.tableView beginUpdates];
	[self.tableView endUpdates];
}

- (void)viewWillDisappear:(BOOL)animated {
	[NSObject cancelPreviousPerformRequestsWithTarget:self];

	// hide the keyboard
    [self.currentFirstResponder resignFirstResponder];
	
	[super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
	NSNotificationCenter *dc = [NSNotificationCenter defaultCenter];
	if ([self.settingsStore isKindOfClass:[IASKSettingsStoreUserDefaults class]]) {
		IASKSettingsStoreUserDefaults *udSettingsStore = (id)self.settingsStore;
		[dc removeObserver:self name:NSUserDefaultsDidChangeNotification object:udSettingsStore.defaults];
		[dc removeObserver:self name:kIASKAppSettingChanged object:self];
	}
	[dc removeObserver:self name:UIApplicationDidEnterBackgroundNotification object:[UIApplication sharedApplication]];
	[dc removeObserver:self name:UIApplicationWillEnterForegroundNotification object:[UIApplication sharedApplication]];
	[dc removeObserver:self name:UIApplicationWillTerminateNotification object:[UIApplication sharedApplication]];

	[super viewDidDisappear:animated];
}

- (void)setHiddenKeys:(NSSet *)theHiddenKeys {
	[self setHiddenKeys:theHiddenKeys animated:NO];
}


- (void)setHiddenKeys:(NSSet*)theHiddenKeys animated:(BOOL)animated {
    if (_hiddenKeys != theHiddenKeys) {
        NSSet *oldHiddenKeys = _hiddenKeys;
        _hiddenKeys = theHiddenKeys;
        
        if (animated) {			
            NSMutableSet *showKeys = [NSMutableSet setWithSet:oldHiddenKeys];
            [showKeys minusSet:theHiddenKeys];
            
            NSMutableSet *hideKeys = [NSMutableSet setWithSet:theHiddenKeys];
            [hideKeys minusSet:oldHiddenKeys];
            
            // calculate rows to be deleted
            NSMutableArray *hideIndexPaths = [NSMutableArray array];
            for (NSString *key in hideKeys) {
                NSIndexPath *indexPath = [self.settingsReader indexPathForKey:key];
                if (indexPath) {
                    [hideIndexPaths addObject:indexPath];
                }
            }
            
            // calculate sections to be deleted
            NSMutableIndexSet *hideSections = [NSMutableIndexSet indexSet];
            for (NSInteger section = 0; section < [self numberOfSectionsInTableView:self.tableView ]; section++) {
                NSInteger rowsInSection = 0;
                for (NSIndexPath *indexPath in hideIndexPaths) {
                    if (indexPath.section == section) {
                        rowsInSection++;
                    }
                }
                if (rowsInSection && rowsInSection >= [self.settingsReader numberOfRowsForSection:section]) {
                    [hideSections addIndex:section];
                }
            }
			
            // set the datasource
            self.settingsReader.hiddenKeys = theHiddenKeys;
            
            
            // calculate rows to be inserted
            NSMutableArray *showIndexPaths = [NSMutableArray array];
            for (NSString *key in showKeys) {
                NSIndexPath *indexPath = [self.settingsReader indexPathForKey:key];
                if (indexPath) {
                    [showIndexPaths addObject:indexPath];
                }
            }
            
            // calculate sections to be inserted
            NSMutableIndexSet *showSections = [NSMutableIndexSet indexSet];
            for (NSInteger section = 0; section < [self.settingsReader numberOfSections]; section++) {
                NSInteger rowsInSection = 0;
                for (NSIndexPath *indexPath in showIndexPaths) {
                    if (indexPath.section == section) {
                        rowsInSection++;
                    }
                }
                if (rowsInSection && rowsInSection >= [self.settingsReader numberOfRowsForSection:section]) {
                    [showSections addIndex:section];
                }
			}
			
			if (hideSections.count || hideIndexPaths.count || showSections.count || showIndexPaths.count) {
				[self.tableView beginUpdates];
				UITableViewRowAnimation animation = animated ? UITableViewRowAnimationAutomatic : UITableViewRowAnimationNone;
				if (hideSections.count) {
					[self.tableView deleteSections:hideSections withRowAnimation:animation];
				}
				if (hideIndexPaths) {
					[self.tableView deleteRowsAtIndexPaths:hideIndexPaths withRowAnimation:animation];
				}
				if (showSections.count) {
					[self.tableView insertSections:showSections withRowAnimation:animation];
				}
				if (showIndexPaths) {
					[self.tableView insertRowsAtIndexPaths:showIndexPaths withRowAnimation:animation];
				}
				[self.tableView endUpdates];
			}
		} else {
			self.settingsReader.hiddenKeys = theHiddenKeys;
			if (!_reloadDisabled) [self.tableView reloadData];
		}
	}
	UIViewController *childViewController = _currentChildViewController;
    if([childViewController respondsToSelector:@selector(setHiddenKeys:animated:)]) {
        [(id)childViewController setHiddenKeys:theHiddenKeys animated:animated];
    }
}

- (void)setNeverShowPrivacySettings:(BOOL)neverShowPrivacySettings {
	_neverShowPrivacySettings = neverShowPrivacySettings;
	self.settingsReader = nil;
	[self reload];
}


- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark -
#pragma mark Actions

- (void)dismiss:(id)sender {
	[self.settingsStore synchronize];
	
	if (self.delegate && [self.delegate conformsToProtocol:@protocol(IASKSettingsDelegate)]) {
		[self.delegate settingsViewControllerDidEnd:self];
	}
}

- (void)toggledValue:(id)sender {
    IASKSwitch *toggle    = (IASKSwitch*)sender;
    IASKSpecifier *spec   = [_settingsReader specifierForKey:[toggle key]];
    
    if ([toggle isOn]) {
        if ([spec trueValue] != nil) {
            [self.settingsStore setObject:[spec trueValue] forKey:[toggle key]];
        }
        else {
            [self.settingsStore setBool:YES forKey:[toggle key]]; 
        }
    }
    else {
        if ([spec falseValue] != nil) {
            [self.settingsStore setObject:[spec falseValue] forKey:[toggle key]];
        }
        else {
            [self.settingsStore setBool:NO forKey:[toggle key]]; 
        }
    }
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:[toggle key]
                                                      userInfo:[NSDictionary dictionaryWithObject:[self.settingsStore objectForKey:[toggle key]]
                                                                                           forKey:[toggle key]]];
}

- (void)sliderChangedValue:(id)sender {
    IASKSlider *slider = (IASKSlider*)sender;
    [self.settingsStore setFloat:[slider value] forKey:[slider key]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:[slider key]
                                                      userInfo:[NSDictionary dictionaryWithObject:[NSNumber numberWithFloat:[slider value]]
                                                                                           forKey:[slider key]]];
}


#pragma mark -
#pragma mark UITableView Functions

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
	return [self.settingsReader numberOfSections];
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.settingsReader numberOfRowsForSection:section];
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
    if ([[specifier type] isEqualToString:kIASKCustomViewSpecifier]) {
		if ([self.delegate respondsToSelector:@selector(tableView:heightForSpecifier:)]) {
			return [self.delegate tableView:tableView heightForSpecifier:specifier];
		} else {
			return 0;
		}
	}
	IASK_IF_IOS7_OR_GREATER
	(
	 NSDictionary *rowHeights = @{UIContentSizeCategoryExtraSmall: @(44),
								  UIContentSizeCategorySmall: @(44),
								  UIContentSizeCategoryMedium: @(44),
								  UIContentSizeCategoryLarge: @(44),
								  UIContentSizeCategoryExtraLarge: @(47)};
	 return (CGFloat)[rowHeights[UIApplication.sharedApplication.preferredContentSizeCategory] doubleValue] ? : 51;
	);
	return 44;
}

- (NSString *)tableView:(UITableView*)tableView titleForHeaderInSection:(NSInteger)section {
    NSString *header = [self.settingsReader titleForSection:section];
	if (0 == header.length) {
		return nil;
	}
	return header;
}

- (UIView *)tableView:(UITableView*)tableView viewForHeaderInSection:(NSInteger)section {
	if ([self.delegate respondsToSelector:@selector(settingsViewController:tableView:viewForHeaderForSection:)]) {
		return [self.delegate settingsViewController:self tableView:tableView viewForHeaderForSection:section];
	} else {
		return nil;
	}
}

- (CGFloat)tableView:(UITableView*)tableView heightForHeaderInSection:(NSInteger)section {
	if ([self tableView:tableView viewForHeaderInSection:section] && [self.delegate respondsToSelector:@selector(settingsViewController:tableView:heightForHeaderForSection:)]) {
		CGFloat result = [self.delegate settingsViewController:self tableView:tableView heightForHeaderForSection:section];
		if (result > 0) {
			return result;
		}
		
	}
	return UITableViewAutomaticDimension;
}

- (NSString *)tableView:(UITableView *)tableView titleForFooterInSection:(NSInteger)section
{
	NSString *footerText = [self.settingsReader footerTextForSection:section];
	if (_showCreditsFooter && (section == [self.settingsReader numberOfSections]-1)) {
		// show credits since this is the last section
		if ((footerText == nil) || ([footerText length] == 0)) {
			// show the credits on their own
			return kIASKCredits;
		} else {
			// show the credits below the app's FooterText
			return [NSString stringWithFormat:@"%@\n\n%@", footerText, kIASKCredits];
		}
	} else {
		return footerText;
	}
}


- (UITableViewCell*)tableView:(UITableView *)tableView newCellForSpecifier:(IASKSpecifier*)specifier {

	NSString *identifier = [NSString stringWithFormat:@"%@-%ld-%d", specifier.type, (long)specifier.textAlignment, !!specifier.subtitle.length];
	UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:identifier];
	if (cell) {
		return cell;
	}
	UITableViewCellStyle style = (specifier.textAlignment == NSTextAlignmentLeft || specifier.subtitle.length) ? UITableViewCellStyleSubtitle : UITableViewCellStyleDefault;
	if ([identifier hasPrefix:kIASKPSToggleSwitchSpecifier]) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:kIASKPSToggleSwitchSpecifier];
		cell.accessoryView = [[IASKSwitch alloc] initWithFrame:CGRectMake(0, 0, 79, 27)];
		[((IASKSwitch*)cell.accessoryView) addTarget:self action:@selector(toggledValue:) forControlEvents:UIControlEventValueChanged];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	else if ([identifier hasPrefix:kIASKPSMultiValueSpecifier] || [identifier hasPrefix:kIASKPSTitleValueSpecifier]) {
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue1 reuseIdentifier:identifier];
		cell.accessoryType = [identifier hasPrefix:kIASKPSMultiValueSpecifier] ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	}
	else if ([identifier hasPrefix:kIASKPSTextFieldSpecifier]) {
		cell = [[IASKPSTextFieldSpecifierViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kIASKPSTextFieldSpecifier];
		[((IASKPSTextFieldSpecifierViewCell*)cell).textField addTarget:self action:@selector(_textChanged:) forControlEvents:UIControlEventEditingChanged];
	}
	else if ([identifier hasPrefix:kIASKPSSliderSpecifier]) {
        cell = [[IASKPSSliderSpecifierViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:kIASKPSSliderSpecifier];
	} else if ([identifier hasPrefix:kIASKPSChildPaneSpecifier]) {
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
	} else if ([identifier isEqualToString:kIASKMailComposeSpecifier]) {
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];
		[cell setAccessoryType:UITableViewCellAccessoryDisclosureIndicator];
	} else {
		cell = [[UITableViewCell alloc] initWithStyle:style reuseIdentifier:identifier];

		if ([identifier isEqualToString:kIASKOpenURLSpecifier]) {
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
	}
	IASK_IF_PRE_IOS6(cell.textLabel.minimumFontSize = kIASKMinimumFontSize;
					 cell.detailTextLabel.minimumFontSize = kIASKMinimumFontSize;);
	IASK_IF_IOS6_OR_GREATER(cell.textLabel.minimumScaleFactor = kIASKMinimumFontSize / cell.textLabel.font.pointSize;
							cell.detailTextLabel.minimumScaleFactor = kIASKMinimumFontSize / cell.detailTextLabel.font.pointSize;);
	return cell;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
	IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
	if ([specifier.type isEqualToString:kIASKCustomViewSpecifier] && [self.delegate respondsToSelector:@selector(tableView:cellForSpecifier:)]) {
		UITableViewCell* cell = [self.delegate tableView:tableView cellForSpecifier:specifier];
		assert(nil != cell && "delegate must return a UITableViewCell for custom cell types");
		return cell;
	}
	
	UITableViewCell* cell = [self tableView:tableView newCellForSpecifier:specifier];

	if ([specifier.type isEqualToString:kIASKPSToggleSwitchSpecifier]) {
		cell.textLabel.text = specifier.title;
		cell.detailTextLabel.text = specifier.subtitle;

		id currentValue = [self.settingsStore objectForKey:specifier.key];
		BOOL toggleState;
		if (currentValue) {
			if ([currentValue isEqual:specifier.trueValue]) {
				toggleState = YES;
			} else if ([currentValue isEqual:specifier.falseValue]) {
				toggleState = NO;
			} else {
				toggleState = [currentValue boolValue];
			}
		} else {
			toggleState = specifier.defaultBoolValue;
		}
		IASKSwitch *toggle = (IASKSwitch*)cell.accessoryView;
		toggle.on = toggleState;
		toggle.key = specifier.key;
	}
	else if ([specifier.type isEqualToString:kIASKPSMultiValueSpecifier]) {
		cell.textLabel.text = specifier.title;
		cell.detailTextLabel.text = [[specifier titleForCurrentValue:[self.settingsStore objectForKey:specifier.key] != nil ? 
									  [self.settingsStore objectForKey:specifier.key] : specifier.defaultValue] description];
	}
	else if ([specifier.type isEqualToString:kIASKPSTitleValueSpecifier]) {
		cell.textLabel.text = specifier.title;
		id value = [self.settingsStore objectForKey:specifier.key] ? : specifier.defaultValue;
		
		NSString *stringValue;
		if (specifier.multipleValues || specifier.multipleTitles) {
			stringValue = [specifier titleForCurrentValue:value];
		} else {
			stringValue = [value description];
		}
		
		cell.detailTextLabel.text = stringValue;
		cell.userInteractionEnabled = NO;
	}
	else if ([specifier.type isEqualToString:kIASKPSTextFieldSpecifier]) {
		cell.textLabel.text = specifier.title;
		
		NSString *textValue = [self.settingsStore objectForKey:specifier.key] != nil ? [self.settingsStore objectForKey:specifier.key] : specifier.defaultStringValue;
		if (textValue && ![textValue isMemberOfClass:[NSString class]]) {
			textValue = [NSString stringWithFormat:@"%@", textValue];
		}
		IASKTextField *textField = ((IASKPSTextFieldSpecifierViewCell*)cell).textField;
		textField.text = textValue;
		textField.key = specifier.key;
		textField.delegate = self;
		textField.secureTextEntry = [specifier isSecure];
		textField.keyboardType = specifier.keyboardType;
		textField.autocapitalizationType = specifier.autocapitalizationType;
		if([specifier isSecure]){
			textField.autocorrectionType = UITextAutocorrectionTypeNo;
		} else {
			textField.autocorrectionType = specifier.autoCorrectionType;
		}
		textField.textAlignment = specifier.textAlignment;
		textField.adjustsFontSizeToFitWidth = specifier.adjustsFontSizeToFitWidth;
	}
	else if ([specifier.type isEqualToString:kIASKPSSliderSpecifier]) {
		if (specifier.minimumValueImage.length > 0) {
			((IASKPSSliderSpecifierViewCell*)cell).minImage.image = [UIImage imageWithContentsOfFile:[_settingsReader pathForImageNamed:specifier.minimumValueImage]];
		}
		
		if (specifier.maximumValueImage.length > 0) {
			((IASKPSSliderSpecifierViewCell*)cell).maxImage.image = [UIImage imageWithContentsOfFile:[_settingsReader pathForImageNamed:specifier.maximumValueImage]];
		}
		
		IASKSlider *slider = ((IASKPSSliderSpecifierViewCell*)cell).slider;
		slider.minimumValue = specifier.minimumValue;
		slider.maximumValue = specifier.maximumValue;
		slider.value =	[self.settingsStore objectForKey:specifier.key] != nil ? [[self.settingsStore objectForKey:specifier.key] floatValue] : [specifier.defaultValue floatValue];
		[slider addTarget:self action:@selector(sliderChangedValue:) forControlEvents:UIControlEventValueChanged];
		slider.key = specifier.key;
		[cell setNeedsLayout];
	}
	else if ([specifier.type isEqualToString:kIASKPSChildPaneSpecifier]) {
		cell.textLabel.text = specifier.title;
		cell.detailTextLabel.text = specifier.subtitle;
	} else if ([specifier.type isEqualToString:kIASKOpenURLSpecifier] || [specifier.type isEqualToString:kIASKMailComposeSpecifier]) {
		cell.textLabel.text = specifier.title;
		cell.detailTextLabel.text = specifier.subtitle ? : [specifier.defaultValue description];
		cell.accessoryType = (specifier.textAlignment == NSTextAlignmentLeft) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	} else if ([specifier.type isEqualToString:kIASKButtonSpecifier]) {
		NSString *value = [self.settingsStore objectForKey:specifier.key];
		cell.textLabel.text = [value isKindOfClass:[NSString class]] ? [self.settingsReader titleForStringId:value] : specifier.title;
		cell.detailTextLabel.text = specifier.subtitle;
		IASK_IF_IOS7_OR_GREATER
		(if (specifier.textAlignment != NSTextAlignmentLeft) {
			cell.textLabel.textColor = tableView.tintColor;
		});
		cell.textLabel.textAlignment = specifier.textAlignment;
		cell.accessoryType = (specifier.textAlignment == NSTextAlignmentLeft) ? UITableViewCellAccessoryDisclosureIndicator : UITableViewCellAccessoryNone;
	} else if ([specifier.type isEqualToString:kIASKPSRadioGroupSpecifier]) {
		NSInteger index = [specifier.multipleValues indexOfObject:specifier.radioGroupValue];
		cell.textLabel.text = [self.settingsReader titleForStringId:specifier.multipleTitles[index]];
		[_selections[indexPath.section] updateSelectionInCell:cell indexPath:indexPath];
	} else {
		cell.textLabel.text = specifier.title;
	}
    
	cell.imageView.image = specifier.cellImage;
	cell.imageView.highlightedImage = specifier.highlightedCellImage;
    
	if (![specifier.type isEqualToString:kIASKPSMultiValueSpecifier] && ![specifier.type isEqualToString:kIASKPSTitleValueSpecifier] && ![specifier.type isEqualToString:kIASKPSTextFieldSpecifier]) {
		cell.textLabel.textAlignment = specifier.textAlignment;
	}
	cell.detailTextLabel.textAlignment = specifier.textAlignment;
	cell.textLabel.adjustsFontSizeToFitWidth = specifier.adjustsFontSizeToFitWidth;
	cell.detailTextLabel.adjustsFontSizeToFitWidth = specifier.adjustsFontSizeToFitWidth;
    return cell;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
	//create a set of specifier types that can't be selected
	static NSSet* noSelectionTypes = nil;
	if(nil == noSelectionTypes) {
		noSelectionTypes = [NSSet setWithObjects:kIASKPSToggleSwitchSpecifier, kIASKPSSliderSpecifier, nil];
	}
  
	IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
	if([noSelectionTypes containsObject:specifier.type]) {
		return nil;
	} else {
		return indexPath;
	}
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    IASKSpecifier *specifier  = [self.settingsReader specifierForIndexPath:indexPath];
    
    //switches and sliders can't be selected (should be captured by tableView:willSelectRowAtIndexPath: delegate method)
    assert(![[specifier type] isEqualToString:kIASKPSToggleSwitchSpecifier]);
    assert(![[specifier type] isEqualToString:kIASKPSSliderSpecifier]);
    
    if ([[specifier type] isEqualToString:kIASKPSMultiValueSpecifier]) {
        IASKSpecifierValuesViewController *targetViewController = [[IASKSpecifierValuesViewController alloc] init];
        [targetViewController setCurrentSpecifier:specifier];
        targetViewController.settingsReader = self.settingsReader;
        targetViewController.settingsStore = self.settingsStore;
		IASK_IF_IOS7_OR_GREATER(targetViewController.view.tintColor = self.view.tintColor;)
        _currentChildViewController = targetViewController;
        [[self navigationController] pushViewController:targetViewController animated:YES];
        
    } else if ([[specifier type] isEqualToString:kIASKPSTextFieldSpecifier]) {
        IASKPSTextFieldSpecifierViewCell *textFieldCell = (id)[tableView cellForRowAtIndexPath:indexPath];
        [textFieldCell.textField becomeFirstResponder];

    } else if ([[specifier type] isEqualToString:kIASKPSChildPaneSpecifier]) {
        if ([specifier viewControllerStoryBoardID]){
            NSString *storyBoardFileFromSpecifier = [specifier viewControllerStoryBoardFile];
            storyBoardFileFromSpecifier = storyBoardFileFromSpecifier && storyBoardFileFromSpecifier.length > 0 ? storyBoardFileFromSpecifier : [[NSBundle mainBundle].infoDictionary objectForKey:@"UIMainStoryboardFile"];
			UIStoryboard *storyBoard = [UIStoryboard storyboardWithName:storyBoardFileFromSpecifier bundle:nil];
			UIViewController * vc = [storyBoard instantiateViewControllerWithIdentifier:[specifier viewControllerStoryBoardID]];
			IASK_IF_IOS7_OR_GREATER(vc.view.tintColor = self.view.tintColor;)
            [self.navigationController pushViewController:vc animated:YES];
			return;
		}
        
        Class vcClass = [specifier viewControllerClass];
        if (vcClass) {
            SEL initSelector = [specifier viewControllerSelector];
            if (!initSelector) {
                initSelector = @selector(init);
            }
            UIViewController * vc = [vcClass alloc];
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
            vc = [vc performSelector:initSelector withObject:[specifier file] withObject:specifier];
#pragma clang diagnostic pop
            if ([vc respondsToSelector:@selector(setDelegate:)]) {
                [vc performSelector:@selector(setDelegate:) withObject:self.delegate];
            }
            if ([vc respondsToSelector:@selector(setSettingsStore:)]) {
                [vc performSelector:@selector(setSettingsStore:) withObject:self.settingsStore];
            }
			IASK_IF_IOS7_OR_GREATER(vc.view.tintColor = self.view.tintColor;)
            [self.navigationController pushViewController:vc animated:YES];
            return;
        }
        
        if (nil == [specifier file]) {
            [tableView deselectRowAtIndexPath:indexPath animated:YES];
            return;
        }
        
        _reloadDisabled = YES; // Disable internal unnecessary reloads
        
        IASKAppSettingsViewController *targetViewController = [[[self class] alloc] init];
        targetViewController.showDoneButton = NO;
        targetViewController.showCreditsFooter = NO; // Does not reload the tableview (but next setters do it)
        targetViewController.delegate = self.delegate;
        targetViewController.settingsStore = self.settingsStore;
        targetViewController.file = specifier.file;
        targetViewController.hiddenKeys = self.hiddenKeys;
        targetViewController.title = specifier.title;
		IASK_IF_IOS7_OR_GREATER(targetViewController.view.tintColor = self.view.tintColor;)
        _currentChildViewController = targetViewController;
        
        _reloadDisabled = NO;
		
        [[self navigationController] pushViewController:targetViewController animated:YES];
        
    } else if ([[specifier type] isEqualToString:kIASKOpenURLSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:[specifier localizedObjectForKey:kIASKFile]]];
    } else if ([[specifier type] isEqualToString:kIASKButtonSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if ([self.delegate respondsToSelector:@selector(settingsViewController:buttonTappedForSpecifier:)]) {
            [self.delegate settingsViewController:self buttonTappedForSpecifier:specifier];
        } else if ([self.delegate respondsToSelector:@selector(settingsViewController:buttonTappedForKey:)]) {
            // deprecated, provided for backward compatibility
            NSLog(@"InAppSettingsKit Warning: -settingsViewController:buttonTappedForKey: is deprecated. Please use -settingsViewController:buttonTappedForSpecifier:");
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
            [self.delegate settingsViewController:self buttonTappedForKey:[specifier key]];
#pragma clang diagnostic pop
        } else {
            // legacy code, provided for backward compatibility
            // the delegate mechanism above is much cleaner and doesn't leak
            Class buttonClass = [specifier buttonClass];
            SEL buttonAction = [specifier buttonAction];
            if ([buttonClass respondsToSelector:buttonAction]) {
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
                [buttonClass performSelector:buttonAction withObject:self withObject:[specifier key]];
#pragma clang diagnostic pop
                NSLog(@"InAppSettingsKit Warning: Using IASKButtonSpecifier without implementing the delegate method is deprecated");
            }
        }
    } else if ([[specifier type] isEqualToString:kIASKMailComposeSpecifier]) {
        [tableView deselectRowAtIndexPath:indexPath animated:YES];
        if ([MFMailComposeViewController canSendMail]) {
            MFMailComposeViewController *mailViewController = [[MFMailComposeViewController alloc] init];
            mailViewController.navigationBar.barStyle = self.navigationController.navigationBar.barStyle;
			IASK_IF_IOS7_OR_GREATER(mailViewController.navigationBar.tintColor = self.navigationController.navigationBar.tintColor;);
            mailViewController.navigationBar.titleTextAttributes =  self.navigationController.navigationBar.titleTextAttributes;
            
            if ([specifier localizedObjectForKey:kIASKMailComposeSubject]) {
                [mailViewController setSubject:[specifier localizedObjectForKey:kIASKMailComposeSubject]];
            }
            if ([[specifier specifierDict] objectForKey:kIASKMailComposeToRecipents]) {
                [mailViewController setToRecipients:[[specifier specifierDict] objectForKey:kIASKMailComposeToRecipents]];
            }
            if ([[specifier specifierDict] objectForKey:kIASKMailComposeCcRecipents]) {
                [mailViewController setCcRecipients:[[specifier specifierDict] objectForKey:kIASKMailComposeCcRecipents]];
            }
            if ([[specifier specifierDict] objectForKey:kIASKMailComposeBccRecipents]) {
                [mailViewController setBccRecipients:[[specifier specifierDict] objectForKey:kIASKMailComposeBccRecipents]];
            }
            if ([specifier localizedObjectForKey:kIASKMailComposeBody]) {
                BOOL isHTML = NO;
                if ([[specifier specifierDict] objectForKey:kIASKMailComposeBodyIsHTML]) {
                    isHTML = [[[specifier specifierDict] objectForKey:kIASKMailComposeBodyIsHTML] boolValue];
                }
                
                if ([self.delegate respondsToSelector:@selector(settingsViewController:mailComposeBodyForSpecifier:)]) {
                    [mailViewController setMessageBody:[self.delegate settingsViewController:self
                                                                 mailComposeBodyForSpecifier:specifier] isHTML:isHTML];
                }
                else {
                    [mailViewController setMessageBody:[specifier localizedObjectForKey:kIASKMailComposeBody] isHTML:isHTML];
                }
            }
            
            UIViewController<MFMailComposeViewControllerDelegate> *vc = nil;
            
            if ([self.delegate respondsToSelector:@selector(settingsViewController:viewControllerForMailComposeViewForSpecifier:)]) {
                vc = [self.delegate settingsViewController:self viewControllerForMailComposeViewForSpecifier:specifier];
            }
            
            if (vc == nil) {
                vc = self;
            }
            
            mailViewController.mailComposeDelegate = vc;
            _currentChildViewController = mailViewController;
            UIStatusBarStyle savedStatusBarStyle = [UIApplication sharedApplication].statusBarStyle;
            [vc presentViewController:mailViewController animated:YES completion:^{
			    [UIApplication sharedApplication].statusBarStyle = savedStatusBarStyle;
            }];
			
        } else {
            UIAlertView *alert = [[UIAlertView alloc]
                                  initWithTitle:NSLocalizedString(@"Mail not configured", @"InAppSettingsKit")
                                  message:NSLocalizedString(@"This device is not configured for sending Email. Please configure the Mail settings in the Settings app.", @"InAppSettingsKit")
                                  delegate: nil
                                  cancelButtonTitle:NSLocalizedString(@"OK", @"InAppSettingsKit")
                                  otherButtonTitles:nil];
            [alert show];
        }
        
    } else if ([[specifier type] isEqualToString:kIASKCustomViewSpecifier] && [self.delegate respondsToSelector:@selector(settingsViewController:tableView:didSelectCustomViewSpecifier:)]) {
        [self.delegate settingsViewController:self tableView:tableView didSelectCustomViewSpecifier:specifier];
	} else if ([[specifier type] isEqualToString:kIASKPSRadioGroupSpecifier]) {
		[_selections[indexPath.section] selectRowAtIndexPath:indexPath];
    } else {
        [tableView deselectRowAtIndexPath:indexPath animated:NO];
    }
}


#pragma mark -
#pragma mark MFMailComposeViewControllerDelegate Function

-(void)mailComposeController:(MFMailComposeViewController*)controller didFinishWithResult:(MFMailComposeResult)result error:(NSError*)error {
    
    // Forward the mail compose delegate
    if ([self.delegate respondsToSelector:@selector(settingsViewController:mailComposeController:didFinishWithResult:error:)]) {
         [self.delegate settingsViewController:self 
                         mailComposeController:controller 
                           didFinishWithResult:result 
                                         error:error];
    }
    
    [self dismissViewControllerAnimated:YES
                             completion:nil];
}

#pragma mark -
#pragma mark UITextFieldDelegate Functions

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
	self.currentFirstResponder = textField;
	return YES;
}

- (void)_textChanged:(id)sender {
    IASKTextField *text = sender;
    [_settingsStore setObject:[text text] forKey:[text key]];
    [[NSNotificationCenter defaultCenter] postNotificationName:kIASKAppSettingChanged
                                                        object:[text key]
                                                      userInfo:[NSDictionary dictionaryWithObject:[text text]
                                                                                           forKey:[text key]]];
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField{
	[textField resignFirstResponder];
	self.currentFirstResponder = nil;
	return YES;
}

- (void)singleTapToEndEdit:(UIGestureRecognizer *)sender {
    [self.tableView endEditing:NO];
}

#pragma mark Notifications

- (void)synchronizeSettings {
    [_settingsStore synchronize];
}

static NSDictionary *oldUserDefaults = nil;
- (void)userDefaultsDidChange {
	dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
		IASKSettingsStoreUserDefaults *udSettingsStore = (id)self.settingsStore;
		NSDictionary *currentDict = udSettingsStore.defaults.dictionaryRepresentation;
		NSMutableArray *indexPathsToUpdate = [NSMutableArray array];
		for (NSString *key in currentDict.allKeys) {
			if (oldUserDefaults && ![[oldUserDefaults valueForKey:key] isEqual:[currentDict valueForKey:key]]) {
				NSIndexPath *path = [self.settingsReader indexPathForKey:key];
				if (path && ![[self.settingsReader specifierForKey:key].type isEqualToString:kIASKCustomViewSpecifier] && [self.tableView.indexPathsForVisibleRows containsObject:path]) {
					[indexPathsToUpdate addObject:path];
				}
			}
		}
		oldUserDefaults = currentDict;
		
		for (UITableViewCell *cell in self.tableView.visibleCells) {
			if ([cell isKindOfClass:[IASKPSTextFieldSpecifierViewCell class]] && [((IASKPSTextFieldSpecifierViewCell*)cell).textField isFirstResponder]) {
				[indexPathsToUpdate removeObject:[self.tableView indexPathForCell:cell]];
			}
		}
		if (indexPathsToUpdate.count) {
			[self.tableView reloadRowsAtIndexPaths:indexPathsToUpdate withRowAnimation:UITableViewRowAnimationAutomatic];
		}
	});
}

- (void)didChangeSettingViaIASK:(NSNotification*)notification {
	[oldUserDefaults setValue:[self.settingsStore objectForKey:notification.object] forKey:notification.object];
}

- (void)reload {
	// wait 0.5 sec until UI is available after applicationWillEnterForeground
	[self.tableView performSelector:@selector(reloadData) withObject:nil afterDelay:0.5];
}

#pragma mark CGRect Utility function
CGRect IASKCGRectSwap(CGRect rect) {
	CGRect newRect;
	newRect.origin.x = rect.origin.y;
	newRect.origin.y = rect.origin.x;
	newRect.size.width = rect.size.height;
	newRect.size.height = rect.size.width;
	return newRect;
}
@end
