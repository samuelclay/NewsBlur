//
//  SHKConfiguration.m
//  ShareKit
//
//  Created by Edward Dale on 10/16/10.

//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.
//
//

#import "SHKConfiguration.h"
#import "LegacySHKConfigurator.h"

@interface SHKConfiguration ()

@property (readonly, retain) DefaultSHKConfigurator *configurator;

- (id)initWithConfigurator:(DefaultSHKConfigurator*)config;

@end

static SHKConfiguration *sharedInstance = nil;

@implementation SHKConfiguration

@synthesize configurator;

#pragma mark -
#pragma mark Instance methods

- (id)configurationValue:(NSString*)selector withObject:(id)object
{
	SHKLog(@"Looking for a configuration value for %@.", selector);

	SEL sel = NSSelectorFromString(selector);
	if ([self.configurator respondsToSelector:sel]) {
		id value;        
        if (object) {
            value = [self.configurator performSelector:sel withObject:object];
        } else {
            value = [self.configurator performSelector:sel];
        }

		if (value) {
			SHKLog(@"Found configuration value for %@: %@", selector, [value description]);
			return value;
		}
	}

	SHKLog(@"Didn't find a configuration value for %@.", selector);
	return nil;
}

#pragma mark -
#pragma mark Singleton methods

// Singleton template based on http://stackoverflow.com/questions/145154

+ (SHKConfiguration*)sharedInstance
{
    @synchronized(self)
    {
        if (sharedInstance == nil) {
            DefaultSHKConfigurator *aConfigurator = [[LegacySHKConfigurator alloc] init];
			sharedInstance = [[SHKConfiguration alloc] initWithConfigurator:aConfigurator];
            [aConfigurator release];
        }
    }
    return sharedInstance;
}

+ (SHKConfiguration*)sharedInstanceWithConfigurator:(DefaultSHKConfigurator*)config
{
    @synchronized(self)
    {
		if (sharedInstance != nil) {
			[NSException raise:@"IllegalStateException" format:@"SHKConfiguration has already been configured with a delegate."];
		}
		sharedInstance = [[SHKConfiguration alloc] initWithConfigurator:config];
    }
    return sharedInstance;
}


+ (id)allocWithZone:(NSZone *)zone {
    @synchronized(self) {
        if (sharedInstance == nil) {
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

- (id)initWithConfigurator:(DefaultSHKConfigurator*)config
{
    if ((self = [super init])) {
		configurator = [config retain];
    }
    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain {
    return self;
}

- (unsigned)retainCount {
    return UINT_MAX;  // denotes an object that cannot be released
}

- (oneway void)release {
    //do nothing
}

- (id)autorelease {
    return self;
}

@end
