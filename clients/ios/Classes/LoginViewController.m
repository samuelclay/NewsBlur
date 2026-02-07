//
//  LoginViewController.m
//  NewsBlur
//
//  Created by Samuel Clay on 10/31/10.
//  Copyright 2010 NewsBlur. All rights reserved.
//

#import "LoginViewController.h"
#import "../Other Sources/OnePasswordExtension/OnePasswordExtension.h"
#import <QuartzCore/QuartzCore.h>
#import <MetalKit/MetalKit.h>

// Login screen brand colors
#define NB_LOGIN_GRADIENT_TOP     0x3F5354
#define NB_LOGIN_GRADIENT_BOTTOM  0x1B2424
#define NB_LOGIN_GOLD_TAGLINE     0xFBDB9B
#define NB_LOGIN_GOLD_BUTTON      0xD9A621
#define NB_LOGIN_GOLD_BUTTON_BOT  0xB8890B

static NSString *const kWaveShaderSource =
    @"#include <metal_stdlib>\n"
    @"using namespace metal;\n"
    @"struct VertexOut { float4 position [[position]]; float2 uv; };\n"
    @"vertex VertexOut waveVertex(uint vid [[vertex_id]]) {\n"
    @"    float2 uv = float2((vid << 1) & 2, vid & 2);\n"
    @"    VertexOut out;\n"
    @"    out.position = float4(uv * 2.0 - 1.0, 0.0, 1.0);\n"
    @"    out.uv = float2(uv.x, 1.0 - uv.y);\n"
    @"    return out;\n"
    @"}\n"
    @"fragment float4 waveFragment(VertexOut in [[stage_in]], constant float &time [[buffer(0)]]) {\n"
    @"    float2 uv = in.uv;\n"
    @"    float t = time;\n"
    @"    float3 darkBase = float3(0.106, 0.141, 0.141);\n"
    @"    float3 teal = float3(0.247, 0.326, 0.329);\n"
    @"    float3 lightTeal = float3(0.35, 0.54, 0.55);\n"
    @"    float3 gold = float3(0.85, 0.65, 0.13);\n"
    @"    float3 softGold = float3(0.98, 0.86, 0.61);\n"
    @"    float3 base = mix(teal, darkBase, smoothstep(0.0, 1.0, uv.y));\n"
    @"    float d1 = uv.x * 0.6 + uv.y * 0.4;\n"
    @"    float d2 = uv.x * 0.4 - uv.y * 0.6;\n"
    @"    float d3 = uv.x * 0.8 + uv.y * 0.2;\n"
    @"    float w1 = sin(d1 * 8.0 + t * 0.5 + sin(uv.y * 4.0 + t * 0.3) * 0.8);\n"
    @"    float ridge1 = exp(-w1 * w1 * 2.5) * 0.35;\n"
    @"    float w2 = sin(d2 * 6.0 + t * 0.7 + cos(uv.x * 3.0 - t * 0.5) * 0.6);\n"
    @"    float ridge2 = exp(-w2 * w2 * 3.0) * 0.2;\n"
    @"    float w3 = sin(d3 * 14.0 - t * 0.9 + sin(d1 * 5.0 + t * 0.4) * 0.4);\n"
    @"    float ridge3 = exp(-w3 * w3 * 4.0) * 0.12;\n"
    @"    float w4 = sin(d1 * 3.0 + t * 0.25);\n"
    @"    float glow = w4 * w4 * 0.15;\n"
    @"    float3 color = base;\n"
    @"    color += lightTeal * ridge1;\n"
    @"    color += gold * 0.7 * ridge2;\n"
    @"    color += softGold * 0.4 * ridge3;\n"
    @"    color += teal * glow;\n"
    @"    return float4(color, 1.0);\n"
    @"}\n";

@interface LoginViewController () <MTKViewDelegate>
@property (nonatomic, strong) MTKView *metalView;
@property (nonatomic, strong) id<MTLDevice> metalDevice;
@property (nonatomic, strong) id<MTLCommandQueue> commandQueue;
@property (nonatomic, strong) id<MTLRenderPipelineState> pipelineState;
@property (nonatomic, assign) CFTimeInterval startTime;
@property (nonatomic, strong) NSLayoutConstraint *emailHeightConstraint;
@property (nonatomic, strong) NSLayoutConstraint *emailTopSpacingConstraint;
@property (nonatomic, strong) NSLayoutConstraint *formBottomToButton;
@property (nonatomic, strong) NSLayoutConstraint *formBottomToForgot;
@end

