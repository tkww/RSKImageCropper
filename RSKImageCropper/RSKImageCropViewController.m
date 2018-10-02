//
// RSKImageCropViewController.m
//
// Copyright (c) 2014-present Ruslan Skorb, http://ruslanskorb.com/
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.
//

#import "RSKImageCropViewController.h"
#import "RSKTouchView.h"
#import "RSKImageScrollView.h"
#import "RSKInternalUtility.h"
#import "UIImage+RSKImageCropper.h"
#import "CGGeometry+RSKImageCropper.h"
#import "UIApplication+RSKImageCropper.h"

static const CGFloat kResetAnimationDuration = 0.4;
static const CGFloat kLayoutImageScrollViewAnimationDuration = 0.25;

@interface RSKImageCropViewController () <UIGestureRecognizerDelegate>

@property (assign, nonatomic) BOOL originalNavigationControllerNavigationBarHidden;
@property (strong, nonatomic) UIImage *originalNavigationControllerNavigationBarShadowImage;
@property (copy, nonatomic) UIColor *originalNavigationControllerViewBackgroundColor;
@property (assign, nonatomic) BOOL originalStatusBarHidden;

@property (strong, nonatomic) RSKImageScrollView *imageScrollView;
@property (strong, nonatomic) RSKTouchView *overlayView;
@property (strong, nonatomic) RSKTouchView *supplementalView;
@property (strong, nonatomic) RSKTouchView *guidelineView;
@property (strong, nonatomic) RSKTouchView *supplementalGuidelineView;
@property (strong, nonatomic) UILabel *cropViewLabel;
@property (strong, nonatomic) UILabel *supplementalViewLabel;
@property (strong, nonatomic) CAShapeLayer *maskLayer;
@property (strong, nonatomic) CAShapeLayer *supplementalMaskLayer;


@property (assign, nonatomic) CGRect maskRect;
@property (copy, nonatomic) UIBezierPath *maskPath;

@property (readonly, nonatomic) CGRect rectForMaskPath;
@property (readonly, nonatomic) CGRect rectForClipPath;

@property (readonly, nonatomic) CGRect imageRect;

@property (strong, nonatomic) UILabel *titleLabel;
@property (strong, nonatomic) UILabel *subtitleLabel;
@property (strong, nonatomic) UIButton *cancelButton;
@property (strong, nonatomic) UIButton *chooseButton;

@property (strong, nonatomic) UITapGestureRecognizer *doubleTapGestureRecognizer;
@property (strong, nonatomic) UIRotationGestureRecognizer *rotationGestureRecognizer;

@property (assign, nonatomic) BOOL didSetupConstraints;
@property (strong, nonatomic) NSLayoutConstraint *titleLabelTopConstraint;
@property (strong, nonatomic) NSLayoutConstraint *cancelButtonBottomConstraint;
@property (strong, nonatomic) NSLayoutConstraint *cancelButtonLeadingConstraint;
@property (strong, nonatomic) NSLayoutConstraint *chooseButtonBottomConstraint;
@property (strong, nonatomic) NSLayoutConstraint *chooseButtonTrailingConstraint;

@end

@implementation RSKImageCropViewController

#pragma mark - Lifecycle

