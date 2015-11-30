//
//  FontListViewController.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-10-30.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "FontListViewController.h"
#import "FontTableViewCell.h"
#import "NewsBlurAppDelegate.h"
#import "StoryPageControl.h"

@interface FontListViewController ()

@property (nonatomic, strong) NSIndexPath *selectedIndexPath;

@end

@implementation FontListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.fontTableView.backgroundColor = UIColorFromRGB(0xECEEEA);
    self.fontTableView.separatorColor = UIColorFromRGB(0x909090);
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    
    self.title = @"Font";
    
    self.preferredContentSize = CGSizeMake(240.0, 38.0 * self.fonts.count);
}

#pragma mark - Table view data source

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return self.fonts.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    static NSString *CellIndentifier = @"FontCell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
    NSDictionary *font = self.fonts[indexPath.row];
    
    if (!cell) {
        cell = [[FontTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIndentifier];
    }
    
    cell.textLabel.attributedText = font[@"name"];
    
    NSString *fontStyle = [[NSUserDefaults standardUserDefaults] stringForKey:@"fontStyle"];
    
    if (!fontStyle) {
        fontStyle = @"NB-helvetica";
    }
    
    if ([font[@"style"] isEqualToString:fontStyle]) {
        cell.accessoryType = UITableViewCellAccessoryCheckmark;
        self.selectedIndexPath = indexPath;
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 38.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    NewsBlurAppDelegate *appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    NSDictionary *font = self.fonts[indexPath.row];
    NSString *style = font[@"style"];
    
    if (self.selectedIndexPath) {
        FontTableViewCell *cell = [self.fontTableView cellForRowAtIndexPath:self.selectedIndexPath];
        cell.accessoryType = UITableViewCellAccessoryNone;
    }
    
    FontTableViewCell *cell = [self.fontTableView cellForRowAtIndexPath:indexPath];
    cell.accessoryType = UITableViewCellAccessoryCheckmark;
    
    self.selectedIndexPath = indexPath;
    
    [appDelegate.storyPageControl setFontStyle:style];
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