@implementation LoginViewController

- (instancetype)init {
    if (self = [super init]) {
    }
    return self;
}

#pragma mark - Metal Setup

- (void)setupMetalBackground {
    self.metalDevice = MTLCreateSystemDefaultDevice();
    if (!self.metalDevice) return;

    self.metalView = [[MTKView alloc] init];
    self.metalView.device = self.metalDevice;
    self.metalView.delegate = self;
    self.metalView.translatesAutoresizingMaskIntoConstraints = NO;
    self.metalView.userInteractionEnabled = NO;
    self.metalView.opaque = YES;
    self.metalView.clearColor = MTLClearColorMake(0.106, 0.141, 0.141, 1.0);
    self.metalView.preferredFramesPerSecond = 60;
    self.metalView.colorPixelFormat = MTLPixelFormatBGRA8Unorm;
    [self.view insertSubview:self.metalView aboveSubview:[self.view viewWithTag:200]];

    [NSLayoutConstraint activateConstraints:@[
        [self.metalView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.metalView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.metalView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.metalView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor]
    ]];

    NSError *error;
    id<MTLLibrary> library = [self.metalDevice newLibraryWithSource:kWaveShaderSource options:nil error:&error];
    if (!library) {
        NSLog(@"Metal shader compilation failed: %@", error);
        [self.metalView removeFromSuperview];
        self.metalView = nil;
        return;
    }

    MTLRenderPipelineDescriptor *desc = [[MTLRenderPipelineDescriptor alloc] init];
    desc.vertexFunction = [library newFunctionWithName:@"waveVertex"];
    desc.fragmentFunction = [library newFunctionWithName:@"waveFragment"];
    desc.colorAttachments[0].pixelFormat = self.metalView.colorPixelFormat;

    self.pipelineState = [self.metalDevice newRenderPipelineStateWithDescriptor:desc error:&error];
    if (!self.pipelineState) {
        NSLog(@"Metal pipeline creation failed: %@", error);
        [self.metalView removeFromSuperview];
        self.metalView = nil;
        return;
    }

    self.commandQueue = [self.metalDevice newCommandQueue];
}

#pragma mark - MTKViewDelegate

- (void)drawInMTKView:(MTKView *)view {
    if (!self.pipelineState) return;

    id<MTLCommandBuffer> commandBuffer = [self.commandQueue commandBuffer];
    MTLRenderPassDescriptor *rpd = view.currentRenderPassDescriptor;
    if (!rpd) return;

    id<MTLRenderCommandEncoder> encoder = [commandBuffer renderCommandEncoderWithDescriptor:rpd];
    [encoder setRenderPipelineState:self.pipelineState];

    float time = (float)(CACurrentMediaTime() - self.startTime) * 0.4;
    [encoder setFragmentBytes:&time length:sizeof(float) atIndex:0];

    [encoder drawPrimitives:MTLPrimitiveTypeTriangle vertexStart:0 vertexCount:3];
    [encoder endEncoding];

    [commandBuffer presentDrawable:view.currentDrawable];
    [commandBuffer commit];
}

- (void)mtkView:(MTKView *)view drawableSizeWillChange:(CGSize)size {
}

#pragma mark - View Setup

