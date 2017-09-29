#import <Foundation/Foundation.h>

@interface JNWThrottledBlock : NSObject

// Runs the block after the buffer time _only_ if another call with the same identifier is not received 
// within the buffer time. If a new call is received within that time period the buffer will be reset.
// The block will be run on the main queue.
// 
// Identifier and block must not be nil.
+ (void)runBlock:(void (^)(void))block withIdentifier:(NSString *)identifier throttle:(CFTimeInterval)bufferTime;

@end
