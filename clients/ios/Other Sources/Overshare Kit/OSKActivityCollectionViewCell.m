//
//  OSKActivityCollectionViewCell.m
//  Overshare
//
//  Created by Jared Sinclair on 10/13/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivityCollectionViewCell.h"

#import "OSKActivityIcon.h"
#import "OSKActivity.h"
#import "OSKShareableContentItem.h"
#import "OSKActivitiesManager.h"
#import "OSKPresentationManager.h"

NSString * const OSKActivityCollectionViewCellIdentifier = @"OSKActivityCollectionViewCellIdentifier";
CGSize const OSKActivityCollectionViewCellSize_Phone = {76.0f, 96.0f};
CGRect const OSKActivityCollectionViewCellLabelRect_Phone = {{4.0f, 64.0f},{68.0f, 32.0f}};
CGSize const OSKActivityCollectionViewCellSize_Pad = {92.0f, 112.0f};
CGRect const OSKActivityCollectionViewCellLabelRect_Pad = {{4.0f, 80.0f},{84.0f, 32.0f}};

static CGFloat OSKActivityIconBadgeWidth_Phone = 76.0f;
static CGFloat OSKActivityIconBadgeWidth_Pad = 96.0f;

@import QuartzCore;

@interface OSKActivityCollectionViewCell ()

@property (weak, nonatomic) IBOutlet OSKActivityIcon *iconButton;
@property (weak, nonatomic) IBOutlet UIImageView *iconBorder;
@property (strong, nonatomic) NSDictionary *textAttributes;
@property (copy, nonatomic) NSAttributedString *attributedText;
@property (assign, nonatomic) BOOL showBadge;
@property (strong, nonatomic) UIButton *purchaseBadge;

@end

@implementation OSKActivityCollectionViewCell

- (void)dealloc {
    [self removePurchaseNotificationObservation];
}

- (id)initWithFrame:(CGRect)frame {
    self = [super initWithFrame:frame];
    if (self) {
        [self commonInit];
    }
    return self;
}

- (void)awakeFromNib {
    [super awakeFromNib];
    [self commonInit];
}

- (void)commonInit {
    [self addPurchaseNotificationObservation];
    UIImage *borderImage = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                            ? [UIImage imageNamed:@"osk-icon-border-76.png"]
                            : [UIImage imageNamed:@"osk-icon-border-60.png"];
    self.iconBorder.image = [borderImage imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    [self updateColors];
    self.iconButton.isAccessibilityElement = NO;
    self.iconBorder.isAccessibilityElement = NO;
    self.clipsToBounds = NO;
}

- (void)updateColors {
    OSKPresentationManager *manager = [OSKPresentationManager sharedInstance];
    UIColor *textColor = [manager color_text];
    
    if ([manager sheetStyle] == OSKActivitySheetViewControllerStyle_Dark) {
        self.iconBorder.tintColor = [UIColor colorWithWhite:1.0 alpha:0.5];
    } else {
        self.iconBorder.tintColor = [UIColor blackColor];
    }
    
    NSMutableParagraphStyle *paragraph = [[NSMutableParagraphStyle alloc] init];
    paragraph.lineBreakMode = NSLineBreakByWordWrapping;
    paragraph.alignment = NSTextAlignmentCenter;
    paragraph.minimumLineHeight = 12.0f;
    paragraph.maximumLineHeight = 12.0f;
    
    CGFloat fontSize = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad) ? 12.0f : 11.0f;
    
    UIFont *font = nil;
    UIFontDescriptor *descriptor = [[OSKPresentationManager sharedInstance] normalFontDescriptor];
    if (descriptor) {
        font = [UIFont fontWithDescriptor:descriptor size:fontSize];
    } else {
        font = [UIFont systemFontOfSize:fontSize];
    }
    
    _textAttributes = @{NSForegroundColorAttributeName:textColor,
                        NSFontAttributeName:font,
                        NSParagraphStyleAttributeName:paragraph};
}

- (void)setActivity:(OSKActivity *)activity {
    if (_activity != activity) {
        _activity = activity;
        [self updateInterface];
    }
}

- (UIAccessibilityTraits)accessibilityTraits {
    return UIAccessibilityTraitButton;
}

