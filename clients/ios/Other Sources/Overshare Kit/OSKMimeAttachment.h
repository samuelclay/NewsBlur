//
//  OSKMimeAttachment.h
//  OvershareKit
//
//  Created by Calman Steynberg on 2014-04-19.
//  Copyright (c) 2014 Overshare Kit. All rights reserved.
//

@import Foundation;

/**
 `OSKMimeAttachment` is intended for use as in email messages only and allows arbitrary mime attachments.
 Add instances of it to OKSEmailContentItem attachment property.
*/

@interface OSKMimeAttachment : NSObject

@property (nonatomic, copy) NSString* mimeType;
@property (nonatomic, copy) NSString* fileName;
@property (nonatomic, strong) NSData* data;

-(instancetype) initWithType:(NSString *)mimeType name:(NSString *)fileName data:(NSData *)data;

@end