- (void)loadView {
    [super loadView];

    self.view.backgroundColor = UIColorFromFixedRGB(NB_LOGIN_GRADIENT_BOTTOM);
    self.startTime = CACurrentMediaTime();

    // === Gradient background (fallback if Metal unavailable) ===
    UIView *gradientBg = [[UIView alloc] init];
    gradientBg.translatesAutoresizingMaskIntoConstraints = NO;
    gradientBg.tag = 200;
    [self.view addSubview:gradientBg];

    self.backgroundGradientLayer = [CAGradientLayer layer];
    self.backgroundGradientLayer.colors = @[
        (id)[UIColorFromFixedRGB(NB_LOGIN_GRADIENT_TOP) CGColor],
        (id)[UIColorFromFixedRGB(NB_LOGIN_GRADIENT_BOTTOM) CGColor],
        (id)[UIColorFromFixedRGB(NB_LOGIN_GRADIENT_BOTTOM) CGColor]
    ];
    self.backgroundGradientLayer.locations = @[@0.0, @0.5, @1.0];
    self.backgroundGradientLayer.startPoint = CGPointMake(0.5, 0.0);
    self.backgroundGradientLayer.endPoint = CGPointMake(0.5, 1.0);
    [gradientBg.layer addSublayer:self.backgroundGradientLayer];

    // === Metal animated wave background ===
    [self setupMetalBackground];

    // === Scroll view ===
    self.scrollView = [[UIScrollView alloc] init];
    self.scrollView.translatesAutoresizingMaskIntoConstraints = NO;
    self.scrollView.backgroundColor = [UIColor clearColor];
    [self.view addSubview:self.scrollView];

    UIView *contentView = [[UIView alloc] init];
    contentView.translatesAutoresizingMaskIntoConstraints = NO;
    contentView.backgroundColor = [UIColor clearColor];
    [self.scrollView addSubview:contentView];

    // === Logo (plain sunburst icon, no text) ===
    UIImageView *logoImageView = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"logo_512"]];
    logoImageView.contentMode = UIViewContentModeScaleAspectFit;
    logoImageView.translatesAutoresizingMaskIntoConstraints = NO;
    logoImageView.layer.shadowColor = UIColorFromFixedRGB(NB_LOGIN_GOLD_TAGLINE).CGColor;
    logoImageView.layer.shadowOffset = CGSizeMake(0, 0);
    logoImageView.layer.shadowRadius = 30;
    logoImageView.layer.shadowOpacity = 0.4;
    [contentView addSubview:logoImageView];

    // === "NewsBlur" in GothamNarrow ===
    UILabel *welcomeLabel = [[UILabel alloc] init];
    welcomeLabel.text = @"NewsBlur";
    welcomeLabel.font = [UIFont fontWithName:@"GothamNarrow-Medium" size:38] ?: [UIFont systemFontOfSize:38 weight:UIFontWeightBold];
    welcomeLabel.textColor = [UIColor whiteColor];
    welcomeLabel.textAlignment = NSTextAlignmentCenter;
    welcomeLabel.translatesAutoresizingMaskIntoConstraints = NO;
    welcomeLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    welcomeLabel.layer.shadowOffset = CGSizeMake(0, 1);
    welcomeLabel.layer.shadowRadius = 2;
    welcomeLabel.layer.shadowOpacity = 0.5;
    [contentView addSubview:welcomeLabel];

    // === Tagline in ChronicleSSm italic ===
    UILabel *taglineLabel = [[UILabel alloc] init];
    taglineLabel.text = @"A personal news reader bringing\npeople together to talk about the world.";
    taglineLabel.font = [UIFont fontWithName:@"ChronicleSSm-BookItalic" size:16] ?: [UIFont italicSystemFontOfSize:16];
    taglineLabel.textColor = UIColorFromFixedRGB(NB_LOGIN_GOLD_TAGLINE);
    taglineLabel.textAlignment = NSTextAlignmentCenter;
    taglineLabel.numberOfLines = 0;
    taglineLabel.translatesAutoresizingMaskIntoConstraints = NO;
    taglineLabel.layer.shadowColor = [UIColor blackColor].CGColor;
    taglineLabel.layer.shadowOffset = CGSizeMake(0, 1);
    taglineLabel.layer.shadowRadius = 0;
    taglineLabel.layer.shadowOpacity = 0.3;
    [contentView addSubview:taglineLabel];

    // === Frosted glass form card ===
    UIBlurEffect *blurEffect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleDark];
    UIVisualEffectView *formCard = [[UIVisualEffectView alloc] initWithEffect:blurEffect];
    formCard.layer.cornerRadius = 20;
    formCard.clipsToBounds = YES;
    formCard.layer.borderWidth = 0.5;
    formCard.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    formCard.translatesAutoresizingMaskIntoConstraints = NO;
    [contentView addSubview:formCard];

    UIView *formContentView = formCard.contentView;

    // === Segmented control ===
    self.loginControl = [[UISegmentedControl alloc] initWithItems:@[@"Log In", @"Sign Up"]];
    self.loginControl.selectedSegmentIndex = 0;
    self.loginControl.translatesAutoresizingMaskIntoConstraints = NO;
    self.loginControl.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.08];
    self.loginControl.selectedSegmentTintColor = [UIColor colorWithWhite:1.0 alpha:0.2];
    NSDictionary *normalAttrs = @{
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.5],
        NSFontAttributeName: [UIFont fontWithName:@"WhitneySSm-Book" size:14] ?: [UIFont systemFontOfSize:14]
    };
    NSDictionary *selectedAttrs = @{
        NSForegroundColorAttributeName: [UIColor whiteColor],
        NSFontAttributeName: [UIFont fontWithName:@"WhitneySSm-Medium" size:14] ?: [UIFont systemFontOfSize:14 weight:UIFontWeightSemibold]
    };
    [self.loginControl setTitleTextAttributes:normalAttrs forState:UIControlStateNormal];
    [self.loginControl setTitleTextAttributes:selectedAttrs forState:UIControlStateSelected];
    [self.loginControl addTarget:self action:@selector(selectLoginSignup) forControlEvents:UIControlEventValueChanged];
    [formContentView addSubview:self.loginControl];

    // === Text fields ===
    self.usernameInput = [self createTextField:@"Username or Email" isSecure:NO];
    self.usernameInput.textContentType = UITextContentTypeUsername;
    self.usernameInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.usernameInput.keyboardType = UIKeyboardTypeEmailAddress;
    [formContentView addSubview:self.usernameInput];

    self.passwordInput = [self createTextField:@"Password" isSecure:YES];
    self.passwordInput.textContentType = UITextContentTypePassword;
    [formContentView addSubview:self.passwordInput];

    self.emailInput = [self createTextField:@"Email" isSecure:NO];
    self.emailInput.textContentType = UITextContentTypeEmailAddress;
    self.emailInput.keyboardType = UIKeyboardTypeEmailAddress;
    self.emailInput.autocapitalizationType = UITextAutocapitalizationTypeNone;
    self.emailInput.alpha = 0;
    self.emailInput.clipsToBounds = YES;
    [formContentView addSubview:self.emailInput];

    // === Submit button (flat gold) ===
    UIButton *submitButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [submitButton setTitle:@"Log In" forState:UIControlStateNormal];
    submitButton.titleLabel.font = [UIFont fontWithName:@"GothamNarrow-Medium" size:17] ?: [UIFont systemFontOfSize:17 weight:UIFontWeightSemibold];
    [submitButton setTitleColor:[UIColor whiteColor] forState:UIControlStateNormal];
    submitButton.backgroundColor = UIColorFromFixedRGB(NB_LOGIN_GOLD_BUTTON);
    submitButton.layer.cornerRadius = 12;
    submitButton.translatesAutoresizingMaskIntoConstraints = NO;
    [submitButton addTarget:self action:@selector(submitAction:) forControlEvents:UIControlEventTouchUpInside];
    submitButton.tag = 100;
    [formContentView addSubview:submitButton];

    // === Error label ===
    self.errorLabel = [[UILabel alloc] init];
    self.errorLabel.textColor = [UIColor colorWithRed:1.0 green:0.4 blue:0.4 alpha:1.0];
    self.errorLabel.font = [UIFont fontWithName:@"WhitneySSm-Book" size:14] ?: [UIFont systemFontOfSize:14];
    self.errorLabel.textAlignment = NSTextAlignmentCenter;
    self.errorLabel.numberOfLines = 0;
    self.errorLabel.translatesAutoresizingMaskIntoConstraints = NO;
    self.errorLabel.hidden = YES;
    [formContentView addSubview:self.errorLabel];

    // === Forgot password button ===
    self.forgotPasswordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.forgotPasswordButton setTitle:@"Forgot Password?" forState:UIControlStateNormal];
    self.forgotPasswordButton.titleLabel.font = [UIFont fontWithName:@"WhitneySSm-Book" size:14] ?: [UIFont systemFontOfSize:14];
    [self.forgotPasswordButton setTitleColor:UIColorFromFixedRGB(NB_LOGIN_GOLD_TAGLINE) forState:UIControlStateNormal];
    self.forgotPasswordButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.forgotPasswordButton addTarget:self action:@selector(forgotPassword:) forControlEvents:UIControlEventTouchUpInside];
    self.forgotPasswordButton.hidden = YES;
    [formContentView addSubview:self.forgotPasswordButton];

    // === 1Password button ===
    self.onePasswordButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [self.onePasswordButton setImage:[UIImage imageNamed:@"onepassword-button"] forState:UIControlStateNormal];
    self.onePasswordButton.tintColor = [UIColor colorWithWhite:1.0 alpha:0.6];
    self.onePasswordButton.translatesAutoresizingMaskIntoConstraints = NO;
    [self.onePasswordButton addTarget:self action:@selector(findLoginFrom1Password:) forControlEvents:UIControlEventTouchUpInside];
    self.onePasswordButton.hidden = ![[OnePasswordExtension sharedExtension] isAppExtensionAvailable];
    [formContentView addSubview:self.onePasswordButton];

    // === Stored constraints for email animation ===
    self.emailTopSpacingConstraint = [self.emailInput.topAnchor constraintEqualToAnchor:self.passwordInput.bottomAnchor constant:0];
    self.emailHeightConstraint = [self.emailInput.heightAnchor constraintEqualToConstant:0];

    // === Layout constraints ===
    NSLayoutConstraint *formCardPreferredWidth = [formCard.widthAnchor constraintEqualToAnchor:contentView.widthAnchor constant:-48];
    formCardPreferredWidth.priority = UILayoutPriorityDefaultHigh;

    [NSLayoutConstraint activateConstraints:@[
        // Gradient background
        [gradientBg.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [gradientBg.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [gradientBg.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [gradientBg.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        // Scroll view
        [self.scrollView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.scrollView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.scrollView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.scrollView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        // Content view
        [contentView.topAnchor constraintEqualToAnchor:self.scrollView.topAnchor],
        [contentView.leadingAnchor constraintEqualToAnchor:self.scrollView.leadingAnchor],
        [contentView.trailingAnchor constraintEqualToAnchor:self.scrollView.trailingAnchor],
        [contentView.bottomAnchor constraintEqualToAnchor:self.scrollView.bottomAnchor],
        [contentView.widthAnchor constraintEqualToAnchor:self.scrollView.widthAnchor],

        // Logo
        [logoImageView.topAnchor constraintEqualToAnchor:contentView.topAnchor constant:60],
        [logoImageView.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [logoImageView.widthAnchor constraintEqualToConstant:120],
        [logoImageView.heightAnchor constraintEqualToConstant:120],

        // Welcome label
        [welcomeLabel.topAnchor constraintEqualToAnchor:logoImageView.bottomAnchor constant:16],
        [welcomeLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:40],
        [welcomeLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-40],

        // Tagline
        [taglineLabel.topAnchor constraintEqualToAnchor:welcomeLabel.bottomAnchor constant:8],
        [taglineLabel.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor constant:50],
        [taglineLabel.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor constant:-50],

        // Form card
        [formCard.topAnchor constraintEqualToAnchor:taglineLabel.bottomAnchor constant:30],
        [formCard.centerXAnchor constraintEqualToAnchor:contentView.centerXAnchor],
        [formCard.leadingAnchor constraintGreaterThanOrEqualToAnchor:contentView.leadingAnchor constant:24],
        [formCard.trailingAnchor constraintLessThanOrEqualToAnchor:contentView.trailingAnchor constant:-24],
        [formCard.widthAnchor constraintLessThanOrEqualToConstant:420],
        formCardPreferredWidth,

        // Segmented control
        [self.loginControl.topAnchor constraintEqualToAnchor:formContentView.topAnchor constant:24],
        [self.loginControl.leadingAnchor constraintEqualToAnchor:formContentView.leadingAnchor constant:20],
        [self.loginControl.trailingAnchor constraintEqualToAnchor:formContentView.trailingAnchor constant:-20],
        [self.loginControl.heightAnchor constraintEqualToConstant:36],

        // Username
        [self.usernameInput.topAnchor constraintEqualToAnchor:self.loginControl.bottomAnchor constant:16],
        [self.usernameInput.leadingAnchor constraintEqualToAnchor:formContentView.leadingAnchor constant:20],
        [self.usernameInput.trailingAnchor constraintEqualToAnchor:formContentView.trailingAnchor constant:-20],
        [self.usernameInput.heightAnchor constraintEqualToConstant:50],

        // Password
        [self.passwordInput.topAnchor constraintEqualToAnchor:self.usernameInput.bottomAnchor constant:12],
        [self.passwordInput.leadingAnchor constraintEqualToAnchor:formContentView.leadingAnchor constant:20],
        [self.passwordInput.trailingAnchor constraintEqualToAnchor:formContentView.trailingAnchor constant:-20],
        [self.passwordInput.heightAnchor constraintEqualToConstant:50],

        // Email (animated: starts collapsed)
        self.emailTopSpacingConstraint,
        [self.emailInput.leadingAnchor constraintEqualToAnchor:formContentView.leadingAnchor constant:20],
        [self.emailInput.trailingAnchor constraintEqualToAnchor:formContentView.trailingAnchor constant:-20],
        self.emailHeightConstraint,

        // Submit button (tight against fields)
        [submitButton.topAnchor constraintEqualToAnchor:self.emailInput.bottomAnchor constant:12],
        [submitButton.leadingAnchor constraintEqualToAnchor:formContentView.leadingAnchor constant:20],
        [submitButton.trailingAnchor constraintEqualToAnchor:formContentView.trailingAnchor constant:-20],
        [submitButton.heightAnchor constraintEqualToConstant:50],

        // Error label
        [self.errorLabel.topAnchor constraintEqualToAnchor:submitButton.bottomAnchor constant:12],
        [self.errorLabel.leadingAnchor constraintEqualToAnchor:formContentView.leadingAnchor constant:20],
        [self.errorLabel.trailingAnchor constraintEqualToAnchor:formContentView.trailingAnchor constant:-20],

        // Forgot password
        [self.forgotPasswordButton.topAnchor constraintEqualToAnchor:self.errorLabel.bottomAnchor constant:4],
        [self.forgotPasswordButton.centerXAnchor constraintEqualToAnchor:formContentView.centerXAnchor],

        // 1Password
        [self.onePasswordButton.trailingAnchor constraintEqualToAnchor:self.passwordInput.trailingAnchor constant:-8],
        [self.onePasswordButton.centerYAnchor constraintEqualToAnchor:self.passwordInput.centerYAnchor],
        [self.onePasswordButton.widthAnchor constraintEqualToConstant:32],
        [self.onePasswordButton.heightAnchor constraintEqualToConstant:32],

        // Content view bottom
        [contentView.bottomAnchor constraintEqualToAnchor:formCard.bottomAnchor constant:40]
    ]];

    // Toggleable form card bottom constraints
    self.formBottomToButton = [formCard.bottomAnchor constraintEqualToAnchor:submitButton.bottomAnchor constant:20];
    self.formBottomToForgot = [formCard.bottomAnchor constraintEqualToAnchor:self.forgotPasswordButton.bottomAnchor constant:20];
    self.formBottomToButton.active = YES;
    self.formBottomToForgot.active = NO;

    self.usernameInput.delegate = self;
    self.passwordInput.delegate = self;
    self.emailInput.delegate = self;
}

- (UITextField *)createTextField:(NSString *)placeholder isSecure:(BOOL)isSecure {
    UITextField *textField = [[UITextField alloc] init];
    textField.attributedPlaceholder = [[NSAttributedString alloc]
        initWithString:placeholder
        attributes:@{
            NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.35],
            NSFontAttributeName: [UIFont fontWithName:@"WhitneySSm-Book" size:16] ?: [UIFont systemFontOfSize:16]
        }];
    textField.borderStyle = UITextBorderStyleNone;
    textField.backgroundColor = [UIColor colorWithWhite:1.0 alpha:0.1];
    textField.layer.cornerRadius = 12;
    textField.layer.borderWidth = 0.5;
    textField.layer.borderColor = [UIColor colorWithWhite:1.0 alpha:0.15].CGColor;
    textField.font = [UIFont fontWithName:@"WhitneySSm-Book" size:16] ?: [UIFont systemFontOfSize:16];
    textField.textColor = [UIColor whiteColor];
    textField.tintColor = UIColorFromFixedRGB(NB_LOGIN_GOLD_TAGLINE);
    textField.keyboardAppearance = UIKeyboardAppearanceDark;
    textField.autocorrectionType = UITextAutocorrectionTypeNo;
    textField.returnKeyType = UIReturnKeyNext;
    textField.secureTextEntry = isSecure;
    textField.translatesAutoresizingMaskIntoConstraints = NO;

    UIView *paddingView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 0)];
    textField.leftView = paddingView;
    textField.leftViewMode = UITextFieldViewModeAlways;
    textField.rightView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 16, 0)];
    textField.rightViewMode = UITextFieldViewModeAlways;

    return textField;
}

