//
//  VUDialogViewController.m
//
//  Created by Boris Buegling.
//

#import <QuartzCore/QuartzCore.h>

#import "VUDialogViewController.h"
#import "VUGradientButton.h"

static const CGFloat kMargin            = 20.0;

static const CGFloat kButtonWidth       = 80.0;
static const CGFloat kButtonHeight      = 30.0;
static const CGFloat kLabelHeight       = 20.0;
static const CGFloat kSwitchWidth       = 60.0;
static const CGFloat kSwitchHeight      = 20.0;
static const CGFloat kTextFieldHeight   = 30.0;
static const CGFloat kTextViewHeight    = 60.0;

@interface VUDialogViewController () <UITextFieldDelegate, UITextViewDelegate>

@property (nonatomic, assign) CGPoint point;
@property (nonatomic, assign) CGFloat pointX;
@property (nonatomic, assign) CGFloat pointY;
@property (nonatomic, readonly) CGFloat width;

@end

#pragma mark -

@implementation VUDialogViewController

@dynamic pointX;
@dynamic pointY;
@dynamic width;

#pragma mark -

-(id)init {
    self = [super init];
    if (self) {
        self.point = CGPointMake(kMargin, kMargin);
    }
    return self;
}

-(void)loadView {
    self.view = [[UIView alloc] initWithFrame:[UIScreen mainScreen].bounds];
    self.view.backgroundColor = [UIColor underPageBackgroundColor];
}

#pragma mark - Layout values

-(CGFloat)pointX {
    return self.point.x;
}

-(CGFloat)pointY {
    return self.point.y;
}

-(void)setPointX:(CGFloat)pointX {
    self.point = CGPointMake(pointX, self.point.y);
}

-(void)setPointY:(CGFloat)pointY {
    self.point = CGPointMake(self.point.x, pointY);
}

-(CGFloat)width {
    return self.view.frame.size.width - 2.0 * kMargin;
}

#pragma mark - UI Elements

-(void)adjustLabelWidth:(UILabel*)label {
    CGFloat labelWidth = [label.text sizeWithFont:label.font].width;
    label.frame = CGRectMake(label.frame.origin.x, label.frame.origin.y, labelWidth, label.frame.size.height);
}

-(UIButton*)buttonAtPoint:(CGPoint)point title:(NSString*)titleText action:(SEL)action {
    VUGradientButton* button = [VUGradientButton buttonWithType:UIButtonTypeCustom];
    button.frame = CGRectMake(point.x, point.y, kButtonWidth, kButtonHeight);
    button.highColor = [UIColor lightGrayColor];
    button.lowColor = [UIColor whiteColor];
    
    [button setTitle:titleText forState:UIControlStateNormal];
    [button setTitleColor:[UIColor blackColor] forState:UIControlStateNormal];
    
    [button addTarget:self action:action forControlEvents:UIControlEventTouchUpInside];
    
    [self.view addSubview:button];
    return button;
}

-(BOOL)defaultDialogButtonsWithSubmitLabel:(NSString*)submitLabel cancelLabel:(NSString*)cancelLabel {
    [self buttonAtPoint:CGPointMake(self.width + kMargin - 2.0 * kButtonWidth - kMargin, self.point.y)
                  title:cancelLabel
                 action:@selector(cancelTapped)];
    
    [self buttonAtPoint:CGPointMake(self.width + kMargin - kButtonWidth, self.point.y)
                  title:submitLabel
                 action:@selector(submitTapped)];
    
    return YES;
}

-(UILabel*)headlineWithImageResource:(NSString*)resourceName ofType:(NSString*)resourceType text:(NSString*)text {
    UIImage* logo = [[UIImage alloc] initWithContentsOfFile:[[NSBundle mainBundle] pathForResource:resourceName ofType:resourceType]];
    UIImageView* logoView = [[UIImageView alloc] initWithImage:logo];
    logoView.frame = CGRectMake(self.point.x, self.point.y, logo.size.width, logo.size.height);
    [self.view addSubview:logoView];
    
    CGFloat oldPointY = self.pointY;
    UILabel* headlineLabel = [self labelAtPoint:self.point width:self.width text:text];
    self.pointY = oldPointY;
    
    headlineLabel.frame = CGRectMake(self.pointX + logo.size.width + kMargin, self.pointY, self.width, 30.0);
    headlineLabel.font = [UIFont boldSystemFontOfSize:25.0];
    headlineLabel.textColor = [UIColor whiteColor];
    
    self.pointY = self.pointY + logoView.frame.size.height + kMargin / 2.0;
    
    return headlineLabel;
}

