//
//  AddViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/04/2011.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"

@class NewsBlurAppDelegate;

@interface AddViewController : UIViewController 
<UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UITextField *inFolderInput;
    UITextField *newFolderInput;
    UITextField *siteAddressInput;
    NSMutableData * jsonString;
    
    UIBarButtonItem *addButton;
    UIBarButtonItem *cancelButton;
    UIPickerView *folderPicker;
    
    UINavigationBar *navBar;
    UIActivityIndicatorView *activityIndicator;
    UILabel *authenticatingLabel;
    UILabel *errorLabel;
    UISegmentedControl *addTypeControl;
    
    UILabel *usernameLabel;
    UILabel *usernameOrEmailLabel;
    UILabel *passwordLabel;
    UILabel *emailLabel;
    UILabel *passwordOptionalLabel;
}

- (void)addSite;
- (void)addFolder;
- (IBAction)selectAddTypeSignup;
- (IBAction)doCancelButton;
- (IBAction)doAddButton;
- (void)animateLoop;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITextField *inFolderInput;
@property (nonatomic, retain) IBOutlet UITextField *newFolderInput;
@property (nonatomic, retain) IBOutlet UITextField *siteAddressInput;

@property (nonatomic, retain) IBOutlet UIBarButtonItem *addButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic, retain) IBOutlet UIPickerView *folderPicker;
@property (nonatomic, retain) NSMutableData * jsonString;

@property (nonatomic, retain) IBOutlet UINavigationBar *navBar;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UILabel *authenticatingLabel;
@property (nonatomic, retain) IBOutlet UILabel *errorLabel;
@property (nonatomic, retain) IBOutlet UISegmentedControl *addTypeControl;

@property (nonatomic, retain) IBOutlet UILabel *usernameLabel;
@property (nonatomic, retain) IBOutlet UILabel *usernameOrEmailLabel;
@property (nonatomic, retain) IBOutlet UILabel *passwordLabel;
@property (nonatomic, retain) IBOutlet UILabel *emailLabel;
@property (nonatomic, retain) IBOutlet UILabel *passwordOptionalLabel;

@end
