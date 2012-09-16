//
//  SHKTumblr.h
//  ShareKit
//
//  Created by Jamie Pinkham on 7/10/10.
//  Copyright 2010 Mobelux. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "SHKSharer.h"

@interface SHKTumblr : SHKSharer {
    //for photo posts
    NSMutableData *data;
    NSHTTPURLResponse *response;
}

@end
