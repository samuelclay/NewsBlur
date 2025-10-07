//
//  FTUXaddSitesViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 7/22/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FirstTimeUserAddSitesViewController.h"
#import "FirstTimeUserAddFriendsViewController.h"
#import "AuthorizeServicesViewController.h"
#import "SiteCell.h"
#import "NewsBlur-Swift.h"

@interface FirstTimeUserAddSitesViewController()

@property (readwrite) int importedFeedCount_;
@property (nonatomic) UIButton *currentButton_;
@property (nonatomic, strong) NSMutableSet *selectedCategories_;
@property (readwrite) BOOL googleImportSuccess_;

@end;

@implementation FirstTimeUserAddSitesViewController

@synthesize googleReaderButton;
@synthesize nextButton;
@synthesize activityIndicator;
@synthesize instructionLabel;
@synthesize categoriesTable;
@synthesize googleReaderButtonWrapper;
@synthesize importedFeedCount_;
@synthesize currentButton_;
@synthesize selectedCategories_;
@synthesize googleImportSuccess_;

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    self.selectedCategories_ = [[NSMutableSet alloc] init];
    
    [super viewDidLoad];
    
    UIBarButtonItem *next = [[UIBarButtonItem alloc] initWithTitle:@"Next step" style:UIBarButtonItemStyleDone target:self action:@selector(tapNextButton)];
    self.nextButton = next;
    self.nextButton.enabled = YES;
    self.navigationItem.rightBarButtonItem = next;
    
    self.navigationItem.title = @"Add Sites";
    self.activityIndicator.hidesWhenStopped = YES;
    
    self.categoriesTable.delegate = self;
    self.categoriesTable.dataSource = self;
    self.categoriesTable.backgroundColor = [UIColor clearColor];
//    self.categoriesTable.separatorColor = [UIColor clearColor];
    self.categoriesTable.opaque = NO;
    self.categoriesTable.backgroundView = nil;
    
    if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
        self.instructionLabel.font = [UIFont systemFontOfSize:20];
    }
    
    
    UIActivityIndicatorView *activityView = [[UIActivityIndicatorView alloc] 
                                             initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    activityView.frame = CGRectMake(68, 7, 20, 20.0);
    self.activityIndicator = activityView;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.navigationItem.rightBarButtonItem setStyle:UIBarButtonItemStyleDone];
    [self.categoriesTable reloadData];
    
    NSLog(@"%f height", self.tableViewHeight);
}

//- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
//    // Return YES for supported orientations
//    if (!self.isPhone) {
//        return YES;
//    } else if (UIInterfaceOrientationIsPortrait(interfaceOrientation)) {
//        return YES;
//    }
//    return NO;
//}


- (IBAction)tapNextButton {
    [appDelegate.ftuxNavigationController showViewController:appDelegate.firstTimeUserAddFriendsViewController sender:self];
    
    if (self.selectedCategories_.count) {
        NSString *urlString = [NSString stringWithFormat:@"%@/categories/subscribe",
                               self.appDelegate.url];
        NSMutableDictionary *params = [NSMutableDictionary dictionary];
        NSMutableArray *categories = [NSMutableArray array];
        
        for (NSObject *category in self.selectedCategories_) {
            [categories addObject:category];
        }
        [params setObject:categories forKey:@"category"];

        [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {

        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [self informError:error];
        }];
    }
}

#pragma mark -
#pragma mark Import Google Reader

- (void)tapGoogleReaderButton {
    AuthorizeServicesViewController *service = [[AuthorizeServicesViewController alloc] init];
    service.url = @"/import/authorize";
    service.type = @"google";
    [appDelegate.ftuxNavigationController showViewController:service sender:self];
}

- (void)importFromGoogleReader {    
    UIView *header = [self.categoriesTable viewWithTag:0];
    UIButton *button = (UIButton *)[header viewWithTag:1000];
    self.googleReaderButton = button;

    self.nextButton.enabled = YES;
    [self.googleReaderButton setTitle:@"Importing sites..." forState:UIControlStateNormal];
    self.instructionLabel.textColor = UIColorFromRGB(0x333333);
    self.googleReaderButton.userInteractionEnabled = NO;
    self.instructionLabel.text = @"This might take a minute.\nFeel free to continue...";
    [self.googleReaderButton addSubview:self.activityIndicator];
    [self.activityIndicator startAnimating];
    NSString *urlString = [NSString stringWithFormat:@"%@/import/import_from_google_reader/",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:@"true" forKey:@"auto_active"];
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [self finishImportFromGoogleReader:responseObject];
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self importFromGoogleReaderFailed:error];
    }];
}

- (void)importFromGoogleReaderFailed:(NSError *)error {
    [self.googleReaderButton setTitle:@"Retry Google Reader" forState:UIControlStateNormal];
    self.instructionLabel.textColor = [UIColor redColor];
    self.instructionLabel.text = error.localizedDescription;
}

