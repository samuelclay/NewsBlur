//
//  IASKPSSliderSpecifierViewCell.m
//  http://www.inappsettingskit.com
//
//  Copyright (c) 2009-2010:
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

#import "IASKPSSliderSpecifierViewCell.h"
#import "IASKSlider.h"
#import "IASKSettingsReader.h"

@implementation IASKPSSliderSpecifierViewCell

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier
{
    self = [super initWithStyle:style reuseIdentifier:reuseIdentifier];
    if (self) {
        // Setting only frame data that will not be overwritten by layoutSubviews
        // Slider
        _slider = [[IASKSlider alloc] initWithFrame:CGRectMake(0, 0, 0, 23)];
        _slider.autoresizingMask = UIViewAutoresizingFlexibleBottomMargin |
        UIViewAutoresizingFlexibleWidth;
        _slider.continuous = NO;
        [self.contentView addSubview:_slider];

        // MinImage
        _minImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 21, 21)];
        _minImage.autoresizingMask = UIViewAutoresizingFlexibleRightMargin |
        UIViewAutoresizingFlexibleBottomMargin;
        [self.contentView addSubview:_minImage];

        // MaxImage
        _maxImage = [[UIImageView alloc] initWithFrame:CGRectMake(0, 0, 21, 21)];
        _maxImage.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
        UIViewAutoresizingFlexibleBottomMargin;
        [self.contentView addSubview:_maxImage];

        self.selectionStyle = UITableViewCellSelectionStyleNone;
    }
    return self;
}

- (void)layoutSubviews {
    [super layoutSubviews];
	CGRect  sliderBounds    = _slider.bounds;
    CGPoint sliderCenter    = _slider.center;
    const CGFloat superViewWidth = _slider.superview.frame.size.width;
    
    sliderCenter.x = superViewWidth / 2;
    sliderCenter.y = self.contentView.center.y;
    sliderBounds.size.width = superViewWidth - kIASKSliderNoImagesPadding * 2;
	_minImage.hidden = YES;
	_maxImage.hidden = YES;

	// Check if there are min and max images. If so, change the layout accordingly.
	if (_minImage.image) {
		// Min image
		_minImage.hidden = NO;
		sliderCenter.x    += (kIASKSliderImagesPadding - kIASKSliderNoImagesPadding) / 2;
		sliderBounds.size.width  -= (kIASKSliderImagesPadding - kIASKSliderNoImagesPadding);
        _minImage.center = CGPointMake(_minImage.frame.size.width / 2 + kIASKPaddingLeft,
                                       self.contentView.center.y);
    }
	if (_maxImage.image) {
		// Max image
		_maxImage.hidden = NO;
		sliderCenter.x    -= (kIASKSliderImagesPadding - kIASKSliderNoImagesPadding) / 2;
		sliderBounds.size.width  -= (kIASKSliderImagesPadding - kIASKSliderNoImagesPadding);
        _maxImage.center = CGPointMake(self.contentView.bounds.size.width - _maxImage.frame.size.width / 2 - kIASKPaddingRight,
                                       self.contentView.center.y);
	}
	
	_slider.bounds = sliderBounds;
    _slider.center = sliderCenter;
}	

- (void)prepareForReuse {
	_minImage.image = nil;
	_maxImage.image = nil;
}
@end
