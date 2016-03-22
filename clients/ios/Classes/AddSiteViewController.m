//
//  AddSiteViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "AddSiteViewController.h"
#import "AddSiteAutocompleteCell.h"
#import "NewsBlurAppDelegate.h"
#import "NewsBlurViewController.h"
#import "ASIHTTPRequest.h"
#import "ASIFormDataRequest.h"
#import "NBContainerViewController.h"
#import "MenuViewController.h"
#import "SBJson4.h"
#import "Base64.h"

@interface AddSiteViewController()

@property (nonatomic) NSString *activeTerm_;
@property (nonatomic, strong) NSMutableDictionary *searchResults_;

@end

@implementation AddSiteViewController

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    
    if (self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil]) {
    }
    return self;
}

- (void)viewDidLoad {
    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancelButton)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add Site" style:UIBarButtonItemStyleDone target:self action:@selector(addSite)];
    
    UIImageView *folderImage = [[UIImageView alloc]
                                initWithImage:[UIImage imageNamed:@"g_icn_folder_sm.png"]];
    folderImage.frame = CGRectMake(0, 0, 24, 16);
    [folderImage setContentMode:UIViewContentModeRight];
    [self.inFolderInput setLeftView:folderImage];
    [self.inFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    
    // If you want to show a disclosure arrow; don't really need it, though.
//    UIImageView *disclosureImage = [[UIImageView alloc]
//                                initWithImage:[UIImage imageNamed:@"accessory_disclosure.png"]];
//    disclosureImage.frame = CGRectMake(0, 0, 24, 20);
//    [disclosureImage setContentMode:UIViewContentModeLeft];
//    [inFolderInput setRightView:disclosureImage];
//    [inFolderInput setRightViewMode:UITextFieldViewModeAlways];
    
    UIImageView *folderImage2 = [[UIImageView alloc]
                                 initWithImage:[UIImage imageNamed:@"g_icn_folder_rss_sm.png"]];
    folderImage2.frame = CGRectMake(0, 0, 24, 16);
    [folderImage2 setContentMode:UIViewContentModeRight];
    [self.addFolderInput setLeftView:folderImage2];
    [self.addFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    
    UIImageView *urlImage = [[UIImageView alloc]
                             initWithImage:[UIImage imageNamed:@"world.png"]];
    urlImage.frame = CGRectMake(0, 0, 24, 16);
    [urlImage setContentMode:UIViewContentModeRight];
    [self.siteAddressInput setLeftView:urlImage];
    [self.siteAddressInput setLeftViewMode:UITextFieldViewModeAlways];
    
    self.siteTable.hidden = YES;
    self.activeTerm_ = @"";
    self.searchResults_ = [[NSMutableDictionary alloc] init];
    
    [super viewDidLoad];
}

- (void)viewWillAppear:(BOOL)animated {
    [self.errorLabel setHidden:YES];
    [self.addingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    
    self.view.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    self.siteTable.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    // eliminate extra separators at bottom of site table (e.g., while animating)
    self.siteTable.tableFooterView = [[UIView alloc] initWithFrame:CGRectZero];

    [super viewWillAppear:animated];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        return YES;
    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
        return YES;
    }
    
    return NO;
}

- (void)viewDidAppear:(BOOL)animated {
    [self.activityIndicator stopAnimating];
    [super viewDidAppear:animated];
    
    [self.siteAddressInput becomeFirstResponder];
}

- (CGSize)preferredContentSize {
    CGSize size = CGSizeMake(320.0, 96.0);
    
    if (self.addFolderButton.selected) {
        size.height += 39.0;
    }
    
    if (!self.siteTable.hidden) {
        size.height += 215.0;
    }
    
    self.navigationController.preferredContentSize = size;
    
    return size;
}

- (IBAction)doCancelButton {
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.appDelegate hidePopover];
    } else {
        [self.appDelegate hidePopoverAnimated:YES];
    }
}

- (IBAction)doAddButton {
    return [self addSite];
}

- (void)reload {
    // Force the view to load.
    [self view];
    
    [self.inFolderInput setText:@"— Top Level —"];
    [self.siteAddressInput setText:@""];
    [self.addFolderInput setText:@""];
}

#pragma mark -
#pragma mark Add Site

- (BOOL)textFieldShouldBeginEditing:(UITextField *)textField {
    [self.errorLabel setText:@""];
    if (textField == self.inFolderInput && ![self.inFolderInput isFirstResponder]) {
        [self showFolderMenu];
        return NO;
    }
    return YES;
}

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    if (textField == self.inFolderInput) {
        
    } else if (textField == self.siteAddressInput) {
        if (self.siteAddressInput.returnKeyType == UIReturnKeySearch) {
            [self checkSiteAddress];
        } else {
            [self addSite];            
        }
    }
	return YES;
}

