//
//  BubbleHybridViewController.m
//  BubblesTwo
//
//  Created by Aurélien SEMENCE Bubbles on 24/06/2016.
//  Copyright © 2016 Absolutlabs. All rights reserved.
//

#import "BridgeServiceHybrid.h"
#import <WebViewJavascriptBridge/WKWebViewJavascriptBridge.h>
#import "Bubbles.h"
#import "DataAccess.h"
#import "UIColor+Expanded.h"
#import <WebKit/WebKit.h>
#import <CoreLocation/CoreLocation.h>
#import "BubbleServiceView.h"
#import "RetryView.h"


@interface BridgeServiceHybrid() <BubblesDelegate, WKNavigationDelegate>

@property (assign) BOOL successURI;
@property (assign) BOOL webviewIsSubview;
@property (assign) NSUInteger currentLocationState;
@property (strong, nonatomic) NSTimer * keepWebViewActiveTimer;
@property (strong, nonatomic) NSString * currentServiceID;
@property (strong, nonatomic) NSString * currentPictoSplashscreen;
@property (strong, nonatomic) NSString * currentBackgroundColor;

@end



@implementation BridgeServiceHybrid


static BridgeServiceHybrid * _sharedInstance;

-(void)setLoading:(BOOL)loading
{
    if (self.loading != loading) {
        _loading = loading;
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    NSLog(@"load view");
    
    
    _sharedInstance = self;
    
    
    _exitBeacons = [NSMutableArray new];
    _enterBeacons = [NSMutableArray new];
    
    _lastBeacons = [NSMutableArray new];
    
    _beacons = [[NSMutableArray alloc] init];
    
    
    
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"onChangeBeacons" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(updateBeacons:) name:@"onChangeBeacons" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"bluetoothEnabled" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(updateBluetoothEnabled:) name:@"bluetoothEnabled" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"bluetoothDisabled" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(updateBluetoothDisabled:) name:@"bluetoothDisabled" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"locationEnabled" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(updateLocationEnabled) name:@"locationEnabled" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"locationDisabled" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(updateLocationDisabled) name:@"locationDisabled" object:nil];
    
    
    self.loading = NO;
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastBeacons"];
    NSMutableArray * arrlastBeacons = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    NSMutableArray * lastBeaconsTemp = [NSKeyedUnarchiver unarchiveObjectWithData:
                                        [NSKeyedArchiver archivedDataWithRootObject:arrlastBeacons]];
    
    for (NSMutableArray * arrayBeacon in lastBeaconsTemp)
    {
        CLBeacon * beacon = [arrayBeacon objectAtIndex:0];
        NSMutableDictionary * dictBeacon = [arrayBeacon objectAtIndex:1];
        
        if (![[dictBeacon objectForKey:@"minor"] isEqualToString:@"0"] &&
            ![[dictBeacon objectForKey:@"major"] isEqualToString:@"0"] ) {
            
            if (![[dictBeacon objectForKey:@"event"] isEqualToString:@"EXIT"])
            {
                
                NSString * beaconUUID = beacon.proximityUUID.UUIDString;
                NSString* UUIDstr = [beaconUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
                
                NSMutableDictionary * newBeacon = [NSMutableDictionary new];
                
                NSString * beaconMinor = [dictBeacon objectForKey:@"minor"];
                NSString * beaconMajor = [dictBeacon objectForKey:@"major"];
                
                if (beaconMinor.length == 1)
                    beaconMinor = [NSString stringWithFormat:@"000%@", beaconMinor];
                else if (beaconMinor.length == 2)
                    beaconMinor = [NSString stringWithFormat:@"00%@", beaconMinor];
                else if (beaconMinor.length == 3)
                    beaconMinor = [NSString stringWithFormat:@"0%@", beaconMinor];
                
                if (beaconMajor.length == 1)
                    beaconMajor = [NSString stringWithFormat:@"000%@", beaconMajor];
                else if (beaconMajor.length == 2)
                    beaconMajor = [NSString stringWithFormat:@"00%@", beaconMajor];
                else if (beaconMajor.length == 3)
                    beaconMajor = [NSString stringWithFormat:@"0%@", beaconMajor];
                
                [newBeacon setObject:beaconMinor forKey:@"minor"];
                [newBeacon setObject:beaconMajor forKey:@"major"];
                [newBeacon setObject:[dictBeacon objectForKey:@"event"] forKey:@"event"];
                [newBeacon setObject:UUIDstr forKey:@"uuid"];
                
                
                [_beacons addObject:newBeacon];
            }
        }
    }
    
    _lastBeacons = [NSMutableArray new];
    _lastBeacons = [NSMutableArray arrayWithArray:_beacons];
    
    
    _checkTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                   target:self
                                                 selector:@selector(checkHidden)
                                                 userInfo:nil
                                                  repeats:YES];
    
    
}

