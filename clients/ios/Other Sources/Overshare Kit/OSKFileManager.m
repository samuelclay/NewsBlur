//
//  OSKFileManager.m
//  Overshare
//
//  Created by Jared Sinclair on 10/10/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKFileManager.h"

#import "OSKLogger.h"

static NSString * OSKFileManagerRootFilePath = @"OvershareKit";

@interface OSKFileManager ()

@property (strong, nonatomic) NSFileManager *fileManager;
@property (strong, nonatomic) NSOperationQueue *diskOperationQueue;

@end

@implementation OSKFileManager

+ (id)sharedInstance {
    static dispatch_once_t once;
    static OSKFileManager * sharedInstance;
    dispatch_once(&once, ^ { sharedInstance = [[self alloc] init]; });
    return sharedInstance;
}

- (id)init {
    self = [super init];
    if (self) {
        _fileManager = [[NSFileManager alloc] init];
        _diskOperationQueue = [[NSOperationQueue alloc] init];
        _diskOperationQueue.maxConcurrentOperationCount = 1;
    }
    return self;
}

#pragma mark - Main

- (id)loadSavedObjectForKey:(NSString *)key {
    id object = nil;
    object = [self unarchiveObjectWithFilename:[self dataPathWithFilename:key]];
    return object;
}

- (void)saveObject:(id <NSSecureCoding, NSCopying>)object forKey:(NSString *)key completion:(void (^)(void))completion completionQueue:(dispatch_queue_t)queue {
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self.diskOperationQueue cancelAllOperations];
    }];
    
    id <NSSecureCoding, NSCopying> copiedObject = [object copyWithZone:nil];
    
    [self.diskOperationQueue addOperationWithBlock:^{
        [self archiveObject:copiedObject withFilename:[self dataPathWithFilename:key]];
        if (completion) {
            dispatch_async(queue, ^{
                completion();
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            });
        }
        else {
            dispatch_async(dispatch_get_main_queue(), ^{
               [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
            });
        }
    }];
}

- (void)deleteSavedObjectForKey:(NSString *)key completion:(void (^)(void))completion completionQueue:(dispatch_queue_t)queue {
    UIBackgroundTaskIdentifier backgroundTaskIdentifier = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:^{
        [self.diskOperationQueue cancelAllOperations];
    }];
    
    [self.diskOperationQueue addOperationWithBlock:^{
        @try {
            NSString *path = [self dataPathWithFilename:key];
            BOOL exists = [self.fileManager fileExistsAtPath:path];
            if (exists == YES) {
                [self.fileManager removeItemAtPath:path error:nil];
            }
        }
        @catch (NSException *exception) {
            OSKLog(@"%@", exception);
        }
        @finally {
            if (completion) {
                dispatch_async(queue, ^{
                    completion();
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                    });
                });
            } else {
                dispatch_async(dispatch_get_main_queue(), ^{
                    [[UIApplication sharedApplication] endBackgroundTask:backgroundTaskIdentifier];
                });
            }
        }
    }];
}

#pragma mark - Convenience

- (BOOL)archiveObject:(id)object withFilename:(NSString *)filename {
    BOOL success = NO;
    @try {
        success = [NSKeyedArchiver archiveRootObject:object toFile:filename];
    }
    @catch (NSException *exception) {
        OSKLog(@"%@", exception);
    }
    return success;
}

- (id)unarchiveObjectWithFilename:(NSString *)filename {
    id object = nil;
    @try {
        object = [NSKeyedUnarchiver unarchiveObjectWithFile:filename];
    }
    @catch (NSException *exception) {
        OSKLog(@"%@", exception);
    }
    return object;
}

- (NSString *)dataPathWithFilename:(NSString *)filename {
    NSString *libraryPath = NSSearchPathForDirectoriesInDomains(NSLibraryDirectory, NSUserDomainMask, YES)[0];
    NSString *dataPath = [libraryPath stringByAppendingPathComponent:OSKFileManagerRootFilePath];
    if ([self.fileManager fileExistsAtPath:dataPath] == NO) {
        [self.fileManager createDirectoryAtPath:dataPath withIntermediateDirectories:YES attributes:nil error:NULL];
    }
    NSString *filePath = [dataPath stringByAppendingPathComponent:filename];
    return filePath;
}

@end




