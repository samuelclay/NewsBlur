//
//  NSHTTPURLResponse+OSKUtilities.h
//  Overshare
//
//  Created by Jared Sinclair on 10/28/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

@interface NSHTTPURLResponse (OSKUtilities)

+ (BOOL)statusCodeAcceptableForResponse:(NSURLResponse *)response;
+ (BOOL)statusCodeAcceptableForResponse:(NSURLResponse *)response otherAcceptableCodes:(NSIndexSet *)otherCodes;

@end
