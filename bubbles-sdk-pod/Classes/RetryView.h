//
//  RetryView.h
//  ProximityApp
//
//  Created by Karim Koriche on 07/06/2017.
//  Copyright © 2017 Karim Koriche. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface RetryView : UIView

@property (strong, nonatomic) UIImageView *logoImageView;
@property (strong, nonatomic) UILabel *loadingLabel;
@property (strong, nonatomic) UIButton *retryButton;
@property (strong, nonatomic) UIButton *cancelbutton;

-(void)loadImageWithUrl:(NSString*)url;

@end
