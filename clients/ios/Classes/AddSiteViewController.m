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
#import "MenuViewController.h"
#import "SBJson4.h"
#import "NewsBlur-Swift.h"

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
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];

    self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemCancel target:self action:@selector(doCancelButton)];
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Add Site" style:UIBarButtonItemStyleDone target:self action:@selector(addSite)];
    
    UIView *folderPadding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 24, 16)];
    UIImageView *folderImage = [[UIImageView alloc]
                                initWithImage:[UIImage imageNamed:@"g_icn_folder_sm.png"]];
    folderImage.frame = CGRectMake(0, 0, 24, 16);
    [folderImage setContentMode:UIViewContentModeRight];
    [folderPadding addSubview:folderImage];
    [self.inFolderInput setLeftView:folderPadding];
    [self.inFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    
    // If you want to show a disclosure arrow; don't really need it, though.
    //    UIImageView *disclosureImage = [[UIImageView alloc]
    //                                initWithImage:[UIImage imageNamed:@"accessory_disclosure.png"]];
    //    disclosureImage.frame = CGRectMake(0, 0, 24, 20);
    //    [disclosureImage setContentMode:UIViewContentModeLeft];
    //    [inFolderInput setRightView:disclosureImage];
    //    [inFolderInput setRightViewMode:UITextFieldViewModeAlways];
    
    UIView *folderPadding2 = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 24, 16)];
    UIImageView *folderImage2 = [[UIImageView alloc]
                                 initWithImage:[UIImage imageNamed:@"g_icn_folder_rss_sm.png"]];
    folderImage2.frame = CGRectMake(0, 0, 24, 16);
    [folderImage2 setContentMode:UIViewContentModeRight];
    [folderPadding2 addSubview:folderImage2];
    [self.addFolderInput setLeftView:folderPadding2];
    [self.addFolderInput setLeftViewMode:UITextFieldViewModeAlways];
    
    UIView *urlPadding = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 24, 16)];
    UIImageView *urlImage = [[UIImageView alloc]
                             initWithImage:[Utilities imageNamed:@"world" sized:16]];
    urlImage.frame = CGRectMake(0, 0, 24, 16);
    [urlImage setContentMode:UIViewContentModeRight];
    [urlPadding addSubview:urlImage];
    [self.siteAddressInput setLeftView:urlPadding];
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
    
    if (!self.errorLabel.hidden) {
        size.height += 140.0;
    }
    
    self.navigationController.preferredContentSize = size;
    
    return size;
}

- (IBAction)doCancelButton {
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
        [appDelegate hidePopover];
    } else {
        [appDelegate hidePopoverAnimated:YES];
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
                           appDelegate.url, [phrase stringByAddingPercentEncodingWithAllowedCharacters:[NSCharacterSet URLHostAllowedCharacterSet]]];
    [appDelegate GET:urlString parameters:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        NSString *query = [NSString stringWithFormat:@"%@", [responseObject objectForKey:@"term"]];
        NSString *phrase = self.siteAddressInput.text;
        
        // cache the results
        [self.searchResults_ setValue:[responseObject objectForKey:@"feeds"] forKey:query];
        
        if ([phrase isEqualToString:query]) {
            self.autocompleteResults = [responseObject objectForKey:@"feeds"];
            [self reloadSearchResults];
        } else {
            [self.siteActivityIndicator stopAnimating];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self.siteActivityIndicator stopAnimating];
    }];
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
                           appDelegate.url];
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    NSString *parent_folder = [self extractParentFolder];
    [params setObject:parent_folder forKey:@"folder"];
    [params setObject:[self.siteAddressInput text] forKey:@"url"];
    if (self.addFolderButton.selected && [self.addFolderInput.text length]) {
        [params setObject:[self.addFolderInput text] forKey:@"new_folder"];
    }
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
        [self.addingLabel setHidden:YES];
        [self.activityIndicator stopAnimating];
        
        int code = [[responseObject valueForKey:@"code"] intValue];
        if (code == -1) {
            [self.errorLabel setText:[responseObject valueForKey:@"message"]];
            [self.errorLabel setHidden:NO];
        } else {
            if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) {
                [self->appDelegate hidePopover];
            } else {
                [self->appDelegate hidePopoverAnimated:YES];
            }
            [self->appDelegate reloadFeedsView:NO];
        }
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        [self.addingLabel setHidden:YES];
        [self.errorLabel setHidden:NO];
        [self.activityIndicator stopAnimating];
        NSLog(@"Error: %@", error);
        [self.errorLabel setText:error.localizedDescription];
        self.siteTable.hidden = YES;
        [self preferredContentSize];
        
    }];
}

- (NSString *)extractParentFolder {
    NSString *parent_folder = [self.inFolderInput text];
    NSInteger folder_loc = [parent_folder rangeOfString:@" ▸ " options:NSBackwardsSearch].location;
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

- (NSArray *)folders {
    return _.without([appDelegate dictFoldersArray],
                     @[@"saved_searches",
                       @"saved_stories",
                       @"read_stories",
                       @"widget_stories",
                       @"river_blurblogs",
                       @"river_global",
                       @"infrequent",
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
        
        NSArray *components = [title componentsSeparatedByString:@" ▸ "];
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
    
    [appDelegate.addSiteNavigationController showViewController:viewController sender:self];
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
        
        if (cell == nil) {
            cell = [AddSiteAutocompleteCell new];
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
        NSData *imageData = [[NSData alloc] initWithBase64EncodedString:favicon options:NSDataBase64DecodingIgnoreUnknownCharacters];
        faviconImage = [UIImage imageWithData:imageData];
    } else {
        faviconImage = [Utilities imageNamed:@"world" sized:16];
    }
    
    cell.feedTitle.text = [result objectForKey:@"label"];
    cell.feedTitle.textColor = UIColorFromRGB(NEWSBLUR_BLACK_COLOR);
    cell.feedUrl.text = [result objectForKey:@"value"];
    cell.feedUrl.textColor = UIColorFromLightDarkRGB(NEWSBLUR_LINK_COLOR, 0x3B7CC5);
    cell.feedSubs.text = [NSString stringWithFormat:@"%@ subscriber%@",
                           [NSString stringWithFormat:@"%@", [numberFormatter stringFromNumber:theScore]], subs == 1 ? @"" : @"s"];
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
