//
//  IASKAppSettingsViewController.h
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

#import <UIKit/UIKit.h>
#import <MessageUI/MessageUI.h>

#import "IASKSettingsStore.h"
#import "IASKViewController.h"
#import "IASKSpecifier.h"

@class IASKSettingsReader;
@class IASKAppSettingsViewController;

@protocol IASKSettingsDelegate
- (void)settingsViewControllerDidEnd:(IASKAppSettingsViewController*)sender;

@optional
#pragma mark - UITableView header customization
- (CGFloat) settingsViewController:(id<IASKViewController>)settingsViewController
                         tableView:(UITableView *)tableView
         heightForHeaderForSection:(NSInteger)section;
- (UIView *) settingsViewController:(id<IASKViewController>)settingsViewController
                          tableView:(UITableView *)tableView
            viewForHeaderForSection:(NSInteger)section;

#pragma mark - UITableView cell customization
- (CGFloat)tableView:(UITableView*)tableView heightForSpecifier:(IASKSpecifier*)specifier;
- (UITableViewCell*)tableView:(UITableView*)tableView cellForSpecifier:(IASKSpecifier*)specifier;

#pragma mark - mail composing customization
- (NSString*) settingsViewController:(id<IASKViewController>)settingsViewController
         mailComposeBodyForSpecifier:(IASKSpecifier*) specifier;

- (UIViewController<MFMailComposeViewControllerDelegate>*) settingsViewController:(id<IASKViewController>)settingsViewController
                                     viewControllerForMailComposeViewForSpecifier:(IASKSpecifier*) specifier;

- (void) settingsViewController:(id<IASKViewController>) settingsViewController
          mailComposeController:(MFMailComposeViewController*)controller
            didFinishWithResult:(MFMailComposeResult)result
                          error:(NSError*)error;

#pragma mark - respond to button taps
- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForKey:(NSString*)key __attribute__((deprecated)); // use the method below with specifier instead
- (void)settingsViewController:(IASKAppSettingsViewController*)sender buttonTappedForSpecifier:(IASKSpecifier*)specifier;
- (void)settingsViewController:(IASKAppSettingsViewController*)sender tableView:(UITableView *)tableView didSelectCustomViewSpecifier:(IASKSpecifier*)specifier;
@end


@interface IASKAppSettingsViewController : UITableViewController <IASKViewController, UITextFieldDelegate, MFMailComposeViewControllerDelegate> {
    id<IASKSettingsDelegate>  _delegate;
    
    NSMutableArray          *_viewList;
    
    IASKSettingsReader		*_settingsReader;
    id<IASKSettingsStore>  _settingsStore;
    NSString				*_file;
    
    id                      _currentFirstResponder;
    
    BOOL                    _showCreditsFooter;
    BOOL                    _showDoneButton;
    
    NSSet                   *_hiddenKeys;
}

@property (nonatomic, assign) IBOutlet id delegate;
@property (nonatomic, copy) NSString *file;
@property (nonatomic, assign) BOOL showCreditsFooter;
@property (nonatomic, assign) BOOL showDoneButton;
@property (nonatomic, retain) NSSet *hiddenKeys;

- (void)synchronizeSettings;
- (void)dismiss:(id)sender;
- (void)setHiddenKeys:(NSSet*)hiddenKeys animated:(BOOL)animated;
@end
