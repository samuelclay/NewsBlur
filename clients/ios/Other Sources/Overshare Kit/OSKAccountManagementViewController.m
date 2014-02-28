//
//  OSKAccountManagementViewController.m
//  Overshare
//
//  Created by Jared Sinclair on 10/29/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKAccountManagementViewController.h"

#import "OSKPresentationManager.h"
#import "OSKActivity.h"
#import "OSKAccountChooserViewController.h"
#import "UIColor+OSKUtility.h"
#import "OSKPocketAccountViewController.h"
#import "OSKAccountTypeCell.h"
#import "OSKActivityToggleCell.h"

#import "OSK1PasswordSearchActivity.h"
#import "OSK1PasswordBrowserActivity.h"
#import "OSKAirDropActivity.h"
#import "OSKAppDotNetActivity.h"
#import "OSKChromeActivity.h"
#import "OSKCopyToPasteboardActivity.h"
#import "OSKDraftsActivity.h"
#import "OSKEmailActivity.h"
#import "OSKFacebookActivity.h"
#import "OSKInstapaperActivity.h"
#import "OSKOmnifocusActivity.h"
#import "OSKPinboardActivity.h"
#import "OSKPocketActivity.h"
#import "OSKReadabilityActivity.h"
#import "OSKReadingListActivity.h"
#import "OSKSafariActivity.h"
#import "OSKSMSActivity.h"
#import "OSKThingsActivity.h"
#import "OSKTwitterActivity.h"
#import "OSKGooglePlusActivity.h"

@interface OSKAccountManagementHeaderView : UITableViewHeaderFooterView

@property (strong, nonatomic) UILabel *label;

@end

static CGFloat OSKAccountManagementHeaderViewTopPadding = 22.0f;
static NSString * OSKAccountManagementHeaderViewIdentifier = @"OSKAccountManagementHeaderViewIdentifier";

@implementation OSKAccountManagementHeaderView

- (id)initWithReuseIdentifier:(NSString *)reuseIdentifier {
    self = [super initWithReuseIdentifier:reuseIdentifier];
    if (self) {
        [self setFrame:CGRectMake(0, 0, 320.0f, 44.0f)]; // to make sure it's non-zero.
        CGFloat padding = OSKAccountManagementHeaderViewTopPadding;
        UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(16.0f, padding, self.bounds.size.width - 32.0f, self.bounds.size.height - padding)];
        label.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
        label.backgroundColor = [UIColor clearColor];
        label.textAlignment = NSTextAlignmentLeft;
        UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
        if (descriptor) {
            [label setFont:[UIFont fontWithDescriptor:descriptor size:14]];
        } else {
            [label setFont:[UIFont systemFontOfSize:14]];
        }
        [label setTextColor:[[OSKPresentationManager sharedInstance] color_hashtags]];
        [self addSubview:label];
        
        _label = label;
    }
    return self;
}

@end


// ======================================================================


@interface OSKAccountManagementViewController ()

@property (strong, nonatomic) NSArray *managedAccountClasses;
@property (strong, nonatomic) NSArray *toggleClasses;

@end

#define ACCOUNTS_SECTION 0
#define TOGGLE_SECTION 1

@implementation OSKAccountManagementViewController

- (instancetype)initWithIgnoredActivityClasses:(NSArray *)ignoredActivityClasses optionalBespokeActivityClasses:(NSArray *)arrayOfClasses {
    self = [super initWithStyle:UITableViewStyleGrouped];
    if (self) {
        
        self.title = @"Sharing";
        NSString *doneTitle = [[OSKPresentationManager sharedInstance] localizedText_Done];
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:doneTitle style:UIBarButtonItemStyleDone target:self action:@selector(cancelButtonPressed:)];

        [self setupManagedAccountClasses:ignoredActivityClasses optionalBespokeActivityClasses:arrayOfClasses];
        [self setupToggleClasses:ignoredActivityClasses optionalBespokeActivityClasses:arrayOfClasses];
    }
    return self;
}