- (void)submitAction:(UIButton *)sender {
    if (self.loginControl.selectedSegmentIndex == 0) {
        [self tapLoginButton];
    } else {
        [self tapSignUpButton];
    }
}

#pragma mark - View Lifecycle

- (void)viewDidLoad {
    [super viewDidLoad];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];

    UIView *gradientBg = [self.view viewWithTag:200];
    self.backgroundGradientLayer.frame = gradientBg.bounds;
}

- (UIStatusBarStyle)preferredStatusBarStyle {
    return UIStatusBarStyleLightContent;
}

- (void)viewWillAppear:(BOOL)animated {
    self.overrideUserInterfaceStyle = UIUserInterfaceStyleLight;

    [self showError:nil];
    [super viewWillAppear:animated];

    self.metalView.paused = NO;

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillShow:)
                                                 name:UIKeyboardWillShowNotification
                                               object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(keyboardWillHide:)
                                                 name:UIKeyboardWillHideNotification
                                               object:nil];

    [self.usernameInput becomeFirstResponder];
}

- (void)viewDidAppear:(BOOL)animated {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    [super viewDidAppear:animated];
}

- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];

    self.metalView.paused = YES;

    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillShowNotification object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIKeyboardWillHideNotification object:nil];

    [[ThemeManager themeManager] systemAppearanceDidChange:self.appDelegate.feedsViewController.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark];
}

