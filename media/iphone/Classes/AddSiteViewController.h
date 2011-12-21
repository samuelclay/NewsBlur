//
//  AddSiteViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/04/2011.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"

@class NewsBlurAppDelegate;

@interface AddSiteViewController : UIViewController 
<UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, UITableViewDelegate, UITableViewDataSource, ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
    
    UITextField *inFolderInput;
    UITextField *addFolderInput;
    UITextField *siteAddressInput;
    NSMutableData *jsonString;
    NSMutableArray *autocompleteResults;
    
    UIBarButtonItem *addButton;
    UIBarButtonItem *cancelButton;
    UIPickerView *folderPicker;
    UITableView *siteTable;
    UIScrollView *siteScrollView;
    
    UINavigationBar *navBar;
    UIActivityIndicatorView *activityIndicator;
    UIActivityIndicatorView *siteActivityIndicator;
    UILabel *addingLabel;
    UILabel *errorLabel;
    UISegmentedControl *addTypeControl;
}

- (void)reload;
- (IBAction)addSite;
- (void)autocompleteSite:(ASIHTTPRequest *)request;
- (IBAction)addFolder;
- (IBAction)selectAddTypeSignup;
- (IBAction)doCancelButton;
- (IBAction)doAddButton;
- (NSString *)extractParentFolder;
- (void)animateLoop;
- (void)showFolderPicker;
- (void)hideFolderPicker;
- (IBAction)checkSiteAddress;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITextField *inFolderInput;
@property (nonatomic, retain) IBOutlet UITextField *addFolderInput;
@property (nonatomic, retain) IBOutlet UITextField *siteAddressInput;

@property (nonatomic, retain) IBOutlet UIBarButtonItem *addButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic, retain) IBOutlet UIPickerView *folderPicker;
@property (nonatomic, retain) IBOutlet UITableView *siteTable;
@property (nonatomic, retain) IBOutlet UIScrollView *siteScrollView;
@property (nonatomic, retain) NSMutableData * jsonString;
@property (nonatomic, retain) NSMutableArray *autocompleteResults;

@property (nonatomic, retain) IBOutlet UINavigationBar *navBar;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *siteActivityIndicator;
@property (nonatomic, retain) IBOutlet UILabel *addingLabel;
@property (nonatomic, retain) IBOutlet UILabel *errorLabel;
@property (nonatomic, retain) IBOutlet UISegmentedControl *addTypeControl;

@end
