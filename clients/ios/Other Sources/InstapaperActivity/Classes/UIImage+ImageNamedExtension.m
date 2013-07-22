//
//  UIImage+ImageNamedExtension.m
//  InstapaperActivity
//
//  http://stackoverflow.com/questions/4754551/iphone-use-external-image-in-uiimage-imagenamed
//

#import "UIImage+ImageNamedExtension.h"

@implementation UIImage (ImageNamedExtension)

+ (UIImage *)imageNamed:(NSString *)name fromDirectory:(NSString *)directory {
	NSString      *name2x      = [name stringByReplacingOccurrencesOfString:[NSString stringWithFormat:@".%@", [name pathExtension]] withString:[NSString stringWithFormat:@"@2x.%@", [name pathExtension]]];
	NSString      *path        = [directory stringByAppendingPathComponent:name];
	NSString      *path2x      = [directory stringByAppendingPathComponent:name2x];
	NSFileManager *fileManager = [NSFileManager defaultManager];
	
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] && [[UIScreen mainScreen] scale] == 2.0) {
		if ([fileManager fileExistsAtPath:path2x]) {
			return [UIImage imageWithContentsOfFile:path2x];
		}
	}
	
	return ([fileManager fileExistsAtPath:path]) ? [UIImage imageWithContentsOfFile:path] : nil;
}

@end
