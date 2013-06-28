//
//  Base64.h
//  NewsBlur
//
//  Created by Samuel Clay on 8/3/11.
//  Copyright 2011 NewsBlur. All rights reserved.
//



@interface NSData (MBBase64)

+ (id)dataWithBase64EncodedString:(NSString *)string;     //  Padding '=' characters are optional. Whitespace is ignored.
- (NSString *)base64Encoding;
@end
