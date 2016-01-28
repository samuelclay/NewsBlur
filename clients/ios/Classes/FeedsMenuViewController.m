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
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return [self.menuOptions count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
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
            image = [[UIImage imageNamed:@"menu_icn_mute.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            cell.imageView.tintColor = [UIColor blueColor];
            break;
            
        case 2:
            image = [[UIImage imageNamed:@"menu_icn_organize.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
            cell.imageView.tintColor = [UIColor orangeColor];
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

@end
