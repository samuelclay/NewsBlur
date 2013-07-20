//
//  VUDialogViewController.h
//
//  Created by Boris Buegling.
//

#import <UIKit/UIKit.h>

@class VUDialogViewController;

@protocol VUDialogDelegate <NSObject>

-(void)cancelWithDialogViewController:(VUDialogViewController*)dialogViewController;
-(void)submitWithDialogViewController:(VUDialogViewController*)dialogViewController;

@end

#pragma mark -

@interface VUDialogViewController : UIViewController

@property (nonatomic, weak) id<VUDialogDelegate> delegate;

-(BOOL)defaultDialogButtonsWithSubmitLabel:(NSString*)submitLabel cancelLabel:(NSString*)cancelLabel;
-(UILabel*)headlineWithImageResource:(NSString*)resourceName ofType:(NSString*)resourceType text:(NSString*)text;
-(UILabel*)labelWithText:(NSString*)text;
-(UISwitch*)switchWithLabel:(NSString*)labelText;
-(UITextField*)textFieldWithLabel:(NSString*)labelText;
-(UITextView*)textViewWithLabel:(NSString*)labelText;

@end