- (instancetype)init
{
    self = [super init];
    if (self) {
        _avoidEmptySpaceAroundImage = NO;
        _alwaysBounceVertical = NO;
        _alwaysBounceHorizontal = NO;
        _applyMaskToCroppedImage = NO;
        _maskLayerLineWidth = 1.0;
        _rotationEnabled = NO;
        _cropMode = RSKImageCropModeCircle;
        
        _portraitCircleMaskRectInnerEdgeInset = 15.0f;
        _portraitSquareMaskRectInnerEdgeInset = 20.0f;
        _portraitTitleLabelTopAndCropViewTopVerticalSpace = 64.0f;
        _portraitCropViewBottomAndCancelButtonBottomVerticalSpace = 21.0f;
        _portraitCropViewBottomAndChooseButtonBottomVerticalSpace = 21.0f;
        _portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace = 13.0f;
        _portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace = 13.0;
        
        _landscapeCircleMaskRectInnerEdgeInset = 45.0f;
        _landscapeSquareMaskRectInnerEdgeInset = 45.0f;
        _subtitleTopSpaceToTitleBottom = 4.0f;
        _landscapeTitleLabelTopAndCropViewTopVerticalSpace = 12.0f;
        _landscapeCropViewBottomAndCancelButtonBottomVerticalSpace = 12.0f;
        _landscapeCropViewBottomAndChooseButtonBottomVerticalSpace = 12.0f;
        _landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace = 13.0;
        _landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace = 13.0;
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)originalImage
{
    self = [self init];
    if (self) {
        _originalImage = originalImage;
    }
    return self;
}

- (instancetype)initWithImage:(UIImage *)originalImage cropMode:(RSKImageCropMode)cropMode
{
    self = [self initWithImage:originalImage];
    if (self) {
        _cropMode = cropMode;
    }
    return self;
}

- (BOOL)prefersStatusBarHidden
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    if ([self respondsToSelector:@selector(edgesForExtendedLayout)]) {
        
        self.edgesForExtendedLayout = UIRectEdgeNone;
    }
    
    if (@available(iOS 11.0, *)) {
        
        self.imageScrollView.contentInsetAdjustmentBehavior = UIScrollViewContentInsetAdjustmentNever;
    }
    else if ([self respondsToSelector:@selector(automaticallyAdjustsScrollViewInsets)] == YES) {
        
        self.automaticallyAdjustsScrollViewInsets = NO;
    }
    
    self.view.backgroundColor = [UIColor blackColor];
    self.view.clipsToBounds = YES;
    
    [self.view addSubview:self.imageScrollView];
    [self.view addSubview:self.overlayView];
    [self.view addSubview:self.supplementalView];
    [self.view addSubview:self.guidelineView];
    if ([self.dataSource respondsToSelector:@selector(imageCropViewControllerSupplementalViewRect:)]) {
        [self.view addSubview:self.supplementalGuidelineView];
        [self.view addSubview:self.supplementalViewLabel];
    }
    [self.view addSubview:self.titleLabel];
    [self.view addSubview:self.subtitleLabel];
    [self.view addSubview:self.cropViewLabel];
    [self.view addSubview:self.cancelButton];
    [self.view addSubview:self.chooseButton];
    
    [self.view addGestureRecognizer:self.doubleTapGestureRecognizer];
    [self.view addGestureRecognizer:self.rotationGestureRecognizer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if ([self respondsToSelector:@selector(prefersStatusBarHidden)] == NO) {
        
        UIApplication *application = [UIApplication rsk_sharedApplication];
        if (application) {
            
            self.originalStatusBarHidden = application.statusBarHidden;
            [application setStatusBarHidden:YES];
        }
    }
    
    self.originalNavigationControllerNavigationBarHidden = self.navigationController.navigationBarHidden;
    [self.navigationController setNavigationBarHidden:YES animated:NO];
    
    self.originalNavigationControllerNavigationBarShadowImage = self.navigationController.navigationBar.shadowImage;
    self.navigationController.navigationBar.shadowImage = nil;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    self.originalNavigationControllerViewBackgroundColor = self.navigationController.view.backgroundColor;
    self.navigationController.view.backgroundColor = [UIColor blackColor];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    
    if ([self respondsToSelector:@selector(prefersStatusBarHidden)] == NO) {
        
        UIApplication *application = [UIApplication rsk_sharedApplication];
        if (application) {
            
            [application setStatusBarHidden:self.originalStatusBarHidden];
        }
    }
    
    [self.navigationController setNavigationBarHidden:self.originalNavigationControllerNavigationBarHidden animated:animated];
    self.navigationController.navigationBar.shadowImage = self.originalNavigationControllerNavigationBarShadowImage;
    self.navigationController.view.backgroundColor = self.originalNavigationControllerViewBackgroundColor;
}

- (void)viewWillLayoutSubviews
{
    [super viewWillLayoutSubviews];
    
    [self updateMaskRect];
    [self layoutImageScrollView];
    [self layoutOverlayView];
    [self updateMaskPath];
    [self.view setNeedsUpdateConstraints];
}

- (void)viewDidLayoutSubviews
{
    [super viewDidLayoutSubviews];
    
    if (!self.imageScrollView.zoomView) {
        [self displayImage];
    }
}

- (void)updateViewConstraints
{
    [super updateViewConstraints];
    
    if (!self.didSetupConstraints) {
        // ---------------------------
        // The label "Move and Scale".
        // ---------------------------
        
        NSLayoutConstraint *constraint = [NSLayoutConstraint constraintWithItem:self.titleLabel attribute:NSLayoutAttributeCenterX relatedBy:NSLayoutRelationEqual
                                                                         toItem:self.view attribute:NSLayoutAttributeCenterX multiplier:1.0f
                                                                       constant:0.0f];
        [self.view addConstraint:constraint];
        
        CGFloat constant = self.portraitTitleLabelTopAndCropViewTopVerticalSpace;
        self.titleLabelTopConstraint = [NSLayoutConstraint constraintWithItem:self.titleLabel attribute:NSLayoutAttributeTop relatedBy:NSLayoutRelationEqual
                                                                       toItem:self.view attribute:NSLayoutAttributeTop multiplier:1.0f
                                                                     constant:constant];
        [self.view addConstraint:self.titleLabelTopConstraint];

        // ---------------------------
        // The "Subtitle" label.
        // ---------------------------

        NSLayoutConstraint *subtitleLeadingConstraint = [self.subtitleLabel.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor constant:46];
        [subtitleLeadingConstraint setActive:YES];

        NSLayoutConstraint *subtitleTrailingConstraint = [self.subtitleLabel.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor constant:-46];
        [subtitleTrailingConstraint setActive:YES];

        NSLayoutConstraint *subtitleTopContraintToTitle = [self.subtitleLabel.topAnchor constraintEqualToAnchor:self.titleLabel.bottomAnchor constant:self.subtitleTopSpaceToTitleBottom];
        [subtitleTopContraintToTitle setActive:YES];

        // ---------------------------
        // The Guideline View
        // ---------------------------

        self.guidelineView.translatesAutoresizingMaskIntoConstraints = NO;
        CGRect guidelineRect = [self.dataSource imageCropViewControllerCustomMaskRect:self];
        NSLayoutConstraint *guidelineViewHeightConstraint = [self.guidelineView.heightAnchor constraintEqualToConstant:guidelineRect.size.height];
        [guidelineViewHeightConstraint setActive:YES];
        NSLayoutConstraint *guidelineViewWidthConstraint = [self.guidelineView.widthAnchor constraintEqualToConstant:guidelineRect.size.width];
        [guidelineViewWidthConstraint setActive:YES];
        NSLayoutConstraint *guidelineXConstraint = [self.guidelineView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor];
        [guidelineXConstraint setActive:YES];
        NSLayoutConstraint *guidelineYConstraint = [self.guidelineView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];
        [guidelineYConstraint setActive:YES];

        // ---------------------------
        // The Supplemental Guideline View
        // ---------------------------

        if ([self.dataSource respondsToSelector:@selector(imageCropViewControllerSupplementalViewRect:)]) {
            self.supplementalGuidelineView.translatesAutoresizingMaskIntoConstraints = NO;
            CGRect supplementalGuidelineRect = [self.dataSource imageCropViewControllerSupplementalViewRect:self];
            NSLayoutConstraint *supplementalGuidelineViewHeightConstraint = [self.supplementalGuidelineView.heightAnchor constraintEqualToConstant:supplementalGuidelineRect.size.height];
            [supplementalGuidelineViewHeightConstraint setActive:YES];
            NSLayoutConstraint *supplementalGuidelineViewWidthConstraint = [self.supplementalGuidelineView.widthAnchor constraintEqualToConstant:supplementalGuidelineRect.size.width];
            [supplementalGuidelineViewWidthConstraint setActive:YES];
            NSLayoutConstraint *supplementalGuidelineXConstraint = [self.supplementalGuidelineView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor];
            [supplementalGuidelineXConstraint setActive:YES];
            NSLayoutConstraint *supplementalGuidelineYConstraint = [self.supplementalGuidelineView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor];
            [supplementalGuidelineYConstraint setActive:YES];
        }

        // ---------------------------
        // The CropView Label
        // ---------------------------

        self.cropViewLabel.translatesAutoresizingMaskIntoConstraints = NO;
        NSLayoutConstraint *cropViewLabelBottomConstraintToGuidelineView = [self.cropViewLabel.bottomAnchor constraintEqualToAnchor:self.guidelineView.topAnchor constant:0];
        [cropViewLabelBottomConstraintToGuidelineView setActive:YES];
        NSLayoutConstraint *cropViewLabelLeadingConstraintToGuidelineView = [self.cropViewLabel.leadingAnchor constraintEqualToAnchor:self.guidelineView.leadingAnchor constant:6];
        [cropViewLabelLeadingConstraintToGuidelineView setActive:YES];

        // ---------------------------
        // The SupplementalView Label
        // ---------------------------

        if ([self.dataSource respondsToSelector:@selector(imageCropViewControllerSupplementalViewRect:)]) {
            self.supplementalViewLabel.translatesAutoresizingMaskIntoConstraints = NO;
            NSLayoutConstraint *supplementalViewLabelBottomConstraintToSupplementalGuidelineView = [self.supplementalViewLabel.bottomAnchor constraintEqualToAnchor:self.supplementalGuidelineView.topAnchor constant:0];
            [supplementalViewLabelBottomConstraintToSupplementalGuidelineView setActive:YES];
            NSLayoutConstraint *supplementalViewLabelLeadingConstraintToSupplementalGuidelineView = [self.supplementalViewLabel.leadingAnchor constraintEqualToAnchor:self.supplementalGuidelineView.leadingAnchor constant:6];
            [supplementalViewLabelLeadingConstraintToSupplementalGuidelineView setActive:YES];
        }
        
        // --------------------
        // The button "Cancel".
        // --------------------
        
        constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace;
        self.cancelButtonLeadingConstraint = [NSLayoutConstraint constraintWithItem:self.cancelButton attribute:NSLayoutAttributeLeading relatedBy:NSLayoutRelationEqual
                                                                             toItem:self.view attribute:NSLayoutAttributeLeading multiplier:1.0f
                                                                           constant:constant];
        [self.view addConstraint:self.cancelButtonLeadingConstraint];
        
        constant = self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace;
        self.cancelButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.cancelButton attribute:NSLayoutAttributeBottom multiplier:1.0f
                                                                          constant:constant];
        [self.view addConstraint:self.cancelButtonBottomConstraint];
        
        // --------------------
        // The button "Choose".
        // --------------------
        
        constant = self.portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace;
        self.chooseButtonTrailingConstraint = [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeTrailing relatedBy:NSLayoutRelationEqual
                                                                              toItem:self.chooseButton attribute:NSLayoutAttributeTrailing multiplier:1.0f
                                                                            constant:constant];
        [self.view addConstraint:self.chooseButtonTrailingConstraint];
        
        constant = self.portraitCropViewBottomAndChooseButtonBottomVerticalSpace;
        self.chooseButtonBottomConstraint = [NSLayoutConstraint constraintWithItem:self.view attribute:NSLayoutAttributeBottom relatedBy:NSLayoutRelationEqual
                                                                            toItem:self.chooseButton attribute:NSLayoutAttributeBottom multiplier:1.0f
                                                                          constant:constant];
        [self.view addConstraint:self.chooseButtonBottomConstraint];
        
        self.didSetupConstraints = YES;
    } else {
        if ([self isPortraitInterfaceOrientation]) {
            self.titleLabelTopConstraint.constant = self.portraitTitleLabelTopAndCropViewTopVerticalSpace;
            self.cancelButtonBottomConstraint.constant = self.portraitCropViewBottomAndCancelButtonBottomVerticalSpace;
            self.cancelButtonLeadingConstraint.constant = self.portraitCancelButtonLeadingAndCropViewLeadingHorizontalSpace;
            self.chooseButtonBottomConstraint.constant = self.portraitCropViewBottomAndChooseButtonBottomVerticalSpace;
            self.chooseButtonTrailingConstraint.constant = self.portraitCropViewTrailingAndChooseButtonTrailingHorizontalSpace;
        } else {
            self.titleLabelTopConstraint.constant = self.landscapeTitleLabelTopAndCropViewTopVerticalSpace;
            self.cancelButtonBottomConstraint.constant = self.landscapeCropViewBottomAndCancelButtonBottomVerticalSpace;
            self.cancelButtonLeadingConstraint.constant = self.landscapeCancelButtonLeadingAndCropViewLeadingHorizontalSpace;
            self.chooseButtonBottomConstraint.constant = self.landscapeCropViewBottomAndChooseButtonBottomVerticalSpace;
            self.chooseButtonTrailingConstraint.constant = self.landscapeCropViewTrailingAndChooseButtonTrailingHorizontalSpace;
        }
    }
}

