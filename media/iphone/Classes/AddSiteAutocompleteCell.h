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
}

@property (nonatomic, retain) IBOutlet UILabel *feedTitle;
@property (nonatomic, retain) IBOutlet UILabel *feedUrl;
@property (nonatomic, retain) IBOutlet UILabel *feedSubs;

@end
