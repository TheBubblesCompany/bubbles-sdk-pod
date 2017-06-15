//
//  BubbleHybridViewController.h
//  BubblesTwo
//
//  Created by Aurélien SEMENCE Bubbles on 23/06/2016.
//  Copyright © 2016 Absolutlabs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <WebViewJavascriptBridge/WKWebViewJavascriptBridge.h>
#import <WebKit/WebKit.h>
#import "BubbleServiceView.h"
#import "RetryView.h"
#import "LoadingView.h"

@interface BridgeServiceHybrid : UIViewController  <WKUIDelegate, WKNavigationDelegate>

@property (strong, nonatomic) NSString * serviceUrl;
@property (strong, nonatomic) NSString * fullServiceUrl;
@property (strong, nonatomic) WKWebView * webviewService;
@property (strong, nonatomic) NSString * serviceCode;

@property (strong, nonatomic) BubbleServiceView * serviceView;
@property (strong, nonatomic) RetryView * retryView;
@property (strong, nonatomic) LoadingView * loadingView;

@property WKWebViewJavascriptBridge * bridge;

@property (weak, nonatomic) IBOutlet UIView *navigationBar;

@property (strong, nonatomic) NSTimer * bubbleTimer;
@property (strong, nonatomic) NSTimer * checkTimer;

@property (nonatomic) BOOL loading;
@property (nonatomic) BOOL callHandler;
@property (nonatomic) BOOL ready;

@property (strong, nonatomic) NSMutableArray * currentBubbles;
@property (strong, nonatomic) NSMutableArray * lastBubbles;

@property (strong, nonatomic) NSMutableArray * beacons;
@property (strong, nonatomic) NSMutableArray * lastBeacons;

@property (strong, nonatomic) NSMutableArray * exitBeacons;
@property (strong, nonatomic) NSMutableArray * exitEndBeacons;
@property (strong, nonatomic) NSMutableArray * enterBeacons;


- (void) loadServiceWithId:(NSString *)serviceId;

- (void) performBridgeProcessForWebview:(UIWebView*)webview;

- (void) metaDataChange:(NSString*)meta;

- (void) releaseService;

@end

