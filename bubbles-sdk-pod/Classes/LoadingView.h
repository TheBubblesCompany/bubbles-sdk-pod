//
//  LoadingView.h
//  ProximityApp
//
//  Created by Karim Koriche on 07/06/2017.
//  Copyright © 2017 Karim Koriche. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <DRPLoadingSpinner/DRPLoadingSpinner.h>

@interface LoadingView : UIView

@property (strong, nonatomic)  UILabel *loadingLabel;
@property (strong, nonatomic)  UIImageView *imageLoading;

@property (strong, nonatomic)  DRPLoadingSpinner * spinner;

-(void)loadImageWithUrl:(NSString*)url;

-(void)showActivityLoader;
-(void)hideActivityLoader;

@end
