//
//  MoveSiteViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 12/2/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "MoveSiteViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSON.h"
#import "StringHelper.h"

@implementation MoveSiteViewController

@synthesize appDelegate;
@synthesize toFolderInput;
@synthesize fromFolderInput;
@synthesize titleLabel;
@synthesize moveButton;
@synthesize cancelButton;
@synthesize folderPicker;
@synthesize navBar;
@synthesize activityIndicator;
@synthesize movingLabel;
@synthesize errorLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewDidLoad {    
    UIImageView *folderImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"folder.png"]];
    [toFolderInput setLeftView:folderImage];
    [toFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    UIImageView *folderImage2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"folder.png"]];
    [fromFolderInput setLeftView:folderImage2];
    [fromFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    [folderImage release];
    [folderImage2 release];
        
    navBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    
    for (UIView *subview in [self.titleLabel subviews]) {
        [subview removeFromSuperview];
    }
    [self.titleLabel addSubview:[appDelegate makeFeedTitle:appDelegate.activeFeed]];
    [self reload];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.activityIndicator stopAnimating];
    [super viewDidAppear:animated];
}

- (void)dealloc {
    [appDelegate release];
    [toFolderInput release];
    [fromFolderInput release];
    [titleLabel release];
    [moveButton release];
    [cancelButton release];
    [folderPicker release];
    [navBar release];
    [super dealloc];
}
- (void)reload {
    BOOL isTopLevel = [[appDelegate.activeFolder trim] isEqualToString:@""];
    NSString *fromFolderName = isTopLevel ? 
                                @"- Top Level -" : 
                                appDelegate.activeFolder;
    [toFolderInput setText:@""];
    [fromFolderInput setText:fromFolderName];
    [folderPicker reloadAllComponents];
    
    int row = isTopLevel ? 
                0 :
                [[appDelegate dictFoldersArray] indexOfObject:fromFolderName];
    [folderPicker selectRow:row inComponent:0 animated:NO];
    
    moveButton.enabled = NO;
}

- (IBAction)doCancelButton {
    [appDelegate.moveSiteViewController dismissModalViewControllerAnimated:YES];
}

- (IBAction)doMoveButton {
    if (appDelegate.isRiverView) {
        [self moveFolder];
    } else {
        [self moveSite];
    }
}

#pragma mark -
#pragma mark Move Site

- (IBAction)moveSite {
    [self.movingLabel setHidden:NO];
    [self.movingLabel setText:@"Moving site..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/move_feed_to_folder",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    NSString *fromFolder = [self extractParentFolder:[fromFolderInput text]];
    NSString *toFolder = [self extractParentFolder:[toFolderInput text]];
    [request setPostValue:fromFolder forKey:@"in_folder"]; 
    [request setPostValue:toFolder forKey:@"to_folder"]; 
    [request setPostValue:[appDelegate.activeFeed objectForKey:@"id"] forKey:@"feed_id"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFinished:(ASIHTTPRequest *)request {
    if ([request responseStatusCode] >= 500) {
        return [self requestFailed:request];
    }
    
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        [self.errorLabel setText:[results valueForKey:@"message"]];   
        [self.errorLabel setHidden:NO];
    } else {
        appDelegate.activeFolder = [toFolderInput text];
        [appDelegate.moveSiteViewController dismissModalViewControllerAnimated:YES];
        [appDelegate reloadFeedsView:NO];
    }
    [results release];
}

- (NSString *)extractParentFolder:(NSString *)folderName {
    if ([folderName containsString:@"Top Level"]) {
        folderName = @"";
    }
    
    if ([folderName containsString:@" - "]) {
        int folder_loc = [folderName rangeOfString:@" - " options:NSBackwardsSearch].location;
        folderName = [folderName substringFromIndex:(folder_loc + 3)];
    }
    
    return folderName;
}

#pragma mark -
#pragma mark Move Folder

- (IBAction)moveFolder {
    [self.movingLabel setHidden:NO];
    [self.movingLabel setText:@"Moving Folder..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/move_folder_to_folder",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    NSString *fromFolder = [self extractParentFolder:[fromFolderInput text]];
    NSString *toFolder = [self extractParentFolder:[toFolderInput text]];
    [request setPostValue:fromFolder forKey:@"from_folder"]; 
    [request setPostValue:toFolder forKey:@"to_folder"]; 
    [request setPostValue:toFolder forKey:@"folder_to_move"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishMoveFolder:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)finishMoveFolder:(ASIHTTPRequest *)request {
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        [self.errorLabel setText:[results valueForKey:@"message"]];   
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate.moveSiteViewController dismissModalViewControllerAnimated:YES];
        [appDelegate reloadFeedsView:NO];
    }
    
    [results release];    
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    [self.movingLabel setHidden:YES];
    [self.errorLabel setHidden:NO];
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    NSLog(@"Error: %@", [request responseString]);
    [self.errorLabel setText:error.localizedDescription];
}

#pragma mark -
#pragma mark Folder Picker

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView
numberOfRowsInComponent:(NSInteger)component {
    return [[appDelegate dictFoldersArray] count];
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
    if (row == 0) {
        return @"— Top Level —";
    } else {
        return [[appDelegate dictFoldersArray] objectAtIndex:row];
    }
}

- (void)pickerView:(UIPickerView *)pickerView 
      didSelectRow:(NSInteger)row 
       inComponent:(NSInteger)component {
    NSString *folder_title;
    if (row == 0) {
        folder_title = @"- Top Level -";
    } else {
        folder_title = [[appDelegate dictFoldersArray] objectAtIndex:row];        
    }
    [toFolderInput setText:folder_title];
    moveButton.enabled = YES;
}

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [errorLabel setText:@""];
    if (textField == toFolderInput && ![toFolderInput isFirstResponder]) {
        [toFolderInput setInputView:folderPicker];
    }
    return NO;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

@end
