//
//  Bubbles.m
//  bubblesFramework
//
//  Created by Pierre RACINE on 08/10/2015.
//  Copyright © 2015 AbsolutLabs. All rights reserved.
//

#import "Bubbles.h"
#import <CoreLocation/CoreLocation.h>
#import "iBeacon.h"
#import <CommonCrypto/CommonDigest.h>
#import "Reachability.h"
#import "BridgeServiceHybrid.h"
#import "BubbleServiceView.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import "Data/DataAccess.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "BLE.h"
#define DEFAULT_UUID @"F3077ABE-93AC-465A-ACF1-67F080CB7AEF"





@interface Bubbles() <CLLocationManagerDelegate, BLEDelegate>


@property (nonatomic, strong) Reachability *internetReachable;
@property (nonatomic, strong) iBeacon * beaconConfig;
@property (nonatomic, copy) void (^responseOwner)(BOOL success);
@property (nonatomic) Reachability * internetReachability;
@property (nonatomic) BOOL isProd;
@property (nonatomic, strong) NSMutableDictionary * bridgeServiceInstances;
@property (nonatomic, strong) BLE * bleShield;

@end





@implementation Bubbles

static Bubbles * _sharedInstance;

+ (BLE *)ble
{
    if(!_sharedInstance.bleShield)
        _sharedInstance.bleShield = [[BLE alloc]init];
    [_sharedInstance.bleShield setDelegate:_sharedInstance];
    return _sharedInstance.bleShield;
}


+ (void) initWithAPIKey:(NSString *)APIKey andUserId:(NSString*)userID andUUID:(NSArray*)UUID andRegistrationId:(NSString *)registrationId andIsProd:(BOOL)isProd andEnableStatsScenario:(BOOL)stats
{
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"releaseHybridView" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(releaseHybridView:) name:@"releaseHybridView" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"onClickNotification" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(onClickNotification:) name:@"onClickNotification" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"openService" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(onOpenService:) name:@"openService" object:nil];
    
    [[NSNotificationCenter defaultCenter] removeObserver:self name:@"closeService" object:nil];
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(onCloseService) name:@"closeService" object:nil];
    
    
    [DATA mode:isProd withAPIkey:APIKey andUserId:userID];
    
    [DATA requestDeviceId];
    
    
    if(!_sharedInstance)
    {
        static dispatch_once_t pred;
        dispatch_once(&pred, ^{
            
            _sharedInstance = [[Bubbles alloc] init];
            
            _sharedInstance.beaconConfig = [[iBeacon alloc] init];
            _sharedInstance.beaconConfig.bubbleInstance = _sharedInstance;
            
        });
    }
    
    
    
    _sharedInstance.beaconConfig.bubblesUUID = DEFAULT_UUID;
    
    _sharedInstance.bridgeServiceInstances = [NSMutableDictionary new];
    
    
    if ([_sharedInstance checkNetwork])
    {
        ////////////////////// INIT BEACON + CHECK LOCALIZATION AND NOTIF + START SCAN /////////////////
        
        [_sharedInstance.beaconConfig initialize];
        
        ////////////////////////////////////////////////////////////////////////////////////////////////
    }
    
    [[self class] ble];
    [_sharedInstance.bleShield controlSetup];
}






+ (void)didReceiveLocalNotification:(NSDictionary *)userInfo withApplicationState:(UIApplicationState)appState
{
    [_sharedInstance.beaconConfig didReceiveLocalbeaconNotification:userInfo withApplicationState:appState];
}


+ (void)setDelegate:(id<BubblesDelegate>)delegate
{
    [_sharedInstance setDelegate:delegate];
}












/**************************************************************/
//////////////////////// SERVICES //////////////////////////////
/**************************************************************/

+ (BubbleServiceView *) getWebviewService
{
    BubbleServiceView * newHybrid;
    
    for (NSString * service in _sharedInstance.bridgeServiceInstances)
    {
        BridgeServiceHybrid * serv = (BridgeServiceHybrid*)[_sharedInstance.bridgeServiceInstances objectForKey:service];
        newHybrid = serv.serviceView;
        break;
    }
    
    return newHybrid;
}



+ (void) loadServiceWithId:(NSString *)serviceId
{
    BridgeServiceHybrid * newHybrid = [BridgeServiceHybrid new];
    
    NSLog(@"loadServiceWithId %@", serviceId);
    [newHybrid loadServiceWithId:serviceId];
    
    if (_sharedInstance.bridgeServiceInstances.count > 0)
    {
        NSLog(@"removeInstance %@", _sharedInstance.bridgeServiceInstances);
        [_sharedInstance.bridgeServiceInstances removeAllObjects];
    }
    
    [_sharedInstance.bridgeServiceInstances setObject:newHybrid forKey:serviceId];
}



