//
//  Navbar.h
//  Everycam
//
//  Created by Benjamin Maer on 10/2/12.
//  Copyright (c) 2012 Resplendent G.P. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "NIAttributedLabel.h"

@interface Navbar : UIView

@property (nonatomic, retain) UIView* animatableContentView;

@property (nonatomic, assign) CGFloat buttonHorizontalEdgeInset;

@property (nonatomic, retain) NIAttributedLabel* titleLabel;
@property (nonatomic, assign) CGFloat titleLabelTopEdgeInset;

@property (nonatomic, strong) UIButton* leftButton;
@property (nonatomic, strong) UIButton* rightButton;
@property (nonatomic, assign) BOOL      autoAdjustButtons;

-(id)initWithFrame:(CGRect)frame autoAdjustButtons:(BOOL)autoAdjustButtons;

//-(void)setAlphaForComponents:(CGFloat)alpha;

@end
