//
//  VUGradientButton.m
//
//  Created by Boris Buegling.
//

#import <QuartzCore/QuartzCore.h>

#import "VUGradientButton.h"

static NSArray* kObservedKeyPaths;

@interface VUGradientButton ()

@property (nonatomic, strong) CAGradientLayer* gradientLayer;

@end

#pragma mark -

@implementation VUGradientButton

+(id)buttonWithType:(UIButtonType)buttonType {
    UIButton* button = [super buttonWithType:buttonType];
    [button awakeFromNib];
    
    if (!kObservedKeyPaths) {
        kObservedKeyPaths = @[ @"bounds", @"frame", @"highColor", @"lowColor" ];
    }
    
    for (NSString* keyPath in kObservedKeyPaths) {
        [button addObserver:button forKeyPath:keyPath options:0 context:NULL];
    }
    
    return button;
}

-(void)dealloc {
    for (NSString* keyPath in kObservedKeyPaths) {
        [self removeObserver:self forKeyPath:keyPath];
    }
}

#pragma mark -

-(void)awakeFromNib {
    self.gradientLayer = [[CAGradientLayer alloc] init];
    self.gradientLayer.bounds = self.bounds;
    self.gradientLayer.position = CGPointMake(self.bounds.size.width / 2.0, self.bounds.size.height / 2.0);
    [self.layer insertSublayer:self.gradientLayer atIndex:0];
    
    self.layer.borderWidth = 1.0f;
    self.layer.cornerRadius = 8.0f;
    self.layer.masksToBounds = YES;
}

-(void)drawRect:(CGRect)rect {
    [self.gradientLayer setColors:@[ (id)[self.highColor CGColor], (id)[self.lowColor CGColor] ]];
    [super drawRect:rect];
}

-(void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    if (![keyPath hasSuffix:@"Color"]) {
        [self awakeFromNib];
    }
    
    [self setNeedsDisplay];
}

@end
