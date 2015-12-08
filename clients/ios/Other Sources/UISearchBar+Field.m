//
//  UISearchBar+Field.m
//  NewsBlur
//
//  Created by David Sinclair on 2015-12-04.
//  Copyright © 2015 NewsBlur. All rights reserved.
//

#import "UISearchBar+Field.h"

@implementation UISearchBar (Field)

- (UITextField *)nb_searchField {
    return [self nb_searchFieldForView:self];
}

- (UITextField *)nb_searchFieldForView:(UIView *)view {
    if ([view isKindOfClass:[UITextField class]])
    {
        return (UITextField *)view;
    }
    
    for (UIView *subview in view.subviews)
    {
        UITextField *field = [self nb_searchFieldForView:subview];
        
        if (field) {
            return field;
        }
    }
    
    return nil;
}

@end
