//
//  VUPinboardViewController.h
//  UIActivityDemo
//
//  Created by Boris Buegling on 29.09.12.
//  Copyright (c) 2012 Boris Buegling. All rights reserved.
//

#import <UIKit/UIKit.h>

#import "VUDialogViewController.h"

@class VUPinboardActivity;

@interface VUPinboardViewController : VUDialogViewController

-(id)initWithURL:(NSURL*)url activity:(VUPinboardActivity*)activity;

@end
