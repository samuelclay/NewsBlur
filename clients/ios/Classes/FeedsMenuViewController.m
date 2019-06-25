//
//  FeedsMenuViewController.m
//  NewsBlur
//
//  Created by Roy Yang on 6/19/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FeedsMenuViewController.h"
#import "NewsBlurAppDelegate.h"
#import "MBProgressHUD.h"
#import "NBContainerViewController.h"
#import "NewsBlurViewController.h"
#import "MenuTableViewCell.h"

@implementation FeedsMenuViewController

#define kMenuOptionHeight 38

@synthesize appDelegate;
@synthesize menuOptions;
@synthesize menuTableView;


- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil
{
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    
    [self rebuildOptions];
}

- (void)rebuildOptions {
    if ([appDelegate.activeUsername isEqualToString:@"samuel"] || [appDelegate.activeUsername isEqualToString:@"Dejal"]) {
        self.menuOptions = [[NSArray alloc]
                            initWithObjects:[@"Preferences" uppercaseString],
                                            [@"Mute Sites" uppercaseString],
                                            [@"Organize Sites" uppercaseString],
                                            [@"Notifications" uppercaseString],
                                            [@"Find Friends" uppercaseString],
                                            [appDelegate.isPremium ? @"Premium Account": @"Upgrade to Premium" uppercaseString],
                                            [@"Logout" uppercaseString],
                                            [@"Login as..." uppercaseString],
                                            nil];
    } else {
        self.menuOptions = [[NSArray alloc]
                            initWithObjects:[@"Preferences" uppercaseString],
                                            [@"Mute Sites" uppercaseString],
                                            [@"Organize Sites" uppercaseString],
                                            [@"Notifications" uppercaseString],
                                            [@"Find Friends" uppercaseString],
                                            [appDelegate.isPremium ? @"Premium Account": @"Upgrade to Premium" uppercaseString],
                                            [@"Logout" uppercaseString], nil];
    }
    
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
    
    [self.menuTableView reloadData];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
    self.menuOptions = nil;
    self.menuTableView = nil;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    [self.menuTableView reloadData];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    [self.fontSizeSegment
     setTitleTextAttributes:@{NSFontAttributeName:
                                  [UIFont fontWithName:@"Helvetica-Bold" size:11.0f]}
     forState:UIControlStateNormal];
    
    if([userPreferences stringForKey:@"feed_list_font_size"]){
        NSString *fontSize = [userPreferences stringForKey:@"feed_list_font_size"];
        if ([fontSize isEqualToString:@"xs"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:0];
        } else if ([fontSize isEqualToString:@"small"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:1];
        } else if ([fontSize isEqualToString:@"medium"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:2];
        } else if ([fontSize isEqualToString:@"large"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:3];
        } else if ([fontSize isEqualToString:@"xl"]) {
            [self.fontSizeSegment setSelectedSegmentIndex:4];
        }
    }
    
    NSString *theme = [ThemeManager themeManager].theme;
    if ([theme isEqualToString:@"sepia"]) {
        self.themeSegmentedControl.selectedSegmentIndex = 1;
    } else if ([theme isEqualToString:@"medium"]) {
        self.themeSegmentedControl.selectedSegmentIndex = 2;
    } else if ([theme isEqualToString:@"dark"]) {
        self.themeSegmentedControl.selectedSegmentIndex = 3;
    } else {
        self.themeSegmentedControl.selectedSegmentIndex = 0;
    }
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return [self.menuOptions count] + 2;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
    if (indexPath.row == [self.menuOptions count]) {
        return [self makeFontSizeTableCell];
    }
    
    if (indexPath.row == [self.menuOptions count] + 1) {
        return [self makeThemeTableCell];
    }
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (cell == nil) {
        cell = [[MenuTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier];
    }
    
    cell.textLabel.text = [self.menuOptions objectAtIndex:[indexPath row]];
    
    UIImage *image = nil;
    
    switch (indexPath.row) {
        case 0:
            image = [UIImage imageNamed:@"menu_icn_preferences.png"];
            break;
            
        case 1:
            image = [UIImage imageNamed:@"menu_icn_mute.png"];
            break;
            
        case 2:
            image = [UIImage imageNamed:@"menu_icn_organize.png"];
            break;
        
        case 3:
            image = [UIImage imageNamed:@"menu_icn_notifications.png"];
            break;
        
        case 4:
            image = [UIImage imageNamed:@"menu_icn_followers.png"];
            break;
            
        case 5:
            image = [UIImage imageNamed:@"g_icn_greensun.png"];
            break;
        
        case 6:
            image = [UIImage imageNamed:@"menu_icn_fetch_subscribers.png"];
            break;
            
        case 7:
            image = [UIImage imageNamed:@"barbutton_sendto.png"];
            break;
            
        default:
            break;
    }
    
    cell.imageView.image = image;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kMenuOptionHeight;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.appDelegate hidePopover];
    } else {
        [self.appDelegate hidePopoverAnimated:YES];
    }

    switch (indexPath.row) {
        case 0:
            [appDelegate showPreferences];
            break;
            
        case 1:
            [appDelegate showMuteSites];
            break;
            
        case 2:
            [appDelegate showOrganizeSites];
            break;
            
        case 3:
            [appDelegate openNotificationsWithFeed:nil];
            break;
        
        case 4:
            [appDelegate showFindFriends];
            break;
            
        case 5:
            [appDelegate showPremiumDialog];
            break;
            
        case 6:
            [appDelegate confirmLogout];
            break;
            
        case 7:
            [self showLoginAsDialog];
            break;
            
        default:
            break;
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

}

