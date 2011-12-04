//
//  MoveSiteViewController.h
//  NewsBlur
//
//  Created by Samuel Clay on 12/2/2011.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"

@class NewsBlurAppDelegate;

@interface MoveSiteViewController : UIViewController 
<UITextFieldDelegate, UIPickerViewDelegate, UIPickerViewDataSource, ASIHTTPRequestDelegate> {
    NewsBlurAppDelegate *appDelegate;
}

- (void)reload;
- (IBAction)moveSite;
- (IBAction)moveFolder;
- (IBAction)doCancelButton;
- (IBAction)doMoveButton;
- (NSArray *)pickerFolders;
- (NSString *)extractFolderName:(NSString *)folderName;
- (NSString *)extractParentFolderName:(NSString *)folderName;

@property (nonatomic, retain) IBOutlet NewsBlurAppDelegate *appDelegate;
@property (nonatomic, retain) IBOutlet UITextField *fromFolderInput;
@property (nonatomic, retain) IBOutlet UITextField *toFolderInput;
@property (nonatomic, retain) IBOutlet UILabel *titleLabel;

@property (nonatomic, retain) IBOutlet UIBarButtonItem *moveButton;
@property (nonatomic, retain) IBOutlet UIBarButtonItem *cancelButton;
@property (nonatomic, retain) IBOutlet UIPickerView *folderPicker;

@property (nonatomic, retain) IBOutlet UINavigationBar *navBar;
@property (nonatomic, retain) IBOutlet UIActivityIndicatorView *activityIndicator;
@property (nonatomic, retain) IBOutlet UILabel *movingLabel;
@property (nonatomic, retain) IBOutlet UILabel *errorLabel;

@property (nonatomic, retain) NSMutableArray *folders;

@end
