//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "AddViewController.h"
#import "AddSiteAutocompleteCell.h"
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
@synthesize siteScrollView;
@synthesize jsonString;
@synthesize autocompleteResults;
@synthesize navBar;
@synthesize activityIndicator;
@synthesize siteActivityIndicator;
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
    UIImageView *folderImage2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"folder.png"]];
    [newFolderInput setLeftView:folderImage2];
    [newFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    [folderImage2 release];
    
    UIImageView *urlImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"world.png"]];
    [siteAddressInput setLeftView:urlImage];
    [siteAddressInput setLeftViewMode:UITextFieldViewModeAlways];
    [urlImage release];
    
    navBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];
    
    newFolderInput.frame = CGRectMake(self.view.frame.size.width, 
                                      siteAddressInput.frame.origin.y, 
                                      siteAddressInput.frame.size.width, 
                                      siteAddressInput.frame.size.height);
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.addingLabel setHidden:YES];
    [self.folderPicker setHidden:YES];
    [self.siteScrollView setAlpha:0];
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
    [siteScrollView release];
    [jsonString release];
    [autocompleteResults release];
    [navBar release];
    [super dealloc];
}

- (IBAction)doCancelButton {
    [appDelegate.addViewController dismissModalViewControllerAnimated:YES];
}

- (IBAction)doAddButton {
    if ([self.addTypeControl selectedSegmentIndex] == 0) {
        return [self addSite];
    } else {
        return [self addFolder];
    }
}

- (void)reload {
    [inFolderInput setText:@""];
    [siteAddressInput setText:@""];
    [newFolderInput setText:@""];
    [folderPicker reloadAllComponents];
    
    folderPicker.frame = CGRectMake(0, self.view.bounds.size.height, 
                                    folderPicker.frame.size.width, 
                                    folderPicker.frame.size.height);
}

#pragma mark -
#pragma mark Add Site

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [errorLabel setText:@""];
    if (textField == inFolderInput && ![inFolderInput isFirstResponder]) {
        [siteAddressInput resignFirstResponder];
        [newFolderInput resignFirstResponder];
        [inFolderInput setInputView:folderPicker];
        if (folderPicker.frame.origin.y >= self.view.bounds.size.height) {
            folderPicker.hidden = NO;
            [UIView animateWithDuration:.35 animations:^{
                folderPicker.frame = CGRectMake(0, self.view.bounds.size.height - folderPicker.frame.size.height, folderPicker.frame.size.width, folderPicker.frame.size.height);            
            }];
        }
        return NO;
    } else if (textField == siteAddressInput) {
        [self hideFolderPicker];
    } else if (textField == newFolderInput) {
        [self hideFolderPicker];
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == inFolderInput) {
        
    } else if (textField == siteAddressInput) {
        [self addSite];
    } else if (textField == newFolderInput) {
        [self addFolder];
    }
	return YES;
}

