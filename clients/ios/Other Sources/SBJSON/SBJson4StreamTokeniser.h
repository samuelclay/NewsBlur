//
// Created by SuperPappi on 09/01/2013.
//
// To change the template use AppCode | Preferences | File Templates.
//

#import <Foundation/Foundation.h>

typedef enum {
    sbjson4_token_error = -1,
    sbjson4_token_eof,

    sbjson4_token_array_open,
    sbjson4_token_array_close,
    sbjson4_token_value_sep,

    sbjson4_token_object_open,
    sbjson4_token_object_close,
    sbjson4_token_entry_sep,

    sbjson4_token_bool,
    sbjson4_token_null,

    sbjson4_token_integer,
    sbjson4_token_real,

    sbjson4_token_string,
    sbjson4_token_encoded,
} sbjson4_token_t;


@interface SBJson4StreamTokeniser : NSObject

@property (nonatomic, readonly, copy) NSString *error;

- (void)appendData:(NSData*)data_;
- (sbjson4_token_t)getToken:(char**)tok length:(NSUInteger*)len;

@end