- (IBAction)checkSiteAddress {
    NSString *phrase = self.siteAddressInput.text;
    
    if ([phrase length] == 0) {
        self.siteTable.hidden = YES;
        [self preferredContentSize];
        return;
    }
    
    if ([self.searchResults_ objectForKey:phrase]) {
        self.autocompleteResults = [self.searchResults_ objectForKey:phrase];
        [self reloadSearchResults];
        return;
    }
    
    NSInteger periodLoc = [phrase rangeOfString:@"."].location;
    if (periodLoc != NSNotFound && self.siteAddressInput.returnKeyType != UIReturnKeyDone) {
        // URL
        [self.siteAddressInput setReturnKeyType:UIReturnKeyDone];
        [self.siteAddressInput resignFirstResponder];
        [self.siteAddressInput becomeFirstResponder];
    } else if (periodLoc == NSNotFound && self.siteAddressInput.returnKeyType != UIReturnKeySearch) {
        // Search
        [self.siteAddressInput setReturnKeyType:UIReturnKeySearch];
        [self.siteAddressInput resignFirstResponder];
        [self.siteAddressInput becomeFirstResponder];
    }
    
    [self.siteActivityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"%@/rss_feeds/feed_autocomplete?term=%@&v=2",
                           self.appDelegate.url, [phrase stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIHTTPRequest requestWithURL:url];
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(autocompleteSite:)];
    [request startAsynchronous];
}

- (void)autocompleteSite:(ASIHTTPRequest *)request {
    NSString *responseString = [request responseString];
    NSData *responseData=[responseString dataUsingEncoding:NSUTF8StringEncoding];    
    NSError *error;
    NSDictionary *results = [NSJSONSerialization 
                             JSONObjectWithData:responseData
                             options:kNilOptions 
                             error:&error];
    

    NSString *query = [NSString stringWithFormat:@"%@", [results objectForKey:@"term"]];
    NSString *phrase = self.siteAddressInput.text;
    
    // cache the results
    [self.searchResults_ setValue:[results objectForKey:@"feeds"] forKey:query];

    if ([phrase isEqualToString:query]) {
        self.autocompleteResults = [results objectForKey:@"feeds"];
        [self reloadSearchResults];       
    }
    
//    NSRange range = [query rangeOfString : activeTerm_];
//    BOOL found = (range.location != NSNotFound);
}

- (void)reloadSearchResults {
    if ([self.siteAddressInput.text length] > 0 && [self.autocompleteResults count] > 0) {
        [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionAllowUserInteraction 
                         animations:^{
                             [self.siteScrollView setAlpha:1];
                         } completion:nil];
    } else {
        [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionAllowUserInteraction 
                         animations:^{
                             [self.siteScrollView setAlpha:0];
                         } completion:nil];
    }
    
    [self.siteActivityIndicator stopAnimating];
    self.siteTable.hidden = NO;
    [self.siteTable reloadData];
    [self preferredContentSize];
}

- (IBAction)addSite {
    self.siteTable.hidden = YES;
    [self preferredContentSize];
    [self.siteAddressInput resignFirstResponder];
    [self.addingLabel setHidden:NO];
    [self.addingLabel setText:@"Adding site..."];
    [self.errorLabel setHidden:YES];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/add_url",
                           self.appDelegate.url];
    NSURL *url = [NSURL URLWithString:urlString];
    ASIFormDataRequest *request = [ASIFormDataRequest requestWithURL:url];
    NSString *parent_folder = [self extractParentFolder];
    [request setPostValue:parent_folder forKey:@"folder"]; 
    [request setPostValue:[self.siteAddressInput text] forKey:@"url"];
    if (self.addFolderButton.selected && [self.addFolderInput.text length]) {
        [request setPostValue:[self.addFolderInput text] forKey:@"new_folder"];
    }
    [request setDelegate:self];
    [request setDidFinishSelector:@selector(requestFinished:)];
    [request setDidFailSelector:@selector(requestFailed:)];
    [request setTimeOutSeconds:30];
    [request startAsynchronous];
}


- (void)requestFinished:(ASIHTTPRequest *)request {
    [self.addingLabel setHidden:YES];
    [self.activityIndicator stopAnimating];
    NSString *responseString = [request responseString];
    NSData *responseData = [responseString dataUsingEncoding:NSUTF8StringEncoding];
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
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            [self.appDelegate hidePopover];
        } else {
            [self.appDelegate hidePopoverAnimated:YES];
        }
        [self.appDelegate reloadFeedsView:NO];
    }
    
}

- (NSString *)extractParentFolder {
    NSString *parent_folder = [self.inFolderInput text];
    NSInteger folder_loc = [parent_folder rangeOfString:@" - " options:NSBackwardsSearch].location;
    if ([parent_folder length] && folder_loc != NSNotFound) {
        parent_folder = [parent_folder substringFromIndex:(folder_loc + 3)];
    }
    NSInteger top_level_loc = [parent_folder rangeOfString:@" Top Level " options:NSBackwardsSearch].location;
    if (parent_folder.length && top_level_loc != NSNotFound) {
        parent_folder = @"";
    }
    return parent_folder;
}

#pragma mark -
#pragma mark Add Folder