#pragma mark - Custom Accessors

- (RSKImageScrollView *)imageScrollView
{
    if (!_imageScrollView) {
        _imageScrollView = [[RSKImageScrollView alloc] init];
        _imageScrollView.clipsToBounds = NO;
        _imageScrollView.aspectFill = self.avoidEmptySpaceAroundImage;
        _imageScrollView.alwaysBounceHorizontal = self.alwaysBounceHorizontal;
        _imageScrollView.alwaysBounceVertical = self.alwaysBounceVertical;
    }
    return _imageScrollView;
}

- (RSKTouchView *)overlayView
{
    if (!_overlayView) {
        _overlayView = [[RSKTouchView alloc] init];
        _overlayView.receiver = self.imageScrollView;
        [_overlayView.layer addSublayer:self.maskLayer];
    }
    return _overlayView;
}

- (RSKTouchView *)supplementalView
{
    if (!_supplementalView) {
        _supplementalView = [[RSKTouchView alloc] init];
        _supplementalView.receiver = self.imageScrollView;
        [_supplementalView.layer addSublayer:self.supplementalMaskLayer];
    }
    return _supplementalView;
}

- (RSKTouchView *)guidelineView
{
    if (!_guidelineView) {
        _guidelineView = [[RSKTouchView alloc] init];
        _guidelineView.receiver = self.imageScrollView;
        _guidelineView.backgroundColor = [UIColor clearColor];
        _guidelineView.layer.borderColor = [[UIColor whiteColor] CGColor];
        _guidelineView.layer.borderWidth = 1.0;
    }
    return _guidelineView;
}

- (RSKTouchView *)supplementalGuidelineView
{
    if (!_supplementalGuidelineView) {
        _supplementalGuidelineView = [[RSKTouchView alloc] init];
        _supplementalGuidelineView.receiver = self.imageScrollView;
        _supplementalGuidelineView.backgroundColor = [UIColor clearColor];
        _supplementalGuidelineView.layer.borderColor = [UIColor colorWithRed:1.0f green:0.0f blue:0.0f alpha:0.9f].CGColor;

        _supplementalGuidelineView.layer.borderWidth = 0.5;
    }
    return _supplementalGuidelineView;
}

- (CAShapeLayer *)maskLayer
{
    if (!_maskLayer) {
        _maskLayer = [CAShapeLayer layer];
        _maskLayer.fillRule = kCAFillRuleEvenOdd;
        _maskLayer.fillColor = self.maskLayerColor.CGColor;
        _maskLayer.lineWidth = self.maskLayerLineWidth;
        _maskLayer.strokeColor = self.maskLayerStrokeColor.CGColor;
    }
    return _maskLayer;
}

