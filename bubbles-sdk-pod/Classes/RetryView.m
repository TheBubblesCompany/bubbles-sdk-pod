//
//  RetryView.m
//  ProximityApp
//
//  Created by Karim Koriche on 07/06/2017.
//  Copyright © 2017 Karim Koriche. All rights reserved.
//

#import "RetryView.h"

@implementation RetryView




-(id)initWithFrame:(CGRect)rect {
    
    self = [super initWithFrame:rect];
    
    if (self) {

        self.backgroundColor = [UIColor whiteColor];
        
        _logoImageView = [[UIImageView alloc] initWithFrame:CGRectMake((self.frame.size.width - 130)/2, 130, 130, 130)];
        [self addSubview:_logoImageView];
        
        _loadingLabel = [[UILabel alloc] initWithFrame:CGRectMake((self.frame.size.width - 250)/2, 280, 250, 70)];
        [_loadingLabel setText:@"Impossible de se connecter au service, veillez vérifier votre connexion internet."];
        [_loadingLabel setTextColor:[UIColor darkGrayColor]];
        _loadingLabel.numberOfLines = 0;
        _loadingLabel.font = [UIFont fontWithName:@"HelveticaNeue-Light" size:17.0f];
        _loadingLabel.textAlignment = NSTextAlignmentCenter;
        [self addSubview:_loadingLabel];
        
        _retryButton = [UIButton buttonWithType:UIButtonTypeCustom];
        [_retryButton setFrame:CGRectMake((self.frame.size.width - 250)/2, 380, 250, 50)];
        _retryButton.backgroundColor = [UIColor colorWithRed:52/255.0 green:189/255.0 blue:204/255.0 alpha:1.0];
        [_retryButton setTitle:@"Réessayer" forState:UIControlStateNormal];
        _retryButton.titleLabel.textColor = [UIColor whiteColor];
        _retryButton.layer.cornerRadius = 25;
        [self addSubview:_retryButton];
        
        _cancelbutton = [[UIButton alloc] initWithFrame:CGRectMake((self.frame.size.width - 250)/2, 440, 250, 50)];
        [_cancelbutton setTitle:@"Quitter" forState:UIControlStateNormal];
        [_cancelbutton setTitleColor:[UIColor grayColor] forState:UIControlStateNormal];
        _cancelbutton.layer.borderWidth = 1;
        _cancelbutton.layer.cornerRadius = 25;
        _cancelbutton.layer.borderColor = [UIColor lightGrayColor].CGColor;
        
        [self addSubview:_cancelbutton];
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
                
                [_logoImageView setImage:image];
                [UIView animateWithDuration:0.05 delay:0.0 options:UIViewAnimationOptionCurveEaseInOut animations:^{
                    _logoImageView.alpha = 1.0;
                } completion:nil];
                
                
            });
        }
    });
}



@end
