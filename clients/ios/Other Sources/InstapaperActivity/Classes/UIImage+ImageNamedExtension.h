//
//  UIImage+ImageNamedExtension.h
//  InstapaperActivity
//
//  http://stackoverflow.com/questions/4754551/iphone-use-external-image-in-uiimage-imagenamed
//

#import <UIKit/UIKit.h>

@interface UIImage (ImageNamedExtension)

+ (UIImage *)imageNamed:(NSString *)name fromDirectory:(NSString *)directory;

@end