- (CAShapeLayer *)supplementalMaskLayer
{
    if (!_supplementalMaskLayer) {
        _supplementalMaskLayer = [CAShapeLayer layer];
        _supplementalMaskLayer.fillRule = kCAFillRuleEvenOdd;
        _supplementalMaskLayer.fillColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.2f].CGColor;
        _supplementalMaskLayer.lineWidth = self.maskLayerLineWidth;
        _supplementalMaskLayer.strokeColor = self.maskLayerStrokeColor.CGColor;
    }
    return _supplementalMaskLayer;
}

- (UIColor *)maskLayerColor
{
    if (!_maskLayerColor) {
        _maskLayerColor = [UIColor colorWithRed:0.0f green:0.0f blue:0.0f alpha:0.7f];
    }
    return _maskLayerColor;
}

- (UILabel *)titleLabel
{
    if (!_titleLabel) {
        _titleLabel = [[UILabel alloc] init];
        _titleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _titleLabel.backgroundColor = [UIColor clearColor];
        _titleLabel.text = RSKLocalizedString(@"Move and Scale", @"Move and Scale label");
        if(_titleLabelText) {
            _titleLabel.text = _titleLabelText;
        }
        _titleLabel.textColor = [UIColor whiteColor];
        if(_titleLabelColor) {
            _titleLabel.textColor = _titleLabelColor;
        }
        if(_titleLabelFont) {
            _titleLabel.font = _titleLabelFont;
        }

        _titleLabel.opaque = NO;
    }
    return _titleLabel;
}

- (UILabel *)subtitleLabel
{
    if (!_subtitleLabel) {
        _subtitleLabel = [[UILabel alloc] init];
        _subtitleLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _subtitleLabel.textAlignment = NSTextAlignmentCenter;
        _subtitleLabel.numberOfLines = 0;
        _subtitleLabel.text = RSKLocalizedString(@"Move and Scale", @"Move and Scale label");
        if(_subtitleLabelText) {
            _subtitleLabel.text = _subtitleLabelText;
        }
        _subtitleLabel.textColor = [UIColor whiteColor];
        if(_subtitleLabelColor) {
            _subtitleLabel.textColor = _subtitleLabelColor;
        }

        if(_subtitleLabelFont) {
            _subtitleLabel.font = _subtitleLabelFont;
        }

        _subtitleLabel.opaque = NO;
    }
    return _subtitleLabel;
}

- (UILabel *)cropViewLabel
{
    if (!_cropViewLabel) {
        _cropViewLabel = [[UILabel alloc] init];
        _cropViewLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _cropViewLabel.backgroundColor = [UIColor clearColor];
        _cropViewLabel.text = @"Mobile View";
        if(_cropViewLabelText) {
            _cropViewLabel.text = _cropViewLabelText;
        }
        _cropViewLabel.textColor = [UIColor whiteColor];
        if(_cropViewLabelColor) {
            _cropViewLabel.textColor = _cropViewLabelColor;
        }
        if(_cropViewLabelFont) {
            _cropViewLabel.font = _cropViewLabelFont;
        }

        _cropViewLabel.opaque = NO;
    }
    return _cropViewLabel;
}

- (UILabel *)supplementalViewLabel
{
    if (!_supplementalViewLabel) {
        _supplementalViewLabel = [[UILabel alloc] init];
        _supplementalViewLabel.translatesAutoresizingMaskIntoConstraints = NO;
        _supplementalViewLabel.backgroundColor = [UIColor clearColor];
        _supplementalViewLabel.text = @"Desktop View";
        if(_supplementalViewLabelText) {
            _supplementalViewLabel.text = _supplementalViewLabelText;
        }
        _supplementalViewLabel.textColor = [UIColor whiteColor];
        if(_supplementalViewLabelColor) {
            _supplementalViewLabel.textColor = _supplementalViewLabelColor;
        }
        if(_supplementalViewLabelFont) {
            _supplementalViewLabel.font = _supplementalViewLabelFont;
        }

        _supplementalViewLabel.opaque = NO;
    }
    return _supplementalViewLabel;
}

- (UIButton *)cancelButton
{
    if (!_cancelButton) {
        _cancelButton = [[UIButton alloc] init];
        _cancelButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_cancelButton setTitle:RSKLocalizedString(@"Cancel", @"Cancel button") forState:UIControlStateNormal];
        if (_cancelButtonFont) {
            _cancelButton.titleLabel.font = _cancelButtonFont;
        }
        if (_cancelButtonTextColor) {
            [_cancelButton setTitleColor:_cancelButtonTextColor forState:UIControlStateNormal];
        }
        [_cancelButton addTarget:self action:@selector(onCancelButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _cancelButton.opaque = NO;
    }
    return _cancelButton;
}

- (UIButton *)chooseButton
{
    if (!_chooseButton) {
        _chooseButton = [[UIButton alloc] init];
        _chooseButton.translatesAutoresizingMaskIntoConstraints = NO;
        [_chooseButton setTitle:RSKLocalizedString(@"Choose", @"Choose button") forState:UIControlStateNormal];
        if (_chooseButtonFont) {
            _chooseButton.titleLabel.font = _chooseButtonFont;
        }
        if (_chooseButtonTextColor) {
            [_chooseButton setTitleColor:_chooseButtonTextColor forState:UIControlStateNormal];
        }
        [_chooseButton addTarget:self action:@selector(onChooseButtonTouch:) forControlEvents:UIControlEventTouchUpInside];
        _chooseButton.opaque = NO;
    }
    return _chooseButton;
}

- (UITapGestureRecognizer *)doubleTapGestureRecognizer
{
    if (!_doubleTapGestureRecognizer) {
        _doubleTapGestureRecognizer = [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleDoubleTap:)];
        _doubleTapGestureRecognizer.delaysTouchesEnded = NO;
        _doubleTapGestureRecognizer.numberOfTapsRequired = 2;
        _doubleTapGestureRecognizer.delegate = self;
    }
    return _doubleTapGestureRecognizer;
}

- (UIRotationGestureRecognizer *)rotationGestureRecognizer
{
    if (!_rotationGestureRecognizer) {
        _rotationGestureRecognizer = [[UIRotationGestureRecognizer alloc] initWithTarget:self action:@selector(handleRotation:)];
        _rotationGestureRecognizer.delaysTouchesEnded = NO;
        _rotationGestureRecognizer.delegate = self;
        _rotationGestureRecognizer.enabled = self.isRotationEnabled;
    }
    return _rotationGestureRecognizer;
}

