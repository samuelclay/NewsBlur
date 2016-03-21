//
//  FontPopover.m
//  NewsBlur
//
//  Created by Roy Yang on 6/18/12.
//  Copyright (c) 2012-2015 NewsBlur. All rights reserved.
//

#import "FontSettingsViewController.h"
#import "NewsBlurAppDelegate.h"
#import "StoryDetailViewController.h"
#import "StoryPageControl.h"
#import "FeedDetailViewController.h"
#import "MenuTableViewCell.h"
#import "NBContainerViewController.h"
#import "StoriesCollection.h"
#import "FontListViewController.h"

@interface FontSettingsViewController ()

@property (nonatomic, strong) NSMutableArray *fonts;

@end

@implementation FontSettingsViewController

#define kMenuOptionHeight 38

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.menuTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.menuTableView.separatorColor = UIColorFromRGB(0x909090);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"Story Options";
    self.navigationItem.backBarButtonItem.title = @"Options";
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    self.fonts = [NSMutableArray array];
    
    // Leave commented out for future use:
//    [self debugOutputFontNames];
    
    // Available fonts, in alphabetic order.  Remember to add bundled font filenames to the Info.plist.
    [self addBuiltInFontWithName:@"Avenir-Medium" styleClass:@"NB-avenir" displayName:nil];
    [self addBundledFontWithName:@"ChronicleSSm-Book" styleClass:@"ChronicleSSm-Book" displayName:@"Chronicle"];
    [self addBuiltInFontWithName:@"Georgia" styleClass:@"NB-georgia" displayName:nil];
    [self addBundledFontWithName:@"GothamNarrow-Book" styleClass:@"GothamNarrow-Book" displayName:nil];
    [self addBuiltInFontWithName:@"Helvetica" styleClass:@"NB-helvetica" displayName:nil];
    [self addBuiltInFontWithName:@"Palatino-Roman" styleClass:@"NB-palatino" displayName:nil];
    [self addBundledFontWithName:@"WhitneySSm-Book" styleClass:@"WhitneySSm-Book" displayName:@"Whitney"];
    
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    if([userPreferences stringForKey:@"story_font_size"]){
        NSString *fontSize = [userPreferences stringForKey:@"story_font_size"];
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
    
    if([userPreferences stringForKey:@"story_line_spacing"]){
        NSString *lineSpacing = [userPreferences stringForKey:@"story_line_spacing"];
        if ([lineSpacing isEqualToString:@"xs"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:0];
        } else if ([lineSpacing isEqualToString:@"small"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:1];
        } else if ([lineSpacing isEqualToString:@"medium"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:2];
        } else if ([lineSpacing isEqualToString:@"large"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:3];
        } else if ([lineSpacing isEqualToString:@"xl"]) {
            [self.lineSpacingSegment setSelectedSegmentIndex:4];
        }
    }
    
    NSString *theme = [ThemeManager themeManager].theme;
    if ([theme isEqualToString:@"sepia"]) {
        self.themeSegment.selectedSegmentIndex = 1;
    } else if ([theme isEqualToString:@"medium"]) {
        self.themeSegment.selectedSegmentIndex = 2;
    } else if ([theme isEqualToString:@"dark"]) {
        self.themeSegment.selectedSegmentIndex = 3;
    } else {
        self.themeSegment.selectedSegmentIndex = 0;
    }
    
    [self.menuTableView reloadData];
    
    // -[NewsBlurAppDelegate navigationController:willShowViewController:animated:] hides this too late, so this gets mis-measured otherwise
    self.navigationController.navigationBarHidden = YES;
    self.navigationController.preferredContentSize = CGSizeMake(240.0, self.menuTableView.contentSize.height + (self.menuTableView.frame.origin.y * 2));
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
	return YES;
}

// allow keyboard comands
- (BOOL)canBecomeFirstResponder {
    return YES;
}

- (void)debugOutputFontNames {
    NSLog(@"Debugging font names");
    for (NSString *family in [[UIFont familyNames] sortedArrayUsingSelector:@selector(compare:)]) {
        NSLog(@"%@", family);
        
        for (NSString *name in [UIFont fontNamesForFamilyName:family]) {
            NSLog(@"  %@", name);
        }
    }
}
                   
- (void)addBuiltInFontWithName:(NSString *)fontName styleClass:(NSString *)styleClass displayName:(NSString *)displayName {
    UIFont *font = [UIFont fontWithName:fontName size:16.0];
    
    if (font) {
        if (!displayName) {
            displayName = font.familyName;
        }
        NSAttributedString *attrb = [[NSAttributedString alloc] initWithString:displayName
                                                                    attributes:@{NSFontAttributeName : font}];
        [self.fonts addObject:@{@"name" : attrb, @"style" : styleClass}];
    }
}

- (void)addBundledFontWithName:(NSString *)fontName styleClass:(NSString *)styleClass displayName:(NSString *)displayName {
    [self addBuiltInFontWithName:fontName styleClass:styleClass displayName:displayName];
}