- (void)finishImportFromGoogleReader:(NSDictionary *)results {
    NSLog(@"results are %@", results);
    
    self.importedFeedCount_ = [[results objectForKey:@"feed_count"] intValue];
    [self performSelector:@selector(updateSites) withObject:nil afterDelay:1];
    self.googleImportSuccess_ = YES;
}

- (void)updateSites {
    self.instructionLabel.text = [NSString stringWithFormat:@"You are subscribed to %lu sites", (unsigned long)[[appDelegate.dictFeeds allKeys] count]];
    NSString *msg = [NSString stringWithFormat:@"Imported %i site%@", 
                     self.importedFeedCount_,
                     self.importedFeedCount_ == 1 ? @"" : @"s"];
    [self.googleReaderButton setTitle:msg  forState:UIControlStateSelected];
    self.googleReaderButton.selected = YES;
    [self.activityIndicator stopAnimating];
    
    UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
    UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
    checkmarkView.frame = CGRectMake(self.googleReaderButton.frame.size.width - 24,
                                     8,
                                     16,
                                     16);
    [self.googleReaderButton addSubview:checkmarkView];
}

#pragma mark -
#pragma mark Add Categories

- (void)addCategory:(id)sender {
    // set the currentButton
    self.currentButton_ = (UIButton *)sender;
    UIButton *button = (UIButton *)sender;
    NSLog(@"self.currentButton_.titleLabel.text is %@", self.currentButton_.titleLabel.text);
    if (button.selected) {
        [self.selectedCategories_ removeObject:self.currentButton_.titleLabel.text];
        
        self.nextButton.enabled = YES;
        button.selected = NO;
        UIImageView *imageView = (UIImageView*)[button viewWithTag:100];
        [imageView removeFromSuperview];
    } else {
        [self.selectedCategories_ addObject:self.currentButton_.titleLabel.text];
        button.selected = YES;
    }

    if (self.googleImportSuccess_) {
        self.nextButton.enabled = YES;
    } else if (self.selectedCategories_.count) {
        self.nextButton.enabled = YES;
    } else {
        self.nextButton.enabled = YES;
    }
    
    [self.categoriesTable reloadData];
}

#pragma mark -
#pragma mark Add Site

- (void)addSite:(NSString *)siteUrl {
    NSString *urlString = [NSString stringWithFormat:@"%@/reader/add_url",
                           self.appDelegate.url];
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:siteUrl forKey:@"url"];
    
    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self informError:error];
    }];
}

#pragma mark -
#pragma mark Table View - Interactions List

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return appDelegate.categories.count + 1;
}

//- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
//{    
//    NSDictionary *category = [appDelegate.categories objectAtIndex:section];
//    return [category objectForKey:@"title"];
//}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {    
    if (section == 0) {
        return 0;
    } else {
        NSDictionary *category = [appDelegate.categories objectAtIndex:section - 1];
        NSArray *categorySiteList = [category objectForKey:@"feed_ids"];
        return categorySiteList.count;
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 26.0;
}

