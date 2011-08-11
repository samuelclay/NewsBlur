//
//  UIImageAdditions.m
//  Created by Devin Ross on 7/25/09.
//
/*
 
 tapku.com || http://github.com/devinross/tapkulibrary
 
 Permission is hereby granted, free of charge, to any person
 obtaining a copy of this software and associated documentation
 files (the "Software"), to deal in the Software without
 restriction, including without limitation the rights to use,
 copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the
 Software is furnished to do so, subject to the following
 conditions:
 
 The above copyright notice and this permission notice shall be
 included in all copies or substantial portions of the Software.
 
 THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 OTHER DEALINGS IN THE SOFTWARE.
 
 */

#import "UIImage+TKCategory.h"
#import "UIView+TKCategory.h"

@implementation UIImage (TKCategory)

- (UIImage *) imageCroppedToRect:(CGRect)rect{
	CGImageRef imageRef = CGImageCreateWithImageInRect([self CGImage], rect);
	UIImage *cropped = [UIImage imageWithCGImage:imageRef];
	CGImageRelease(imageRef);
	return cropped; // autoreleased
}

- (UIImage *) squareImage{
	CGFloat shortestSide = self.size.width <= self.size.height ? self.size.width : self.size.height;	
	return [self imageCroppedToRect:CGRectMake(0.0, 0.0, shortestSide, shortestSide)];
}




- (void) drawInRect:(CGRect)rect withImageMask:(UIImage*)mask{
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGContextSaveGState(context);
	
	CGContextTranslateCTM(context, 0.0, rect.size.height);
	CGContextScaleCTM(context, 1.0, -1.0);
	
	rect.origin.y = rect.origin.y * -1;
	
	CGContextClipToMask(context, rect, mask.CGImage);
	//CGContextSetRGBFillColor(context, color[0], color[1], color[2], color[3]);
	//CGContextFillRect(context, rect);
	CGContextDrawImage(context,rect,self.CGImage);
	
	
	CGContextRestoreGState(context);
}

- (void) drawMaskedColorInRect:(CGRect)rect withColor:(UIColor*)color{
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);
	
	
	CGContextSetFillColorWithColor(context, color.CGColor);
	
	CGContextTranslateCTM(context, 0.0, rect.size.height);
	CGContextScaleCTM(context, 1.0, -1.0);
	rect.origin.y = rect.origin.y * -1;
	
	
	CGContextClipToMask(context, rect, self.CGImage);
	CGContextFillRect(context, rect);
	
	CGContextRestoreGState(context);
	
}
- (void) drawMaskedGradientInRect:(CGRect)rect withColors:(NSArray*)colors{
	
	CGContextRef context = UIGraphicsGetCurrentContext();
	CGContextSaveGState(context);

	CGContextTranslateCTM(context, 0.0, rect.size.height);
	CGContextScaleCTM(context, 1.0, -1.0);
	
	rect.origin.y = rect.origin.y * -1;
	
	CGContextClipToMask(context, rect, self.CGImage);
	
	[UIView drawGradientInRect:rect withColors:colors];
	
	CGContextRestoreGState(context);
}

@end