- (IBAction)changeFontSize:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [self.appDelegate.storyPageControl changeFontSize:@"xs"];
        [userPreferences setObject:@"xs" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [self.appDelegate.storyPageControl changeFontSize:@"small"];
        [userPreferences setObject:@"small" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [self.appDelegate.storyPageControl changeFontSize:@"medium"];
        [userPreferences setObject:@"medium" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [self.appDelegate.storyPageControl changeFontSize:@"large"];
        [userPreferences setObject:@"large" forKey:@"story_font_size"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [self.appDelegate.storyPageControl changeFontSize:@"xl"];
        [userPreferences setObject:@"xl" forKey:@"story_font_size"];
    }
    [userPreferences synchronize];
}

- (IBAction)changeLineSpacing:(id)sender {
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    if ([sender selectedSegmentIndex] == 0) {
        [self.appDelegate.storyPageControl changeLineSpacing:@"xs"];
        [userPreferences setObject:@"xs" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 1) {
        [self.appDelegate.storyPageControl changeLineSpacing:@"small"];
        [userPreferences setObject:@"small" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 2) {
        [self.appDelegate.storyPageControl changeLineSpacing:@"medium"];
        [userPreferences setObject:@"medium" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 3) {
        [self.appDelegate.storyPageControl changeLineSpacing:@"large"];
        [userPreferences setObject:@"large" forKey:@"story_line_spacing"];
    } else if ([sender selectedSegmentIndex] == 4) {
        [self.appDelegate.storyPageControl changeLineSpacing:@"xl"];
        [userPreferences setObject:@"xl" forKey:@"story_line_spacing"];
    }
    [userPreferences synchronize];
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

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return 9;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIndentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    
    if (indexPath.row == 6) {
        return [self makeFontSizeTableCell];
    } else if (indexPath.row == 7) {
        return [self makeLineSpacingTableCell];
    } else if (indexPath.row == 8) {
        return [self makeThemeTableCell];
    }
    
    if (cell == nil) {
        cell = [[MenuTableViewCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:CellIndentifier];
    }
    
    cell.textLabel.textColor = UIColorFromRGB(0x303030);
    cell.textLabel.highlightedTextColor = UIColorFromRGB(0x303030);
    cell.textLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
    cell.backgroundView.backgroundColor = UIColorFromRGB(0xFFFFFF);
    cell.selectedBackgroundView.backgroundColor = UIColorFromRGB(0xECEEEA);
    cell.imageView.tintColor = UIColorFromRGB(0x303030);

    if (indexPath.row == 0) {
        bool isSaved = [[self.appDelegate.activeStory objectForKey:@"starred"] boolValue];
        if (isSaved) {
            cell.textLabel.text = [@"Unsave this story" uppercaseString];
        } else {
            cell.textLabel.text = [@"Save this story" uppercaseString];
        }
        cell.imageView.image = [UIImage imageNamed:@"clock.png"];
    } else if (indexPath.row == 1) {
        bool isRead = [[self.appDelegate.activeStory objectForKey:@"read_status"] boolValue];
        if (isRead) {
            cell.textLabel.text = [@"Mark as unread" uppercaseString];
        } else {
            cell.textLabel.text = [@"Mark as read" uppercaseString];
        }
        cell.imageView.image = [UIImage imageNamed:@"g_icn_unread.png"];
    } else if (indexPath.row == 2) {
        cell.textLabel.text = [@"Send to..." uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_mail.png"];
    } else if (indexPath.row == 3) {
        cell.textLabel.text = [@"Train this story" uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_train.png"];
    } else if (indexPath.row == 4) {
        cell.textLabel.text = [@"Share this story" uppercaseString];
        cell.imageView.image = [UIImage imageNamed:@"menu_icn_share.png"];
    } else if (indexPath.row == 5) {
        NSString *fontStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontStyle"];
        if (!fontStyle) {
            fontStyle = @"NB-helvetica";
        }
        NSUInteger idx = [self.fonts indexOfObjectPassingTest:^BOOL(NSDictionary *obj, NSUInteger idx, BOOL * _Nonnull stop) {
            return [obj[@"style"] isEqualToString:fontStyle];
        }];
        if (idx != NSNotFound) {
            NSDictionary *font = self.fonts[idx];
            NSAttributedString *name = font[@"name"];
            cell.textLabel.attributedText = name;
        } else {
            cell.textLabel.text = @"Font...";
        }
        cell.imageView.image = [[UIImage imageNamed:@"choose_font.png"] imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return kMenuOptionHeight;
}

- (NSIndexPath *)tableView:(UITableView *)tableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row >= 6) {
        return nil;
    }
    return indexPath;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.row != 5) {
        [self dismissViewControllerAnimated:indexPath.row != 2 && indexPath.row != 3 completion:nil];
    }
    
    if (indexPath.row == 0) {
        [self.appDelegate.storiesCollection toggleStorySaved];
        [self.appDelegate.feedDetailViewController reloadData];
        [self.appDelegate.storyPageControl refreshHeaders];
    } else if (indexPath.row == 1) {
        [self.appDelegate.storiesCollection toggleStoryUnread];
        [self.appDelegate.feedDetailViewController reloadData];
        [self.appDelegate.storyPageControl refreshHeaders];
    } else if (indexPath.row == 2) {
        [self.appDelegate.storyPageControl openSendToDialog:self.appDelegate.storyPageControl.fontSettingsButton];
    } else if (indexPath.row == 3) {
        [self.appDelegate openTrainStory:self.appDelegate.storyPageControl.fontSettingsButton];
    } else if (indexPath.row == 4) {
        [self.appDelegate.storyPageControl.currentPage openShareDialog];
    } else if (indexPath.row == 5) {
        [self showFontList];
    }
    
    
//    if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
//        if (indexPath.row != 2 && indexPath.row != 3) {
//            // if we're opening another popover, then don't animate out - it looks strange
//            [self.appDelegate.masterContainerViewController hidePopover];
//        }
//    } else {
//        [self.appDelegate.storyPageControl.popoverController dismissPopoverAnimated:YES];
//        self.appDelegate.storyPageControl.popoverController = nil;
//    }
//    
//    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

- (void)showFontList {
    FontListViewController *controller = [[FontListViewController alloc] initWithNibName:@"FontListViewController" bundle:nil];
    
    controller.fonts = self.fonts;
    
    [self.navigationController pushViewController:controller animated:YES];
}

- (UITableViewCell *)makeFontSizeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    self.fontSizeSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [self.fontSizeSegment setTitle:@"XS" forSegmentAtIndex:0];
    [self.fontSizeSegment setTitle:@"S" forSegmentAtIndex:1];
    [self.fontSizeSegment setTitle:@"M" forSegmentAtIndex:2];
    [self.fontSizeSegment setTitle:@"L" forSegmentAtIndex:3];
    [self.fontSizeSegment setTitle:@"XL" forSegmentAtIndex:4];
    [self.fontSizeSegment setTintColor:UIColorFromRGB(0x738570)];
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

- (UITableViewCell *)makeLineSpacingTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    self.lineSpacingSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_xs"] forSegmentAtIndex:0];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_s"] forSegmentAtIndex:1];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_m"] forSegmentAtIndex:2];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_l"] forSegmentAtIndex:3];
    [self.lineSpacingSegment setImage:[UIImage imageNamed:@"line_spacing_xl"] forSegmentAtIndex:4];
    [self.lineSpacingSegment setTintColor:UIColorFromRGB(0x738570)];
    self.lineSpacingSegment.backgroundColor = UIColorFromRGB(0xeeeeee);
    
    [cell addSubview:self.lineSpacingSegment];
    
    return cell;
}

- (UITableViewCell *)makeThemeTableCell {
    UITableViewCell *cell = [[UITableViewCell alloc] init];
    cell.frame = CGRectMake(0, 0, 240, kMenuOptionHeight);
    cell.selectionStyle = UITableViewCellSelectionStyleNone;
    cell.separatorInset = UIEdgeInsetsZero;
    cell.backgroundColor = UIColorFromRGB(0xffffff);
    
    UIImage *lightImage = [self themeImageWithName:@"theme_color_light" selected:self.themeSegment.selectedSegmentIndex == 0];
    UIImage *sepiaImage = [self themeImageWithName:@"theme_color_sepia" selected:self.themeSegment.selectedSegmentIndex == 1];
    UIImage *mediumImage = [self themeImageWithName:@"theme_color_medium" selected:self.themeSegment.selectedSegmentIndex == 2];
    UIImage *darkImage = [self themeImageWithName:@"theme_color_dark" selected:self.themeSegment.selectedSegmentIndex == 3];
    
    self.themeSegment.frame = CGRectMake(8, 4, cell.frame.size.width - 8*2, kMenuOptionHeight - 4*2);
    [self.themeSegment setImage:lightImage forSegmentAtIndex:0];
    [self.themeSegment setImage:sepiaImage forSegmentAtIndex:1];
    [self.themeSegment setImage:mediumImage forSegmentAtIndex:2];
    [self.themeSegment setImage:darkImage forSegmentAtIndex:3];
    
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(1, self.themeSegment.frame.size.height), NO, 0.0);
    UIImage *blankImage = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    
    [self.themeSegment setDividerImage:blankImage forLeftSegmentState:UIControlStateNormal rightSegmentState:UIControlStateNormal barMetrics:UIBarMetricsDefault];
    self.themeSegment.tintColor = [UIColor clearColor];
    self.themeSegment.backgroundColor = [UIColor clearColor];
    
    [cell addSubview:self.themeSegment];
    
    return cell;
}

- (UIImage *)themeImageWithName:(NSString *)name selected:(BOOL)selected {
    if (selected) {
        name = [name stringByAppendingString:@"-sel"];
    }
    
    return [[UIImage imageNamed:name] imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
}

@end
