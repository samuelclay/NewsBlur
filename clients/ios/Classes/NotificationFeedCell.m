//
//  NotificationFeedCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 11/23/16.
//  Copyright © 2016 NewsBlur. All rights reserved.
//

#import "NotificationFeedCell.h"
#import "NewsBlurAppDelegate.h"

@implementation NotificationFeedCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        // Initialization code
        self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];

        self.tintColor = UIColorFromRGB(0x707070);
        self.textLabel.font = [UIFont fontWithName:@"WhitneySSm-Medium" size:15.0];
        self.detailTextLabel.font = [UIFont fontWithName:@"WhitneySSm-Book" size:14.0];
        [self setSeparatorInset:UIEdgeInsetsMake(0, 38, 0, 0)];
        UIView *background = [[UIView alloc] init];
        [background setBackgroundColor:UIColorFromRGB(0xFFFFFF)];
        [self setBackgroundView:background];
        
        UIView *selectedBackground = [[UIView alloc] init];
        [selectedBackground setBackgroundColor:UIColorFromRGB(0xECEEEA)];
        [self setSelectedBackgroundView:selectedBackground];
        
        NSDictionary *controlAttrs = @{NSForegroundColorAttributeName: [UIColor lightGrayColor]};
        self.filterControl = [[UISegmentedControl alloc] initWithItems:@[@"Unread Stories",
                                                                         @"Focus Stories"]];
        self.filterControl.tintColor = UIColorFromRGB(0x8F918B);
        [self.filterControl.subviews objectAtIndex:1].accessibilityLabel = @"Focus Stories";
        [self.filterControl.subviews objectAtIndex:0].accessibilityLabel = @"Unread Stories";
        [self.filterControl setTitle:@"Unread Stories" forSegmentAtIndex:0];
        [self.filterControl setTitle:@"Focus Stories" forSegmentAtIndex:1];
        [self.filterControl setImage:[UIImage imageNamed:@"unread_yellow.png"] forSegmentAtIndex:0];
        [self.filterControl setImage:[UIImage imageNamed:@"unread_green.png"] forSegmentAtIndex:1];
        [self.filterControl setTitleTextAttributes:controlAttrs forState:UIControlStateNormal];
        self.filterControl.frame = CGRectMake(36, 38, CGRectGetWidth(self.frame), 28);
        [self.contentView addSubview:self.filterControl];
        
        CGFloat offset = 0;
        
        [[ThemeManager themeManager] updateSegmentedControl:self.filterControl];
        
        self.emailNotificationTypeButton = [self makeNotificationTypeControlWithTitle:@"Email" offset:&offset];
        self.webNotificationTypeButton = [self makeNotificationTypeControlWithTitle:@"Web" offset:&offset];
        self.iOSNotificationTypeButton = [self makeNotificationTypeControlWithTitle:@"iOS" offset:&offset];
        self.androidNotificationTypeButton = [self makeNotificationTypeControlWithTitle:@"Android" offset:&offset];
    }
    
    return self;
}

- (UIButton *)makeNotificationTypeControlWithTitle:(NSString *)title offset:(CGFloat *)offset {
    CGRect frame = CGRectMake(36 + *offset, 76, CGRectGetWidth(self.frame) * 0.25, 28);
    UIButton *button = [UIButton buttonWithType:UIButtonTypeCustom];
    button.frame = frame;
    
    button.layer.borderColor = UIColorFromLightDarkRGB(0xe7e6e7, 0x303030).CGColor;
    button.layer.borderWidth = 1.5;
    button.layer.cornerRadius = 8.0;
    
    [button setTitleColor:UIColorFromLightDarkRGB(0x909090, 0xaaaaaa) forState:UIControlStateNormal];
    [button setTitleColor:UIColorFromLightDarkRGB(0x0, 0xffffff) forState:UIControlStateSelected];
    
    button.titleLabel.font = [UIFont systemFontOfSize:14];
    [button setTitle:title forState:UIControlStateNormal];
    
    [button addTarget:self action:@selector(changeNotification:) forControlEvents:UIControlEventTouchUpInside];
    
    *offset += CGRectGetWidth(button.bounds);
    
    [self.contentView addSubview:button];
    
    return button;
}