- (void)keyboardWillShow:(NSNotification *)notification {
    NSDictionary *info = [notification userInfo];
    CGSize keyboardSize = [[info objectForKey:UIKeyboardFrameEndUserInfoKey] CGRectValue].size;

    UIEdgeInsets contentInsets = UIEdgeInsetsMake(0.0, 0.0, keyboardSize.height, 0.0);
    self.scrollView.contentInset = contentInsets;
    self.scrollView.scrollIndicatorInsets = contentInsets;
}

- (void)keyboardWillHide:(NSNotification *)notification {
    self.scrollView.contentInset = UIEdgeInsetsZero;
    self.scrollView.scrollIndicatorInsets = UIEdgeInsetsZero;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
}

#pragma mark - Error Display

- (void)showError:(NSString *)error {
    BOOL hasError = error.length > 0;

    if (hasError) {
        self.errorLabel.text = error;
    }

    self.errorLabel.hidden = !hasError;
    self.forgotPasswordButton.hidden = !hasError;

    // Toggle form card bottom: tight to button normally, expanded to forgot password on error
    self.formBottomToButton.active = !hasError;
    self.formBottomToForgot.active = hasError;
    [self.view layoutIfNeeded];
}

#pragma mark - 1Password

- (IBAction)findLoginFrom1Password:(id)sender {
    [[OnePasswordExtension sharedExtension] findLoginForURLString:@"https://www.newsblur.com" forViewController:self sender:sender completion:^(NSDictionary *loginDictionary, NSError *error) {
        if (loginDictionary.count == 0) {
            if (error.code != AppExtensionErrorCodeCancelledByUser) {
                NSLog(@"Error invoking 1Password App Extension for find login: %@", error);
            }
            return;
        }

        self.usernameInput.text = loginDictionary[AppExtensionUsernameKey];
        [self.passwordInput becomeFirstResponder];
        self.passwordInput.text = loginDictionary[AppExtensionPasswordKey];
    }];
}

