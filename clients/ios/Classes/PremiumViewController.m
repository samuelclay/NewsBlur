//
//  PremiumViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/9/17.
//  Copyright © 2017 NewsBlur. All rights reserved.
//

#import "PremiumViewController.h"
#import "NewsBlur-Swift.h"
#import "PremiumManager.h"

#define kPremiumSubscriptionSection 0
#define kPremiumArchiveSubscriptionSection 1

#define kManageSubscriptionHeight 100

@interface PremiumViewController ()

@end

@implementation PremiumViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Done"
                                                                     style: UIBarButtonItemStylePlain
                                                                    target: self
                                                                    action: @selector(closeDialog:)];
    [self.navigationItem setLeftBarButtonItem:cancelButton];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIBarButtonItem *restoreButton = [[UIBarButtonItem alloc] initWithTitle: @"Restore"
                                                                      style: UIBarButtonItemStylePlain
                                                                     target: self
                                                                     action: @selector(restorePurchase:)];
    [self.navigationItem setRightBarButtonItem:restoreButton];
    
    self.navigationItem.title = @"NewsBlur Premium";
    [self loadProducts];
    
    self.premiumTable.tableFooterView = [self makePolicyView];
    [self updateTheme];
}

- (void)closeDialog:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (NSInteger)rowsInSection:(NSInteger)section {
    switch (section) {
        case kPremiumSubscriptionSection:
            return self.appDelegate.premiumManager.premiumReasons.count + 2;
            break;
        case kPremiumArchiveSubscriptionSection:
            return self.appDelegate.premiumManager.premiumArchiveReasons.count + 1;
            break;
    }
    
    return 0;
}

- (UIView *)makeManageSubscriptionView {
    CGSize viewSize = CGSizeMake(self.view.frame.size.width, kManageSubscriptionHeight);
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewSize.width, viewSize.height)];
    
    UIView *button = [self makeButtonWithTitle:@"Manage Subscription" forURL:@"https://apps.apple.com/account/subscriptions"];
    
    button.frame = CGRectMake(((viewSize.width - CGRectGetWidth(button.frame)) / 2) - 20, 15, CGRectGetWidth(button.frame) + 40, CGRectGetHeight(button.frame) + 5);
    
    [view addSubview:button];
    
    UILabel *label = [UILabel new];
    
    if (self.appDelegate.premiumExpire != 0) {
        NSDate *date = [NSDate dateWithTimeIntervalSince1970:self.appDelegate.premiumExpire];
        NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"MMMM d, yyyy"];
        label.text = [NSString stringWithFormat:@"Your premium subscription will renew on %@", [dateFormatter stringFromDate:date]];
    } else {
        label.text = @"Your premium subscription is set to never expire. Whoa!";
    }
    
    label.textAlignment = NSTextAlignmentCenter;
    label.numberOfLines = 0;
    label.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:[UIFont smallSystemFontSize]];
    label.textColor = UIColorFromRGB(0x0c0c0c);
    CGSize measuredSize = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
    label.frame = CGRectMake((viewSize.width - measuredSize.width) / 2, 15 + CGRectGetHeight(button.frame) + 15, measuredSize.width, measuredSize.height);
    
    [view addSubview:label];
    
    return view;
}

- (UIView *)makePolicyView {
    CGSize viewSize = CGSizeMake(self.view.frame.size.width, 120);
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, viewSize.width, viewSize.height)];
    
    UIView *button = [self makeButtonWithTitle:@"Privacy Policy" forURL:@"https://newsblur.com/privacy/"];
    CGFloat buttonHeight = CGRectGetHeight(button.frame) + 5;
    
    button.frame = CGRectMake(((viewSize.width - CGRectGetWidth(button.frame)) / 2) - 20, 15, CGRectGetWidth(button.frame) + 40, buttonHeight);
    
    [view addSubview:button];
    
    button = [self makeButtonWithTitle:@"Terms of Use" forURL:@"https://newsblur.com/tos/"];
    
    button.frame = CGRectMake(((viewSize.width - CGRectGetWidth(button.frame)) / 2) - 20, 15 + buttonHeight + 15, CGRectGetWidth(button.frame) + 40, buttonHeight);
    
    [view addSubview:button];
    
    return view;
}

