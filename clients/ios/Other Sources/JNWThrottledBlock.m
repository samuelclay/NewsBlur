#import "JNWThrottledBlock.h"

@implementation JNWThrottledBlock

+ (NSMutableDictionary *)mappingsDictionary {
    static NSMutableDictionary *mappings = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mappings = [NSMutableDictionary dictionary];
    });
    
    return mappings;
}

+ (void)runBlock:(void (^)(void))block withIdentifier:(NSString *)identifier throttle:(CFTimeInterval)bufferTime {
    if (block == NULL || identifier == nil) {
        NSAssert(NO, @"block or identifier must not be nil");
    }

    dispatch_source_t source = self.mappingsDictionary[identifier];
    if (source != nil) {
//        dispatch_source_cancel(source); // This is a debounce, not a throttle
        return; // This is a throttle
    }

    source = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
    dispatch_source_set_timer(source, dispatch_time(DISPATCH_TIME_NOW, bufferTime * NSEC_PER_SEC), DISPATCH_TIME_FOREVER, 0);
    dispatch_source_set_event_handler(source, ^{
        block();
        dispatch_source_cancel(source);
        [self.mappingsDictionary removeObjectForKey:identifier];
    });
    dispatch_resume(source);

    self.mappingsDictionary[identifier] = source;
}

@end
