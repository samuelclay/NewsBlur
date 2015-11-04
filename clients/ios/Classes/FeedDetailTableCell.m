//
//  FeedDetailTableCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 7/14/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FeedDetailViewController.h"
#import "FeedDetailTableCell.h"
#import "DashboardViewController.h"
#import "ABTableViewCell.h"
#import "UIView+TKCategory.h"
#import "UIImageView+AFNetworking.h"
#import "Utilities.h"
#import "MCSwipeTableViewCell.h"
#import "TMCache.h"

static UIFont *textFont = nil;
static UIFont *indicatorFont = nil;

@class FeedDetailViewController;

@implementation FeedDetailTableCell

@synthesize storyTitle;
@synthesize storyAuthor;
@synthesize storyDate;
@synthesize storyContent;
@synthesize storyImageUrl;
@synthesize storyTimestamp;
@synthesize storyScore;
@synthesize storyImage;
@synthesize siteTitle;
@synthesize siteFavicon;
@synthesize isRead;
@synthesize isShared;
@synthesize isSaved;
@synthesize isShort;
@synthesize isRiverOrSocial;
@synthesize feedColorBar;
@synthesize feedColorBarTopBorder;
@synthesize hasAlpha;
@synthesize inDashboard;


#define leftMargin 30
#define rightMargin 18


+ (void) initialize {
    if (self == [FeedDetailTableCell class]) {
        textFont = [UIFont boldSystemFontOfSize:18];
        indicatorFont = [UIFont boldSystemFontOfSize:12];
    }
}

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier {
    if (self = [super initWithStyle:style reuseIdentifier:reuseIdentifier]) {
        cellContent = [[FeedDetailTableCellView alloc] initWithFrame:self.frame];
        cellContent.opaque = YES;
        self.isReadAvailable = YES;
        
        [self.contentView addSubview:cellContent];
    }
    
    return self;
}

- (void)drawRect:(CGRect)rect {
    ((FeedDetailTableCellView *)cellContent).cell = self;
    ((FeedDetailTableCellView *)cellContent).storyImage = nil;
    ((FeedDetailTableCellView *)cellContent).appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    cellContent.frame = rect;
    [cellContent setNeedsDisplay];
}

- (void)setupGestures {
    NSString *unreadIcon;
    if (storyScore == -1) {
        unreadIcon = @"g_icn_hidden.png";
    } else if (storyScore == 1) {
        unreadIcon = @"g_icn_focus.png";
    } else {
        unreadIcon = @"g_icn_unread.png";
    }
    
    UIColor *shareColor = self.isSaved ?
                            UIColorFromRGB(0xF69E89) :
                            UIColorFromRGB(0xA4D97B);
    UIColor *readColor = self.isRead ?
                            UIColorFromRGB(0xBED49F) :
                            UIColorFromRGB(0xFFFFD2);
    
    if (!self.isReadAvailable) {
        unreadIcon = nil;
        readColor = nil;
    }
    
    appDelegate = [NewsBlurAppDelegate sharedAppDelegate];
    if (inDashboard) {
        [self setDelegate:(FeedDetailViewController <MCSwipeTableViewCellDelegate> *)appDelegate.dashboardViewController.storiesModule];
    } else {
        [self setDelegate:(FeedDetailViewController <MCSwipeTableViewCellDelegate> *)appDelegate.feedDetailViewController];
    }
    [self setFirstStateIconName:@"clock.png"
                     firstColor:shareColor
            secondStateIconName:nil
                    secondColor:nil
                  thirdIconName:unreadIcon
                     thirdColor:readColor
                 fourthIconName:nil
                    fourthColor:nil];

    self.mode = MCSwipeTableViewCellModeSwitch;
    self.shouldAnimatesIcons = NO;
}


- (UIFontDescriptor *)fontDescriptorUsingPreferredSize:(NSString *)textStyle {
    UIFontDescriptor *fontDescriptor = appDelegate.fontDescriptorTitleSize;

    if (fontDescriptor) return fontDescriptor;
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];
    
    fontDescriptor = [UIFontDescriptor preferredFontDescriptorWithTextStyle:textStyle];
    if (![userPreferences boolForKey:@"use_system_font_size"]) {
        if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xs"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:11.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"small"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:12.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"medium"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:13.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"large"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:15.0f];
        } else if ([[userPreferences stringForKey:@"feed_list_font_size"] isEqualToString:@"xl"]) {
            fontDescriptor = [fontDescriptor fontDescriptorWithSize:17.0f];
        }
    }
    
    return fontDescriptor;
}