- (UIView *)makeButtonWithTitle:(NSString *)title forURL:(NSString *)urlString {
    UIAction *action = [UIAction actionWithHandler:^(__kindof UIAction * _Nonnull action) {
        NSURL *url = [NSURL URLWithString:urlString];
        
        [UIApplication.sharedApplication openURL:url options:@{} completionHandler:nil];
    }];
    
    action.title = title;
    
    UIButton *button = [UIButton buttonWithType:UIButtonTypeSystem primaryAction:action];
    
    button.tintColor = UIColor.whiteColor;
    button.backgroundColor = UIColorFromFixedRGB(0x939EAF);
    button.layer.cornerRadius = 10;
    
    [button sizeToFit];
    
    return button;
}

- (void)updateTheme {
    [super updateTheme];
    
    self.premiumTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
    
    [self.premiumTable reloadData];
}

#pragma mark - StoreKit

- (void)loadProducts {
    [self.appDelegate.premiumManager loadProducts];
}

- (void)loadedProducts {
    [self.premiumTable reloadData];
}

- (SKProduct *)productForSection:(NSInteger)section {
    if (section == kPremiumSubscriptionSection) {
        return self.appDelegate.premiumManager.premiumProduct;
    } else {
        return self.appDelegate.premiumManager.premiumArchiveProduct;
    }
}

- (void)purchase:(SKProduct *)product {
    [self.appDelegate.premiumManager purchase:product];
}

- (IBAction)restorePurchase:(id)sender {
    [self.appDelegate.premiumManager restorePurchase];
}

- (void)finishedTransaction {
    [self.premiumTable reloadData];
}

- (void)informError:(id)error {
    [super informError:error];
}

