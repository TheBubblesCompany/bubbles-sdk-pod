//
//  LoadingView.m
//  ProximityApp
//
//  Created by Karim Koriche on 07/06/2017.
//  Copyright © 2017 Karim Koriche. All rights reserved.
//

#import "LoadingView.h"

@implementation LoadingView


-(id)initWithFrame:(CGRect)rect {
    
    self = [super initWithFrame:rect];
    
    if (self) {
        
        self.backgroundColor = [UIColor whiteColor];
        
        _imageLoading = [[UIImageView alloc] initWithFrame:CGRectMake((self.frame.size.width - 130)/2, 130, 130, 130)];
        [self addSubview:_imageLoading];
        
        _loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.frame.size.width - 200)/2, 310, 200, 30)];
        [_loadingLabel setTextColor:[UIColor darkGrayColor]];
        [_loadingLabel setText:@"Chargement en cours ..."];
        _loadingLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:18.0f];
        _loadingLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_loadingLabel];
    
    }
    
    return self;
}


-(void)loadImageWithUrl:(NSString*)url
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^(void) {
        
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:url]];
        UIImage* image = [[UIImage alloc] initWithData:imageData];
        
        if(image)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                
                [_imageLoading setImage:image];
                [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    _imageLoading.alpha = 1.0;
                } completion:nil];
                
                
            });
        }
    });
}

-(void)showActivityLoader
{
    _spinner = [[DRPLoadingSpinner alloc] initWithFrame:CGRectMake((self.frame.size.width - 40)/2, 380, 40, 40)];
    _spinner.colorSequence = @[ UIColor.cyanColor ];
    _spinner.lineWidth = 3;

    [self addSubview:_spinner];

    [_spinner startAnimating];
}


-(void)hideActivityLoader
{
    [_spinner removeFromSuperview];
    [_spinner stopAnimating];
}



@end
