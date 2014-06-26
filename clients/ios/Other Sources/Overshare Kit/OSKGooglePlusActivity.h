//
//  OSKFacebookActivity.h
//  Overshare
//
//  Created by Peter Friese on 2/5/14.
//  Copyright (c) 2014 Google. All rights reserved.
//

#import "OSKActivity.h"

#import "OSKMicrobloggingActivity.h"
#import "OSKActivity_GenericAuthentication.h"

@interface OSKGooglePlusActivity : OSKActivity <OSKMicrobloggingActivity, OSKActivity_GenericAuthentication>
@property(nonatomic, copy) OSKActivityCompletionHandler activityCompletionHandler;
@end