- (void)setupManagedAccountClasses:(NSArray *)ignoredActivityClasses optionalBespokeActivityClasses:(NSArray *)bespokeClasses {
    NSMutableArray *classes = [[NSMutableArray alloc] init];
    
    NSMutableSet *defaultClasses = [NSMutableSet set];
    [defaultClasses addObject:[OSKAppDotNetActivity class]];
    [defaultClasses addObject:[OSKInstapaperActivity class]];
    [defaultClasses addObject:[OSKPocketActivity class]];
    [defaultClasses addObject:[OSKReadabilityActivity class]];
    [defaultClasses addObject:[OSKPinboardActivity class]];
    
    for (Class ignoredClass in ignoredActivityClasses) {
        if ([defaultClasses containsObject:ignoredClass]) {
            [defaultClasses removeObject:ignoredClass];
        }
    }
    
    [classes addObjectsFromArray:defaultClasses.allObjects];
    
    if (bespokeClasses.count) {
        for (Class activityClass in bespokeClasses) {
            NSAssert([activityClass isSubclassOfClass:[OSKActivity class]], @"OSKAccountChooserViewController requires an OSKActivity subclass passed to initForManagingAccountsOfActivityClass:");
            BOOL usesAppropriateAuthentication = NO;
            if ([activityClass authenticationMethod] == OSKAuthenticationMethod_ManagedAccounts
                || [activityClass authenticationMethod] == OSKAuthenticationMethod_Generic) {
                usesAppropriateAuthentication = YES;
            }
            NSAssert(usesAppropriateAuthentication, @"OSKAccountChooserViewController requires a subclass of OSKActivity that conforms to OSKActivity_ManagedAccounts");
        }
        [classes addObjectsFromArray:bespokeClasses];
    }
    
    [classes sortUsingComparator:^NSComparisonResult(Class class1, Class class2) {
        return [(NSString *)[class1 activityName] compare:(NSString *)[class2 activityName] options:NSCaseInsensitiveSearch];
    }];
    
    [self setManagedAccountClasses:classes];

}

- (void)setupToggleClasses:(NSArray *)ignoredActivityClasses optionalBespokeActivityClasses:(NSArray *)bespokeClasses {
    NSMutableArray *classes = [[NSMutableArray alloc] init];
    
    NSMutableSet *defaultClasses = [NSMutableSet set];
    [defaultClasses addObject:[OSKAppDotNetActivity class]];
    [defaultClasses addObject:[OSKInstapaperActivity class]];
    [defaultClasses addObject:[OSKPocketActivity class]];
    [defaultClasses addObject:[OSKReadingListActivity class]];
    [defaultClasses addObject:[OSKReadabilityActivity class]];
    [defaultClasses addObject:[OSKPinboardActivity class]];
    [defaultClasses addObject:[OSKTwitterActivity class]];
    [defaultClasses addObject:[OSKFacebookActivity class]];
    [defaultClasses addObject:[OSKGooglePlusActivity class]];

    if ([OSK1PasswordSearchActivity isAvailable]) {
        [defaultClasses addObject:[OSK1PasswordSearchActivity class]];
        [defaultClasses addObject:[OSK1PasswordBrowserActivity class]];
    }
    if ([OSKChromeActivity isAvailable]) {
        [defaultClasses addObject:[OSKChromeActivity class]];
    }
    if ([OSKOmnifocusActivity isAvailable]) {
        [defaultClasses addObject:[OSKOmnifocusActivity class]];
    }
    if ([OSKThingsActivity isAvailable]) {
        [defaultClasses addObject:[OSKThingsActivity class]];
    }
    if ([OSKDraftsActivity isAvailable]) {
        [defaultClasses addObject:[OSKDraftsActivity class]];
    }
    
    for (Class ignoredClass in ignoredActivityClasses) {
        if ([defaultClasses containsObject:ignoredClass]) {
            [defaultClasses removeObject:ignoredClass];
        }
    }
    
    [classes addObjectsFromArray:defaultClasses.allObjects];
    
    if (bespokeClasses.count) {
        for (Class activityClass in bespokeClasses) {
            NSAssert([activityClass isSubclassOfClass:[OSKActivity class]], @"OSKAccountChooserViewController requires an OSKActivity subclass passed to initForManagingAccountsOfActivityClass:");
            BOOL usesAppropriateAuthentication = NO;
            if ([activityClass authenticationMethod] == OSKAuthenticationMethod_ManagedAccounts
                || [activityClass authenticationMethod] == OSKAuthenticationMethod_Generic) {
                usesAppropriateAuthentication = YES;
            }
            NSAssert(usesAppropriateAuthentication, @"OSKAccountChooserViewController requires a subclass of OSKActivity that conforms to OSKActivity_ManagedAccounts");
        }
        [classes addObjectsFromArray:bespokeClasses];
    }
    
    [classes sortUsingComparator:^NSComparisonResult(Class class1, Class class2) {
        return [(NSString *)[class1 activityName] compare:(NSString *)[class2 activityName] options:NSCaseInsensitiveSearch];
    }];
    
    [self setToggleClasses:classes];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    UIColor *bgColor = [presentationManager color_groupedTableViewBackground];
    self.view.backgroundColor = bgColor;
    self.tableView.backgroundColor = bgColor;
    self.tableView.backgroundView.backgroundColor = bgColor;
    self.tableView.separatorColor = presentationManager.color_separators;
    [self.tableView registerClass:[OSKAccountTypeCell class] forCellReuseIdentifier:OSKAccountTypeCellIdentifier];
    [self.tableView registerClass:[OSKActivityToggleCell class] forCellReuseIdentifier:OSKActivityToggleCellIdentifier];
    [self.tableView registerClass:[OSKAccountManagementHeaderView class] forHeaderFooterViewReuseIdentifier:OSKAccountManagementHeaderViewIdentifier];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.tableView reloadData];
}

