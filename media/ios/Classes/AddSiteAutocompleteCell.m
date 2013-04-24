//
//  AddSiteAutocompleteCell.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/12/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//

#import "AddSiteAutocompleteCell.h"

@implementation AddSiteAutocompleteCell

@synthesize feedTitle;
@synthesize feedUrl;
@synthesize feedSubs;
@synthesize feedFavicon;

- (id)initWithStyle:(UITableViewCellStyle)style 
    reuseIdentifier:(NSString *)reuseIdentifier {
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) {
        // Initialization code
    }
    return self;
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {
    
    [super setSelected:selected animated:animated];
}




@end