+ (void)releaseHybridView:(NSNotification*)notification
{
    NSString *mpObject = (NSString *) notification.object;
    
    BridgeServiceHybrid * newHybrid = (BridgeServiceHybrid*)[_sharedInstance.bridgeServiceInstances objectForKey:mpObject];
    
    newHybrid.bridge = nil;
    [newHybrid.beacons removeAllObjects];
    [newHybrid.exitBeacons removeAllObjects];
    
    [newHybrid.webviewService stopLoading];
    newHybrid.webviewService = nil;
    newHybrid.bridge = nil;
    [newHybrid.webviewService removeFromSuperview];
    
    
    [newHybrid.bubbleTimer invalidate];
    newHybrid.bubbleTimer = nil;
    
    newHybrid = nil;
    
    [_sharedInstance.bridgeServiceInstances removeAllObjects];
    
}


+ (void)releaseService
{
    for (NSString * service in _sharedInstance.bridgeServiceInstances)
    {
        BridgeServiceHybrid * serv = (BridgeServiceHybrid*)[_sharedInstance.bridgeServiceInstances objectForKey:service];
        
        [serv releaseService];
        
        break;
    }
}






+ (void)getServices
{
    [DATA requestGETWithUrl:@"service/list" andDictionaryPost:nil success:^(NSURLSessionDataTask *sessionDataTask, id response) {
        
        NSMutableDictionary * service = response;
        
        if(service)
        {
            [[NSUserDefaults standardUserDefaults]setObject:[NSDate date] forKey:@"serviceRequestLastDate"];
            
            [[NSUserDefaults standardUserDefaults]setObject:service forKey:@"services"];
            [[NSUserDefaults standardUserDefaults]synchronize];
            
            if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onServicesListLoaded:)]){
                [_sharedInstance.delegate onServicesListLoaded:service];
            }
        }
        
    } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
        
        NSLog(@"serviceList Failed");
        [[self class] onRequestServicesFailed];
        
    }];
}


+(void)onRequestServicesLoaded
{
    NSUserDefaults * userDefaults = [NSUserDefaults standardUserDefaults];
    NSDictionary * services = [userDefaults objectForKey:@"services"];
    
    if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onServicesListLoaded:)])
    {
        [_sharedInstance.delegate onServicesListLoaded:services];
    }
}


+(void)onRequestServicesFailed
{
    if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onServicesListFailed)])
    {
        [_sharedInstance.delegate onServicesListFailed];
    }
}

+(void)onHybridServiceLoaded
{
    NSLog(@"onHybridServiceLoaded");
    
    if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onHybridServiceReady)]){
        [_sharedInstance.delegate onHybridServiceReady];
    }
}

+(void)onHybridServiceFail
{
    NSLog(@"onHybridServiceFail");
    
    if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onHybridServiceTimeout)]){
        [_sharedInstance.delegate onHybridServiceTimeout];
    }
}

+(void)onOpenService:(NSNotification*)notification
{
    NSString * service = (NSString *) notification.object;
    
    if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onOpenService:)]){
        [_sharedInstance.delegate onOpenService:service];
    }
}

+(void)onCloseService
{
    if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onCloseService)]){
        [_sharedInstance.delegate onCloseService];
    }
}

+(void)onClickNotification:(NSNotification*)notification {
    
    
    NSMutableDictionary * infos = (NSMutableDictionary *) notification.object;
    
    if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onClickNotification:)]){
        [_sharedInstance.delegate onClickNotification:infos];
    }
}


/**************************************************************/
/**************************************************************/




+(void)updateUserId:(NSString *)userId
{
    DATA.userId = userId;
    
    [DATA requestDeviceId];
}


#pragma mark Network


-(BOOL)checkNetwork
{
    
    self.internetReachability = [Reachability reachabilityForInternetConnection];
    [self.internetReachability startNotifier];
    
    NetworkStatus netStatus = [self.internetReachability currentReachabilityStatus];
    
    if (netStatus == 0)
    {
        if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onNetworkAvailable:)]){
            [_sharedInstance.delegate onNetworkAvailable:NO];
        }
        
        return NO;
    }
    else
    {
        
        if (_sharedInstance.delegate && [_sharedInstance.delegate respondsToSelector:@selector(onNetworkAvailable:)]){
            [_sharedInstance.delegate onNetworkAvailable:YES];
        }
        
        return YES;
    }
}



+(void)setDebugLogBeaconEnabled:(BOOL)enable
{
    [_sharedInstance.beaconConfig setDebugLogBeaconEnabled:enable];
}




+ (void)didEnterBackground;
{
    _sharedInstance.beaconConfig.inBackground = YES;
    [_sharedInstance.beaconConfig extendBackgroundRunningTime];
    
    
}

+ (void)didBecomeActive;
{
    _sharedInstance.beaconConfig.inBackground = NO;
}



@end
