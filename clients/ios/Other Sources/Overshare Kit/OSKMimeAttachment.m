//
//  OSKMimeAttachment.m
//  OvershareKit
//
//  Created by Calman Steynberg on 2014-04-19.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

#import "OSKMimeAttachment.h"

@implementation OSKMimeAttachment

-(instancetype) initWithType:(NSString *)mimeType name:(NSString *)fileName data:(NSData *)data {
    self = [super init];
    if (self) {
        _mimeType = mimeType;
        _fileName = fileName;
        _data = data;
    }
    return self;
}

@end