- (CGRect)imageRect
{
    float zoomScale = 1.0 / self.imageScrollView.zoomScale;
    
    CGRect imageRect = CGRectZero;
    
    imageRect.origin.x = self.imageScrollView.contentOffset.x * zoomScale;
    imageRect.origin.y = self.imageScrollView.contentOffset.y * zoomScale;
    imageRect.size.width = CGRectGetWidth(self.imageScrollView.bounds) * zoomScale;
    imageRect.size.height = CGRectGetHeight(self.imageScrollView.bounds) * zoomScale;
    
    imageRect = RSKRectNormalize(imageRect);
    
    CGSize imageSize = self.originalImage.size;
    CGFloat x = CGRectGetMinX(imageRect);
    CGFloat y = CGRectGetMinY(imageRect);
    CGFloat width = CGRectGetWidth(imageRect);
    CGFloat height = CGRectGetHeight(imageRect);
    
    UIImageOrientation imageOrientation = self.originalImage.imageOrientation;
    if (imageOrientation == UIImageOrientationRight || imageOrientation == UIImageOrientationRightMirrored) {
        imageRect.origin.x = y;
        imageRect.origin.y = floor(imageSize.width - CGRectGetWidth(imageRect) - x);
        imageRect.size.width = height;
        imageRect.size.height = width;
    } else if (imageOrientation == UIImageOrientationLeft || imageOrientation == UIImageOrientationLeftMirrored) {
        imageRect.origin.x = floor(imageSize.height - CGRectGetHeight(imageRect) - y);
        imageRect.origin.y = x;
        imageRect.size.width = height;
        imageRect.size.height = width;
    } else if (imageOrientation == UIImageOrientationDown || imageOrientation == UIImageOrientationDownMirrored) {
        imageRect.origin.x = floor(imageSize.width - CGRectGetWidth(imageRect) - x);
        imageRect.origin.y = floor(imageSize.height - CGRectGetHeight(imageRect) - y);
    }
    
    CGFloat imageScale = self.originalImage.scale;
    imageRect = CGRectApplyAffineTransform(imageRect, CGAffineTransformMakeScale(imageScale, imageScale));
    
    return imageRect;
}

- (CGRect)cropRect
{
    CGRect maskRect = self.maskRect;
    CGFloat rotationAngle = self.rotationAngle;
    CGRect rotatedImageScrollViewFrame = self.imageScrollView.frame;
    float zoomScale = 1.0 / self.imageScrollView.zoomScale;
    
    CGAffineTransform imageScrollViewTransform = self.imageScrollView.transform;
    self.imageScrollView.transform = CGAffineTransformIdentity;
    
    CGRect imageScrollViewFrame = self.imageScrollView.frame;
    self.imageScrollView.frame = self.maskRect;
    
    CGRect imageFrame = CGRectZero;
    imageFrame.origin.x = CGRectGetMinX(maskRect) - self.imageScrollView.contentOffset.x;
    imageFrame.origin.y = CGRectGetMinY(maskRect) - self.imageScrollView.contentOffset.y;
    imageFrame.size = self.imageScrollView.contentSize;
    
    CGFloat tx = CGRectGetMinX(imageFrame) + self.imageScrollView.contentOffset.x + CGRectGetWidth(maskRect) * 0.5f;
    CGFloat ty = CGRectGetMinY(imageFrame) + self.imageScrollView.contentOffset.y + CGRectGetHeight(maskRect) * 0.5f;
    
    CGFloat sx = CGRectGetWidth(rotatedImageScrollViewFrame) / CGRectGetWidth(imageScrollViewFrame);
    CGFloat sy = CGRectGetHeight(rotatedImageScrollViewFrame) / CGRectGetHeight(imageScrollViewFrame);
    
    CGAffineTransform t1 = CGAffineTransformMakeTranslation(-tx, -ty);
    CGAffineTransform t2 = CGAffineTransformMakeRotation(rotationAngle);
    CGAffineTransform t3 = CGAffineTransformMakeScale(sx, sy);
    CGAffineTransform t4 = CGAffineTransformMakeTranslation(tx, ty);
    CGAffineTransform t1t2 = CGAffineTransformConcat(t1, t2);
    CGAffineTransform t1t2t3 = CGAffineTransformConcat(t1t2, t3);
    CGAffineTransform t1t2t3t4 = CGAffineTransformConcat(t1t2t3, t4);
    
    imageFrame = CGRectApplyAffineTransform(imageFrame, t1t2t3t4);
    
    CGRect cropRect = CGRectMake(0.0, 0.0, CGRectGetWidth(maskRect), CGRectGetHeight(maskRect));
    
    cropRect.origin.x = -CGRectGetMinX(imageFrame) + CGRectGetMinX(maskRect);
    cropRect.origin.y = -CGRectGetMinY(imageFrame) + CGRectGetMinY(maskRect);
    
    cropRect = CGRectApplyAffineTransform(cropRect, CGAffineTransformMakeScale(zoomScale, zoomScale));
    
    cropRect = RSKRectNormalize(cropRect);
    
    CGFloat imageScale = self.originalImage.scale;
    cropRect = CGRectApplyAffineTransform(cropRect, CGAffineTransformMakeScale(imageScale, imageScale));
    
    self.imageScrollView.frame = imageScrollViewFrame;
    self.imageScrollView.transform = imageScrollViewTransform;
    
    return cropRect;
}

- (CGRect)rectForClipPath
{
    if (!self.maskLayerStrokeColor) {
        return self.overlayView.frame;
    } else {
        CGFloat maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0;
        return CGRectInset(self.overlayView.frame, -maskLayerLineHalfWidth, -maskLayerLineHalfWidth);
    }
}

- (CGRect)rectForMaskPath
{
    if (!self.maskLayerStrokeColor) {
        return self.maskRect;
    } else {
        CGFloat maskLayerLineHalfWidth = self.maskLayerLineWidth / 2.0;
        return CGRectInset(self.maskRect, maskLayerLineHalfWidth, maskLayerLineHalfWidth);
    }
}

- (CGFloat)rotationAngle
{
    CGAffineTransform transform = self.imageScrollView.transform;
    CGFloat rotationAngle = atan2(transform.b, transform.a);
    return rotationAngle;
}

- (CGFloat)zoomScale
{
    return self.imageScrollView.zoomScale;
}

- (void)setAvoidEmptySpaceAroundImage:(BOOL)avoidEmptySpaceAroundImage
{
    if (_avoidEmptySpaceAroundImage != avoidEmptySpaceAroundImage) {
        _avoidEmptySpaceAroundImage = avoidEmptySpaceAroundImage;
        
        self.imageScrollView.aspectFill = avoidEmptySpaceAroundImage;
    }
}

- (void)setAlwaysBounceVertical:(BOOL)alwaysBounceVertical
{
    if (_alwaysBounceVertical != alwaysBounceVertical) {
        _alwaysBounceVertical = alwaysBounceVertical;
        
        self.imageScrollView.alwaysBounceVertical = alwaysBounceVertical;
    }
}

