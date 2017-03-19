//
//  MoveSiteViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 12/2/2011.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"

@class NewsBlurAppDelegate;

@interface FolderTextField : UITextField

@end

@interface MoveSiteViewController : BaseViewController
<UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource> {
    NewsBlurAppDelegate *appDelegate;
}

- (void)reload;
- (IBAction)moveSite;
- (IBAction)moveFolder;
- (IBAction)doCancelButton;
- (IBAction)doMoveButton;
- (NSArray *)pickerFolders;

@property (nonatomic) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic) IBOutlet UITextField *fromFolderInput;
@property (nonatomic) IBOutlet FolderTextField *toFolderInput;
@property (nonatomic) IBOutlet UILabel *titleLabel;

@property (nonatomic) IBOutlet UIBarButtonItem *moveButton;
@property (nonatomic) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic) IBOutlet UIPickerView *folderPicker;

@property (nonatomic) IBOutlet UINavigationBar *navBar;
@property (nonatomic) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic) IBOutlet UILabel *movingLabel;
@property (nonatomic) IBOutlet UILabel *errorLabel;

@property (nonatomic) NSMutableArray *folders;

@end

