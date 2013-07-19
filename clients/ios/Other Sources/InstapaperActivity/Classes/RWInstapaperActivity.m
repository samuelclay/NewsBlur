//
//  RWInstapaperActivity.m
//  InstapaperActivity
//
//  Created by Justin Ridgewell on 2/27/13.
//
//

#import "RWInstapaperActivity.h"
#import "RWInstapaperActivityRequest.h"


#ifdef DEBUG
#   define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#   define DLog(...)
#endif

@interface RWInstapaperActivity ()

@property (strong, nonatomic) NSArray *validURLSchemes;
@property (strong, nonatomic) NSMutableArray *activityItems;
@property (strong, nonatomic) RWInstapaperActivityRequest *request;
- (ZYInstapaperActivityItem *)canPerformWithActivityItem:(id)item;

@end


@implementation RWInstapaperActivity

- (instancetype)init {
    if (self = [super init]) {
		self.activityItems = [NSMutableArray array];
		self.validURLSchemes = @[@"http", @"https"];
    }
    return self;
}

+ (instancetype)instance {
    static dispatch_once_t pred = 0;
    __strong static id _instance = nil;
    
    dispatch_once(&pred, ^{
        _instance = [[self alloc] init];
    });
    
    return _instance;
}

- (NSString *)activityType {
	return @"instapaper";
}

- (NSString *)activityTitle {
	return NSLocalizedString(@"Instapaper", @"");
}

- (UIImage *)activityImage {
    UIImage *image = [UIImage imageNamed:@"InstapaperActivityIcon.png"];
    
    return image;
}

- (BOOL)canPerformWithActivityItems:(NSArray *)activityItems {
	__block BOOL canPerform = NO;
	[activityItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if ([self canPerformWithActivityItem:obj]) {
            canPerform = YES;
            *stop = YES;
        }
    }];
	
	DLog("%i", canPerform);
	return canPerform;
}

- (ZYInstapaperActivityItem *)canPerformWithActivityItem:(id)item {
	//If it's a well formated URL string.
	if ([item isKindOfClass:[NSString class]] == YES) {
		DLog(@"NSString URL: %@", item);
		item = [NSURL URLWithString:item];
	}
	//If it's a non-empty URL.
	if ([item isKindOfClass:[NSURL class]] == YES) {
		DLog(@"NSURL: %@", [item absoluteString]);
		NSString *scheme = [item scheme];
		DLog(@"Scheme: %@", scheme);
		if ([self.validURLSchemes containsObject:scheme]) {
			item = [[ZYInstapaperActivityItem alloc] initWithURL:item];
		}
	}
	DLog(@"%@", item);

	//If it's an InstapaperActivityItem (internal, non-empty URL is guaranteed).
	if ([item isKindOfClass:[ZYInstapaperActivityItem class]] == YES) {
		return item;
	}
	
	return nil;
}

- (void)prepareWithActivityItems:(NSArray *)activityItems {
	[activityItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		ZYInstapaperActivityItem *item = [self canPerformWithActivityItem:obj];
        if (item) {
            [self.activityItems addObject:item];
        }
    }];
	DLog(@"%@", self.activityItems);
}

- (void)performActivity {

	[self.activityItems enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
		ZYInstapaperActivityItem *item = (ZYInstapaperActivityItem *)obj;
		DLog(@"%@", item);
		self.request = [[RWInstapaperActivityRequest alloc] initWithItem:item username:self.username password:self.password delegate:self];
    }];
}

#pragma mark - Protocols
#pragma mark ZYInstapaperAddRequestDelegate

- (void)instapaperAddRequestSucceded:(id)request {
	DLog();
	[self activityDidFinish:YES];
}

- (void)instapaperAddRequestFailed:(id)request {
	DLog();
	//TODO: This should really be a UIView...
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Failure", @"")
													message:NSLocalizedString(@"An unexpected error occured. Try again later.", @"")
												   delegate:nil
										  cancelButtonTitle:NSLocalizedString(@"OK", @"")
										  otherButtonTitles:nil];
	[alert show];
	[self activityDidFinish:NO];
}

- (void)instapaperAddRequestIncorrectPassword:(id)request {
	DLog();
	//TODO: This should really be a UIView...
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:NSLocalizedString(@"Error", @"")
													message:NSLocalizedString(@"Incorrect password. Please fix in Preferences.", @"")
												   delegate:nil
										  cancelButtonTitle:NSLocalizedString(@"OK", @"")
										  otherButtonTitles:nil];
	[alert show];
	[self activityDidFinish:NO];
}


@end
