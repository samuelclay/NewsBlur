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

@implementation MoveSiteViewController

@synthesize appDelegate;
@synthesize toFolderInput;
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
    [folderImage release];
        
    navBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.movingLabel setHidden:YES];
    [self.folderPicker setHidden:YES];
    [self.activityIndicator stopAnimating];
    
    UIView *titleLabelView = [appDelegate makeFeedTitle:appDelegate.activeFeed];
    self.titleLabel = titleLabelView;
    
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.activityIndicator stopAnimating];
    [super viewDidAppear:animated];
}


- (void)didReceiveMemoryWarning {
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
	
	// Release any cached data, images, etc that aren't in use.
}

- (void)dealloc {
    [appDelegate release];
    [toFolderInput release];
    [titleLabel release];
    [moveButton release];
    [cancelButton release];
    [folderPicker release];
    [navBar release];
    [super dealloc];
}

- (IBAction)doCancelButton {
    [appDelegate.moveSiteViewController dismissModalViewControllerAnimated:YES];
}

- (IBAction)doMoveButton {

}

- (void)reload {
    [toFolderInput setText:@""];
    [folderPicker reloadAllComponents];
    
    folderPicker.frame = CGRectMake(0, self.view.bounds.size.height, 
                                    folderPicker.frame.size.width, 
                                    folderPicker.frame.size.height);
}

#pragma mark -
#pragma mark Move Site

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [errorLabel setText:@""];
    if (textField == toFolderInput && ![toFolderInput isFirstResponder]) {
        [toFolderInput setInputView:folderPicker];
        if (folderPicker.frame.origin.y >= self.view.bounds.size.height) {
            folderPicker.hidden = NO;
            [UIView animateWithDuration:.35 animations:^{
                folderPicker.frame = CGRectMake(0, 
                                                self.view.bounds.size.height - 
                                                folderPicker.frame.size.height, 
                                                folderPicker.frame.size.width, 
                                                folderPicker.frame.size.height);            
            }];
        }
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    return YES;
}

- (IBAction)moveSite {
    [self hideFolderPicker];
    [self.movingLabel setHidden:NO];
    [self.movingLabel setText:@"Moving site..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/move_site_to_folder",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    NSString *fromFolder = [self extractParentFolder:[toFolderInput text]];
    NSString *toFolder = [self extractParentFolder:[toFolderInput text]];
    [request setPostValue:fromFolder forKey:@"from_folder"]; 
    [request setPostValue:toFolder forKey:@"to_folder"]; 
    [request setPostValue:[appDelegate.activeFeed objectForKey:@"feed_id"] forKey:@"feed_id"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)requestFinished:(ASIHTTPRequest *)request {
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
        [appDelegate reloadFeedsView];
    }
    
    [results release];
}

- (NSString *)extractParentFolder:(NSString *)folderName {
    int folder_loc = [folderName rangeOfString:@" - " options:NSBackwardsSearch].location;
    if ([folderName length] && folder_loc != NSNotFound) {
        folderName = [folderName substringFromIndex:(folder_loc + 3)];
    }
    return folderName;
}

#pragma mark -
#pragma mark Move Folder

- (IBAction)moveFolder {
    [self hideFolderPicker];
    [self.movingLabel setHidden:NO];
    [self.movingLabel setText:@"Moving Folder..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/add_folder",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    NSString *fromFolder = [self extractParentFolder:[toFolderInput text]];
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
        [appDelegate reloadFeedsView];
    }
    
    [results release];    
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    [self.movingLabel setHidden:YES];
    [self.errorLabel setHidden:NO];
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
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
}

- (void)hideFolderPicker {
    [UIView animateWithDuration:.35 animations:^{
        folderPicker.frame = CGRectMake(0, self.view.bounds.size.height, folderPicker.frame.size.width, folderPicker.frame.size.height);          
    }];
}

@end
