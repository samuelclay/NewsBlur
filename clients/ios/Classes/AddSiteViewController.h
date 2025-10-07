//
//  AddSiteViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/04/2011.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlur-Swift.h"

@interface AddSiteViewController : BaseViewController
<UITextFieldDelegate, UITableViewDelegate, UITableViewDataSource>

- (void)reload;
- (IBAction)addSite;
- (IBAction)doCancelButton;
- (IBAction)doAddButton;
- (NSString *)extractParentFolder;
- (IBAction)checkSiteAddress;
- (void)reloadSearchResults;
- (IBAction)toggleAddFolder:(id)sender;
- (NSArray *)folders;

@property (nonatomic) IBOutlet UITextField *inFolderInput;
@property (nonatomic) IBOutlet UITextField *addFolderInput;
@property (nonatomic) IBOutlet UITextField *siteAddressInput;

@property (nonatomic) IBOutlet UIBarButtonItem *addButton;
@property (nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic) IBOutlet UITableView *siteTable;
@property (nonatomic) IBOutlet UIScrollView *siteScrollView;
@property (nonatomic) IBOutlet UIButton *addFolderButton;
@property (nonatomic) NSMutableData * jsonString;
@property (nonatomic) NSMutableArray *autocompleteResults;

@property (nonatomic) IBOutlet UINavigationBar *navBar;
@property (nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic) IBOutlet UIActivityIndicatorView *siteActivityIndicator;
@property (nonatomic) IBOutlet UILabel *addingLabel;
@property (nonatomic) IBOutlet UILabel *errorLabel;

@end