- (void)setAlwaysBounceHorizontal:(BOOL)alwaysBounceHorizontal
{
    if (_alwaysBounceHorizontal != alwaysBounceHorizontal) {
        _alwaysBounceHorizontal = alwaysBounceHorizontal;
        
        self.imageScrollView.alwaysBounceHorizontal = alwaysBounceHorizontal;
    }
}

- (void)setCropMode:(RSKImageCropMode)cropMode
{
    if (_cropMode != cropMode) {
        _cropMode = cropMode;
        
        if (self.imageScrollView.zoomView) {
            [self reset:NO];
        }
    }
}

- (void)setOriginalImage:(UIImage *)originalImage
{
    if (![_originalImage isEqual:originalImage]) {
        _originalImage = originalImage;
        if (self.isViewLoaded && self.view.window) {
            [self displayImage];
        }
    }
}

- (void)setMaskPath:(UIBezierPath *)maskPath
{
    if (![_maskPath isEqual:maskPath]) {
        _maskPath = maskPath;
        
        UIBezierPath *clipPath = [UIBezierPath bezierPathWithRect:self.rectForClipPath];
        [clipPath appendPath:maskPath];
        clipPath.usesEvenOddFillRule = YES;
        
        CABasicAnimation *pathAnimation = [CABasicAnimation animationWithKeyPath:@"path"];
        pathAnimation.duration = [CATransaction animationDuration];
        pathAnimation.timingFunction = [CATransaction animationTimingFunction];
        [self.maskLayer addAnimation:pathAnimation forKey:@"path"];

        self.maskLayer.path = [clipPath CGPath];


        if ([self.dataSource respondsToSelector:@selector(imageCropViewControllerSupplementalViewMaskPath:)]) {
            UIBezierPath *supplementalMaskPath = [self.dataSource imageCropViewControllerSupplementalViewMaskPath:self];
            UIBezierPath *supplementalClipPath = [UIBezierPath bezierPathWithRect:self.rectForClipPath];
            [supplementalClipPath appendPath:supplementalMaskPath];
            supplementalClipPath.usesEvenOddFillRule = YES;
            self.supplementalMaskLayer.path = [supplementalClipPath CGPath];
        }
    }
}

- (void)setRotationAngle:(CGFloat)rotationAngle
{
    if (self.rotationAngle != rotationAngle) {
        CGFloat rotation = (rotationAngle - self.rotationAngle);
        CGAffineTransform transform = CGAffineTransformRotate(self.imageScrollView.transform, rotation);
        self.imageScrollView.transform = transform;
    }
}

- (void)setRotationEnabled:(BOOL)rotationEnabled
{
    if (_rotationEnabled != rotationEnabled) {
        _rotationEnabled = rotationEnabled;
        
        self.rotationGestureRecognizer.enabled = rotationEnabled;
    }
}

- (void)setZoomScale:(CGFloat)zoomScale
{
    self.imageScrollView.zoomScale = zoomScale;
}

#pragma mark - Action handling

- (void)onCancelButtonTouch:(UIBarButtonItem *)sender
{
    [self cancelCrop];
}

- (void)onChooseButtonTouch:(UIBarButtonItem *)sender
{
    [self cropImage];
}

- (void)handleDoubleTap:(UITapGestureRecognizer *)gestureRecognizer
{
    [self reset:YES];
}

- (void)handleRotation:(UIRotationGestureRecognizer *)gestureRecognizer
{
    [self setRotationAngle:(self.rotationAngle + gestureRecognizer.rotation)];
    gestureRecognizer.rotation = 0;
    
    if (gestureRecognizer.state == UIGestureRecognizerStateEnded) {
        [UIView animateWithDuration:kLayoutImageScrollViewAnimationDuration
                              delay:0.0
                            options:UIViewAnimationOptionBeginFromCurrentState
                         animations:^{
                             [self layoutImageScrollView];
                         }
                         completion:nil];
    }
}

- (void)zoomToRect:(CGRect)rect animated:(BOOL)animated
{
    [self.imageScrollView zoomToRect:rect animated:animated];
}

#pragma mark - Public

- (BOOL)isPortraitInterfaceOrientation
{
    return CGRectGetHeight(self.view.bounds) > CGRectGetWidth(self.view.bounds);
}

#pragma mark - Private

- (void)reset:(BOOL)animated
{
    if (animated) {
        [UIView beginAnimations:@"rsk_reset" context:NULL];
        [UIView setAnimationCurve:UIViewAnimationCurveEaseInOut];
        [UIView setAnimationDuration:kResetAnimationDuration];
        [UIView setAnimationBeginsFromCurrentState:YES];
    }
    
    [self resetRotation];
    [self resetFrame];
    [self resetZoomScale];
    [self resetContentOffset];
    
    if (animated) {
        [UIView commitAnimations];
    }
}

- (void)resetContentOffset
{
    CGSize boundsSize = self.imageScrollView.bounds.size;
    CGRect frameToCenter = self.imageScrollView.zoomView.frame;
    
    CGPoint contentOffset;
    if (CGRectGetWidth(frameToCenter) > boundsSize.width) {
        contentOffset.x = (CGRectGetWidth(frameToCenter) - boundsSize.width) * 0.5f;
    } else {
        contentOffset.x = 0;
    }
    if (CGRectGetHeight(frameToCenter) > boundsSize.height) {
        contentOffset.y = (CGRectGetHeight(frameToCenter) - boundsSize.height) * 0.5f;
    } else {
        contentOffset.y = 0;
    }
    
    self.imageScrollView.contentOffset = contentOffset;
}

- (void)resetFrame
{
    [self layoutImageScrollView];
}

- (void)resetRotation
{
    [self setRotationAngle:0.0];
}

- (void)resetZoomScale
{
    CGFloat zoomScale;
    if (CGRectGetWidth(self.view.bounds) > CGRectGetHeight(self.view.bounds)) {
        zoomScale = CGRectGetHeight(self.view.bounds) / self.originalImage.size.height;
    } else {
        zoomScale = CGRectGetWidth(self.view.bounds) / self.originalImage.size.width;
    }
    self.imageScrollView.zoomScale = zoomScale;
}

