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

@interface PremiumViewController ()

@end

@implementation PremiumViewController

@synthesize appDelegate;
@synthesize productsTable;
@synthesize reasonsTable;
@synthesize spinner;
@synthesize navigationBar;
@synthesize doneButton;
@synthesize restoreButton;
@synthesize freeView;
@synthesize premiumView;
@synthesize confettiView;
@synthesize productsHeight;
@synthesize labelTitle;
@synthesize labelSubtitle;
@synthesize labelPremiumTitle;
@synthesize labelPremiumExpire;

- (void)viewDidLoad {
    [super viewDidLoad];
    
    UIBarButtonItem *cancelButton = [[UIBarButtonItem alloc] initWithTitle: @"Done"
                                                                     style: UIBarButtonItemStylePlain
                                                                    target: self
                                                                    action: @selector(closeDialog:)];
    [self.navigationItem setLeftBarButtonItem:cancelButton];
    
    self.productsTable.tableFooterView = [UIView new];
    self.reasonsTable.tableFooterView = [self makeShilohCell];
    self.productsTable.separatorColor = [UIColor clearColor];
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
    [self preparePolicyText];
    [self updateTheme];
    [confettiView setNeedsLayout];
    [confettiView startConfetti];
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    [confettiView setNeedsLayout];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
    
    [confettiView stopConfetti];
}

- (void)closeDialog:(id)sender {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)preparePolicyText {
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.alignment = NSTextAlignmentCenter;
    NSDictionary *attributes = @{NSParagraphStyleAttributeName : paragraphStyle};
    NSMutableAttributedString *policyString = [[NSMutableAttributedString alloc] initWithString:@"See NewsBlur's " attributes:attributes];
    NSURL *privacyURL = [NSURL URLWithString:@"https://newsblur.com/privacy/"];
    NSURL *termsURL = [NSURL URLWithString:@"https://newsblur.com/tos/"];
    NSAttributedString *privacyLink = [[NSAttributedString alloc] initWithString:@"privacy policy"
                                                                      attributes:@{NSLinkAttributeName : privacyURL}];
    NSAttributedString *termsLink = [[NSAttributedString alloc] initWithString:@"terms of use"
                                                                    attributes:@{NSLinkAttributeName : termsURL}];
    
    [policyString appendAttributedString:privacyLink];
    [policyString appendAttributedString:[[NSAttributedString alloc] initWithString:@" and "]];
    [policyString appendAttributedString:termsLink];
    [policyString appendAttributedString:[[NSAttributedString alloc] initWithString:@" for details."]];
    
    self.policyTextView.attributedText = policyString;
}

- (void)updateTheme {
    [super updateTheme];
    
    self.productsTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.reasonsTable.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.view.backgroundColor = UIColorFromRGB(0xf4f4f4);
    self.labelTitle.textColor = UIColorFromRGB(0x0c0c0c);
    self.labelSubtitle.textColor = UIColorFromRGB(0x0c0c0c);
    self.policyTextView.textColor = UIColorFromRGB(0x0c0c0c);
    self.policyTextView.linkTextAttributes = @{NSForegroundColorAttributeName : UIColorFromRGB(NEWSBLUR_LINK_COLOR)};

    self.labelPremiumExpire.textColor = UIColorFromRGB(0x0c0c0c);
    self.labelPremiumTitle.textColor = UIColorFromRGB(0x0c0c0c);
    self.labelPremiumExpire.shadowColor = UIColorFromRGB(0xf4f4f4);
    self.labelPremiumTitle.shadowColor = UIColorFromRGB(0xf4f4f4);

    [self.productsTable reloadData];
    [self.reasonsTable reloadData];
}

#pragma mark - StoreKit

- (void)loadProducts {
    [spinner startAnimating];
    productsTable.hidden = YES;
    
    [appDelegate.premiumManager loadProducts];
    
    if (appDelegate.isPremium) {
        freeView.hidden = YES;
        premiumView.hidden = NO;
        self.navigationItem.rightBarButtonItem = nil;
        
        if (appDelegate.premiumExpire != 0) {
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:appDelegate.premiumExpire];
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"MMMM d, yyyy"];
            labelPremiumExpire.text = [NSString stringWithFormat:@"Your premium subscription will renew on %@", [dateFormatter stringFromDate:date]];
        } else {
            labelPremiumExpire.text = @"Your premium subscription is set to never expire. Whoa!";
        }
    } else {
        freeView.hidden = NO;
        premiumView.hidden = YES;
    }
}

- (void)loadedProducts {
    spinner.hidden = YES;
    productsTable.hidden = NO;
    [productsTable reloadData];
}

- (void)purchase:(SKProduct *)product {
    productsTable.hidden = YES;
    spinner.hidden = NO;
    
    [appDelegate.premiumManager purchase:product];
}

- (IBAction)restorePurchase:(id)sender {
    productsTable.hidden = YES;
    spinner.hidden = NO;
    
    [appDelegate.premiumManager restorePurchase];
}

- (void)finishedTransaction {
    productsTable.hidden = NO;
    spinner.hidden = YES;
}