- (IBAction)checkSiteAddress {
    NSString *phrase = siteAddressInput.text;
    if ([phrase length] == 0) {
        [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionAllowUserInteraction 
                         animations:^{
                             [siteScrollView setAlpha:0];
                         } completion:nil];
        return;
    }
    
    int period_loc = [phrase rangeOfString:@"."].location;
    if (period_loc != NSNotFound) {
        // URL
        [siteAddressInput setReturnKeyType:UIReturnKeyDone];
        [siteAddressInput resignFirstResponder];
        [siteAddressInput becomeFirstResponder];
    } else {
        // Search
        [siteAddressInput setReturnKeyType:UIReturnKeySearch];
        [siteAddressInput resignFirstResponder];
        [siteAddressInput becomeFirstResponder];
    }
    
    
    [self.siteActivityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/rss_feeds/feed_autocomplete?term=%@",
                           NEWSBLUR_URL, [phrase stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(autocompleteSite:)];
    [request startAsynchronous];
}

- (void)autocompleteSite:(ASIHTTPRequest *)request {
    if ([siteAddressInput.text length] > 0) {
        [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionAllowUserInteraction 
                         animations:^{
                             [siteScrollView setAlpha:1];
                         } completion:nil];
    }
    [self.siteActivityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    autocompleteResults = [[NSMutableArray alloc] initWithArray:[responseString JSONValue]];
    NSLog(@"%@", autocompleteResults);
    [siteTable reloadData];
}

- (IBAction)addSite {
    [self hideFolderPicker];
    [siteAddressInput resignFirstResponder];
    [self.addingLabel setHidden:NO];
    [self.addingLabel setText:@"Adding site..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/add_url",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    NSString *parent_folder = [self extractParentFolder];
    [request setPostValue:parent_folder forKey:@"folder"]; 
    [request setPostValue:[siteAddressInput text] forKey:@"url"]; 
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
        [self.errorLabel setText:[results valueForKey:@"message"]];   
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate.addViewController dismissModalViewControllerAnimated:YES];
        [appDelegate reloadFeedsView];
    }
    
    [results release];
}

- (NSString *)extractParentFolder {
    NSString *parent_folder = [inFolderInput text];
    int folder_loc = [parent_folder rangeOfString:@" - " options:NSBackwardsSearch].location;
    if ([parent_folder length] && folder_loc != NSNotFound) {
        parent_folder = [parent_folder substringFromIndex:(folder_loc + 3)];
    }
    return parent_folder;
}

#pragma mark -
#pragma mark Add Folder


- (IBAction)addFolder {
    [self hideFolderPicker];
    [newFolderInput resignFirstResponder];
    [self.addingLabel setHidden:NO];
    [self.addingLabel setText:@"Adding Folder..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"http://%@/reader/add_folder",
                           NEWSBLUR_URL];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    NSString *parent_folder = [self extractParentFolder];
    [request setPostValue:parent_folder forKey:@"parent_folder"]; 
    [request setPostValue:[newFolderInput text] forKey:@"folder"]; 
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
        [self.errorLabel setText:[results valueForKey:@"message"]];   
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate.addViewController dismissModalViewControllerAnimated:YES];
        [appDelegate reloadFeedsView];
    }
    
    [results release];    
}

- (void)requestFailed:(ASIHTTPRequest *)request
{
    [self.addingLabel setHidden:YES];
    [self.errorLabel setHidden:NO];
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [self.errorLabel setText:error.localizedDescription];
}

#pragma mark -
#pragma mark Page Controls

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
            siteScrollView.alpha = 0;
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
    NSString *folder_title;
    if (row == 0) {
        folder_title = @"- Top Level -";
    } else {
        folder_title = [[appDelegate dictFoldersArray] objectAtIndex:row];        
    }
    [inFolderInput setText:folder_title];
}

- (void)hideFolderPicker {
    [UIView animateWithDuration:.35 animations:^{
        folderPicker.frame = CGRectMake(0, self.view.bounds.size.height, folderPicker.frame.size.width, folderPicker.frame.size.height);          
    }];
}

#pragma mark -
#pragma mark Autocomplete sites


- (int)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [autocompleteResults count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView 
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *AddSiteAutocompleteCellIdentifier = @"AddSiteAutocompleteCellIdentifier";
    
	AddSiteAutocompleteCell *cell = (AddSiteAutocompleteCell *)[tableView dequeueReusableCellWithIdentifier:AddSiteAutocompleteCellIdentifier];
	if (cell == nil) {
		NSArray *nib = [[NSBundle mainBundle] loadNibNamed:@"AddSiteAutocompleteCell"
                                                     owner:self
                                                   options:nil];
        for (id oneObject in nib) {
            if ([oneObject isKindOfClass:[AddSiteAutocompleteCell class]]) {
                cell = (AddSiteAutocompleteCell *)oneObject;
            }
        }
	}
    
    NSDictionary *result = [autocompleteResults objectAtIndex:indexPath.row];
    int subs = [[result objectForKey:@"num_subscribers"] intValue];
    NSNumberFormatter *numberFormatter = [[[NSNumberFormatter alloc] init] autorelease];
	[numberFormatter setPositiveFormat:@"#,###"];
	NSNumber *theScore = [NSNumber numberWithInt:subs];
    cell.feedTitle.text = [result objectForKey:@"label"];
    cell.feedUrl.text = [result objectForKey:@"value"];
    cell.feedSubs.text = [NSString stringWithFormat:@"%@ subscriber%@", 
                          [NSString stringWithFormat:@"%@", [numberFormatter stringFromNumber:theScore]], subs == 1 ? @"" : @"s"];
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *result = [autocompleteResults objectAtIndex:indexPath.row];
    [self.siteAddressInput setText:[result objectForKey:@"value"]];
    [self addSite];
    [UIView animateWithDuration:.35 animations:^{
        siteScrollView.alpha = 0;
    }];
}

@end