- (NSArray *)intersectionPointsOfLineSegment:(RSKLineSegment)lineSegment withRect:(CGRect)rect
{
    RSKLineSegment top = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
                                            CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)));
    
    RSKLineSegment right = RSKLineSegmentMake(CGPointMake(CGRectGetMaxX(rect), CGRectGetMinY(rect)),
                                              CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)));
    
    RSKLineSegment bottom = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)),
                                               CGPointMake(CGRectGetMaxX(rect), CGRectGetMaxY(rect)));
    
    RSKLineSegment left = RSKLineSegmentMake(CGPointMake(CGRectGetMinX(rect), CGRectGetMinY(rect)),
                                             CGPointMake(CGRectGetMinX(rect), CGRectGetMaxY(rect)));
    
    CGPoint p0 = RSKLineSegmentIntersection(top, lineSegment);
    CGPoint p1 = RSKLineSegmentIntersection(right, lineSegment);
    CGPoint p2 = RSKLineSegmentIntersection(bottom, lineSegment);
    CGPoint p3 = RSKLineSegmentIntersection(left, lineSegment);
    
    NSMutableArray *intersectionPoints = [@[] mutableCopy];
    if (!RSKPointIsNull(p0)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p0]];
    }
    if (!RSKPointIsNull(p1)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p1]];
    }
    if (!RSKPointIsNull(p2)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p2]];
    }
    if (!RSKPointIsNull(p3)) {
        [intersectionPoints addObject:[NSValue valueWithCGPoint:p3]];
    }
    
    return [intersectionPoints copy];
}

- (void)displayImage
{
    if (self.originalImage) {
        [self.imageScrollView displayImage:self.originalImage];
        [self reset:NO];

        if ([self.delegate respondsToSelector:@selector(imageCropViewControllerDidDisplayImage:)]) {
            [self.delegate imageCropViewControllerDidDisplayImage:self];
        }
    }
}

- (void)layoutImageScrollView
{
    CGRect frame = CGRectZero;
    
    // The bounds of the image scroll view should always fill the mask area.
    switch (self.cropMode) {
        case RSKImageCropModeSquare: {
            if (self.rotationAngle == 0.0) {
                frame = self.maskRect;
            } else {
                // Step 1: Rotate the left edge of the initial rect of the image scroll view clockwise around the center by `rotationAngle`.
                CGRect initialRect = self.maskRect;
                CGFloat rotationAngle = self.rotationAngle;
                
                CGPoint leftTopPoint = CGPointMake(initialRect.origin.x, initialRect.origin.y);
                CGPoint leftBottomPoint = CGPointMake(initialRect.origin.x, initialRect.origin.y + initialRect.size.height);
                RSKLineSegment leftLineSegment = RSKLineSegmentMake(leftTopPoint, leftBottomPoint);
                
                CGPoint pivot = RSKRectCenterPoint(initialRect);
                
                CGFloat alpha = fabs(rotationAngle);
                RSKLineSegment rotatedLeftLineSegment = RSKLineSegmentRotateAroundPoint(leftLineSegment, pivot, alpha);
                
                // Step 2: Find the points of intersection of the rotated edge with the initial rect.
                NSArray *points = [self intersectionPointsOfLineSegment:rotatedLeftLineSegment withRect:initialRect];
                
                // Step 3: If the number of intersection points more than one
                // then the bounds of the rotated image scroll view does not completely fill the mask area.
                // Therefore, we need to update the frame of the image scroll view.
                // Otherwise, we can use the initial rect.
                if (points.count > 1) {
                    // We have a right triangle.
                    
                    // Step 4: Calculate the altitude of the right triangle.
                    if ((alpha > M_PI_2) && (alpha < M_PI)) {
                        alpha = alpha - M_PI_2;
                    } else if ((alpha > (M_PI + M_PI_2)) && (alpha < (M_PI + M_PI))) {
                        alpha = alpha - (M_PI + M_PI_2);
                    }
                    CGFloat sinAlpha = sin(alpha);
                    CGFloat cosAlpha = cos(alpha);
                    CGFloat hypotenuse = RSKPointDistance([points[0] CGPointValue], [points[1] CGPointValue]);
                    CGFloat altitude = hypotenuse * sinAlpha * cosAlpha;
                    
                    // Step 5: Calculate the target width.
                    CGFloat initialWidth = CGRectGetWidth(initialRect);
                    CGFloat targetWidth = initialWidth + altitude * 2;
                    
                    // Step 6: Calculate the target frame.
                    CGFloat scale = targetWidth / initialWidth;
                    CGPoint center = RSKRectCenterPoint(initialRect);
                    frame = RSKRectScaleAroundPoint(initialRect, center, scale, scale);
                    
                    // Step 7: Avoid floats.
                    frame.origin.x = floor(CGRectGetMinX(frame));
                    frame.origin.y = floor(CGRectGetMinY(frame));
                    frame = CGRectIntegral(frame);
                } else {
                    // Step 4: Use the initial rect.
                    frame = initialRect;
                }
            }
            break;
        }
        case RSKImageCropModeCircle: {
            frame = self.maskRect;
            break;
        }
        case RSKImageCropModeCustom: {
            frame = [self.dataSource imageCropViewControllerCustomMovementRect:self];
            break;
        }
    }
    
    CGAffineTransform transform = self.imageScrollView.transform;
    self.imageScrollView.transform = CGAffineTransformIdentity;
    self.imageScrollView.frame = frame;
    self.imageScrollView.transform = transform;
}

- (void)layoutOverlayView
{
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds) * 2, CGRectGetHeight(self.view.bounds) * 2);
    self.overlayView.frame = frame;
}

- (void)layoutTestCustomView
{
    CGRect frame = CGRectMake(0, 0, CGRectGetWidth(self.view.bounds) * 2, CGRectGetHeight(self.view.bounds) * 2);
    self.supplementalView.frame = frame;
}

- (void)updateMaskRect
{
    switch (self.cropMode) {
        case RSKImageCropModeCircle: {
            CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
            CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
            
            CGFloat diameter;
            if ([self isPortraitInterfaceOrientation]) {
                diameter = MIN(viewWidth, viewHeight) - self.portraitCircleMaskRectInnerEdgeInset * 2;
            } else {
                diameter = MIN(viewWidth, viewHeight) - self.landscapeCircleMaskRectInnerEdgeInset * 2;
            }
            
            CGSize maskSize = CGSizeMake(diameter, diameter);
            
            self.maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                       (viewHeight - maskSize.height) * 0.5f,
                                       maskSize.width,
                                       maskSize.height);
            break;
        }
        case RSKImageCropModeSquare: {
            CGFloat viewWidth = CGRectGetWidth(self.view.bounds);
            CGFloat viewHeight = CGRectGetHeight(self.view.bounds);
            
            CGFloat length;
            if ([self isPortraitInterfaceOrientation]) {
                length = MIN(viewWidth, viewHeight) - self.portraitSquareMaskRectInnerEdgeInset * 2;
            } else {
                length = MIN(viewWidth, viewHeight) - self.landscapeSquareMaskRectInnerEdgeInset * 2;
            }
            
            CGSize maskSize = CGSizeMake(length, length);
            
            self.maskRect = CGRectMake((viewWidth - maskSize.width) * 0.5f,
                                       (viewHeight - maskSize.height) * 0.5f,
                                       maskSize.width,
                                       maskSize.height);
            break;
        }
        case RSKImageCropModeCustom: {
            self.maskRect = [self.dataSource imageCropViewControllerCustomMaskRect:self];
            break;
        }
    }
}

