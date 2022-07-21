//
//  MoveSiteViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 12/2/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "MoveSiteViewController.h"
#import "NewsBlurAppDelegate.h"
#import "StringHelper.h"
#import "StoriesCollection.h"

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
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    UIImageView *folderImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"folder-open"]];
    folderImage.frame = CGRectMake(0, 0, 24, 16);
    [folderImage setContentMode:UIViewContentModeRight];
    [toFolderInput setLeftView:folderImage];
    [toFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    
    UIImageView *folderImage2 = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"g_icn_folder_rss.png"]];
    folderImage2.frame = CGRectMake(0, 0, 24, 16);
    [folderImage2 setContentMode:UIViewContentModeRight];
    [fromFolderInput setLeftView:folderImage2];
    [fromFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    
    navBar.tintColor = [UIColor colorWithRed:0.16f green:0.36f blue:0.46 alpha:0.9];

    CGRect frame = self.navBar.frame;
    frame.size.height += 20;
    self.navBar.frame = frame;
    
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    [super viewDidLoad];
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    // Return YES for supported orientations
//    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
//        return YES;
//    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
//        return YES;
//    }
//    
//    return NO;
//}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    
    for (UIView *subview in [self.titleLabel subviews]) {
        [subview removeFromSuperview];
    }
    UIView *label = [appDelegate makeFeedTitle:appDelegate.storiesCollection.activeFeed];
    label.frame = CGRectMake(8,
                             0, 
                             200, 
                             20);
    [self.titleLabel addSubview:label];
    [self reload];
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated {
    [self.activityIndicator stopAnimating];
    [super viewDidAppear:animated];
}


- (void)reload {
    BOOL isTopLevel = [[appDelegate.storiesCollection.activeFolder trim] isEqualToString:@""] ||
                      [appDelegate.storiesCollection.activeFolder isEqual:@"everything"];
    NSInteger row = 0;
    [toFolderInput setText:@""];
    
    if (appDelegate.storiesCollection.isRiverView) {
        NSString *parentFolderName = [appDelegate extractParentFolderName:appDelegate.storiesCollection.activeFolder];
        row = [[self pickerFolders] 
               indexOfObject:parentFolderName];
        fromFolderInput.text = parentFolderName;
    } else {
        fromFolderInput.text = isTopLevel ? @"— Top Level —" : appDelegate.storiesCollection.activeFolder;
        row = isTopLevel ? 
                0 :
                [[self pickerFolders] indexOfObject:appDelegate.storiesCollection.activeFolder];
    }
    self.folders = [NSMutableArray array];
    [folderPicker reloadAllComponents];
    [folderPicker selectRow:row inComponent:0 animated:NO];
    
    moveButton.enabled = NO;
    moveButton.title = appDelegate.storiesCollection.isRiverView ? @"Move Folder to Folder" : @"Move Site to Folder";
}

- (IBAction)doCancelButton {
    [appDelegate.moveSiteViewController dismissViewControllerAnimated:YES completion:nil];
}

- (IBAction)doMoveButton {
    if (appDelegate.storiesCollection.isRiverView) {
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
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/move_feed_to_folder",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *fromFolder = [appDelegate extractFolderName:[fromFolderInput text]];
    NSString *toFolder = [appDelegate extractFolderName:[toFolderInput text]];
    [params setObject:fromFolder forKey:@"in_folder"];
    [params setObject:toFolder forKey:@"to_folder"]; 
    [params setObject:[appDelegate.storiesCollection.activeFeed objectForKey:@"id"] forKey:@"feed_id"];
    [appDelegate POST:urlString parameters:params target:self success:@selector(requestFinished:) failure:@selector(requestFailed:)];
}

- (void)requestFinished:(NSDictionary *)results {
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];

    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        [self.errorLabel setText:[results valueForKey:@"message"]];   
        [self.errorLabel setHidden:NO];
    } else {
        appDelegate.storiesCollection.activeFolder = [toFolderInput text];
        [appDelegate.moveSiteViewController dismissViewControllerAnimated:YES completion:nil];
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
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/move_folder_to_folder",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *folderName = [appDelegate extractFolderName:appDelegate.storiesCollection.activeFolder];
    NSString *fromFolder = [appDelegate extractFolderName:[fromFolderInput text]];
    NSString *toFolder = [appDelegate extractFolderName:[toFolderInput text]];
    [params setObject:fromFolder forKey:@"in_folder"]; 
    [params setObject:toFolder forKey:@"to_folder"]; 
    [params setObject:folderName forKey:@"folder_name"];
    [appDelegate POST:urlString parameters:params target:self success:@selector(finishMoveFolder:) failure:@selector(requestFailed:)];
}

- (void)finishMoveFolder:(NSDictionary *)results {
    [self.movingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];

    int code = [[results valueForKey:@"code"] intValue];
    if (code == -1) {
        [self.errorLabel setText:[results valueForKey:@"message"]];   
        [self.errorLabel setHidden:NO];
    } else {
        [appDelegate.moveSiteViewController dismissViewControllerAnimated:YES completion:nil];
        [appDelegate reloadFeedsView:NO];
    }
    
}

- (void)requestFailed:(NSError *)error {
    [self.movingLabel setHidden:YES];
    [self.errorLabel setHidden:NO];
    [self.activityIndicator stopAnimating];
    NSLog(@"Error: %@", error);
    [self.errorLabel setText:error.localizedDescription];
}

#pragma mark -
#pragma mark Folder Picker

- (NSArray *)pickerFolders {
    if ([self.folders count]) return self.folders;
    
    self.folders = [NSMutableArray array];
    [self.folders addObject:@"— Top Level —"];
    
    for (NSString *folder in appDelegate.dictFoldersArray) {
        if ([folder isEqualToString:@"everything"]) continue;
        if ([folder isEqualToString:@"infrequent"]) continue;
        if ([folder isEqualToString:@"river_blurblogs"]) continue;
        if ([folder isEqualToString:@"river_global"]) continue;
        if ([folder isEqualToString:@"widget_stories"]) continue;
        if ([folder isEqualToString:@"read_stories"]) continue;
        if ([folder isEqualToString:@"saved_searches"]) continue;
        if ([folder isEqualToString:@"saved_stories"]) continue;
        if ([[folder trim] isEqualToString:@""]) continue;
        if (appDelegate.storiesCollection.isRiverView) {
            if (![folder containsString:appDelegate.storiesCollection.activeFolder]) {
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


@implementation FolderTextField

- (CGRect)textRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 24, 0);
}

- (CGRect)editingRectForBounds:(CGRect)bounds {
    return CGRectInset(bounds, 24, 0);
}

@end