#pragma mark - Login

- (BOOL)textFieldShouldReturn:(UITextField *)textField {
    [textField resignFirstResponder];

    if (textField == self.usernameInput) {
        [self.passwordInput becomeFirstResponder];
    } else if (textField == self.passwordInput && [self.loginControl selectedSegmentIndex] == 0) {
        [self checkPassword];
    } else if (textField == self.passwordInput && [self.loginControl selectedSegmentIndex] == 1) {
        [self.emailInput becomeFirstResponder];
    } else if (textField == self.emailInput) {
        [self registerAccount];
    }

    return YES;
}

- (void)checkPassword {
    [self showError:nil];
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Authenticating";

    NSString *urlString = [NSString stringWithFormat:@"%@/api/login",
                           self.appDelegate.url];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[self.usernameInput text] forKey:@"username"];
    [params setObject:[self.passwordInput text] forKey:@"password"];
    [params setObject:@"login" forKey:@"submit"];
    [params setObject:@"1" forKey:@"api"];

    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];

        int code = [[responseObject valueForKey:@"code"] intValue];
        if (code == -1) {
            NSDictionary *errors = [responseObject valueForKey:@"errors"];
            if ([errors valueForKey:@"username"]) {
                [self showError:[[errors valueForKey:@"username"] firstObject]];
            } else if ([errors valueForKey:@"__all__"]) {
                [self showError:[[errors valueForKey:@"__all__"] firstObject]];
            }
        } else {
            [self.passwordInput setText:@""];
            [self.appDelegate reloadFeedsView:YES];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)registerAccount {
    [MBProgressHUD hideHUDForView:self.view animated:YES];
    MBProgressHUD *HUD = [MBProgressHUD showHUDAddedTo:self.view animated:YES];
    HUD.labelText = @"Registering...";
    [self showError:nil];
    NSString *urlString = [NSString stringWithFormat:@"%@/api/signup",
                           self.appDelegate.url];
    [[NSHTTPCookieStorage sharedHTTPCookieStorage]
     setCookieAcceptPolicy:NSHTTPCookieAcceptPolicyAlways];

    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    [params setObject:[self.usernameInput text] forKey:@"username"];
    [params setObject:[self.passwordInput text] forKey:@"password"];
    [params setObject:[self.emailInput text] forKey:@"email"];
    [params setObject:@"login" forKey:@"submit"];
    [params setObject:@"1" forKey:@"api"];

    [appDelegate POST:urlString parameters:params success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        [MBProgressHUD hideHUDForView:self.view animated:YES];

        int code = [[responseObject valueForKey:@"code"] intValue];
        if (code == -1) {
            NSDictionary *errors = [responseObject valueForKey:@"errors"];
            if ([errors valueForKey:@"email"]) {
                [self showError:[[errors valueForKey:@"email"] objectAtIndex:0]];
            } else if ([errors valueForKey:@"username"]) {
                [self showError:[[errors valueForKey:@"username"] objectAtIndex:0]];
            } else if ([errors valueForKey:@"__all__"]) {
                [self showError:[[errors valueForKey:@"__all__"] objectAtIndex:0]];
            }
        } else {
            [self.passwordInput setText:@""];
            [self.appDelegate reloadFeedsView:YES];
            [self dismissViewControllerAnimated:YES completion:nil];
        }
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        [self requestFailed:error];
    }];
}