- (void)cancelButtonPressed:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    NSInteger count = 0;
    if (section == ACCOUNTS_SECTION) {
        count = self.managedAccountClasses.count;
    }
    else if (section == TOGGLE_SECTION) {
        count = self.toggleClasses.count;
    }
    return count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell = nil;
    if (indexPath.section == ACCOUNTS_SECTION) {
        OSKAccountTypeCell *accountCell = [tableView dequeueReusableCellWithIdentifier:OSKAccountTypeCellIdentifier forIndexPath:indexPath];
        Class activityClass = self.managedAccountClasses[indexPath.row];
        [accountCell setActivityClass:activityClass];
        cell = accountCell;
    }
    else if (indexPath.section == TOGGLE_SECTION) {
        OSKActivityToggleCell *toggleCell = [tableView dequeueReusableCellWithIdentifier:OSKActivityToggleCellIdentifier forIndexPath:indexPath];
        Class activityClass = self.toggleClasses[indexPath.row];
        [toggleCell setActivityClass:activityClass];
        cell = toggleCell;
    }
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 45.0f;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 52.0f;
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    OSKAccountManagementHeaderView *view = [tableView dequeueReusableHeaderFooterViewWithIdentifier:OSKAccountManagementHeaderViewIdentifier];
    NSString *title = nil;
    if (section == ACCOUNTS_SECTION) {
        title = [[OSKPresentationManager sharedInstance] localizedText_Accounts];
    }
    else if (section == TOGGLE_SECTION) {
        title = [[OSKPresentationManager sharedInstance] localizedText_OptionalActivities];
    }
    [view.label setText:title.uppercaseString];
    return view;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    if (indexPath.section == ACCOUNTS_SECTION) {
        Class activityClass = self.managedAccountClasses[indexPath.row];
        if ([activityClass authenticationMethod] == OSKAuthenticationMethod_ManagedAccounts) {
            OSKAccountChooserViewController *chooser = [[OSKAccountChooserViewController alloc] initForManagingAccountsOfActivityClass:activityClass];
            [self.navigationController pushViewController:chooser animated:YES];
        } else {
            OSKPocketAccountViewController *pocketVC = [[OSKPocketAccountViewController alloc] initWithStyle:UITableViewStyleGrouped];
            [self.navigationController pushViewController:pocketVC animated:YES];
        }
    }
}

@end











