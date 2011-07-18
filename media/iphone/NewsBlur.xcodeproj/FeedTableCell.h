//
//  FeedTableCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 7/18/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface FeedTableCell : UITableViewCell {
    UILabel *feedTitle;
    UIImageView *feedFavicon;
    UIWebView *feedUnreadView;
}

@property (nonatomic, retain) IBOutlet UILabel *feedTitle;
@property (nonatomic, retain) IBOutlet UIImageView *feedFavicon;
@property (nonatomic, retain) IBOutlet UIWebView *feedUnreadView;

@end