- (void)layoutSubviews {
    [super layoutSubviews];
    
    self.textLabel.backgroundColor = [UIColor clearColor];
    self.textLabel.textColor = UIColorFromRGB(0x303030);
    self.textLabel.shadowColor = UIColorFromRGB(0xF0F0F0);
    self.textLabel.shadowOffset = CGSizeMake(0, 1);
    self.textLabel.highlightedTextColor = UIColorFromRGB(0x303030);
    self.detailTextLabel.highlightedTextColor = UIColorFromRGB(0x505050);
    self.detailTextLabel.textColor = UIColorFromRGB(0x505050);
    self.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.backgroundView.backgroundColor = UIColorFromRGB(0xFFFFFF);
    self.selectedBackgroundView.backgroundColor = UIColorFromRGB(0xECEEEA);
    
    self.imageView.frame = CGRectMake(10.0, 10.0, 16.0, 16.0);
    self.imageView.contentMode = UIViewContentModeScaleAspectFit;
    
    [self.textLabel sizeToFit];
    CGRect frame = self.textLabel.frame;
    frame.origin.x = 35.0;
    frame.size.width = self.detailTextLabel.frame.origin.x - self.textLabel.frame.origin.x;
    self.textLabel.frame = frame;
        CGRect textFrame = self.textLabel.frame;
    textFrame.origin.y = 10;
    self.textLabel.frame = textFrame;

    CGRect detailFrame = self.detailTextLabel.frame;
    detailFrame.origin.y = 10;
    self.detailTextLabel.frame = detailFrame;

    CGFloat detailTextLabelWidth = self.detailTextLabel.attributedText.size.width;
    CGRect detailTextLabelFrame = self.detailTextLabel.frame;
    CGFloat detailTextLabelExtraWidth = detailTextLabelWidth - detailTextLabelFrame.size.width;
    if (detailTextLabelExtraWidth > 0) {
        detailTextLabelFrame.origin.x -= detailTextLabelExtraWidth;
        detailTextLabelFrame.size.width = detailTextLabelWidth;
        self.detailTextLabel.frame = detailTextLabelFrame;
        
        CGRect textLabelFrame = self.textLabel.frame;
        textLabelFrame.size.width = self.detailTextLabel.frame.origin.x - self.textLabel.frame.origin.x;
        self.textLabel.frame = textLabelFrame;
    }
    
    NSDictionary *feed = [self.appDelegate.dictFeeds objectForKey:self.feedId];
    if ([[feed objectForKey:@"notification_filter"] isEqualToString:@"focus"]) {
        self.filterControl.selectedSegmentIndex = 1;
    } else {
        self.filterControl.selectedSegmentIndex = 0;
    }
    
    NSArray *notificationTypes = [feed objectForKey:@"notification_types"];
    [self updateNotificationTypeButton:self.emailNotificationTypeButton forCondition:[notificationTypes containsObject:@"email"]];
    [self updateNotificationTypeButton:self.webNotificationTypeButton forCondition:[notificationTypes containsObject:@"web"]];
    [self updateNotificationTypeButton:self.iOSNotificationTypeButton forCondition:[notificationTypes containsObject:@"ios"]];
    [self updateNotificationTypeButton:self.androidNotificationTypeButton forCondition:[notificationTypes containsObject:@"android"]];
}

- (void)updateNotificationTypeButton:(UIButton *)button forCondition:(BOOL)on {
    button.selected = on;
    button.backgroundColor = on ? UIColorFromLightDarkRGB(0xffffff, 0x6f6f75) : UIColorFromLightDarkRGB(0xe7e6e7, 0x3b3b3d);
}

- (void)changeNotification:(UIButton *)button {
    [self updateNotificationTypeButton:button forCondition:!button.selected];
    
    [self saveNotifications];
}

- (void)saveNotifications {
    NSMutableArray *notificationTypes = [NSMutableArray array];
    NSString *notificationFilter = self.filterControl.selectedSegmentIndex == 0 ? @"unread": @"focus";
    
    if (self.emailNotificationTypeButton.selected) {
        [notificationTypes addObject:@"email"];
    }
    if (self.webNotificationTypeButton.selected) {
        [notificationTypes addObject:@"web"];
    }
    if (self.iOSNotificationTypeButton.selected) {
        [notificationTypes addObject:@"ios"];
    }
    if (self.androidNotificationTypeButton.selected) {
        [notificationTypes addObject:@"android"];
    }
    
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:self.feedId forKey:@"feed_id"];
    [params setObject:notificationTypes forKey:@"notification_types"];
    [params setObject:notificationFilter forKey:@"notification_filter"];
    
    [self.appDelegate updateNotifications:params feed:self.feedId];
}

@end
