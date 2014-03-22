//
//  OSKActivityCollectionViewCell.h
//  Overshare
//
//  Created by Jared Sinclair on 10/13/13.
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

@import UIKit;

@class OSKActivity;

extern NSString * const OSKActivityCollectionViewCellIdentifier;
extern CGSize const OSKActivityCollectionViewCellSize_Phone;
extern CGSize const OSKActivityCollectionViewCellSize_Pad;

@interface OSKActivityCollectionViewCell : UICollectionViewCell

@property (strong, nonatomic) OSKActivity *activity;

@end
