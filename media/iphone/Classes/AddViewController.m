//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "AddViewController.h"
#import "NewsBlurAppDelegate.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "JSON.h"

@implementation AddViewController

@synthesize appDelegate;
@synthesize inFolderInput;
@synthesize newFolderInput;
@synthesize siteAddressInput;
@synthesize addButton;
@synthesize cancelButton;
@synthesize folderPicker;
@synthesize siteTable;
@synthesize jsonString;
@synthesize navBar;
@synthesize activityIndicator;
@synthesize addingLabel;
@synthesize errorLabel;
@synthesize addTypeControl;
@synthesize usernameLabel;
@synthesize usernameOrEmailLabel;
@synthesize passwordLabel;
@synthesize emailLabel;
@synthesize passwordOptionalLabel;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
	
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewDidLoad {    
    UIImageView *folderImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"folder.png"]];
    [inFolderInput setLeftView:folderImage];
    [inFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    [folderImage release];
    
    
    navBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.addingLabel setHidden:YES];
    [self.folderPicker setHidden:YES];
    [self.siteTable setHidden:YES];
    [self.activityIndicator stopAnimating];
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
    [inFolderInput release];
    [newFolderInput release];
    [siteAddressInput release];
    [addButton release];
    [cancelButton release];
    [folderPicker release];
    [siteTable release];
    [jsonString release];
    [navBar release];
    [super dealloc];
}

#pragma mark -
#pragma mark Add Site

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    if (textField == inFolderInput) {
        [siteAddressInput resignFirstResponder];
        [newFolderInput resignFirstResponder];
        folderPicker.frame = CGRectMake(0, self.view.bounds.size.height, folderPicker.frame.size.width, folderPicker.frame.size.height);
        folderPicker.hidden = NO;
        [UIView animateWithDuration:.35 animations:^{
            folderPicker.frame = CGRectMake(0, self.view.bounds.size.height - folderPicker.frame.size.height, folderPicker.frame.size.width, folderPicker.frame.size.height);            
        }];
        return NO;
    } else if (textField == siteAddressInput) {
        [UIView animateWithDuration:.35 animations:^{
            folderPicker.frame = CGRectMake(0, self.view.bounds.size.height, folderPicker.frame.size.width, folderPicker.frame.size.height);          
        }];
        
    } else if (textField == newFolderInput) {
        [UIView animateWithDuration:.35 animations:^{
            folderPicker.frame = CGRectMake(0, self.view.bounds.size.height, folderPicker.frame.size.width, folderPicker.frame.size.height);          
        }];
        
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == inFolderInput) {
    }
//	if(textField == usernameInput) {
//        [passwordInput becomeFirstResponder];
//    } else if (textField == passwordInput && [self.addTypeControl selectedSegmentIndex] == 0) {
//        NSLog(@"Password return");
//        NSLog(@"appdelegate:: %@", [self appDelegate]);
//        [self checkPassword];
//    } else if (textField == passwordInput && [self.addTypeControl selectedSegmentIndex] == 1) {
//        [emailInput becomeFirstResponder];
//    } else if (textField == emailInput) {
//        [self registerAccount];
//    }
	return YES;
}

- (void)addSite {
    [self.addingLabel setHidden:NO];
    [self.addingLabel setText:@"Adding site..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/api/login",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[inFolderInput text] forKey:@"in_folder"]; 
    [request setPostValue:[siteAddressInput text] forKey:@"address"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}


- (void)requestFinished:(ASIHTTPRequest *)request {
    [self.addingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"username"]) {
            [self.errorLabel setText:[[errors valueForKey:@"username"] objectAtIndex:0]];   
        } else if ([errors valueForKey:@"__all__"]) {
            [self.errorLabel setText:[[errors valueForKey:@"__all__"] objectAtIndex:0]];
        }
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate reloadFeedsView];
    }
    
    [results release];
}


- (void)addFolder {
    [self.addingLabel setHidden:NO];
    [self.addingLabel setText:@"Adding Folder..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/api/add_folder",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    [request setPostValue:[inFolderInput text] forKey:@"in_folder"]; 
    [request setPostValue:[newFolderInput text] forKey:@"folder_name"]; 
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(finishAddFolder:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request startAsynchronous];
}

- (void)finishAddFolder:(ASIHTTPRequest *)request {
    [self.addingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSDictionary *results = [[NSDictionary alloc] 
                             initWithDictionary:[responseString JSONValue]];
    // int statusCode = [request responseStatusCode];
    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        NSDictionary *errors = [results valueForKey:@"errors"];
        if ([errors valueForKey:@"email"]) {
            [self.errorLabel setText:[[errors valueForKey:@"email"] objectAtIndex:0]];   
        } else if ([errors valueForKey:@"username"]) {
            [self.errorLabel setText:[[errors valueForKey:@"username"] objectAtIndex:0]];
        }
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate reloadFeedsView];
    }
    
    [results release];    
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
}

#pragma mark -
#pragma mark Add Folder

- (IBAction)selectAddTypeSignup {
    [self animateLoop];
}

- (void)animateLoop {
    if ([self.addTypeControl selectedSegmentIndex] == 0) {
        [addButton setTitle:@"Add Site"];
        [newFolderInput resignFirstResponder];
        [UIView animateWithDuration:0.5 animations:^{
            siteAddressInput.frame = CGRectMake(newFolderInput.frame.origin.x, 
                                                siteAddressInput.frame.origin.y, 
                                                siteAddressInput.frame.size.width, 
                                                siteAddressInput.frame.size.height);
            newFolderInput.frame = CGRectMake(self.view.frame.size.width, 
                                              siteAddressInput.frame.origin.y, 
                                              siteAddressInput.frame.size.width, 
                                              siteAddressInput.frame.size.height);
        }];
    } else {
        [addButton setTitle:@"Add Folder"];
        [siteAddressInput resignFirstResponder];
        newFolderInput.frame = CGRectMake(self.view.frame.size.width, 
                                          siteAddressInput.frame.origin.y, 
                                          siteAddressInput.frame.size.width, 
                                          siteAddressInput.frame.size.height);
        [UIView animateWithDuration:0.5 animations:^{
            newFolderInput.frame = CGRectMake(siteAddressInput.frame.origin.x, 
                                              siteAddressInput.frame.origin.y, 
                                              siteAddressInput.frame.size.width, 
                                              siteAddressInput.frame.size.height);
            siteAddressInput.frame = CGRectMake(-1 * (siteAddressInput.frame.origin.x + 
                                                      siteAddressInput.frame.size.width), 
                                                siteAddressInput.frame.origin.y, 
                                                siteAddressInput.frame.size.width, 
                                                siteAddressInput.frame.size.height);
        }];
    }
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
    
}

#pragma mark -
#pragma mark Autocomplete sites


- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 0;
}

#pragma mark -
#pragma mark Server

- (IBAction)doCancelButton {
    [appDelegate.addViewController dismissModalViewControllerAnimated:YES];
}

- (IBAction)doAddButton {
    
}

@end