- (void)updateMaskPath
{
    switch (self.cropMode) {
        case RSKImageCropModeCircle: {
            self.maskPath = [UIBezierPath bezierPathWithOvalInRect:self.rectForMaskPath];
            break;
        }
        case RSKImageCropModeSquare: {
            self.maskPath = [UIBezierPath bezierPathWithRect:self.rectForMaskPath];
            break;
        }
        case RSKImageCropModeCustom: {
            self.maskPath = [self.dataSource imageCropViewControllerCustomMaskPath:self];
            break;
        }
    }
}

- (UIImage *)imageWithImage:(UIImage *)image inRect:(CGRect)rect scale:(CGFloat)scale imageOrientation:(UIImageOrientation)imageOrientation
{
    if (!image.images) {
        CGImageRef cgImage = CGImageCreateWithImageInRect(image.CGImage, rect);
        UIImage *image = [UIImage imageWithCGImage:cgImage scale:scale orientation:imageOrientation];
        CGImageRelease(cgImage);
        return image;
    } else {
        UIImage *animatedImage = image;
        NSMutableArray *images = [NSMutableArray array];
        for (UIImage *animatedImageImage in animatedImage.images) {
            UIImage *image = [self imageWithImage:animatedImageImage inRect:rect scale:scale imageOrientation:imageOrientation];
            [images addObject:image];
        }
        return [UIImage animatedImageWithImages:images duration:image.duration];
    }
}

- (UIImage *)croppedImage:(UIImage *)originalImage cropMode:(RSKImageCropMode)cropMode cropRect:(CGRect)cropRect imageRect:(CGRect)imageRect rotationAngle:(CGFloat)rotationAngle zoomScale:(CGFloat)zoomScale maskPath:(UIBezierPath *)maskPath applyMaskToCroppedImage:(BOOL)applyMaskToCroppedImage
{
    // Step 1: create an image using the data contained within the specified rect.
    UIImage *image = [self imageWithImage:originalImage inRect:imageRect scale:originalImage.scale imageOrientation:originalImage.imageOrientation];
    
    // Step 2: fix orientation of the image.
    image = [image fixOrientation];
    
    // Step 3: If current mode is `RSKImageCropModeSquare` and the original image is not rotated
    // or mask should not be applied to the image after cropping and the original image is not rotated,
    // we can return the image immediately.
    // Otherwise, we must further process the image.
    if ((cropMode == RSKImageCropModeSquare || !applyMaskToCroppedImage) && rotationAngle == 0.0) {
        // Step 4: return the image immediately.
        return image;
    } else {
        // Step 4: create a new context.
        CGSize contextSize = cropRect.size;
        UIGraphicsBeginImageContextWithOptions(contextSize, NO, originalImage.scale);
        
        // Step 5: apply the mask if needed.
        if (applyMaskToCroppedImage) {
            // 5a: scale the mask to the size of the crop rect.
            UIBezierPath *maskPathCopy = [maskPath copy];
            CGFloat scale = 1.0 / zoomScale;
            [maskPathCopy applyTransform:CGAffineTransformMakeScale(scale, scale)];
            
            // 5b: center the mask.
            CGPoint translation = CGPointMake(-CGRectGetMinX(maskPathCopy.bounds) + (CGRectGetWidth(cropRect) - CGRectGetWidth(maskPathCopy.bounds)) * 0.5f,
                                              -CGRectGetMinY(maskPathCopy.bounds) + (CGRectGetHeight(cropRect) - CGRectGetHeight(maskPathCopy.bounds)) * 0.5f);
            [maskPathCopy applyTransform:CGAffineTransformMakeTranslation(translation.x, translation.y)];
            
            // 5c: apply the mask.
            [maskPathCopy addClip];
        }
        
        // Step 6: rotate the image if needed.
        if (rotationAngle != 0) {
            image = [image rotateByAngle:rotationAngle];
        }
        
        // Step 7: draw the image.
        CGPoint point = CGPointMake(floor((contextSize.width - image.size.width) * 0.5f),
                                    floor((contextSize.height - image.size.height) * 0.5f));
        [image drawAtPoint:point];
        
        // Step 8: get the cropped image affter processing from the context.
        UIImage *croppedImage = UIGraphicsGetImageFromCurrentImageContext();
        
        // Step 9: remove the context.
        UIGraphicsEndImageContext();
        
        croppedImage = [UIImage imageWithCGImage:croppedImage.CGImage scale:originalImage.scale orientation:image.imageOrientation];
        
        // Step 10: return the cropped image affter processing.
        return croppedImage;
    }
}

- (void)cropImage
{
    if ([self.delegate respondsToSelector:@selector(imageCropViewController:willCropImage:)]) {
        [self.delegate imageCropViewController:self willCropImage:self.originalImage];
    }
    
    UIImage *originalImage = self.originalImage;
    RSKImageCropMode cropMode = self.cropMode;
    CGRect cropRect = self.cropRect;
    CGRect imageRect = self.imageRect;
    CGFloat rotationAngle = self.rotationAngle;
    CGFloat zoomScale = self.imageScrollView.zoomScale;
    UIBezierPath *maskPath = self.maskPath;
    BOOL applyMaskToCroppedImage = self.applyMaskToCroppedImage;
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        UIImage *croppedImage = [self croppedImage:originalImage cropMode:cropMode cropRect:cropRect imageRect:imageRect rotationAngle:rotationAngle zoomScale:zoomScale maskPath:maskPath applyMaskToCroppedImage:applyMaskToCroppedImage];
        
        dispatch_async(dispatch_get_main_queue(), ^{
            [self.delegate imageCropViewController:self didCropImage:croppedImage usingCropRect:cropRect rotationAngle:rotationAngle];
        });
    });
}

- (void)cancelCrop
{
    if ([self.delegate respondsToSelector:@selector(imageCropViewControllerDidCancelCrop:)]) {
        [self.delegate imageCropViewControllerDidCancelCrop:self];
    }
}

#pragma mark - UIGestureRecognizerDelegate

- (BOOL)gestureRecognizer:(UIGestureRecognizer *)gestureRecognizer shouldRecognizeSimultaneouslyWithGestureRecognizer:(UIGestureRecognizer *)otherGestureRecognizer
{
    return YES;
}

@end