#pragma mark -
#pragma mark Menu Options

- (void)showLoginAsDialog {
    UIAlertController *alertController = [UIAlertController alertControllerWithTitle:@"Login as..." message:nil preferredStyle:UIAlertControllerStyleAlert];
    [alertController addTextFieldWithConfigurationHandler:nil];
    [alertController addAction:[UIAlertAction actionWithTitle: @"Login" style:UIAlertActionStyleDefault handler:^(UIAlertAction * action) {
        [alertController dismissViewControllerAnimated:YES completion:nil];
        NSString *username = alertController.textFields[0].text;
        NSString *urlString = [NSString stringWithFormat:@"%@/reader/login_as?user=%@",
                          self.appDelegate.url, username];

        [appDelegate.networkManager GET:urlString parameters:nil progress:nil success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
            NSLog(@"Login as %@ successful", username);
            [MBProgressHUD hideHUDForView:appDelegate.feedsViewController.view animated:YES];
            [appDelegate reloadFeedsView:YES];
        } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
            [MBProgressHUD hideHUDForView:appDelegate.feedsViewController.view animated:YES];
            [self informError:error];
        }];
        
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:appDelegate.feedsViewController.view animated:YES];
        HUD.labelText = [NSString stringWithFormat:@"Login: %@", username];
    }]];
    [alertController addAction:[UIAlertAction actionWithTitle:@"Cancel"
                                                        style:UIAlertActionStyleCancel handler:nil]];
    [appDelegate.feedsViewController presentViewController:alertController animated:YES completion:nil];
}

- (UITableViewCell *)makeFontSizeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    self.fontSizeSegment.frame = CGRectMake(8, 7, cell.frame.size.width - 8*2, kMenuOptionHeight - 7*2);
    [self.fontSizeSegment setTitle:@"XS" forSegmentAtIndex:0];
    [self.fontSizeSegment setTitle:@"S" forSegmentAtIndex:1];
    [self.fontSizeSegment setTitle:@"M" forSegmentAtIndex:2];
    [self.fontSizeSegment setTitle:@"L" forSegmentAtIndex:3];
    [self.fontSizeSegment setTitle:@"XL" forSegmentAtIndex:4];
    self.fontSizeSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
    [self.fontSizeSegment setTitleTextAttributes:@{NSFontAttributeName:[UIFont fontWithName:@"Helvetica-Bold" size:11.0f]} forState:UIControlStateNormal];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:0];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:1];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:2];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:3];
    [self.fontSizeSegment setContentOffset:CGSizeMake(0, 1) forSegmentAtIndex:4];
    
    [cell addSubview:self.fontSizeSegment];
    
    return cell;
}

- (IBAction)changeFontSize:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [userPreferences setObject:@"xs" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [userPreferences setObject:@"small" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [userPreferences setObject:@"medium" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [userPreferences setObject:@"large" forKey:@"feed_list_font_size"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [userPreferences setObject:@"xl" forKey:@"feed_list_font_size"];
    }
    [userPreferences synchronize];
    
    [appDelegate resizeFontSize];
}

#pragma mark - Theme Options

- (UITableViewCell *)makeThemeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    UIImage *lightImage = [self themeImageWithName:@"theme_color_light" selected:self.themeSegmentedControl.selectedSegmentIndex == 0];
    UIImage *sepiaImage = [self themeImageWithName:@"theme_color_sepia" selected:self.themeSegmentedControl.selectedSegmentIndex == 1];
    UIImage *mediumImage = [self themeImageWithName:@"theme_color_medium" selected:self.themeSegmentedControl.selectedSegmentIndex == 2];
    UIImage *darkImage = [self themeImageWithName:@"theme_color_dark" selected:self.themeSegmentedControl.selectedSegmentIndex == 3];
    
    self.themeSegmentedControl.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [self.themeSegmentedControl setImage:lightImage forSegmentAtIndex:0];
    [self.themeSegmentedControl setImage:sepiaImage forSegmentAtIndex:1];
    [self.themeSegmentedControl setImage:mediumImage forSegmentAtIndex:2];
    [self.themeSegmentedControl setImage:darkImage forSegmentAtIndex:3];
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, self.themeSegmentedControl.frame.size.height), NO, 0.0);
    UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self.themeSegmentedControl setDividerImage:blankImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    self.themeSegmentedControl.tintColor = [UIColor clearColor];
    self.themeSegmentedControl.backgroundColor = [UIColor clearColor];
    
    [cell addSubview:self.themeSegmentedControl];
    
    return cell;
}

- (UIImage *)themeImageWithName:(NSString *)name selected:(BOOL)selected {
    if (selected) {
        name = [name stringByAppendingString:@"-sel"];
    }
    
    return [[UIImage imageNamed:name] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

- (IBAction)changeTheme:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    NSString *theme = ThemeStyleLight;
    switch ([sender selectedSegmentIndex]) {
        case 1:
            theme = ThemeStyleSepia;
            break;
        case 2:
            theme = ThemeStyleMedium;
            break;
        case 3:
            theme = ThemeStyleDark;
            break;
            
        default:
            break;
    }
    [ThemeManager themeManager].theme = theme;
    
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
    [self.menuTableView reloadData];
    [userPreferences synchronize];
}

@end