- (IBAction)toggleAddFolder:(id)sender {
    if (!self.addFolderButton.selected) {
        self.addFolderButton.selected = YES;
        [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.addFolderInput.alpha = 1;
                             self.siteScrollView.frame = CGRectMake(self.siteScrollView.frame.origin.x,
                                                                    self.siteScrollView.frame.origin.y + 40,
                                                                    self.view.frame.size.width,
                                                                    self.siteScrollView.frame.size.height);
                         } completion:nil];

    } else {
        self.addFolderButton.selected = NO;
        [UIView animateWithDuration:.35 delay:0 options:UIViewAnimationOptionAllowUserInteraction
                         animations:^{
                             self.addFolderInput.alpha = 0;
                             self.siteScrollView.frame = CGRectMake(self.siteScrollView.frame.origin.x,
                                                                    self.siteScrollView.frame.origin.y - 40,
                                                                    self.view.frame.size.width,
                                                                    self.siteScrollView.frame.size.height);
                         } completion:nil];
    }
    
    [self preferredContentSize];
}

- (void)requestFailed:(ASIHTTPRequest *)request {
    [self.addingLabel setHidden:YES];
    [self.errorLabel setHidden:NO];
    [self.activityIndicator stopAnimating];
    NSError *error = [request error];
    NSLog(@"Error: %@", error);
    [self.errorLabel setText:error.localizedDescription];
    self.siteTable.hidden = YES;
    [self preferredContentSize];
}

- (NSArray *)folders {
    return _.without([self.appDelegate dictFoldersArray],
                     @[@"saved_stories",
                       @"read_stories",
                       @"river_blurblogs",
                       @"river_global",
                       @"everything"]);
}

- (void)showFolderMenu {
    MenuViewController *viewController = [MenuViewController new];
    viewController.title = @"Add To";
    
    __weak __typeof(&*self)weakSelf = self;
    
    [viewController addTitle:@"Top Level" iconName:@"menu_icn_all.png" selectionShouldDismiss:NO handler:^{
        weakSelf.inFolderInput.text = @"— Top Level —";
        [self.navigationController popViewControllerAnimated:YES];
    }];
    
    NSArray *folders = self.folders;
    
    for (NSString *folder in folders) {
        NSString *title = folder;
        NSString *iconName = @"menu_icn_move.png";
        
        NSArray *components = [title componentsSeparatedByString:@" - "];
        title = components.lastObject;
        for (NSUInteger idx = 0; idx < components.count; idx++) {
            title = [@"\t" stringByAppendingString:title];
        }
        
        [viewController addTitle:title iconName:iconName selectionShouldDismiss:NO handler:^{
            weakSelf.inFolderInput.text = folder;
            [self.navigationController popViewControllerAnimated:YES];
        }];
    }
    
    if ([self.inFolderInput.text isEqualToString:@"— Top Level —"]) {
        viewController.checkedRow = 0;
    } else {
        viewController.checkedRow = [folders indexOfObject:self.inFolderInput.text] + 1;
    }
    
    [self.appDelegate.addSiteNavigationController pushViewController:viewController animated:YES];
}

#pragma mark -
#pragma mark Autocomplete sites


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self.autocompleteResults count];
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
    
    NSDictionary *result = [self.autocompleteResults objectAtIndex:indexPath.row];
    int subs = [[result objectForKey:@"num_subscribers"] intValue];
    NSNumberFormatter *numberFormatter = [[NSNumberFormatter alloc] init];
	[numberFormatter setPositiveFormat:@"#,###"];
	NSNumber *theScore = [NSNumber numberWithInt:subs];
    NSString *favicon = [result objectForKey:@"favicon"];
    UIImage *faviconImage;
    if ((NSNull *)favicon != [NSNull null] && [favicon length] > 0) {
        NSData *imageData = [NSData dataWithBase64EncodedString:favicon];
        faviconImage = [UIImage imageWithData:imageData];
    } else {
        faviconImage = [UIImage imageNamed:@"world.png"];
    }

    cell.feedTitle.text = [result objectForKey:@"label"];
    cell.feedTitle.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    cell.feedUrl.text = [result objectForKey:@"value"];
    cell.feedUrl.textColor = UIColorFromFixedRGB(NEWSBLUR_LINK_COLOR);
    cell.feedSubs.text = [[NSString stringWithFormat:@"%@ subscriber%@",
                          [NSString stringWithFormat:@"%@", [numberFormatter stringFromNumber:theScore]], subs == 1 ? @"" : @"s"] uppercaseString];
    cell.feedSubs.textColor = UIColorFromRGB(0x808080);
    cell.feedFavicon.image = faviconImage;
    cell.backgroundColor = UIColorFromRGB(NEWSBLUR_WHITE_COLOR);
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NSDictionary *result = [self.autocompleteResults objectAtIndex:indexPath.row];
    [self.siteAddressInput setText:[result objectForKey:@"value"]];
    self.siteTable.hidden = YES;
    [self preferredContentSize];
}

@end
