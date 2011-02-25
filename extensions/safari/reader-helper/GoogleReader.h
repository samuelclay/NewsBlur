//
//  GoogleReader.h
//  Reader Helper
//
//  Created by Geoff Hulette on 7/28/08.
//  Copyright 2008 Collidescope. All rights reserved.
//
//  Based on the reader API documentation at http://www.niallkennedy.com/blog/2005/12/google-reader-api.html
//
//

#import <Cocoa/Cocoa.h>


@interface GoogleReader : NSObject {
}

+(void)subscribeToFeed:(NSString *)feedURL;

@end
