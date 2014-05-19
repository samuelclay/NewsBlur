//
//  OSKApplicationCredential.m
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKApplicationCredential.h"

@interface OSKApplicationCredential ()

@property (copy, nonatomic, readwrite) NSString *applicationKey;
@property (copy, nonatomic, readwrite) NSString *applicationSecret;
@property (copy, nonatomic, readwrite) NSString *appName;

@end

@implementation OSKApplicationCredential

- (instancetype)initWithOvershareApplicationKey:(NSString *)applicationKey applicationSecret:(NSString *)applicationSecret appName:(NSString *)appName {
    self = [super init];
    if (self) {
        _applicationKey = [applicationKey copy];
        _applicationSecret = [applicationSecret copy];
        _appName = [appName copy];
    }
    return self;
}

@end




