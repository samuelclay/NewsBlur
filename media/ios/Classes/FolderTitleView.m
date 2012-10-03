//
//  FolderTitleView.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/2/12.
//  Copyright (c) 2012 NewsBlur. All rights reserved.
//

#import "NewsBlurAppDelegate.h"
#import "FolderTitleView.h"

@implementation FolderTitleView

@synthesize appDelegate;

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        
    }
    return self;
}

- (UIControl *)drawWithRect:(CGRect)rect inSection:(NSInteger)section {
    
    self.appDelegate = (NewsBlurAppDelegate *)[[UIApplication sharedApplication] delegate];
    NSUserDefaults *userPreferences = [NSUserDefaults standardUserDefaults];

    NSString *folderName;
    if (section == 0) {
        folderName = @"river_blurblogs";
    } else {
        folderName = [appDelegate.dictFoldersArray objectAtIndex:section];
    }
    NSString *collapseKey = [NSString stringWithFormat:@"folderCollapsed:%@", folderName];
    bool isFolderCollapsed = [userPreferences boolForKey:collapseKey];
    
    // create the parent view that will hold header Label
    UIControl* customView = [[UIControl alloc]
                             initWithFrame:rect];
    UIView *borderTop = [[UIView alloc]
                         initWithFrame:CGRectMake(rect.origin.x, rect.origin.y,
                                                  rect.size.width, 1.0)];
    borderTop.backgroundColor = UIColorFromRGB(0xe0e0e0);
    borderTop.opaque = NO;
    [customView addSubview:borderTop];
    
    
    UIView *borderBottom = [[UIView alloc]
                            initWithFrame:CGRectMake(rect.origin.x, rect.size.height-1,
                                                     rect.size.width, 1.0)];
    borderBottom.backgroundColor = [UIColorFromRGB(0xB7BDC6) colorWithAlphaComponent:0.5];
    borderBottom.opaque = NO;
    [customView addSubview:borderBottom];
    
    UILabel * headerLabel = [[UILabel alloc] initWithFrame:CGRectZero];
    customView.opaque = NO;
    headerLabel.backgroundColor = [UIColor clearColor];
    headerLabel.opaque = NO;
    headerLabel.textColor = [UIColor colorWithRed:0.3 green:0.3 blue:0.3 alpha:1.0];
    headerLabel.highlightedTextColor = [UIColor whiteColor];
    headerLabel.font = [UIFont boldSystemFontOfSize:11];
    headerLabel.frame = CGRectMake(36.0, 1.0, rect.size.width - 36, rect.size.height);
    headerLabel.shadowColor = [UIColor colorWithRed:.94 green:0.94 blue:0.97 alpha:1.0];
    headerLabel.shadowOffset = CGSizeMake(0.0, 1.0);
    if (section == 0) {
        headerLabel.text = @"ALL BLURBLOG STORIES";
        //        customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
        //                                      colorWithAlphaComponent:0.8];
    } else if (section == 1) {
        headerLabel.text = @"ALL STORIES";
        //        customView.backgroundColor = [UIColorFromRGB(0xE6DDD7)
        //                                      colorWithAlphaComponent:0.8];
    } else {
        headerLabel.text = [[appDelegate.dictFoldersArray objectAtIndex:section] uppercaseString];
        //        customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
        //                                      colorWithAlphaComponent:0.8];
    }
    
    customView.backgroundColor = [UIColorFromRGB(0xD7DDE6)
                                  colorWithAlphaComponent:0.8];
    [customView addSubview:headerLabel];
    
    UIButton *invisibleHeaderButton = [UIButton buttonWithType:UIButtonTypeCustom];
    invisibleHeaderButton.frame = CGRectMake(0, 0, customView.frame.size.width, customView.frame.size.height);
    invisibleHeaderButton.alpha = .1;
    invisibleHeaderButton.tag = section;
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(didSelectSectionHeader:) forControlEvents:UIControlEventTouchUpInside];
    [customView addSubview:invisibleHeaderButton];
    
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(sectionTapped:) forControlEvents:UIControlEventTouchDown];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(sectionUntapped:) forControlEvents:UIControlEventTouchUpInside];
    [invisibleHeaderButton addTarget:appDelegate.feedsViewController action:@selector(sectionUntappedOutside:) forControlEvents:UIControlEventTouchUpOutside];
    
    if (!appDelegate.hasNoSites) {
        if (section != 1) {
            UIImage *disclosureBorder = [UIImage imageNamed:@"disclosure_border.png"];
            UIImageView *disclosureBorderView = [[UIImageView alloc] initWithImage:disclosureBorder];
            disclosureBorderView.frame = CGRectMake(customView.frame.size.width - 30, -1, 29, 29);
            [customView addSubview:disclosureBorderView];
        }
        
        UIButton *disclosureButton = [UIButton buttonWithType:UIButtonTypeCustom];
        UIImage *disclosureImage = [UIImage imageNamed:@"disclosure.png"];
        [disclosureButton setImage:disclosureImage forState:UIControlStateNormal];
        disclosureButton.frame = CGRectMake(customView.frame.size.width - 30, -1, 29, 29);
        if (section != 1) {
            if (!isFolderCollapsed) {
                disclosureButton.transform = CGAffineTransformMakeRotation(M_PI_2);
            }
            
            disclosureButton.tag = section;
            [disclosureButton addTarget:appDelegate.feedsViewController action:@selector(didCollapseFolder:) forControlEvents:UIControlEventTouchUpInside];
        }
        [customView addSubview:disclosureButton];
    }
    
    UIImage *folderImage;
    int folderImageViewX = 10;
    
    if (section == 0) {
        folderImage = [UIImage imageNamed:@"group.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 8;
        }
    } else if (section == 1) {
        folderImage = [UIImage imageNamed:@"archive.png"];
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
            folderImageViewX = 10;
        } else {
            folderImageViewX = 7;
        }
    } else {
        if (isFolderCollapsed) {
            folderImage = [UIImage imageNamed:@"folder_collapsed.png"];
        } else {
            folderImage = [UIImage imageNamed:@"folder_2.png"];
        }
        if (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad) {
        } else {
            folderImageViewX = 7;
        }
    }
    UIImageView *folderImageView = [[UIImageView alloc] initWithImage:folderImage];
    folderImageView.frame = CGRectMake(folderImageViewX, 3, 20, 20);
    [customView addSubview:folderImageView];
    
    [customView setAutoresizingMask:UIViewAutoresizingNone];
    
    return customView;
}

@end