- (void)requestFailed:(NSError *)error {
    NSLog(@"Error: %@", error);
    [appDelegate informError:error];

    [MBProgressHUD hideHUDForView:self.view animated:YES];
}

- (IBAction)forgotPassword:(id)sender {
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@/folder_rss/forgot_password", appDelegate.url]];
    SFSafariViewController *safariViewController = [[SFSafariViewController alloc] initWithURL:url];
    [self presentViewController:safariViewController animated:YES completion:nil];
}

- (IBAction)tapLoginButton {
    [self.view endEditing:YES];
    [self checkPassword];
}

- (IBAction)tapSignUpButton {
    [self.view endEditing:YES];
    [self registerAccount];
}

#pragma mark - Sign Up/Login Toggle

- (IBAction)selectLoginSignup {
    [self animateLoop];
}

- (void)animateLoop {
    BOOL isLogin = [self.loginControl selectedSegmentIndex] == 0;

    UIButton *submitButton = [self.view viewWithTag:100];
    [submitButton setTitle:(isLogin ? @"Log In" : @"Sign Up") forState:UIControlStateNormal];

    // Animate email field expand/collapse
    self.emailHeightConstraint.constant = isLogin ? 0 : 50;
    self.emailTopSpacingConstraint.constant = isLogin ? 0 : 12;

    NSDictionary *placeholderAttrs = @{
        NSForegroundColorAttributeName: [UIColor colorWithWhite:1.0 alpha:0.35],
        NSFontAttributeName: [UIFont fontWithName:@"WhitneySSm-Book" size:16] ?: [UIFont systemFontOfSize:16]
    };

    [UIView animateWithDuration:0.35 delay:0 usingSpringWithDamping:0.85 initialSpringVelocity:0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
        self.emailInput.alpha = isLogin ? 0.0 : 1.0;
        self.onePasswordButton.alpha = isLogin ? 1.0 : 0.0;
        [self.view layoutIfNeeded];

        if (isLogin) {
            self.usernameInput.attributedPlaceholder = [[NSAttributedString alloc]
                initWithString:@"Username or Email" attributes:placeholderAttrs];
            self.usernameInput.keyboardType = UIKeyboardTypeEmailAddress;
            self.passwordInput.returnKeyType = UIReturnKeyGo;
        } else {
            self.usernameInput.attributedPlaceholder = [[NSAttributedString alloc]
                initWithString:@"Username" attributes:placeholderAttrs];
            self.usernameInput.keyboardType = UIKeyboardTypeDefault;
            self.passwordInput.returnKeyType = UIReturnKeyNext;
        }
    } completion:^(BOOL finished) {
        [self.usernameInput becomeFirstResponder];
    }];

    [self showError:nil];
}

@end
