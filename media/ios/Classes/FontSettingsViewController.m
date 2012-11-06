//
//  FontPopover.m
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "FontSettingsViewController.h"
#import "NewsBlurAppDelegate.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "FeedDetailViewController.h"
#import "MenuTableViewCell.h"
#import "NBContainerViewController.h"

@implementation FontSettingsViewController

#define kMenuOptionHeight 38

@synthesize appDelegate;
@synthesize fontStyleSegment;
@synthesize fontSizeSegment;
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
    self.menuTableView.backgroundColor = UIColorFromRGB(0xF0FFF0);
    self.menuTableView.separatorColor = UIColorFromRGB(0x8AA378);
}

- (void)viewWillAppear:(BOOL)animated {
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if ([userPreferences stringForKey:@"fontStyle"]) {
        if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-san-serif"]) {
            [fontStyleSegment setSelectedSegmentIndex:0];
        } else if ([[userPreferences stringForKey:@"fontStyle"] isEqualToString:@"NB-serif"]) {    
            [fontStyleSegment setSelectedSegmentIndex:1];
        }
    }

    if([userPreferences stringForKey:@"fontSizing"]){
        NSString *fontSize = [NSString stringWithFormat:@"%@", [userPreferences stringForKey:@"fontSizing"]];
        if ([fontSize isEqualToString:@"NB-extra-small"]) {
            [fontSizeSegment setSelectedSegmentIndex:0]; 
        } else if ([fontSize isEqualToString:@"NB-small"]) {
            [fontSizeSegment setSelectedSegmentIndex:1];
        } else if ([fontSize isEqualToString:@"NB-medium"]) {
            [fontSizeSegment setSelectedSegmentIndex:2];
        } else if ([fontSize isEqualToString:@"NB-large"]) {
            [fontSizeSegment setSelectedSegmentIndex:3];
        } else if ([fontSize isEqualToString:@"NB-extra-large"]) {
            [fontSizeSegment setSelectedSegmentIndex:4];
        }
    }
    
    [self.menuTableView reloadData];
}

- (void)viewDidUnload
{

    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
	return YES;
}

- (IBAction)changeFontStyle:(id)sender {
    if ([sender selectedSegmentIndex] == 0) {
        [self setSanSerif];
    } else {
        [self setSerif];
    }
}

- (IBAction)changeFontSize:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-extra-small"];
        [userPreferences setObject:@"NB-extra-small" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-small"];
        [userPreferences setObject:@"NB-small" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-medium"];
        [userPreferences setObject:@"NB-medium" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-large"];
        [userPreferences setObject:@"NB-large" forKey:@"fontSizing"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [appDelegate.storyDetailViewController changeFontSize:@"NB-extra-large"];
        [userPreferences setObject:@"NB-extra-large" forKey:@"fontSizing"];
    }
    [userPreferences synchronize];
}

- (void)setSanSerif {
    [fontStyleSegment setSelectedSegmentIndex:0];
    [appDelegate.storyDetailViewController setFontStyle:@"Helvetica"];
}
        
- (void)setSerif {
    [fontStyleSegment setSelectedSegmentIndex:1];
    [appDelegate.storyDetailViewController setFontStyle:@"Georgia"];
}

#pragma mark -
#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return 6;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIndentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (indexPath.row == 4) {
        return [self makeFontSelectionTableCell];
    } else if (indexPath.row == 5) {
        return [self makeFontSizeTableCell];
    }
    
    if (cell == nil) {
        cell = [[MenuTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier];
    }
        
    if (indexPath.row == 0) {
        bool isSaved = [[appDelegate.activeStory objectForKey:@"starred"] boolValue];
        if (isSaved) {
            cell.textLabel.text = [@"Unsave this story" uppercaseString];
        } else {
            cell.textLabel.text = [@"Save this story" uppercaseString];
        }
        cell.imageView.image = [UIImage imageNamed:@"time"];
    } else if (indexPath.row == 1) {
        bool isRead = [[appDelegate.activeStory objectForKey:@"read_status"] boolValue];
        if (isRead) {
            cell.textLabel.text = [@"Mark as unread" uppercaseString];
        } else {
            cell.textLabel.text = [@"Mark as read" uppercaseString];
        }
        cell.imageView.image = [UIImage imageNamed:@"bullet_orange"];
    } else if (indexPath.row == 2) {
        cell.textLabel.text = [@"Send to..." uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"email"];
    } else if (indexPath.row == 3) {
        cell.textLabel.text = [@"Share this story" uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"rainbow"];
    }

    return cell;
}

- (float)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kMenuOptionHeight;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= 4) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.row == 0) {
        bool isSaved = [[appDelegate.activeStory objectForKey:@"starred"] boolValue];
        if (isSaved) {
            [appDelegate.storyPageControl markStoryAsUnsaved];
        } else {
            [appDelegate.storyPageControl markStoryAsSaved];
        }
    } else if (indexPath.row == 1) {
        bool isRead = [[appDelegate.activeStory objectForKey:@"read_status"] boolValue];
        if (isRead) {
            [appDelegate.storyPageControl markStoryAsUnread];
        } else {
            [appDelegate.storyPageControl markStoryAsRead];
            [appDelegate.feedDetailViewController redrawUnreadStory];
        }
    } else if (indexPath.row == 2) {
        [appDelegate.storyPageControl openSendToDialog];
    } else if (indexPath.row == 3) {
        [appDelegate.storyDetailViewController openShareDialog];
    }
    
    
    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        [appDelegate.masterContainerViewController hidePopover];
    } else {
        [appDelegate.storyPageControl.popoverController dismissPopoverAnimated:YES];
        appDelegate.storyPageControl.popoverController = nil;
    }
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    
}

- (UITableViewCell *)makeFontSelectionTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;

    fontStyleSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [fontStyleSegment setTitle:@"Helvetica" forSegmentAtIndex:0];
    [fontStyleSegment setTitle:@"Georgia" forSegmentAtIndex:1];
    [fontStyleSegment setTintColor:UIColorFromRGB(0x738570)];
    
    [cell addSubview:fontStyleSegment];
    
    return cell;
}

- (UITableViewCell *)makeFontSizeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    
    fontSizeSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [fontSizeSegment setTitle:@"11pt" forSegmentAtIndex:0];
    [fontSizeSegment setTitle:@"12pt" forSegmentAtIndex:1];
    [fontSizeSegment setTitle:@"14pt" forSegmentAtIndex:2];
    [fontSizeSegment setTitle:@"16pt" forSegmentAtIndex:3];
    [fontSizeSegment setTitle:@"18pt" forSegmentAtIndex:4];
    [fontSizeSegment setTintColor:UIColorFromRGB(0x738570)];
    
    [cell addSubview:fontSizeSegment];
    
    return cell;    
}


@end
