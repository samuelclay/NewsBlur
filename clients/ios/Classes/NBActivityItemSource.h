//
//  NBActivityItemSource.h
//  NewsBlur
//
//  Created by Samuel Clay on 12/15/14.
//  Copyright (c) 2014 NewsBlur. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface NBActivityItemSource : NSObject <UIActivityItemSource> {
    NSURL *url;
    NSString *authorName;
    NSString *text;
    NSString *title;
    NSString *feedTitle;
}

- (instancetype)initWithUrl:(NSURL *)url
                 authorName:(NSString *)authorName
                       text:(NSString *)text
                      title:(NSString *)title
                  feedTitle:(NSString *)feedTitle;
@end
