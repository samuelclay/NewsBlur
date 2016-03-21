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
@synthesize loginAsAlert;

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
    
    if ([appDelegate.activeUsername isEqualToString:@"samuel"]) {
        self.menuOptions = [[NSArray alloc]
                            initWithObjects:[@"Preferences" uppercaseString],
                                            [@"Mute Sites" uppercaseString],
                                            [@"Organize Sites" uppercaseString],
                                            [@"Find Friends" uppercaseString],
                                            [@"Logout" uppercaseString],
                                            [@"Login as..." uppercaseString],
                                            nil];
    } else {
        self.menuOptions = [[NSArray alloc]
                            initWithObjects:[@"Preferences" uppercaseString],
                                            [@"Mute Sites" uppercaseString],
                                            [@"Organize Sites" uppercaseString],
                                            [@"Find Friends" uppercaseString],
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
    return [self.menuOptions count] + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
    if (indexPath.row == [self.menuOptions count]) {
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
            image = [UIImage imageNamed:@"menu_icn_followers.png"];
            break;
            
        case 4:
            image = [UIImage imageNamed:@"menu_icn_fetch_subscribers.png"];
            break;
            
        case 5:
            image = [UIImage imageNamed:@"barbutton_sendto.png"];
            break;
            
        default:
            break;
    }
    
    cell.imageView.image = image;
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 38;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
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
            [appDelegate showFindFriends];
            break;
            
        case 4:
            [appDelegate confirmLogout];
            break;
            
        case 5:
            [self showLoginAsDialog];
            break;
            
        default:
            break;
    }
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [self.appDelegate hidePopover];
    } else {
        [self.appDelegate hidePopoverAnimated:YES];
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];

}

#pragma mark -
#pragma mark Menu Options

- (void)showLoginAsDialog {
    loginAsAlert = [[UIAlertView alloc] initWithTitle:@"Login as..." message:nil delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"Login", nil];
    loginAsAlert.alertViewStyle = UIAlertViewStylePlainTextInput;
    UITextField * alertTextField = [loginAsAlert textFieldAtIndex:0];
    alertTextField.keyboardType = UIKeyboardTypeAlphabet;
    alertTextField.placeholder = @"Username";
    [loginAsAlert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex {
    UITextField * alertTextField = [loginAsAlert textFieldAtIndex:0];
    if ([alertTextField.text length] <= 0 || buttonIndex == 0){
        return;
    }
    if (buttonIndex == 1) {
        NSString *urlS = [NSString stringWithFormat:@"%@/reader/login_as?user=%@",
                          self.appDelegate.url, alertTextField.text];
        NSURL *url = [NSURL URLWithString:urlS];
        
        __block ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
        [request setValidatesSecureCertificate:NO];
        [request setDelegate:self];
        [request setResponseEncoding:NSUTF8StringEncoding];
        [request setDefaultResponseEncoding:NSUTF8StringEncoding];
        [request setFailedBlock:^(void) {
            [MBProgressHUD hideHUDForView:self.view animated:YES];
        }];
        [request setCompletionBlock:^(void) {
            NSLog(@"Login as %@ successful", alertTextField.text);
            [MBProgressHUD hideHUDForView:self.view animated:YES];
            [appDelegate reloadFeedsView:YES];
        }];
        [request setTimeOutSeconds:30];
        [request startAsynchronous];
        
        [ASIHTTPRequest setSessionCookies:nil];
        
        [MBProgressHUD hideHUDForView:self.view animated:YES];
        MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:appDelegate.feedsViewController.view animated:YES];
        HUD.labelText = [NSString stringWithFormat:@"Login: %@", alertTextField.text];
    }
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
