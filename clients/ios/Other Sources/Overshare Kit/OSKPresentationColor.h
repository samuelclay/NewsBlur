//
//  OSKPresentationColor.h
//  Overshare
//
//  Created by Jared Sinclair 10/31/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import Foundation;

///-----------------------------------------------
/// @name Presentation Color
///-----------------------------------------------

/**
 A protocol for overriding the default colors of Overshare's views.
 */
@protocol OSKPresentationColor <NSObject>
@optional

- (UIColor *)osk_color_activitySheetTopLine;
- (UIColor *)osk_color_opaqueBackground;
- (UIColor *)osk_color_translucentBackground;
- (UIColor *)osk_color_toolbarBackground;
- (UIColor *)osk_color_toolbarText;
- (UIColor *)osk_color_toolbarBorders;
- (UIColor *)osk_color_groupedTableViewBackground;
- (UIColor *)osk_color_groupedTableViewCells;
- (UIColor *)osk_color_separators;
- (UIColor *)osk_color_action;
- (UIColor *)osk_color_text;
- (UIColor *)osk_color_textViewBackground;
- (UIColor *)osk_color_pageIndicatorColor_current;
- (UIColor *)osk_color_pageIndicatorColor_other;
- (UIColor *)osk_color_cancelButtonColor_BackgroundHighlighted;
- (UIColor *)osk_color_hashtags;
- (UIColor *)osk_color_mentions;
- (UIColor *)osk_color_links;
- (UIColor *)osk_color_characterCounter_normal;
- (UIColor *)osk_color_characterCounter_warning;

@end
