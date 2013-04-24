//
//  AddSiteAutocompleteCell.h
//  NewsBlur
//
//  Created by Samuel Clay on 10/12/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface AddSiteAutocompleteCell : UITableViewCell {
    UILabel *feedTitle;
    UILabel *feedUrl;
    UILabel *feedSubs;
    UIImageView *feedFavicon;
}

@property (nonatomic) IBOutlet UILabel *feedTitle;
@property (nonatomic) IBOutlet UILabel *feedUrl;
@property (nonatomic) IBOutlet UILabel *feedSubs;
@property (nonatomic) IBOutlet UIImageView *feedFavicon;

@end