#pragma mark - Table Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 2;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [self rowsInSection:section];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    NSInteger rowsInSection = [self rowsInSection:indexPath.section];
    
    if (indexPath.section == kPremiumSubscriptionSection && indexPath.row == rowsInSection - 2) {
        static NSString *DogCellIdentifier = @"PremiumDogCell";
        cell = [tableView dequeueReusableCellWithIdentifier:DogCellIdentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:DogCellIdentifier];
        }
        
        cell.backgroundColor = UIColorFromRGB(0xf4f4f4);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        
        UIImageView *imgView = [[UIImageView alloc] init];
        imgView.translatesAutoresizingMaskIntoConstraints = NO;
        imgView.tag = 1;
        imgView.contentMode = UIViewContentModeScaleAspectFit;
        [cell addSubview:imgView];
        
        [cell addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:cell attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
        [cell addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:cell attribute:NSLayoutAttributeTop multiplier:1.0 constant:12]];
        [imgView addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:96]];
        
        UIImageView *_imgView = (UIImageView *)[cell viewWithTag:1];
        _imgView.image = [UIImage imageNamed:@"Lyric.jpg"];
    } else if (indexPath.row < rowsInSection - 1) {
        static NSString *ReasonsCellIdentifier = @"PremiumReasonsCell";
        cell = [tableView dequeueReusableCellWithIdentifier:ReasonsCellIdentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ReasonsCellIdentifier];
        }
        
        BOOL isArchive = indexPath.section == kPremiumArchiveSubscriptionSection;
        NSArray *reasons = isArchive ? self.appDelegate.premiumManager.premiumArchiveReasons : self.appDelegate.premiumManager.premiumReasons;
        
        cell.backgroundColor = UIColorFromRGB(0xf4f4f4);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = reasons[indexPath.row][0];
        cell.textLabel.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:14.0];
        cell.textLabel.textColor = UIColorFromRGB(0x0c0c0c);
        cell.textLabel.numberOfLines = 2;
        CGSize itemSize = CGSizeMake(18, 18);
        NSString *imageName = reasons[indexPath.row][1];
        UIImage *image = [UIImage imageNamed:imageName];
        
        if (ThemeManager.themeManager.isDarkTheme) {
            cell.imageView.image = [image imageWithTintColor:UIColor.whiteColor];
        } else {
            cell.imageView.image = image;
        }
        
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.clipsToBounds = NO;
        UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
        CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
        [cell.imageView.image drawInRect:imageRect];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else {
        static NSString *CellIdentifier = @"PremiumCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        BOOL isSubscribed = NO;
        SKProduct *product = [self productForSection:indexPath.section];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = UIColorFromRGB(0xf4f4f4);
        cell.textLabel.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:18.0];
        cell.textLabel.textColor = UIColorFromRGB(0x203070);
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:18.0];
        cell.detailTextLabel.textColor = UIColorFromRGB(0x0c0c0c);
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [formatter setLocale:product.priceLocale];
        
        if (indexPath.section == kPremiumSubscriptionSection && self.appDelegate.isPremium) {
            if (self.appDelegate.isPremiumArchive) {
                cell.textLabel.text = @"Your premium archive subscription includes everything above";
            } else {
                cell.textLabel.text = @"Your premium subscription is active";
            }
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            isSubscribed = YES;
        } else if (indexPath.section == kPremiumArchiveSubscriptionSection && self.appDelegate.isPremiumArchive) {
            cell.textLabel.text = @"Your premium archive subscription is active";
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            isSubscribed = YES;
        } else if (product == nil) {
            cell.textLabel.text = @"Not currently available";
        } else if (!product.localizedTitle) {
            cell.textLabel.text = @"NewsBlur Premium Subscription";
        } else {
            cell.textLabel.text = product.localizedTitle;
        }
        
        if (!isSubscribed && product != nil) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ per year (%@/month)", [formatter stringFromNumber:product.price], [formatter stringFromNumber:@(round([product.price doubleValue] / 12.f))]];
        } else {
            cell.detailTextLabel.text = nil;
        }
        
        UILabel *label = [[UILabel alloc] init];
        label.text = isSubscribed ? @"✅" : @"👉🏽";
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor;
        label.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:18.0];
        CGSize measuredSize = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
        label.frame = CGRectMake(0, 0, measuredSize.width, measuredSize.height);
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, label.opaque, 0.0);
        [label.layer renderInContext:UIGraphicsGetCurrentContext()];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    NSInteger rowsInSection = [self rowsInSection:indexPath.section];
    
    if (indexPath.section == kPremiumSubscriptionSection && indexPath.row == rowsInSection - 2) {
        return 120;
    } else if (indexPath.row < [self tableView:tableView numberOfRowsInSection:indexPath.section] - 1) {
        return 40;
    } else {
        return 60;
    }
}

- (UIView *)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    UILabel *label = [[UILabel alloc] init];
    label.text = section == kPremiumArchiveSubscriptionSection ? @"   Premium Archive Subscription" : @"   Premium Subscription";
    label.opaque = YES;
    label.backgroundColor = UIColor.darkGrayColor;
    label.textColor = UIColor.whiteColor;
    label.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:20.0];
    CGSize measuredSize = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
    label.frame = CGRectMake(0, 0, measuredSize.width, measuredSize.height);
    
    return label;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 60;
}

- (UIView *)tableView:(UITableView *)tableView viewForFooterInSection:(NSInteger)section {
    if (section == kPremiumArchiveSubscriptionSection && self.appDelegate.isPremiumArchive) {
        return [self makeManageSubscriptionView];
    } else if (section == kPremiumSubscriptionSection && self.appDelegate.isPremium) {
        return [self makeManageSubscriptionView];
    } else {
        return nil;
    }
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    if (section == kPremiumArchiveSubscriptionSection && self.appDelegate.isPremiumArchive) {
        return kManageSubscriptionHeight;
    } else if (section == kPremiumSubscriptionSection && self.appDelegate.isPremium) {
        return kManageSubscriptionHeight;
    } else {
        return 0;
    }
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    SKProduct *product = [self productForSection:indexPath.section];
    
    if (product != nil && indexPath.row == [self tableView:tableView numberOfRowsInSection:indexPath.section] - 1) {
        if (indexPath.section == kPremiumSubscriptionSection && !self.appDelegate.isPremium) {
            [self purchase:product];
        } else if (indexPath.section == kPremiumArchiveSubscriptionSection && !self.appDelegate.isPremiumArchive) {
            [self purchase:product];
        }
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end
