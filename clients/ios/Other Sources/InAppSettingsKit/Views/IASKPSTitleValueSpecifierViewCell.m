//
//  IASKPSTitleValueSpecifierViewCell.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2010:
//  Luc Vandal, Edovia Inc., http://www.edovia.com
//  Ortwin Gentz, FutureTap GmbH, http://www.futuretap.com
//  All rights reserved.
// 
//  It is appreciated but not required that you give credit to Luc Vandal and Ortwin Gentz, 
//  as the original authors of this code. You can give credit in a blog post, a tweet or on 
//  a info page of your app. Also, the original authors appreciate letting them know if you use this code.
//
//  This code is licensed under the BSD license that is available at: http://www.opensource.org/licenses/bsd-license.php
//

#import "IASKPSTitleValueSpecifierViewCell.h"
#import "IASKSettingsReader.h"


@implementation IASKPSTitleValueSpecifierViewCell

- (void)layoutSubviews {
	[super layoutSubviews];
	
	CGSize viewSize =  [self.textLabel superview].frame.size;

	// if there's an image, make room for it
	CGFloat imageOffset = floor(self.imageView.image ? self.imageView.bounds.size.width + self.imageView.frame.origin.x : 0);
  
	// set the left title label frame
	CGFloat labelWidth = [self.textLabel sizeThatFits:CGSizeZero].width;
	CGFloat minValueWidth = (self.detailTextLabel.text.length) ? kIASKMinValueWidth + kIASKSpacing : 0;
	labelWidth = MIN(labelWidth, viewSize.width - minValueWidth - kIASKPaddingLeft -kIASKPaddingRight - imageOffset);
	CGRect labelFrame = CGRectMake(kIASKPaddingLeft + imageOffset, 0, labelWidth, viewSize.height -2);
	if (!self.detailTextLabel.text.length) {
		labelFrame = CGRectMake(kIASKPaddingLeft + imageOffset, 0, viewSize.width - kIASKPaddingLeft - kIASKPaddingRight - imageOffset, viewSize.height -2);
	}
	self.textLabel.frame = labelFrame;
	
	// set the right value label frame
	if (!self.textLabel.text.length) {
		viewSize =  [self.detailTextLabel superview].frame.size;
		self.detailTextLabel.frame = CGRectMake(kIASKPaddingLeft + imageOffset, 0, viewSize.width - kIASKPaddingLeft - kIASKPaddingRight - imageOffset, viewSize.height -2);
	} else if (self.detailTextLabel.textAlignment == NSTextAlignmentLeft) {
		CGRect valueFrame = self.detailTextLabel.frame;
		valueFrame.origin.x = labelFrame.origin.x + MAX(kIASKMinLabelWidth - imageOffset, labelWidth) + kIASKSpacing;
		valueFrame.size.width = self.detailTextLabel.superview.frame.size.width - valueFrame.origin.x - kIASKPaddingRight;
		self.detailTextLabel.frame = valueFrame;
	}
}

@end
