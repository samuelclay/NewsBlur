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
@synthesize folders;

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
        
    navBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    [super viewDidLoad];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return YES;
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    
    for (UIView *subview in [self.titleLabel subviews]) {
        [subview removeFromSuperview];
    }
    UIView *label = [appDelegate makeFeedTitle:appDelegate.activeFeed];
    label.frame = CGRectMake(label.frame.origin.x, 
                             label.frame.origin.y, 
                             self.titleLabel.frame.size.width - 
                             (self.titleLabel.frame.origin.x-label.frame.origin.x), 
                             label.frame.size.height);
    [self.titleLabel addSubview:label];
    [self reload];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.activityIndicator stopAnimating];
    [super viewDidAppear:animated];
}


- (void)reload {
    BOOL isTopLevel = [[appDelegate.activeFolder trim] isEqualToString:@""];
    int row = 0;
    [toFolderInput setText:@""];
    
    if (appDelegate.isRiverView) {
        NSString *parentFolderName = [appDelegate extractParentFolderName:appDelegate.activeFolder];
        row = [[self pickerFolders] 
               indexOfObject:parentFolderName];
        fromFolderInput.text = parentFolderName;
    } else {
        fromFolderInput.text = isTopLevel ? @"— Top Level —" : appDelegate.activeFolder;
        row = isTopLevel ? 
                0 :
                [[self pickerFolders] indexOfObject:appDelegate.activeFolder];
    }
    self.folders = [NSMutableArray array];
    [folderPicker reloadAllComponents];
    [folderPicker selectRow:row inComponent:0 animated:NO];
    
    moveButton.enabled = NO;
    moveButton.title = appDelegate.isRiverView ? @"Move Folder to Folder" : @"Move Site to Folder";
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
    NSString *fromFolder = [appDelegate extractFolderName:[fromFolderInput text]];
    NSString *toFolder = [appDelegate extractFolderName:[toFolderInput text]];
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
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
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
    NSString *folderName = [appDelegate extractFolderName:appDelegate.activeFolder];
    NSString *fromFolder = [appDelegate extractFolderName:[fromFolderInput text]];
    NSString *toFolder = [appDelegate extractFolderName:[toFolderInput text]];
    [request setPostValue:fromFolder forKey:@"in_folder"]; 
    [request setPostValue:toFolder forKey:@"to_folder"]; 
    [request setPostValue:folderName forKey:@"folder_name"];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishMoveFolder:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)finishMoveFolder:(ASIHTTPRequest *)request {
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        [self.errorLabel setText:[results valueForKey:@"message"]];   
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate.moveSiteViewController dismissModalViewControllerAnimated:YES];
        [appDelegate reloadFeedsView:NO];
    }
    
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

- (NSArray *)pickerFolders {
    if ([self.folders count]) return self.folders;
    
    self.folders = [NSMutableArray array];
    [self.folders addObject:@"— Top Level —"];
    
    for (NSString *folder in appDelegate.dictFoldersArray) {
        if ([[folder trim] isEqualToString:@""]) continue;
        if (appDelegate.isRiverView) {
            if (![folder containsString:appDelegate.activeFolder]) {
                [self.folders addObject:folder];
            }
        } else {
            [self.folders addObject:folder];
        }
    }
    
    return self.folders;
}

- (NSInteger)numberOfComponentsInPickerView:(UIPickerView *)pickerView {
    return 1;
}

- (NSInteger)pickerView:(UIPickerView *)pickerView
numberOfRowsInComponent:(NSInteger)component {
    return [[self pickerFolders] count];
}

- (NSString *)pickerView:(UIPickerView *)pickerView
             titleForRow:(NSInteger)row
            forComponent:(NSInteger)component {
    return [[self pickerFolders] objectAtIndex:row];
}

- (void)pickerView:(UIPickerView *)pickerView 
      didSelectRow:(NSInteger)row 
       inComponent:(NSInteger)component {
    [toFolderInput setText:[[self pickerFolders] objectAtIndex:row]];
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
