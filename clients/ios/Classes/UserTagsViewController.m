//
//  UserTagsViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/10/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import "UserTagsViewController.h"
#import "FeedTableCell.h"
#import "FolderTitleView.h"
#import "StoriesCollection.h"

@interface UserTagsViewController ()

@end

@implementation UserTagsViewController

const NSInteger kHeaderHeight = 24;

@synthesize appDelegate;

- (void)viewDidLoad {
    [super viewDidLoad];

    appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    tagsTableView = [[UITableView alloc] init];
    tagsTableView.delegate = self;
    tagsTableView.dataSource = self;
    tagsTableView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    tagsTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
    [self.view addSubview:tagsTableView];
    
    addTagBar = [[UISearchBar alloc]
                 initWithFrame:CGRectMake(0, 0,
                                          CGRectGetWidth(tagsTableView.frame), 44.)];
    [addTagBar setDelegate:self];
    [addTagBar setImage:[UIImage imageNamed:@"add_tag.png"]
       forSearchBarIcon:UISearchBarIconSearch
                  state:UIControlStateNormal];
    [addTagBar setReturnKeyType:UIReturnKeyDone];
    [addTagBar setBackgroundColor:UIColorFromRGB(0xDCDFD6)];
    [addTagBar setSearchBarStyle:UISearchBarStyleMinimal];
    [addTagBar setAutocapitalizationType:UITextAutocapitalizationTypeWords];
    tagsTableView.tableHeaderView = addTagBar;
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    tagsTableView.frame = CGRectMake(0, 0, self.view.frame.size.width, self.view.frame.size.height);
    [tagsTableView reloadData];
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (NSArray *)arrayUserTags {
    return [appDelegate.activeStory objectForKey:@"user_tags"];
}

- (NSArray *)arrayUserTagsNotInStory {
    NSArray *userTags = [self arrayUserTags];
    NSMutableArray *tags = [[NSMutableArray alloc] init];

    for (NSString *tagKey in [appDelegate.dictSavedStoryTags allKeys]) {
        NSString *tagName = [[appDelegate.dictSavedStoryTags objectForKey:tagKey]
                             objectForKey:@"feed_title"];
        if (![userTags containsObject:tagName]) {
            [tags addObject:tagName];
        }
    }
    
    return [tags sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 caseInsensitiveCompare:obj2];
    }];
}

#pragma mark - Table data

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (section == 0) {
        // Tagged
        return [[self arrayUserTags] count];
    } else if (section == 1) {
        // Untagged
        return [[self arrayUserTagsNotInStory] count];
    }
    return 0;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    if ([self tableView:tableView numberOfRowsInSection:section] == 0) return 0;
    return kHeaderHeight;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section {
    if (section == 0) {
        return @"Saved Tags";
    } else if (section == 1) {
        return @"Available Tags";
    }
    return @"";
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    CGRect rect = CGRectMake(0, 0, CGRectGetWidth(tableView.frame), kHeaderHeight);
    UIView *customView = [[UIView alloc] initWithFrame:rect];

    // Background
    CAGradientLayer *gradient = [CAGradientLayer layer];
    gradient.frame = rect;
    gradient.colors = [NSArray arrayWithObjects:(id)[UIColorFromRGB(0xEAECE5) CGColor],
                       (id)[UIColorFromRGB(0xDCDFD6) CGColor], nil];
    [customView.layer insertSublayer:gradient atIndex:0];

    // Borders
    UIView *topBorder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetWidth(rect), 1)];
    topBorder.backgroundColor = UIColorFromRGB(0xFAFCF5);
    [customView addSubview:topBorder];
    
    // bottom border
    UIView *bottomBorder = [[UIView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(rect)-0.25f,
                                                                    CGRectGetWidth(rect), 1)];
    bottomBorder.backgroundColor = UIColorFromRGB(0xB7BBAA);
    [customView addSubview:bottomBorder];
    
    // Folder title
    UIColor *textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    UIFontDescriptor *boldFontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:UIFontTextStyleCaption1];
    boldFontDescriptor = [boldFontDescriptor fontDescriptorWithSymbolicTraits:UIFontDescriptorTraitBold];
    UIFont *font = [UIFont fontWithDescriptor: boldFontDescriptor size:0.0];
    UIColor *shadowColor = UIColorFromRGB(0xF0F2E9);

    UILabel *label = [[UILabel alloc] initWithFrame:CGRectMake(12, 0,
                                                               CGRectGetWidth(rect),
                                                               CGRectGetHeight(rect))];
    [label setText:[self tableView:tableView titleForHeaderInSection:section]];
    [label setFont:font];
    [label setTextColor:textColor];
    [label setShadowColor:shadowColor];
    [label setShadowOffset:CGSizeMake(0, 1)];
    [label setLineBreakMode:NSLineBreakByTruncatingTail];
    [label setTextAlignment:NSTextAlignmentLeft];
    [customView addSubview:label];
    
    return customView;
}

