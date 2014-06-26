//
//  OSKTwitterActivity.h
//  Overshare
//
//   
//  Copyright (c) 2013 Overshare Kit. All rights reserved.
//

#import "OSKActivity.h"

#import "OSKMicrobloggingActivity.h"
#import "OSKActivity_SystemAccounts.h"

@interface OSKTwitterActivity : OSKActivity <OSKMicrobloggingActivity, OSKActivity_SystemAccounts>

@end