- (void)informError:(id)error {
    productsTable.hidden = NO;
    spinner.hidden = YES;
    
    [super informError:error];
}

#pragma mark - Table Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if (tableView == reasonsTable) {
        return [appDelegate.premiumManager.reasons count];
    } else if (tableView == productsTable) {
        return [appDelegate.premiumManager.products count];
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    UITableViewCell *cell;
    
    if (tableView == reasonsTable) {
        static NSString *ReasonsCellIndentifier = @"PremiumReasonsCell";
        cell = [tableView dequeueReusableCellWithIdentifier:ReasonsCellIndentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:ReasonsCellIndentifier];
        }
        
        cell.backgroundColor = UIColorFromRGB(0xf4f4f4);
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = appDelegate.premiumManager.reasons[indexPath.row][0];
        cell.textLabel.font = [UIFont systemFontOfSize:14.f weight:UIFontWeightLight];
        cell.textLabel.textColor = UIColorFromRGB(0x0c0c0c);
        cell.textLabel.numberOfLines = 2;
        CGSize itemSize = CGSizeMake(18, 18);
        cell.imageView.image = [UIImage imageNamed:appDelegate.premiumManager.reasons[indexPath.row][1]];
        cell.imageView.contentMode = UIViewContentModeScaleAspectFill;
        cell.imageView.clipsToBounds = NO;
        UIGraphicsBeginImageContextWithOptions(itemSize, NO, UIScreen.mainScreen.scale);
        CGRect imageRect = CGRectMake(0.0, 0.0, itemSize.width, itemSize.height);
        [cell.imageView.image drawInRect:imageRect];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
        UIGraphicsEndImageContext();
    } else { //} if (tableView == productsTable) {
        static NSString *CellIndentifier = @"PremiumCell";
        cell = [tableView dequeueReusableCellWithIdentifier:CellIndentifier];
        
        if (!cell) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIndentifier];
        }

        SKProduct *product = appDelegate.premiumManager.products[indexPath.row];
        cell.selectionStyle = UITableViewCellSelectionStyleBlue;
        cell.backgroundColor = UIColorFromRGB(0xf4f4f4);
        cell.textLabel.textColor = UIColorFromRGB(0x203070);
        cell.textLabel.numberOfLines = 2;
        cell.detailTextLabel.textColor = UIColorFromRGB(0x0c0c0c);
        NSNumberFormatter *formatter = [[NSNumberFormatter alloc] init];
        [formatter setFormatterBehavior:NSNumberFormatterBehavior10_4];
        [formatter setNumberStyle:NSNumberFormatterCurrencyStyle];
        [formatter setLocale:product.priceLocale];
        
        if (!product.localizedTitle) {
            cell.textLabel.text = [NSString stringWithFormat:@"NewsBlur Premium Subscription"];
        } else {
            cell.textLabel.text = [NSString stringWithFormat:@"%@", product.localizedTitle];
        }
        cell.detailTextLabel.text = [NSString stringWithFormat:@"%@ per year (%@/month)", [formatter stringFromNumber:product.price], [formatter stringFromNumber:@(round([product.price doubleValue] / 12.f))]];;
        
        UILabel *label = [[UILabel alloc] init];
        label.text = @"👉🏽";
        label.opaque = NO;
        label.backgroundColor = UIColor.clearColor;
        label.font = [UIFont systemFontOfSize:18];
        CGSize measuredSize = [label.text sizeWithAttributes:@{NSFontAttributeName: label.font}];
        label.frame = CGRectMake(0, 0, measuredSize.width, measuredSize.height);
        UIGraphicsBeginImageContextWithOptions(label.bounds.size, label.opaque, 0.0);
        [label.layer renderInContext:UIGraphicsGetCurrentContext()];
        cell.imageView.image = UIGraphicsGetImageFromCurrentImageContext();
    }
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForFooterInSection:(NSInteger)section {
    return 0;
}

- (UIView *)makeShilohCell {
    UIView *view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.frame.size.width, 96+12+12)];
    UIImageView *imgView = [[UIImageView alloc] init];
    imgView.translatesAutoresizingMaskIntoConstraints = NO;
    imgView.tag = 1;
    imgView.contentMode = UIViewContentModeScaleAspectFit;
    [view addSubview:imgView];
    
    [view addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeCenterX multiplier:1.0 constant:0]];
    [view addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual toItem:view attribute:NSLayoutAttributeTop multiplier:1.0 constant:12]];
    [imgView addConstraint:[NSLayoutConstraint constraintWithItem:imgView attribute:NSLayoutAttributeHeight relatedBy:NSLayoutRelationEqual toItem:nil attribute:NSLayoutAttributeNotAnAttribute multiplier:1.0 constant:96]];

    UIImageView *_imgView = (UIImageView *)[view viewWithTag:1];
    _imgView.image = [UIImage imageNamed:@"Shiloh.jpg"];
    
    return view;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    if (tableView == productsTable) {
        [self purchase:appDelegate.premiumManager.products[indexPath.row]];
    }
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
}
@end