@end

@implementation FeedDetailTableCellView

@synthesize cell;
@synthesize storyImage;
@synthesize appDelegate;

- (void)drawRect:(CGRect)r {
    int riverPadding = 0;
    if (cell.isRiverOrSocial) {
        riverPadding = 20;
    }

    CGContextRef context = UIGraphicsGetCurrentContext();
    
    CGRect rect = CGRectInset(r, 12, 12);
    rect.size.width -= 18; // Scrollbar padding
    
    UIColor *backgroundColor;
    backgroundColor = cell.highlighted || cell.selected ?
                      UIColorFromRGB(0xFFFDEF) : UIColorFromRGB(0xf4f4f4);
    [backgroundColor set];
    
    CGContextFillRect(context, r);
    
    if (cell.storyImageUrl) {
        CGRect imageFrame = CGRectMake(r.size.width-r.size.height, 1,
                                       r.size.height, r.size.height);
        UIImageView *storyImageView = [[UIImageView alloc] initWithFrame:imageFrame];
        
        UIImage *cachedImage = (UIImage *)[appDelegate.cachedStoryImages objectForKey:cell.storyImageUrl];
        if (cachedImage && ![cachedImage isKindOfClass:[NSNull class]]) {
//            NSLog(@"Found cached image: %@", cell.storyTitle);
            storyImageView.image = cachedImage;
            [storyImageView setContentMode:UIViewContentModeScaleAspectFill];
            [storyImageView setClipsToBounds:YES];
            CGFloat alpha = 1.0f;
            if (cell.highlighted || cell.selected) {
                alpha = cell.isRead ? 0.5f : 0.85f;
            } else if (cell.isRead) {
                alpha = 0.34f;
            }
            [storyImageView.image drawInRect:imageFrame blendMode:Nil alpha:alpha];
            rect.size.width -= imageFrame.size.width;
        }
    }
    
    UIColor *textColor;
    UIFont *font;
    UIFontDescriptor *fontDescriptor = [cell fontDescriptorUsingPreferredSize:UIFontTextStyleCaption1];
    
    if (cell.isRead) {
        font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        textColor = UIColorFromRGB(0x808080);
    } else {
        UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];
        font = [UIFont fontWithDescriptor: boldFontDescriptor size:0.0];
        textColor = UIColorFromRGB(0x606060);
        
    }
    if (cell.highlighted || cell.selected) {
        textColor = UIColorFromRGB(0x686868);
    }
    
    NSMutableParagraphStyle *paragraphStyle = [[NSMutableParagraphStyle defaultParagraphStyle] mutableCopy];
    paragraphStyle.lineBreakMode = NSLineBreakByWordWrapping;
    paragraphStyle.alignment = NSTextAlignmentLeft;
    paragraphStyle.lineHeightMultiple = 0.95f;

    if (cell.isRiverOrSocial) {
        NSInteger siteTitleY = (20 - font.pointSize/2)/2;
        [cell.siteTitle drawInRect:CGRectMake(leftMargin + 20, siteTitleY, rect.size.width - 20, 20)
                    withAttributes:@{NSFontAttributeName: font,
                                     NSForegroundColorAttributeName: textColor,
                                     NSParagraphStyleAttributeName: paragraphStyle}];

        // site favicon
        if (cell.isRead && !cell.hasAlpha) {
            if (cell.isRiverOrSocial) {
                cell.siteFavicon = [cell imageByApplyingAlpha:cell.siteFavicon withAlpha:0.25];
            }
            cell.hasAlpha = YES;
        }

        [cell.siteFavicon drawInRect:CGRectMake(leftMargin, siteTitleY, 16.0, 16.0)];

        if (cell.isRead) {
            font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
            textColor = UIColorFromRGB(0x585858);
        } else {
            UIFontDescriptor *boldFontDescriptor = [fontDescriptor fontDescriptorWithSymbolicTraits: UIFontDescriptorTraitBold];
            font = [UIFont fontWithDescriptor: boldFontDescriptor size:0.0];
            textColor = UIColorFromRGB(0x333333);
        }
        if (cell.highlighted || cell.selected) {
            textColor = UIColorFromRGB(0x686868);
        }
    }
    
    // story title
    CGSize theSize = [cell.storyTitle
                      boundingRectWithSize:CGSizeMake(rect.size.width, cell.isShort ? font.pointSize*1.5 : font.pointSize*3)
                      options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                      attributes:@{NSFontAttributeName: font,
                                   NSParagraphStyleAttributeName: paragraphStyle}
                      context:nil].size;
    
    int storyTitleY = 14 + riverPadding + ((font.pointSize*2 - theSize.height)/2);
    if (cell.isShort) {
        storyTitleY = 14 + riverPadding - (theSize.height/font.pointSize*2);
    }
    int storyTitleX = leftMargin;
    if (cell.isSaved) {
        UIImage *savedIcon = [UIImage imageNamed:@"clock"];
        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:nil alpha:1];
        storyTitleX += 20;
    }
    if (cell.isShared) {
        UIImage *savedIcon = [UIImage imageNamed:@"menu_icn_share"];
        [savedIcon drawInRect:CGRectMake(storyTitleX, storyTitleY - 1, 16, 16) blendMode:nil alpha:1];
        storyTitleX += 20;
    }
    CGRect storyTitleFrame = CGRectMake(storyTitleX, storyTitleY,
                                        rect.size.width - storyTitleX + leftMargin, theSize.height);
    [cell.storyTitle drawWithRect:storyTitleFrame
                          options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                       attributes:@{NSFontAttributeName: font,
                                    NSForegroundColorAttributeName: textColor,
                                    NSParagraphStyleAttributeName: paragraphStyle}
                          context:nil];
    
    if (cell.storyContent) {
        int storyContentWidth = rect.size.width;
        if (cell.inDashboard) {
            storyContentWidth -= leftMargin*2;
        }
        CGSize contentSize = [cell.storyContent
                              boundingRectWithSize:CGSizeMake(storyContentWidth,
                                                              cell.isShort ? font.pointSize*1.5 : font.pointSize*3)
                              options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
                              attributes:@{NSFontAttributeName: font,
                                           NSParagraphStyleAttributeName: paragraphStyle}
                              context:nil].size;

        int storyContentY = r.size.height - 16 - 4 - ((font.pointSize*2 + font.lineHeight) + contentSize.height)/2;
        if (cell.isShort) {
            storyContentY = r.size.height - 10 - 4 - ((font.pointSize + font.lineHeight) + contentSize.height)/2;
        }
        
        if (cell.isRead) {
            textColor = UIColorFromRGB(0xB8B8B8);
            font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        } else {
            textColor = UIColorFromRGB(0x404040);
            font = [UIFont fontWithDescriptor:fontDescriptor size:0.0];
        }
        if (cell.highlighted || cell.selected) {
            if (cell.isRead) {
                textColor = UIColorFromRGB(0xB8B8B8);
            } else {
                textColor = UIColorFromRGB(0x686868);
            }
        }
        
        [cell.storyContent
         drawWithRect:CGRectMake(storyTitleX, storyContentY,
                                 rect.size.width - storyTitleX + leftMargin, contentSize.height)
         options:NSStringDrawingTruncatesLastVisibleLine|NSStringDrawingUsesLineFragmentOrigin
         attributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}
         context:nil];
    }
    
    // story date
    int storyAuthorDateY = r.size.height - 18;
    
    if (cell.isRead) {
        textColor = UIColorFromRGB(0xbabdd1);
        font = [UIFont fontWithName:@"Helvetica" size:10];
    } else {
        textColor = UIColorFromRGB(0x262c6c);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    }
    
    if (cell.highlighted || cell.selected) {
        if (cell.isRead) {
            textColor = UIColorFromRGB(0xaaadc1);
        } else {
            textColor = UIColorFromRGB(0x5a5d91);
        }
    }
    
    paragraphStyle.alignment = NSTextAlignmentRight;
    NSString *date = [Utilities formatShortDateFromTimestamp:cell.storyTimestamp];
    CGSize dateSize = [date sizeWithAttributes:@{NSFontAttributeName: font,
                                                 NSForegroundColorAttributeName: textColor,
                                                 NSParagraphStyleAttributeName: paragraphStyle}];
    [date
     drawInRect:CGRectMake(0, storyAuthorDateY, rect.size.width + leftMargin, 15.0)
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];
    
    // Story author
    if (cell.isRead) {
        textColor = UIColorFromRGB(0xB8B8B8);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    } else {
        textColor = UIColorFromRGB(0xA6A8A2);
        font = [UIFont fontWithName:@"Helvetica-Bold" size:10];
    }
    if (cell.highlighted || cell.selected) {
        if (cell.isRead) {
            textColor = UIColorFromRGB(0xA8A8A8);
        } else {
            textColor = UIColorFromRGB(0x959595);
        }
    }
    
    paragraphStyle.alignment = NSTextAlignmentLeft;
    [cell.storyAuthor
     drawInRect:CGRectMake(leftMargin, storyAuthorDateY, rect.size.width - dateSize.width - 12, 15.0)
     withAttributes:@{NSFontAttributeName: font,
                      NSForegroundColorAttributeName: textColor,
                      NSParagraphStyleAttributeName: paragraphStyle}];

    // feed bar
    CGContextSetStrokeColor(context, CGColorGetComponents([cell.feedColorBarTopBorder CGColor]));
    if (cell.isRead) {
        CGContextSetAlpha(context, 0.15);
    }
    CGContextSetLineWidth(context, 4.0f);
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 2.0f, 0);
    CGContextAddLineToPoint(context, 2.0f, cell.frame.size.height);
    CGContextStrokePath(context);
    
    CGContextSetStrokeColor(context, CGColorGetComponents([cell.feedColorBar CGColor]));
    CGContextBeginPath(context);
    CGContextMoveToPoint(context, 6.0f, 0);
    CGContextAddLineToPoint(context, 6.0, cell.frame.size.height);
    CGContextStrokePath(context);
    
    // reset for borders
    UIColor *white = UIColorFromRGB(0xffffff);
    CGContextSetAlpha(context, 1.0);
    if (cell.highlighted || cell.selected) {
        // top border
        CGContextSetStrokeColor(context, CGColorGetComponents([white CGColor]));
        
        CGContextSetLineWidth(context, 1.0f);
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 0.5f);
        CGContextAddLineToPoint(context, cell.bounds.size.width, 0.5f);
        CGContextStrokePath(context);
        
        CGFloat lineWidth = 0.5f;
        CGContextSetLineWidth(context, lineWidth);
        UIColor *blue = UIColorFromRGB(0xDFDDCF);
        
        CGContextSetStrokeColor(context, CGColorGetComponents([blue CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, 1.0f + 0.5f*lineWidth);
        CGContextAddLineToPoint(context, cell.bounds.size.width, 1.0f + 0.5f*lineWidth);
        CGContextStrokePath(context);
        
        // bottom border
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0, cell.bounds.size.height - .5f*lineWidth);
        CGContextAddLineToPoint(context, cell.bounds.size.width, cell.bounds.size.height - .5f*lineWidth);
        CGContextStrokePath(context);
    } else {
        // top border
        CGContextSetLineWidth(context, 1.0f);
        
        CGContextSetStrokeColor(context, CGColorGetComponents([white CGColor]));
        
        CGContextBeginPath(context);
        CGContextMoveToPoint(context, 0.0f, 0.5f);
        CGContextAddLineToPoint(context, cell.bounds.size.width, 0.5f);
        CGContextStrokePath(context);
    }
    
    // story indicator
    int storyIndicatorY = storyTitleFrame.origin.y + storyTitleFrame.size.height / 2;
    
    UIImage *unreadIcon;
    if (cell.storyScore == -1) {
        unreadIcon = [UIImage imageNamed:@"g_icn_hidden"];
    } else if (cell.storyScore == 1) {
        unreadIcon = [UIImage imageNamed:@"g_icn_focus"];
    } else {
        unreadIcon = [UIImage imageNamed:@"g_icn_unread"];
    }
    
    [unreadIcon drawInRect:CGRectMake(15, storyIndicatorY - 3, 8, 8) blendMode:nil alpha:(cell.isRead ? .15 : 1)];
}

@end