-(void)checkHidden
{
    if (_webviewService.superview || _webviewService.window)
    {
        [self checkLocation];
        
        _webviewIsSubview = YES;
    }
    
    if (_webviewIsSubview && (!_webviewService.superview || !_webviewService.window))
    {
        [self performSelector:@selector(releaseService) withObject:nil];
    }
}

-(void)checkLocation
{
    if ([CLLocationManager authorizationStatus]==kCLAuthorizationStatusDenied)
    {
        if ([CLLocationManager authorizationStatus] != _currentLocationState)
        {
            _currentLocationState = [CLLocationManager authorizationStatus];
            
            [self updateLocationDisabled];
        }
    }
    else
    {
        if ([CLLocationManager authorizationStatus] != _currentLocationState)
        {
            _currentLocationState = [CLLocationManager authorizationStatus];
            
            [self updateLocationEnabled];
        }
    }
}




-(void)loadServiceWithId:(NSString *)serviceId
{
    int timeout = 5;
    
    _currentServiceID = serviceId;
    
    
    [self performSelector:@selector(serviceTimeout) withObject:nil afterDelay:timeout];
    
    
    NSMutableDictionary * services = [[NSUserDefaults standardUserDefaults] objectForKey:@"services"];
    
    if(services)
    {
        NSMutableDictionary * service = [services objectForKey:@"service"];
        
        bool flag = NO;
        for (NSMutableDictionary * srv in service) {
            
            if ([[srv objectForKey:@"id"] isEqualToString:serviceId])
            {
                flag = YES;
                
                NSLog(@"currentService : %@", service);
                
                _serviceUrl = [srv objectForKey:@"open_url"];
                _currentPictoSplashscreen = [srv objectForKey:@"picto_splashscreen"];
                _currentBackgroundColor = [srv objectForKey:@"picto_color"];
                
                break;
            }
        }
    }
    
    _fullServiceUrl = _serviceUrl;
    
    NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:_fullServiceUrl]];
    NSMutableURLRequest *mutableRequest = [request mutableCopy];
    
    [mutableRequest addValue:DATA.applicationLanguage forHTTPHeaderField:@"X-Application-Language"];
    [mutableRequest addValue:[NSString stringWithFormat:@"%f", [UIScreen mainScreen].scale] forHTTPHeaderField:@"X-Device-Scale"];
    [mutableRequest addValue:DATA.deviceId forHTTPHeaderField:@"X-Device-ID"];
    
    if ([[NSUserDefaults standardUserDefaults]  valueForKey:_fullServiceUrl])
        [mutableRequest addValue:[[NSUserDefaults standardUserDefaults]  valueForKey:_fullServiceUrl] forHTTPHeaderField:@"Cookie"];
    
    request = [mutableRequest copy];
    
    
    NSLog(@"allHTTPHeaderFields : %@", request.allHTTPHeaderFields);
    
    for (NSHTTPCookie* cookie in [NSHTTPCookieStorage sharedHTTPCookieStorage].cookies)
    {
        NSLog(@"Launch_Service_Cookie %@", cookie.name);
    }
    
    NSLog(@"newUrlHybrid: %@", _fullServiceUrl);
    NSLog(@"CookiesFromNSuserdefault %@", [[NSUserDefaults standardUserDefaults]  valueForKey:_fullServiceUrl]);
    
    
    WKWebViewConfiguration * config = [WKWebViewConfiguration new];
    self.webviewService = [[WKWebView alloc] initWithFrame:self.view.frame configuration:config];
    self.webviewService.scrollView.bounces = NO;
    self.webviewService.navigationDelegate = self;
    [self.webviewService loadRequest:request];
    
    
    if (!_serviceView)
    {
        _serviceView = [[BubbleServiceView alloc] init];
        
        _retryView = [[RetryView alloc] initWithFrame:self.view.frame];
        [_retryView loadImageWithUrl:_currentPictoSplashscreen];
        [_retryView.retryButton addTarget:self action:@selector(retry) forControlEvents:UIControlEventTouchUpInside];
        [_retryView.cancelbutton addTarget:self action:@selector(cancel) forControlEvents:UIControlEventTouchUpInside];
        
        _loadingView = [[LoadingView alloc] initWithFrame:self.view.frame];
        [_loadingView loadImageWithUrl:_currentPictoSplashscreen];
        [_loadingView showActivityLoader];
        [_serviceView.view addSubview:_loadingView];
    }
    
    
    self.ready = NO;
    
    
    [WKWebViewJavascriptBridge enableLogging];
    
    self.bridge = [WKWebViewJavascriptBridge bridgeForWebView:self.webviewService];
    
    [_bridge setWebViewDelegate:self];
    [self.bridge disableJavscriptAlertBoxSafetyTimeout];
    
    
    [self.bridge registerHandler:@"ready" handler:^(id data, WVJBResponseCallback responseCallback)
     {
         if (!self.ready) {
             
             self.ready = YES;
             
             [self serviceReady];
         }
     }];
    
    [self.bridge registerHandler:@"log" handler:^(id data, WVJBResponseCallback responseCallback)
     {
         NSLog(@"Bridge log: %@", data);
     }];
    
    
    [self.bridge registerHandler:@"getVersion" handler:^(id data, WVJBResponseCallback responseCallback)
     {
         NSDictionary * dictionary = @{@"success" : [NSNumber numberWithBool:YES], @"version" : @"1.3.0"};
         
         NSError * error;
         NSData   *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
         NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
         
         responseCallback(jsonString);
     }];
    
    [self.bridge registerHandler:@"getBeaconsAround" handler:^(id data, WVJBResponseCallback responseCallback)
     {
         BOOL foundBeacons;
         if (self.beacons.count > 0)
             foundBeacons = YES;
         else
             foundBeacons = NO;
         
         NSDictionary * dictionary = @{@"success" : [NSNumber numberWithBool:foundBeacons], @"beacons" : self.beacons};
         
         NSError * error;
         NSData   *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
         NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
         
         responseCallback(jsonString);
         
     }];
    
    [self.bridge registerHandler:@"openURI" handler:^(id data, WVJBResponseCallback responseCallback)
     {
         NSString *jsonString = (NSString *) data;
         
         self.successURI = NO;
         
         NSData * jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
         NSError * error=nil;
         NSDictionary * dictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
         
         NSString * url = [dictionary objectForKey:@"uri"];
         
         UIApplication *application = [UIApplication sharedApplication];
         NSURL *URL = [NSURL URLWithString:url];
         
         if ([application respondsToSelector:@selector(openURL:options:completionHandler:)])
         {
             [application openURL:URL options:@{}
                completionHandler:^(BOOL successHandler) {
                    
                    self.successURI = YES;
                    
                }];
         }
         else
         {
             BOOL successHandler = [application openURL:URL];
             self.successURI = successHandler;
             
         }
         
         NSDictionary * dictionarya = @{@"success"    : [NSNumber numberWithBool:self.successURI]};
         
         NSError * errora;
         NSData   *jsonData1 = [NSJSONSerialization dataWithJSONObject:dictionarya options:0 error:&errora];
         NSString *jsonStringReturn = [[NSString alloc] initWithData:jsonData1 encoding:NSUTF8StringEncoding];
         
         responseCallback(jsonStringReturn);
         
     }];
    
    
    [self.bridge registerHandler:@"openService" handler:^(id data, WVJBResponseCallback responseCallback)
     {
         NSString *jsonString = (NSString *) data;
         
         self.successURI = NO;
         
         NSData * jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
         NSError * error=nil;
         NSDictionary * dictionary = [NSJSONSerialization JSONObjectWithData:jsonData options:kNilOptions error:&error];
         
         NSString * service = [dictionary objectForKey:@"service_id"];
         
         
         [[NSNotificationCenter defaultCenter]postNotificationName:@"openService" object:service];
         
         
         NSDictionary * dictionarya = @{@"success"    : [NSNumber numberWithBool:YES]};
         
         NSError * errora;
         NSData   *jsonData1 = [NSJSONSerialization dataWithJSONObject:dictionarya options:0 error:&errora];
         NSString *jsonStringReturn = [[NSString alloc] initWithData:jsonData1 encoding:NSUTF8StringEncoding];
         
         responseCallback(jsonStringReturn);
         
     }];
    
    [self.bridge registerHandler:@"closeService" handler:^(id data, WVJBResponseCallback responseCallback)
     {
         
         [[NSNotificationCenter defaultCenter]postNotificationName:@"closeService" object:nil];
         
         NSDictionary * dictionary = @{@"success"    : [NSNumber numberWithBool:YES]};
         
         NSError * error;
         NSData   *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
         NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
         
         responseCallback(jsonString);
     }];
    
    
    [self checkLocation];
    
    
    if (DATA.bluetoothEnable)
    {
        [self callHandlerBluetoothStateChange:@"true"];
    }
    else
    {
        [self callHandlerBluetoothStateChange:@"false"];
    }
    
}