-(UILabel*)labelAtPoint:(CGPoint)point width:(CGFloat)width text:(NSString*)text {
    UILabel* label = [[UILabel alloc] initWithFrame:CGRectMake(point.x, point.y, width, kLabelHeight)];
    label.backgroundColor = [UIColor clearColor];
    label.text = text;
    
    [self.view addSubview:label];
    self.pointY = self.pointY + label.frame.size.height + kMargin;
    
    return label;
}

-(UILabel*)labelAtPoint:(CGPoint)point text:(NSString*)text {
    CGFloat labelWidth = [text sizeWithFont:[UIFont systemFontOfSize:18.0]].width;
    return [self labelAtPoint:point width:labelWidth text:text];
}

-(UILabel*)labelWithText:(NSString*)text {
    return [self labelAtPoint:self.point width:self.width text:text];
}

-(UISwitch*)switchAtPoint:(CGPoint)point width:(CGFloat)width withLabel:(NSString*)labelText {
    CGFloat oldPointY = self.pointY;
    [self labelAtPoint:CGPointMake(point.x, point.y + 5.0) text:labelText];
    self.pointY = oldPointY;
    
    UISwitch* switchObject = [[UISwitch alloc] initWithFrame:CGRectMake(width - kSwitchWidth, point.y, kSwitchWidth, kSwitchHeight)];
    
    [self.view addSubview:switchObject];
    self.pointY += switchObject.frame.size.height + kMargin;
    
    return switchObject;
}

-(UISwitch*)switchWithLabel:(NSString*)labelText {
    return [self switchAtPoint:self.point width:self.width withLabel:labelText];
}

-(UITextField*)textFieldAtPoint:(CGPoint)point width:(CGFloat)width {
    UITextField* textField = [[UITextField alloc] initWithFrame:CGRectMake(point.x, point.y, width, kTextFieldHeight)];
    textField.borderStyle = UITextBorderStyleRoundedRect;
    textField.delegate = self;
    
    [self.view addSubview:textField];
    self.pointY = self.pointY + textField.frame.size.height + kMargin;
    
    return textField;
}

-(UITextField*)textFieldAtPoint:(CGPoint)point width:(CGFloat)width withLabel:(NSString*)labelText {
    CGFloat oldPointY = self.pointY;
    UILabel* label = [self labelAtPoint:CGPointMake(point.x, point.y + 5.0) text:labelText];
    self.pointY = oldPointY;
    CGFloat margin = label.frame.size.width + 10.0;
    return [self textFieldAtPoint:CGPointMake(point.x + margin, point.y) width:width - margin];
}

-(UITextField*)textFieldWithLabel:(NSString*)labelText {
    return [self textFieldAtPoint:self.point width:self.width withLabel:labelText];
}

-(UITextView*)textViewAtPoint:(CGPoint)point width:(CGFloat)width {
    UITextView* textView = [[UITextView alloc] initWithFrame:CGRectMake(point.x, point.y, width, kTextViewHeight)];
    textView.layer.borderWidth = 1.0;
    textView.layer.cornerRadius = 5.0;
    textView.clipsToBounds = YES;
    
    [self.view addSubview:textView];
    self.pointY = self.pointY + textView.frame.size.height + kMargin;
    
    return textView;
}

-(UITextView*)textViewAtPoint:(CGPoint)point width:(CGFloat)width withLabel:(NSString*)labelText {
    [self labelAtPoint:point width:width text:labelText];
    self.pointY = self.pointY - (kMargin / 2.0);
    return [self textViewAtPoint:self.point width:width];
}

-(UITextView*)textViewWithLabel:(NSString*)labelText {
    return [self textViewAtPoint:self.point width:self.width withLabel:labelText];
}

#pragma mark - Handle actions

-(void)cancelTapped {
    if ([self.delegate respondsToSelector:@selector(cancelWithDialogViewController:)]) {
        [self.delegate cancelWithDialogViewController:self];
    }
}

-(void)submitTapped {
    if ([self.delegate respondsToSelector:@selector(submitWithDialogViewController:)]) {
        [self.delegate submitWithDialogViewController:self];
    }
}

#pragma mark - UITextField delegate methods

-(BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];
    return NO;
}

#pragma mark - UITextView delegate methods

@end