- (CGFloat) tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 30.0;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        UIView* categoryTitleView = [UIView new];
        UILabel *categoryTitleLabel = [UILabel new];
        categoryTitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        categoryTitleLabel.text = @"You can always add your own individual sites.";
        categoryTitleLabel.font = [UIFont fontWithName:@"WhitneySSm-Book" size:15];
        [categoryTitleView addSubview:categoryTitleLabel];
        categoryTitleLabel.textColor = [UIColor darkGrayColor];
        categoryTitleLabel.backgroundColor = [UIColor clearColor];
        categoryTitleView.backgroundColor = [UIColor clearColor];
        categoryTitleLabel.textAlignment = NSTextAlignmentCenter;
        
        [NSLayoutConstraint constraintWithItem:categoryTitleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:categoryTitleView attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0.0].active = YES;
        [NSLayoutConstraint constraintWithItem:categoryTitleLabel attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:categoryTitleView attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0].active = YES;
        
        return categoryTitleView;
    }
    
    // create the parent view that will hold header Label
    UIView* customView = [UIView new];
    customView.tag = section;
    
    UIImage *buttonImage =[[UIImage imageNamed:@"google.png"]
                           stretchableImageWithLeftCapWidth:5.0 topCapHeight:0.0];
    UIButton *headerBtn = [UIButton buttonWithType:UIButtonTypeCustom];
    headerBtn.translatesAutoresizingMaskIntoConstraints = NO;
    headerBtn.tag = section + 1000;
    [headerBtn setBackgroundImage:buttonImage forState:UIControlStateNormal];
    headerBtn.titleLabel.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:15];
    
    headerBtn.titleLabel.shadowColor = UIColorFromRGB(0x1E5BDB);
    headerBtn.titleLabel.shadowOffset = CGSizeMake(0, 1);
    NSString *categoryTitle;
    NSDictionary *category = [appDelegate.categories objectAtIndex:section - 1];
    categoryTitle = [category objectForKey:@"title"];
    
    BOOL inSelect = [self.selectedCategories_
                     containsObject:[NSString stringWithFormat:@"%@", [category objectForKey:@"title"]]];
    NSLog(@"inselected %i", inSelect);
    
    if (inSelect) {
        headerBtn.selected = YES;
        UIImage *checkmark = [UIImage imageNamed:@"258-checkmark"];
        UIImageView *checkmarkView = [[UIImageView alloc] initWithImage:checkmark];
        checkmarkView.translatesAutoresizingMaskIntoConstraints = NO;
        checkmarkView.tag = 100;
        [headerBtn addSubview:checkmarkView];
        
        NSDictionary *views = @{@"checkmark" : checkmarkView};
        
        [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:[checkmark(16)]-10-|" options:0 metrics:nil views:views]];
        [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:[checkmark(16)]" options:0 metrics:nil views:views]];
        [NSLayoutConstraint constraintWithItem:checkmarkView attribute:NSLayoutAttributeCenterY relatedBy:NSLayoutRelationEqual toItem:headerBtn attribute:NSLayoutAttributeCenterY multiplier:1.0 constant:0.0].active = YES;
    }
    
    [headerBtn setTitle:categoryTitle forState:UIControlStateNormal];
    [headerBtn addTarget:self action:@selector(addCategory:) forControlEvents:UIControlEventTouchUpInside];
    [customView addSubview:headerBtn];
    
    NSDictionary *views = @{@"button" : headerBtn, @"customView" : customView};
    
    [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|-0-[button]-0-|" options:0 metrics:nil views:views]];
    [NSLayoutConstraint activateConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|-0-[button]-0-|" options:0 metrics:nil views:views]];
    
    return customView;
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    SiteCell *cell = [tableView
                      dequeueReusableCellWithIdentifier:@"ActivityCell"];
    if (cell == nil) {
        cell = [[SiteCell alloc] 
                initWithStyle:UITableViewCellStyleDefault 
                reuseIdentifier:@"ActivityCell"];
    } 

    NSString *siteTitle;

    NSDictionary *category = [appDelegate.categories objectAtIndex:indexPath.section - 1];
    NSArray *categorySiteList = [category objectForKey:@"feed_ids"];
    NSString * feedId = [NSString stringWithFormat:@"%@", [categorySiteList objectAtIndex:indexPath.row ]];
    
    NSDictionary *feed = [appDelegate.categoryFeeds objectForKey:feedId];
    siteTitle = [feed objectForKey:@"feed_title"];
    
    BOOL inSelect = [self.selectedCategories_ containsObject:[NSString stringWithFormat:@"%@", [category objectForKey:@"title"]]];

    if (inSelect) {
        cell.isRead = NO;
    } else {
        cell.isRead = YES;
    }

    // feed color bar border
    unsigned int colorBorder = 0;
    NSString *faviconColor = [feed valueForKey:@"favicon_color"];
    
    if ([faviconColor class] == [NSNull class]) {
        faviconColor = @"505050";
    }    
    NSScanner *scannerBorder = [NSScanner scannerWithString:faviconColor];
    [scannerBorder scanHexInt:&colorBorder];
    
    cell.feedColorBar = UIColorFromFixedRGB(colorBorder);
    
    // feed color bar border
    NSString *faviconFade = [feed valueForKey:@"favicon_border"];
    if ([faviconFade class] == [NSNull class]) {
        faviconFade = @"505050";
    }    
    scannerBorder = [NSScanner scannerWithString:faviconFade];
    [scannerBorder scanHexInt:&colorBorder];
    cell.feedColorBarTopBorder =  UIColorFromFixedRGB(colorBorder);
    
    // favicon
    
    NSString *faviconStr = [NSString stringWithFormat:@"%@", [feed valueForKey:@"favicon"]];
    NSData *imageData = [[NSData alloc] initWithBase64EncodedString:faviconStr options:NSDataBase64DecodingIgnoreUnknownCharacters];
    UIImage *faviconImage = [UIImage imageWithData:imageData];
    

    cell.siteFavicon = faviconImage;

    cell.opaque = NO;
    cell.siteTitle = siteTitle; 
    
    return cell;
}

- (void)tableView:(UITableView *)tableView 
didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIView *header = [self.categoriesTable viewWithTag:indexPath.section];
    UIButton *button = (UIButton *)[header viewWithTag:indexPath.section + 1000];
    [button sendActionsForControlEvents:UIControlEventTouchUpInside];
}

-(NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    UIView *header = [self.categoriesTable viewWithTag:indexPath.section];
    UIButton *button = (UIButton *)[header viewWithTag:indexPath.section + 1000];
    [button sendActionsForControlEvents:UIControlEventTouchDragInside];
    return indexPath;
}

- (CGFloat)tableViewHeight {
    [self.categoriesTable layoutIfNeeded];
    return [self.categoriesTable contentSize].height;
}

@end
