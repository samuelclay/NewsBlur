//
//  IASKSettingsStoreFile.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2010:
//  Luc Vandal, Edovia Inc., http://www.edovia.com
//  Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//  Marc-Etienne M.Léveillé, Edovia Inc., http://www.edovia.com
//  All rights reserved.
// 
//  It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz, 
//  as the original authors of this code. You can give credit in a blog post, a tweet or on 
//  a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//  This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import "IASKSettingsStoreFile.h"

@interface IASKSettingsStoreFile() {
    NSMutableDictionary * _dict;
}

@property (nonatomic, retain, readwrite) NSString* filePath;

@end

@implementation IASKSettingsStoreFile

- (id)initWithPath:(NSString*)path {
    if((self = [super init])) {
        _filePath = [path retain];
        _dict = [[NSMutableDictionary alloc] initWithContentsOfFile:path];
        if(_dict == nil) {
            _dict = [[NSMutableDictionary alloc] init];
        }
    }
    return self;
}

- (void)dealloc {
    [_dict release], _dict = nil;
    [_filePath release], _filePath = nil;

    [super dealloc];
}

- (void)setObject:(id)value forKey:(NSString *)key {
    [_dict setObject:value forKey:key];
}

- (id)objectForKey:(NSString *)key {
    return [_dict objectForKey:key];
}

- (BOOL)synchronize {
    return [_dict writeToFile:_filePath atomically:YES];
}

@end