- (NSString *)accessibilityLabel {
    return self.attributedText.string;
}

- (BOOL)isAccessibilityElement {
    CGRect myFrameConverted = [self.superview convertRect:self.frame toView:self.superview.superview];
    return (CGRectIntersectsRect(myFrameConverted, self.superview.frame));
}

- (void)updateInterface {
    NSString *name = nil;
    if (self.activity.contentItem.alternateActivityName) {
        name = self.activity.contentItem.alternateActivityName;
    } else {
        name = [self.activity.class activityName];
    }
    self.attributedText = [[NSAttributedString alloc] initWithString:name attributes:_textAttributes];
    
    UIImage *icon = nil;
    OSKPresentationManager *presentationManager = [OSKPresentationManager sharedInstance];
    UIUserInterfaceIdiom idiom = [[UIDevice currentDevice] userInterfaceIdiom];
    icon = [presentationManager alternateIconForActivityType:[self.activity.class activityType] idiom:idiom];
    if (icon == nil) {
        icon = self.activity.contentItem.alternateActivityIcon;
    }
    if (icon == nil) {
        icon = [self.activity.class iconForIdiom:[[UIDevice currentDevice] userInterfaceIdiom]];
    }
    [self.iconButton setBackgroundImage:icon forActivityType:[self.activity.class activityType] displayString:name];
    
    [self setShowBadge:![self.activity isAlreadyPurchased]];
}

- (void)setHighlighted:(BOOL)highlighted {
    [super setHighlighted:highlighted];
    [self.iconButton setHighlighted:highlighted];
    [_purchaseBadge setHighlighted:highlighted];
}

- (void)setAttributedText:(NSAttributedString *)attributedText {
    _attributedText = attributedText.copy;
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect {
    CGRect textRect = ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPad)
                        ? OSKActivityCollectionViewCellLabelRect_Pad
                        : OSKActivityCollectionViewCellLabelRect_Phone;
    [self.attributedText drawWithRect:textRect options:NSStringDrawingUsesLineFragmentOrigin context:nil];
}

- (void)setShowBadge:(BOOL)showBadge {
    if (_showBadge != showBadge) {
        _showBadge = showBadge;
        if (_showBadge == NO) {
            [_purchaseBadge setHidden:YES];
        }
        else {
            if (_purchaseBadge == nil) {
                _purchaseBadge = [UIButton buttonWithType:UIButtonTypeCustom];
                CGFloat width;
                UIImage *badgeImage = nil;
                if ([[UIDevice currentDevice] userInterfaceIdiom] == UIUserInterfaceIdiomPhone) {
                    width = OSKActivityIconBadgeWidth_Phone;
                    badgeImage = [UIImage imageNamed:@"osk-iap-badge-60.png"];
                } else {
                    width = OSKActivityIconBadgeWidth_Pad;
                    badgeImage = [UIImage imageNamed:@"osk-iap-badge-76.png"];
                }
                _purchaseBadge.frame = CGRectMake(0, 0, width, width);
                _purchaseBadge.center = self.iconButton.center;
                [self addSubview:_purchaseBadge];
                [_purchaseBadge setBackgroundImage:badgeImage forState:UIControlStateNormal];
                [_purchaseBadge setUserInteractionEnabled:NO]; // We use a button so highlighting matches the icon's highlighting
            }
            [_purchaseBadge setHidden:NO];
        }
    }
}

- (void)addPurchaseNotificationObservation {
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activitiesWerePurchased:) name:OSKActivitiesManagerDidMarkActivityTypesAsPurchasedNotification object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(activitiesWereUnpurchased:) name:OSKActivitiesManagerDidMarkActivityTypesAsUnpurchasedNotification object:nil];
}

- (void)removePurchaseNotificationObservation {
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OSKActivitiesManagerDidMarkActivityTypesAsPurchasedNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:OSKActivitiesManagerDidMarkActivityTypesAsUnpurchasedNotification object:nil];
}

- (void)activitiesWerePurchased:(NSNotification *)notification {
    [self setShowBadge:![self.activity isAlreadyPurchased]];
}

- (void)activitiesWereUnpurchased:(NSNotification *)notification {
    [self setShowBadge:![self.activity isAlreadyPurchased]];
}

@end