- (UITableViewCell *)tableView:(UITableView *)tableView
         cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSString  *cellIdentifier = @"SavedCellIdentifier";
    FeedTableCell *cell = (FeedTableCell *)[tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) {
        cell = [[FeedTableCell alloc]
                initWithStyle:UITableViewCellStyleDefault
                reuseIdentifier:cellIdentifier];
        cell.appDelegate = appDelegate;
    }

    NSString *title;
    int count = 0;
    if (indexPath.section == 0) {
        // Tagged
        NSString *tagName = [[self arrayUserTags] objectAtIndex:indexPath.row];
        NSString *savedTagId = [NSString stringWithFormat:@"saved:%@", tagName];
        NSDictionary *tag = [appDelegate.dictSavedStoryTags objectForKey:savedTagId];
        title = [tag objectForKey:@"feed_title"];
        count = [[tag objectForKey:@"ps"] intValue];;
    } else if (indexPath.section == 1) {
        // Untagged
        NSString *tagName = [[self arrayUserTagsNotInStory] objectAtIndex:indexPath.row];
        NSString *savedTagId = [NSString stringWithFormat:@"saved:%@", tagName];
        NSDictionary *tag = [appDelegate.dictSavedStoryTags objectForKey:savedTagId];
        title = [tag objectForKey:@"feed_title"];
        count = [[tag objectForKey:@"ps"] intValue];
    }
    cell.feedFavicon = [appDelegate getFavicon:nil isSocial:NO isSaved:YES];
    cell.feedTitle     = title;
    cell.positiveCount = count;
    cell.neutralCount  = 0;
    cell.negativeCount = 0;
    cell.isSaved       = YES;
    
    [cell setNeedsDisplay];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 32;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (indexPath.section == 0) {
        NSString *tagName = [[self arrayUserTags] objectAtIndex:indexPath.row];
        NSMutableDictionary *story = [appDelegate.activeStory mutableCopy];
        NSMutableArray *newUserTags = [[story objectForKey:@"user_tags"] mutableCopy];
        [newUserTags removeObject:tagName];
        [story setObject:newUserTags forKey:@"user_tags"];
        [appDelegate.storiesCollection markStory:story asSaved:YES];
        [appDelegate.storiesCollection syncStoryAsSaved:story];
        NSInteger newCount = [self adjustSavedStoryCount:tagName direction:-1];
        
        NSInteger row = [[self arrayUserTagsNotInStory] indexOfObject:tagName];
        [tagsTableView beginUpdates];
        [tagsTableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:indexPath.row inSection:0]]
                             withRowAnimation:UITableViewRowAnimationTop];
        if (newCount > 0) {
            [tagsTableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:1]]
                                 withRowAnimation:UITableViewRowAnimationBottom];
        }
        [tagsTableView endUpdates];
    } else if (indexPath.section == 1) {
        NSString *tagName = [[self arrayUserTagsNotInStory] objectAtIndex:indexPath.row];
        NSMutableDictionary *story = [appDelegate.activeStory mutableCopy];
        
        [story setObject:[[story objectForKey:@"user_tags"] arrayByAddingObject:tagName] forKey:@"user_tags"];
        [appDelegate.storiesCollection markStory:story asSaved:YES];
        [appDelegate.storiesCollection syncStoryAsSaved:story];
        [self adjustSavedStoryCount:tagName direction:1];

        NSInteger row = [[self arrayUserTags] indexOfObject:tagName];
        [tagsTableView beginUpdates];
        [tagsTableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]]
                             withRowAnimation:UITableViewRowAnimationTop];
        [tagsTableView deleteRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:indexPath.row inSection:1]]
                             withRowAnimation:UITableViewRowAnimationBottom];
        [tagsTableView endUpdates];
    }
}

- (NSInteger)adjustSavedStoryCount:(NSString *)tagName direction:(NSInteger)direction {
    NSString *savedTagId = [NSString stringWithFormat:@"saved:%@", tagName];
    NSMutableDictionary *newTag = [[appDelegate.dictSavedStoryTags objectForKey:savedTagId] mutableCopy];
    if (!newTag) {
        newTag = [@{@"ps": [NSNumber numberWithInt:0],
                    @"feed_title": tagName
                    } mutableCopy];
    }
    NSInteger newCount = [[newTag objectForKey:@"ps"] integerValue] + direction;
    [newTag setObject:[NSNumber numberWithInteger:newCount] forKey:@"ps"];
    NSMutableDictionary *savedStoryDict = [[NSMutableDictionary alloc] init];
    for (NSString *tagId in [appDelegate.dictSavedStoryTags allKeys]) {
        if ([tagId isEqualToString:savedTagId]) {
            if (newCount > 0) {
                [savedStoryDict setObject:newTag forKey:tagId];
            }
        } else {
            [savedStoryDict setObject:[appDelegate.dictSavedStoryTags objectForKey:tagId]
                               forKey:tagId];
        }
    }
    
    // If adding a tag, it won't already be in dictSavedStoryTags
    if (![appDelegate.dictSavedStoryTags objectForKey:savedStoryDict] && newCount > 0) {
        [savedStoryDict setObject:newTag forKey:savedTagId];
    }
    appDelegate.dictSavedStoryTags = savedStoryDict;
    
    return newCount;
}

#pragma mark - Search Bar

- (void)searchBarSearchButtonClicked:(UISearchBar *)searchBar {
    [addTagBar resignFirstResponder];
    NSString *tagName = addTagBar.text;
    NSMutableDictionary *story = [appDelegate.activeStory mutableCopy];
    
    [story setObject:[[story objectForKey:@"user_tags"] arrayByAddingObject:tagName] forKey:@"user_tags"];
    [appDelegate.storiesCollection markStory:story asSaved:YES];
    [appDelegate.storiesCollection syncStoryAsSaved:story];
    [self adjustSavedStoryCount:tagName direction:1];
    
    NSInteger row = [[self arrayUserTags] indexOfObject:tagName];
    [tagsTableView beginUpdates];
    [tagsTableView insertRowsAtIndexPaths:@[[NSIndexPath indexPathForRow:row inSection:0]]
                         withRowAnimation:UITableViewRowAnimationTop];
    [tagsTableView endUpdates];
    
    [addTagBar setText:@""];
}

@end