-(void)retry
{
    NSLog(@"hey you retry !!");
    
    [self loadServiceWithId:_currentServiceID];
    
    [_retryView removeFromSuperview];
    [_loadingView showActivityLoader];
    [_serviceView.view addSubview:_loadingView];
    
}

-(void)cancel
{
    
    NSLog(@"hey you cancel !!");
    
    Class class = NSClassFromString(@"Bubbles");
    SEL selector = NSSelectorFromString(@"onHybridServiceFail");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [class performSelector:selector];
#pragma clang diagnostic pop
    
}



-(void)serviceReady
{
    NSLog(@"serviceReady");
    
    [_loadingView removeFromSuperview];
    [_serviceView.view addSubview:self.webviewService];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(serviceTimeout) object:nil];
    
    Class class = NSClassFromString(@"Bubbles");
    SEL selector = NSSelectorFromString(@"onHybridServiceLoaded");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [class performSelector:selector];
#pragma clang diagnostic pop
    
}

-(void)serviceTimeout
{
    NSLog(@"serviceTimeouttt");
    
    [_loadingView hideActivityLoader];
    [_loadingView removeFromSuperview];
    [_serviceView.view addSubview:_retryView];
    
    [self releaseService];
    
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(serviceReady) object:nil];
}



-(void)updateBeacons:(NSNotification*)notification {
    
    [_beacons removeAllObjects];
    _beacons = [NSMutableArray new];
    
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastBeacons"];
    NSMutableArray * arrlastBeacons = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    NSMutableArray * lastBeaconsTemp = [NSKeyedUnarchiver unarchiveObjectWithData:
                                        [NSKeyedArchiver archivedDataWithRootObject:arrlastBeacons]];
    
    for (NSMutableArray * arrayBeacon in lastBeaconsTemp)
    {
        CLBeacon * beacon = [arrayBeacon objectAtIndex:0];
        NSMutableDictionary * dictBeacon = [arrayBeacon objectAtIndex:1];
        
        if (![[dictBeacon objectForKey:@"minor"] isEqualToString:@"0"] &&
            ![[dictBeacon objectForKey:@"major"] isEqualToString:@"0"] ) {
            
            
            if (![[dictBeacon objectForKey:@"event"] isEqualToString:@"EXIT"])
            {
                NSString * beaconUUID = beacon.proximityUUID.UUIDString;
                NSString* UUIDstr = [beaconUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
                
                NSMutableDictionary * newBeacon = [NSMutableDictionary new];
                
                NSString * beaconMinor = [dictBeacon objectForKey:@"minor"];
                NSString * beaconMajor = [dictBeacon objectForKey:@"major"];
                
                if (beaconMinor.length == 1)
                    beaconMinor = [NSString stringWithFormat:@"000%@", beaconMinor];
                else if (beaconMinor.length == 2)
                    beaconMinor = [NSString stringWithFormat:@"00%@", beaconMinor];
                else if (beaconMinor.length == 3)
                    beaconMinor = [NSString stringWithFormat:@"0%@", beaconMinor];
                
                if (beaconMajor.length == 1)
                    beaconMajor = [NSString stringWithFormat:@"000%@", beaconMajor];
                else if (beaconMajor.length == 2)
                    beaconMajor = [NSString stringWithFormat:@"00%@", beaconMajor];
                else if (beaconMajor.length == 3)
                    beaconMajor = [NSString stringWithFormat:@"0%@", beaconMajor];
                
                [newBeacon setObject:beaconMinor forKey:@"minor"];
                [newBeacon setObject:beaconMajor forKey:@"major"];
                [newBeacon setObject:[dictBeacon objectForKey:@"event"] forKey:@"event"];
                [newBeacon setObject:UUIDstr forKey:@"uuid"];
                
                [_beacons addObject:newBeacon];
                
            }
        }
    }
    
    
    if (_beacons.count > 0)
    {
        for (NSMutableDictionary * newBeacon in _beacons)
        {
            BOOL contain = NO;
            id lastObj = [_lastBeacons lastObject];
            for (NSMutableDictionary * lastBeacon in _lastBeacons)
            {
                if ([[lastBeacon objectForKey:@"minor"] isEqualToString:[newBeacon objectForKey:@"minor"]] &&
                    [[lastBeacon objectForKey:@"major"] isEqualToString:[newBeacon objectForKey:@"major"]])
                {
                    contain = YES;
                    
                    if(![[lastBeacon objectForKey:@"event"] isEqualToString:[newBeacon objectForKey:@"event"]])
                    {
                        [self callHandlerWithBeacon: newBeacon];
                        break;
                    }
                }
                
                if ([lastObj isEqual:lastBeacon] && !contain) // ENTER
                {
                    [self callHandlerWithBeacon:newBeacon];
                }
            }
        }
        
        NSMutableArray * lastBeaconTemp = [_lastBeacons mutableCopy];
        for (NSMutableDictionary * lastBeacon in _lastBeacons)
        {
            for (NSMutableDictionary * newBeacon in _beacons)
            {
                if ([[lastBeacon objectForKey:@"minor"] isEqualToString:[newBeacon objectForKey:@"minor"]] &&
                    [[lastBeacon objectForKey:@"major"] isEqualToString:[newBeacon objectForKey:@"major"]])
                {
                    [lastBeaconTemp removeObject:lastBeacon];
                    
                    break;
                }
            }
        }
        
        for (NSMutableDictionary * beacon in lastBeaconTemp)
        {
            NSMutableDictionary * newBeacon = [beacon mutableCopy];
            [newBeacon setObject:@"EXIT" forKey:@"event"];
            [self callHandlerWithBeacon:newBeacon];
        }
    }
    
    _lastBeacons = [NSMutableArray new];
    _lastBeacons = [NSMutableArray arrayWithArray:_beacons];
    
}


-(void)updateBluetoothEnabled:(NSNotification*)notification {
    
    [self callHandlerBluetoothStateChange:@"true"];
}


-(void)updateBluetoothDisabled:(NSNotification*)notification {
    
    [self callHandlerBluetoothStateChange:@"false"];
    
    [_beacons removeAllObjects];
    _beacons = [NSMutableArray new];
    
    NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastBeacons"];
    NSMutableArray * arrlastBeacons = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    NSMutableArray * lastBeaconsTemp = [NSKeyedUnarchiver unarchiveObjectWithData:
                                        [NSKeyedArchiver archivedDataWithRootObject:arrlastBeacons]];
    
    for (NSMutableArray * arrayBeacon in lastBeaconsTemp)
    {
        CLBeacon * beacon = [arrayBeacon objectAtIndex:0];
        NSMutableDictionary * dictBeacon = [arrayBeacon objectAtIndex:1];
        
        if (![[dictBeacon objectForKey:@"minor"] isEqualToString:@"0"] &&
            ![[dictBeacon objectForKey:@"major"] isEqualToString:@"0"] ) {
            
            NSString * beaconUUID = beacon.proximityUUID.UUIDString;
            NSString* UUIDstr = [beaconUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
            
            NSMutableDictionary * newBeacon = [NSMutableDictionary new];
            
            NSString * beaconMinor = [dictBeacon objectForKey:@"minor"];
            NSString * beaconMajor = [dictBeacon objectForKey:@"major"];
            
            
            if (beaconMinor.length == 1)
                beaconMinor = [NSString stringWithFormat:@"000%@", beaconMinor];
            else if (beaconMinor.length == 2)
                beaconMinor = [NSString stringWithFormat:@"00%@", beaconMinor];
            else if (beaconMinor.length == 3)
                beaconMinor = [NSString stringWithFormat:@"0%@", beaconMinor];
            
            if (beaconMajor.length == 1)
                beaconMajor = [NSString stringWithFormat:@"000%@", beaconMajor];
            else if (beaconMajor.length == 2)
                beaconMajor = [NSString stringWithFormat:@"00%@", beaconMajor];
            else if (beaconMajor.length == 3)
                beaconMajor = [NSString stringWithFormat:@"0%@", beaconMajor];
            
            [newBeacon setObject:beaconMinor forKey:@"minor"];
            [newBeacon setObject:beaconMajor forKey:@"major"];
            [newBeacon setObject:@"EXIT" forKey:@"event"];
            [newBeacon setObject:UUIDstr forKey:@"uuid"];
            
            [_beacons addObject:newBeacon];
        }
    }
    
    if (_beacons.count > 0)
    {
        for (NSMutableDictionary * newBeacon in _beacons)
        {
            [self callHandlerWithBeacon: newBeacon];
            
        }
    }
}



-(void)callHandlerWithBeacon:(NSMutableDictionary *)beacon
{
    
    NSDictionary * dictionary = @{@"success" : [NSNumber numberWithBool:YES], @"beacon" : beacon};
    
    NSError * error;
    NSData   *jsonData = [NSJSONSerialization dataWithJSONObject:dictionary options:0 error:&error];
    NSString *jsonString = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [self.bridge callHandler:@"onBeaconChange" data:jsonString responseCallback:^(id responseData) {
        
    }];
    
}

-(void)callHandlerBluetoothStateChange:(NSString*)state
{
    NSLog(@"callHandlerBluetoothStateChange state : %@", state);
    
    NSString * jsonString;
    
    if ([state isEqualToString:@"true"])
    {
        jsonString = @"{\"isActivated\":true}";
    }
    else
    {
        jsonString = @"{\"isActivated\":false}";
    }
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [self.bridge callHandler:@"onBluetoothStateChange" data:json responseCallback:^(id responseData) {
        
        NSLog(@"onBluetoothStateChange: %@", json);
        
    }];
}


-(void)updateLocationEnabled
{
    NSString * jsonString = @"{\"isActivated\":true}";
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [self.bridge callHandler:@"onLocationStateChange" data:json responseCallback:^(id responseData) {
        
        NSLog(@"onLocationStateChange: %@", jsonString);
        
    }];
}

-(void)updateLocationDisabled
{
    NSString * jsonString = @"{\"isActivated\":false}";
    
    NSData *jsonData = [jsonString dataUsingEncoding:NSUTF8StringEncoding];
    
    NSString *json = [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
    
    [self.bridge callHandler:@"onLocationStateChange" data:json responseCallback:^(id responseData) {
        
        NSLog(@"onLocationStateChange: %@", jsonString);
        
    }];
}


-(void)viewDidAppear:(BOOL)animated
{
    [self.bridge callHandler:@"onResume" data:nil responseCallback:^(id responseData) {
    }];
}

-(void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:YES];
    
    [self releaseService];
}








-(void)releaseService
{
    
    WKWebsiteDataStore *dateStore = [WKWebsiteDataStore defaultDataStore];
    [dateStore fetchDataRecordsOfTypes:[WKWebsiteDataStore allWebsiteDataTypes]
                     completionHandler:^(NSArray<WKWebsiteDataRecord *> * __nonnull records) {
                         
                         if (records.count > 0)
                         {
                             WKWebsiteDataRecord * lastRecord = [records lastObject];
                             
                             for (WKWebsiteDataRecord *record  in records)
                             {
                                 [[WKWebsiteDataStore defaultDataStore] removeDataOfTypes:record.dataTypes
                                                                           forDataRecords:@[record]
                                                                        completionHandler:^{
                                                                            
                                                                            if (record == lastRecord)
                                                                            {
                                                                                [self releaseAfterClearCookie];
                                                                            }
                                                                        }];
                             }
                         }
                         else
                         {
                             [self releaseAfterClearCookie];
                         }
                         
                     }];
}


-(void)releaseAfterClearCookie
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"onChangeBeacons" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"bluetoothDisabled" object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"bluetoothEnabled" object:nil];
    
    [self.bridge callHandler:@"onPause" data:nil responseCallback:^(id responseData) {
    }];
    
    [[NSURLCache sharedURLCache] removeAllCachedResponses];
    
    self.bridge = nil;
    [_beacons removeAllObjects];
    [_exitBeacons removeAllObjects];
    
    [_webviewService stopLoading];
    
    _webviewService = nil;
    
    [_webviewService removeFromSuperview];
    
    [_checkTimer invalidate];
    _checkTimer = nil;
    
    [[NSNotificationCenter defaultCenter] postNotificationName:@"releaseHybridView" object:_serviceUrl];
}







@end
