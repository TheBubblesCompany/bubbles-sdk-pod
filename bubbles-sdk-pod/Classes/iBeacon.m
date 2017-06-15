//
//  Bubbles.m
//  bubblesFramework
//
//  Created by Pierre RACINE on 08/10/2015.
//  Copyright © 2015 AbsolutLabs. All rights reserved.
//

#import "iBeacon.h"
#import "DataAccess.h"
#import "BridgeServiceHybrid.h"
#import "ISMessages.h"

#define kTimeInterval 15


@implementation iBeacon

#pragma mark - Init


-(void)initialize
{
    if(self.debug)
        NSLog(@"INITIALIZE");
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(BluetoothEnabled) name:@"BluetoothON" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(BluetoothDisabled) name:@"BluetoothOFF" object:nil];
    
    _standardUserDefaults = [NSUserDefaults standardUserDefaults];
    [_standardUserDefaults synchronize];
    
    _dateFormatterYYYYMMDD = [[NSDateFormatter alloc]init];
    [_dateFormatterYYYYMMDD setDateFormat:@"yyyyMMdd"];
    
    _dateFormatterGMT = [[NSDateFormatter alloc]init];
    [_dateFormatterGMT setDateFormat:@"Z"];
    
    [[UIDevice currentDevice] setBatteryMonitoringEnabled:YES];
    
    [self requestConfiguration];
    [self initLocationManager];
    [self initBeacon];
    
    _beaconTimer = [NSTimer scheduledTimerWithTimeInterval:3
                                                    target:self
                                                  selector:@selector(initBeacon)
                                                  userInfo:nil
                                                   repeats:YES];
}



-(void)BluetoothDisabled
{
    _bluetoothEnable = NO;
    DATA.bluetoothEnable = NO;
    
    [_beaconTimer invalidate];
    _beaconTimer = nil;
    
    NSData * data = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastBeacons"];
    NSMutableArray * arrlastBeacons = [NSKeyedUnarchiver unarchiveObjectWithData:data];
    
    for (NSMutableArray * arrayBeacon in arrlastBeacons)
    {
        NSMutableDictionary * dictBeacon = [arrayBeacon objectAtIndex:1];
        [dictBeacon setObject:@"EXIT" forKey:@"event"];
    }
    
    NSData *dataSave = [NSKeyedArchiver archivedDataWithRootObject:arrlastBeacons];
    [[NSUserDefaults standardUserDefaults] setObject:dataSave forKey:@"lastBeacons"];
    [[NSUserDefaults standardUserDefaults] synchronize];
    
    if(self.debug)
        NSLog(@"Bluetooth OFF");
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"bluetoothDisabled" object:nil];
}


-(void)BluetoothEnabled
{
    _bluetoothEnable = YES;
    DATA.bluetoothEnable = YES;
    
    
    if (!_beaconTimer)
    {
        _beaconTimer = [NSTimer scheduledTimerWithTimeInterval:1
                                                        target:self
                                                      selector:@selector(initBeacon)
                                                      userInfo:nil
                                                       repeats:YES];
    }
    
    if(self.debug)
        NSLog(@"Bluetooth ON");
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"bluetoothEnabled" object:nil];
}





-(void)applicationState:(NSNotification*)notification
{
    NSNumber *mpObject = (NSNumber *) notification.object;
    
    _inBackground = [mpObject boolValue];
    
    if (_inBackground) {
        [self extendBackgroundRunningTime];
    }
}



-(void)setDebugLogBeaconEnabled:(BOOL)enable
{
    self.debug = enable;
}



-(void) initLocationManager
{
    DATA.locationManager = [[CLLocationManager alloc] init];
    DATA.locationManager.delegate = self;
    
    [self requestLocalizationAndNotificationsAuthorization];
}


- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    
    NSLog(@"didchangeeeeeee");
    
    if (status == kCLAuthorizationStatusAuthorizedAlways)
    {
        // The user accepted authorization
        
        NSLog(@"didchangeeeeeee1");
        
        if (![[NSUserDefaults standardUserDefaults] objectForKey:@"confirm_localization"])
        {
            [DATA confirmLocalization];
        }
        
        [[NSNotificationCenter defaultCenter]postNotificationName:@"LocationEnabled" object:nil];
        
    }
    else if (status == kCLAuthorizationStatusDenied || status == kCLAuthorizationStatusRestricted)
    {
        NSLog(@"didchangeeeeeee2");
        [[NSNotificationCenter defaultCenter]postNotificationName:@"LocationDisabled" object:nil];
    }
    
    
}







-(void) initBeacon
{
    if(self.debug)
        NSLog(@"----------------- Scan Bubble GO -----------------");
    
    self.beaconRegion = nil;
    
    NSUUID * beaconUUID = [[NSUUID alloc] initWithUUIDString : _bubblesUUID ];
    
    CLBeaconRegion* stopRegion = [[CLBeaconRegion alloc] initWithProximityUUID:[NSUUID UUID] identifier:@"bubbles_beacon"];
    [DATA.locationManager stopMonitoringForRegion:stopRegion];
    
    self.beaconRegion = [[CLBeaconRegion alloc] initWithProximityUUID:beaconUUID identifier:@"bubbles_beacon"];
    self.beaconRegion.notifyEntryStateOnDisplay = YES;
    
    self.beaconRegion.notifyOnEntry = YES;
    self.beaconRegion.notifyOnExit = YES;
    self.beaconRegion.notifyEntryStateOnDisplay=YES;
    
    [DATA.locationManager startMonitoringForRegion:self.beaconRegion];
    [DATA.locationManager startRangingBeaconsInRegion:self.beaconRegion];
}





- (void) locationManager:(CLLocationManager *)manager didStartMonitoringForRegion:(CLRegion *)region
{
    [DATA.locationManager requestStateForRegion:self.beaconRegion];
}




-(void)requestLocalizationAndNotificationsAuthorization
{
    [DATA.locationManager requestAlwaysAuthorization];
    
    if([DATA.locationManager respondsToSelector:@selector(requestAlwaysAuthorization)])
        [DATA.locationManager requestAlwaysAuthorization];
    
    [self requestNotificationAuthorization];
}


- (void) requestNotificationAuthorization
{
    UIUserNotificationType types = UIUserNotificationTypeBadge | UIUserNotificationTypeSound | UIUserNotificationTypeAlert;
    UIUserNotificationSettings * mySettings = [UIUserNotificationSettings settingsForTypes:types categories:nil];
    
    [UIApplication.sharedApplication registerUserNotificationSettings : mySettings];
}






#pragma mark - Beacons location







-(void)locationManager:(CLLocationManager *)manager didRangeBeacons:(NSArray<CLBeacon *> *)beacons inRegion:(CLBeaconRegion *)region
{
    
    if (_bluetoothEnable)
    {
        
        NSData *data = [[NSUserDefaults standardUserDefaults] objectForKey:@"lastBeacons"];
        NSMutableArray * arrlastBeacons = [NSKeyedUnarchiver unarchiveObjectWithData:data];
        
        
        NSDateFormatter * df1 = [[NSDateFormatter alloc] init];
        [df1 setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
        NSString * date = [df1 stringFromDate:[NSDate date]];
        
        
        NSMutableArray * lastBeaconsTemp = [NSKeyedUnarchiver unarchiveObjectWithData:
                                            [NSKeyedArchiver archivedDataWithRootObject:arrlastBeacons]];
        
        
        if(beacons.count > 0)
        {
            
            for (CLBeacon * beacon in beacons)
            {
                
                if (arrlastBeacons.count > 0)
                {
                    
                    BOOL containBeacon = NO;
                    
                    for (int j = 0; j < [arrlastBeacons count]; j++)
                    {
                        
                        NSMutableArray * arLastBeacon = [lastBeaconsTemp objectAtIndex:j];
                        
                        CLBeacon * lastCLBeacon = [arLastBeacon objectAtIndex:0];
                        NSMutableDictionary * dictBeacon = [arLastBeacon objectAtIndex:1];
                        
                        if([lastCLBeacon.proximityUUID isEqual:beacon.proximityUUID] && [lastCLBeacon.major isEqual:beacon.major] && [lastCLBeacon.minor isEqual:beacon.minor])
                        {
                            containBeacon = YES;
                            
                            
                            if(lastCLBeacon.proximityUUID == CLProximityUnknown)
                            {
                                // NSString * beaconMinor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.minor integerValue]];
                                //  NSLog(@"Bubble SAME %@ proximity %ld", beaconMinor, (long)beacon.proximity);
                            }
                            else
                            {
                                NSString * beaconMinor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.minor integerValue]];
                                NSString * beaconMajor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.major integerValue]];
                                
                                NSString * proximity = @"";
                                switch(beacon.proximity) {
                                    case CLProximityFar:
                                        proximity = @"IN_FAR_REGION";
                                        break;
                                    case CLProximityNear:
                                        proximity = @"IN_NEAR_REGION";
                                        break;
                                    case CLProximityImmediate:
                                        proximity = @"IN_IMMEDIATE_REGION";
                                        break;
                                    case CLProximityUnknown:
                                        proximity = @"UNKNOWN";
                                }
                                
                                NSString * lastdDate = [dictBeacon objectForKey:@"date"];
                                
                                NSDateFormatter * df1 = [[NSDateFormatter alloc] init];
                                [df1 setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                                NSDate *dtPostDate = [df1 dateFromString:lastdDate];
                                
                                NSString *strToday = [df1 stringFromDate:[NSDate date]];
                                NSDate *todaydate = [df1 dateFromString:strToday];
                                
                                NSTimeInterval interval = [todaydate timeIntervalSinceDate:dtPostDate];
                                
                                
                                if ( interval > kTimeInterval )
                                {
                                    if(self.debug) NSLog(@"Scan Bubble %@ ENTER", beaconMinor);
                                    [dictBeacon setObject:@"ENTER" forKey:@"event"];
                                    [dictBeacon setObject:date forKey:@"date"];
                                }
                                else if ([[dictBeacon objectForKey:@"event"] isEqualToString:@"EXIT"])
                                {
                                    if(self.debug) NSLog(@"Scan Bubble %@ ENTER", beaconMinor);
                                    [dictBeacon setObject:@"ENTER" forKey:@"event"];
                                    [dictBeacon setObject:date forKey:@"date"];
                                    [dictBeacon setObject:date forKey:@"dateScenario"];
                                    [dictBeacon setObject:beaconMinor forKey:@"minor"];
                                    [dictBeacon setObject:beaconMajor forKey:@"major"];
                                    
                                }
                                else if (![proximity isEqualToString:@"UNKNOWN"])
                                {
                                    if(self.debug) NSLog(@"Scan Bubble %@ proximity %ld", beaconMinor, (long)beacon.proximity);
                                    [dictBeacon setObject:proximity forKey:@"event"];
                                    [dictBeacon setObject:date forKey:@"date"];
                                }
                                
                                break;
                            }
                        }
                        
                        
                        if (j == [arrlastBeacons count]-1)
                        {
                            if (!containBeacon)
                            {
                                // ENTER
                                NSString * beaconMinor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.minor integerValue]];
                                NSString * beaconMajor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.major integerValue]];
                                if(self.debug) NSLog(@"Scan Bubble %@ ENTER", beaconMinor);
                                
                                NSMutableDictionary * dictBeacon = [NSMutableDictionary new];
                                NSMutableArray * arLastBeacon = [NSMutableArray new];
                                [dictBeacon setObject:beaconMinor forKey:@"minor"];
                                [dictBeacon setObject:beaconMajor forKey:@"major"];
                                [dictBeacon setObject:@"ENTER" forKey:@"event"];
                                [dictBeacon setObject:date forKey:@"date"];
                                [dictBeacon setObject:date forKey:@"dateScenario"];
                                
                                [arLastBeacon addObject:beacon];
                                [arLastBeacon addObject:dictBeacon];
                                
                                [lastBeaconsTemp addObject:arLastBeacon];
                            }
                        }
                    }
                    
                }
                else
                {
                    NSString * beaconMinor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.minor integerValue]];
                    NSString * beaconMajor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.major integerValue]];
                    
                    if(self.debug) NSLog(@"Scan Bubble %@ ENTER", beaconMinor);
                    
                    NSMutableDictionary * dictBeacon = [NSMutableDictionary new];
                    NSMutableArray * arLastBeacon = [NSMutableArray new];
                    [dictBeacon setObject:beaconMinor forKey:@"minor"];
                    [dictBeacon setObject:beaconMajor forKey:@"major"];
                    [dictBeacon setObject:@"ENTER" forKey:@"event"];
                    [dictBeacon setObject:date forKey:@"date"];
                    [dictBeacon setObject:date forKey:@"dateScenario"];
                    
                    [arLastBeacon addObject:beacon];
                    [arLastBeacon addObject:dictBeacon];
                    
                    [lastBeaconsTemp addObject:arLastBeacon];
                }
                
            }
            
            /////////// CHECK TIMESTAMP FOR EXIT STATE, SEND IF < 10 sec
            
            for (int j = 0; j < [arrlastBeacons count]; j++)
            {
                
                NSMutableArray * arLastBeacon = [lastBeaconsTemp objectAtIndex:j];
                
                CLBeacon * lastCLBeacon = [arLastBeacon objectAtIndex:0];
                NSMutableDictionary * dictBeacon = [arLastBeacon objectAtIndex:1];
                
                BOOL containBeacon = NO;
                id lastObj = [beacons lastObject];
                
                for (CLBeacon * beacon in beacons)
                {
                    
                    if([lastCLBeacon.proximityUUID isEqual:beacon.proximityUUID] && [lastCLBeacon.major isEqual:beacon.major] && [lastCLBeacon.minor isEqual:beacon.minor])
                    {
                        containBeacon = YES;
                        break;
                    }
                    
                    if ( beacon == lastObj )
                    {
                        if (!containBeacon)
                        {
                            NSString * lastdDate = [dictBeacon objectForKey:@"date"];
                            
                            NSDateFormatter * df1 = [[NSDateFormatter alloc] init];
                            [df1 setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                            NSDate *dtPostDate = [df1 dateFromString:lastdDate];
                            
                            NSString *strToday = [df1 stringFromDate:[NSDate date]];
                            NSDate *todaydate = [df1 dateFromString:strToday];
                            
                            NSTimeInterval interval = [todaydate timeIntervalSinceDate:dtPostDate];
                            
                            if (interval > kTimeInterval && ![[dictBeacon objectForKey:@"event"] isEqualToString:@"EXIT"]) {
                                
                                NSString * beaconMinor = [NSString stringWithFormat:@"%lX",(unsigned long)[lastCLBeacon.minor integerValue]];
                                
                                
                                if (![[dictBeacon objectForKey:@"event"] isEqualToString:@"EXIT"])
                                {
                                    [dictBeacon setObject:date forKey:@"date"];
                                }
                                
                                if(self.debug) NSLog(@"Scan Bubble %@ EXIT", beaconMinor);
                                [dictBeacon setObject:beaconMinor forKey:@"minor"];
                                [dictBeacon setObject:@"EXIT" forKey:@"event"];
                                
                            }
                        }
                    }
                }
            }
            
            //////// CHECK IF EVENT IS DIFFERENT OR IF EVENT IS NOT DIFFERENT BUT TIMESTAMP < 1 MIN
            
            for (NSMutableArray * array in lastBeaconsTemp)
            {
                CLBeacon * beacon = [array objectAtIndex:0];
                NSMutableDictionary * dictBeacon = [array objectAtIndex:1];
                
                for (NSMutableArray * arrayLast in arrlastBeacons)
                {
                    CLBeacon * lastBeacon = [arrayLast objectAtIndex:0];
                    NSMutableDictionary * dictLast = [arrayLast objectAtIndex:1];
                    
                    
                    if ([lastBeacon.major isEqual:beacon.major] && [lastBeacon.minor isEqual:beacon.minor])
                    {
                        
                        if(![[dictBeacon objectForKey:@"minor"] isEqualToString:@"0"] && ![[dictLast objectForKey:@"minor"] isEqualToString:@"0"])
                        {
                            
                            NSString * lastdDate = [dictBeacon objectForKey:@"dateScenario"];
                            
                            NSDateFormatter * df1 = [[NSDateFormatter alloc] init];
                            [df1 setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
                            NSDate *dtPostDate = [df1 dateFromString:lastdDate];
                            
                            NSString *strToday = [df1 stringFromDate:[NSDate date]];
                            NSDate *todaydate = [df1 dateFromString:strToday];
                            
                            NSTimeInterval interval = [todaydate timeIntervalSinceDate:dtPostDate];
                            
                            if(![[dictBeacon objectForKey:@"event"] isEqualToString:[dictLast objectForKey:@"event"]])
                            {
                                [self requestAPIForBeacon:beacon andProximity:[dictBeacon objectForKey:@"event"] andDate:[dictBeacon objectForKey:@"date"]];
                                
                                [dictBeacon setObject:date forKey:@"dateScenario"];
                                
                            }
                            else if(interval >= kTimeInterval && ![[dictBeacon objectForKey:@"event"] isEqualToString:@"ENTER"] && ![[dictBeacon objectForKey:@"event"] isEqualToString:@"EXIT"])
                            {
                                [self requestAPIForBeacon:beacon andProximity:[dictBeacon objectForKey:@"event"] andDate:[dictBeacon objectForKey:@"date"]];
                                
                                [dictBeacon setObject:date forKey:@"dateScenario"];
                            }
                            
                            break;
                        }
                    }
                }
            }
        }
        
        
        arrlastBeacons = [NSMutableArray arrayWithArray:lastBeaconsTemp];
        
        
        NSData *dataSave = [NSKeyedArchiver archivedDataWithRootObject:arrlastBeacons];
        [[NSUserDefaults standardUserDefaults] setObject:dataSave forKey:@"lastBeacons"];
        [[NSUserDefaults standardUserDefaults] synchronize];
        
    }
    
    [[NSNotificationCenter defaultCenter]postNotificationName:@"onChangeBeacons" object:nil];
    
}




-(void) locationManager : (CLLocationManager *) manager didEnterRegion : (CLRegion *)region
{
    [manager startRangingBeaconsInRegion : (CLBeaconRegion*) region];
    [DATA.locationManager startUpdatingLocation];
}

-(void) locationManager : (CLLocationManager *) manager didExitRegion : (CLRegion *) region
{
    [manager stopRangingBeaconsInRegion : (CLBeaconRegion*)region];
    [DATA.locationManager stopUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager monitoringDidFailForRegion:(CLRegion *)region withError:(NSError *)error {
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error {
}




- (void)locationManager:(CLLocationManager *)manager didDetermineState:(CLRegionState)state forRegion:(CLRegion *)region {
    
    if (_inBackground) {
        [self extendBackgroundRunningTime];
    }
    
    if ([region isKindOfClass:[CLBeaconRegion class]] && state == CLRegionStateInside)
    {
        [self locationManager:manager didEnterRegion:region];
    }
    else if ([region isKindOfClass:[CLBeaconRegion class]] && state == CLRegionStateOutside)
    {
        [self locationManager:manager didExitRegion:region];
    }
}




- (void)extendBackgroundRunningTime {
    if (_backgroundTask != UIBackgroundTaskInvalid) {
        // if we are in here, that means the background task is already running.
        // don't restart it.
        return;
    }
    
    if(self.debug) NSLog(@"Attempting to extend background running time");
    
    __block Boolean self_terminate = YES;
    
    _backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithName:@"DummyTask" expirationHandler:^{
        if(self.debug) NSLog(@"Background task expired by iOS");
        if (self_terminate) {
            [[UIApplication sharedApplication] endBackgroundTask:_backgroundTask];
            _backgroundTask = UIBackgroundTaskInvalid;
            
        }
    }];
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        while (true) {
            if(self.debug) NSLog(@"background time remaining: %8.2f", [UIApplication sharedApplication].backgroundTimeRemaining);
            
            [NSThread sleepForTimeInterval:1];
        }
        
    });
}






-(NSMutableDictionary*)formParamForRequestAPIwithBeacon: (CLBeacon *)beacon andProximity:(NSString *)proximity anDate:(NSString*)date
{
    
    if ([proximity isEqualToString:@"UNKNOWN"])
        return nil;
    
    CLLocation * currentLocation = DATA.locationManager.location;
    int battery_level = (int)round([UIDevice currentDevice].batteryLevel * 100);
    
    NSString * beaconMinor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.minor integerValue]];
    NSString * beaconMajor = [NSString stringWithFormat:@"%lX",(unsigned long)[beacon.major integerValue]];
    
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
    
    NSString* UUIDstr = [beacon.proximityUUID.UUIDString stringByReplacingOccurrencesOfString:@"-" withString:@""];
    
    NSMutableDictionary * params = [@{@"uuid": UUIDstr, @"major": beaconMajor, @"minor" : beaconMinor, @"battery_level" : [NSString stringWithFormat:@"%d", battery_level], @"event" : proximity}mutableCopy];
    
    if(currentLocation)
    {
        [params setObject:[NSString stringWithFormat:@"%f", currentLocation.coordinate.latitude] forKey:@"latitude"];
        [params setObject:[NSString stringWithFormat:@"%f", currentLocation.coordinate.longitude] forKey:@"longitude"];
    }
    
    //  if(DATA.userId)
    //    [params setObject:[NSString stringWithFormat:@"%@", DATA.userId] forKey:@"user_id"];
    
    return params;
}











#pragma mark - Request configuration



- (void) requestConfiguration
{
    NSDate * lastRequestConfig = [_standardUserDefaults objectForKey:@"lastRequestConfig"];
    
    int currentDate = [[_dateFormatterYYYYMMDD stringFromDate:[NSDate date]]intValue];
    int lastRequestConfigInt = [[_dateFormatterYYYYMMDD stringFromDate:lastRequestConfig]intValue];
    
    if(!lastRequestConfig || currentDate > lastRequestConfigInt)
    {
        
        [DATA requestGETWithUrl:@"ibeacon/configuration" andDictionaryPost:nil success:^(NSURLSessionDataTask *sessionDataTask, id response) {
            
            if(response && [response isKindOfClass:[NSDictionary class]] && [[response allKeys]containsObject:@"bubbles_uuid"] && [[response objectForKey:@"bubbles_uuid"]isKindOfClass:[NSString class]])
            {
                [_standardUserDefaults setObject:[NSDate date] forKey:@"lastRequestConfig"];
                NSString * bubbles_uuid = [response objectForKey:@"bubbles_uuid"];
                
                [_standardUserDefaults setObject:[NSString stringWithFormat:@"%@-%@-%@-%@-%@", [bubbles_uuid substringWithRange:NSMakeRange(0, 8)], [bubbles_uuid substringWithRange:NSMakeRange(8, 4)], [bubbles_uuid substringWithRange:NSMakeRange(12, 4)], [bubbles_uuid substringWithRange:NSMakeRange(16, 4)], [bubbles_uuid substringWithRange:NSMakeRange(20, 12)]]  forKey:@"BubblesUUID"];
                
                [_standardUserDefaults synchronize];
                
                [self initBeacon];
            }
            
            
        } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
            
            if(self.debug)
                NSLog(@"ERROR - request configuration -- %@", error);
            
        }];
        
    }
}


#pragma mark - Request scenario


- (void) requestAPIForBeacon : (CLBeacon *) beacon andProximity:(NSString *)proximity andDate:(NSString*)date
{
    
    if (![[NSUserDefaults standardUserDefaults] objectForKey:@"confirm_notification"])
    {
        [DATA confirmNotification];
    }
    
    NSMutableDictionary * paramBeacon  = [self formParamForRequestAPIwithBeacon:beacon andProximity:proximity anDate:date];
    
    if (self.debug)
        NSLog(@"PARAMS -- %@", paramBeacon);
    
    if (paramBeacon)
    {
        NSLog(@"ok1 paramBeacon = %@", paramBeacon);
        
        [DATA requestGETWithUrl:@"ibeacon/scenario" andDictionaryPost:paramBeacon success:^(NSURLSessionDataTask *sessionDataTask, id response) {
            
            
            if(response && [response isKindOfClass:[NSDictionary class]] && [[response allKeys]containsObject:@"success"] && [[response objectForKey:@"success"]boolValue] && [[response allKeys]containsObject:@"notification_text"])
            {
                if([[response allKeys]containsObject:@"type"] && [[response objectForKey:@"type"]isEqualToString:@"URI"])
                {
                    
                    NSLog(@"REQUEST URI SUCCESS -- %@", response);
                    
                    NSDictionary * dictionaryURI = [response objectForKey:@"uri"];
                    NSURL * urlURIDefault = nil;
                    NSURL * urlURIFallback = nil;
                    
                    if([[dictionaryURI allKeys]containsObject:@"default"] && [[dictionaryURI objectForKey:@"default"]isKindOfClass:[NSString class]])
                        urlURIDefault = [NSURL URLWithString:[dictionaryURI objectForKey:@"default"]];
                    
                    if([[dictionaryURI allKeys]containsObject:@"fallback"] && [[dictionaryURI objectForKey:@"fallback"]isKindOfClass:[NSString class]])
                        urlURIFallback = [NSURL URLWithString:[dictionaryURI objectForKey:@"fallback"]];
                    
                    
                    [self sendLocalNotificationWithUserInfo:response];
                    
                }
                else if([[response allKeys]containsObject:@"type"] && [[response objectForKey:@"type"]isEqualToString:@"IMG"])
                {
                    NSLog(@"REQUEST IMAGE SUCCESS -- %@", response);
                    [self downloadImageAndSendNotif:response];
                }
                else
                {
                    NSLog(@"REQUEST SCENARIO SUCCESS -- %@", response);
                    [self sendLocalNotificationWithUserInfo:response];
                }
            }
            
            
        } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
            
            if(self.debug)
                NSLog(@"Error - rerquest scenario -- %@", error);
            
        }];
        
    }
}


-(void)downloadImageAndSendNotif:(NSMutableDictionary*)infos
{
    
    if(infos)
    {
        if([[infos allKeys]containsObject:@"image"] && [[[infos objectForKey:@"image"]allKeys]containsObject:@"url"])
        {
            NSString * imageURL = [[infos objectForKey:@"image"]objectForKey:@"url"];
            if(imageURL)
            {
                dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
                dispatch_async(queue, ^(void) {
                    
                    NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:imageURL]];
                    UIImage* image = [[UIImage alloc] initWithData:imageData];
                    
                    if (image) {
                        
                        NSLog(@"downloadImageAndSendNotif");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            
                            [self sendLocalNotificationWithUserInfo:infos];
                            
                        });
                    }
                });
            }
        }
    }
    
}









#pragma mark - Local Notification


- (void) sendLocalNotificationWithUserInfo : (NSDictionary *) userInfo
{
    
    
    
    //#ifdef __IPHONE_8_0
    
    NSMutableDictionary * dicoTemp = [userInfo mutableCopy];
    [dicoTemp setObject:@"BubbleBeacon" forKey:@"category"];
    
    UILocalNotification *notification = [[UILocalNotification alloc] init];
    notification.alertBody = [dicoTemp objectForKey:@"notification_text"];
    // notification.fireDate = [NSDate dateWithTimeIntervalSinceNow : 1];
    notification.userInfo = dicoTemp;
    // notification.soundName = UILocalNotificationDefaultSoundName;
    notification.soundName = @"notificationBubblesSound.caf";
    [UIApplication.sharedApplication scheduleLocalNotification : notification];
    
    /*#endif
     
     UNMutableNotificationContent *content = [[UNMutableNotificationContent alloc] init];
     content.body = [userInfo objectForKey:@"notification_text"];
     content.userInfo = userInfo;
     content.sound = [UNNotificationSound defaultSound];
     [content setValue:@(YES) forKeyPath:@"shouldAlwaysAlertWhileAppIsForeground"];
     content.categoryIdentifier = @"UYLLocalNotification";
     // Objective-C
     NSString *identifier = @"UYLLocalNotification";
     
     UNNotificationRequest *request = [UNNotificationRequest requestWithIdentifier:identifier
     content:content trigger:nil];
     
     UNUserNotificationCenter *center = [UNUserNotificationCenter currentNotificationCenter];
     
     [center addNotificationRequest:request withCompletionHandler:^(NSError * _Nullable error) {
     if (error != nil) {
     NSLog(@"Something went wrong: %@",error);
     }
     }];*/
}

/*
 - (void) sendLocalNotification:(NSString*)val
 {
 // [dicoTemp setObject:[NSNumber numberWithBool:YES] forKey:@"BBBeaconNotification"];
 
 UILocalNotification *notification = [[UILocalNotification alloc] init];
 notification.alertBody = val;
 // notification.fireDate = [NSDate dateWithTimeIntervalSinceNow : 1];
 // notification.userInfo = dicoTemp;
 // notification.soundName = UILocalNotificationDefaultSoundName;
 notification.soundName = @"notificationBubblesSound.caf";
 [UIApplication.sharedApplication scheduleLocalNotification : notification];
 }*/





//// If service doesn't exist in local list, we have to call this method to refresh services ////

- (void)getServiceListForService:(NSDictionary*)data withApplicationState:(UIApplicationState)appState
{
    
    NSLog(@"serviceDoesn'tExist !!");
    
    [DATA requestGETWithUrl:@"service/list" andDictionaryPost:nil success:^(NSURLSessionDataTask *sessionDataTask, id response) {
        
        NSMutableDictionary * service = response;
        
        if(service)
        {
            [[NSUserDefaults standardUserDefaults]setObject:[NSDate date] forKey:@"serviceRequestLastDate"];
            
            [[NSUserDefaults standardUserDefaults]setObject:service forKey:@"services"];
            [[NSUserDefaults standardUserDefaults]synchronize];
            
            
            [self didReceiveLocalbeaconNotification:data withApplicationState:UIApplicationStateActive];
        }
        
    } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
    }];
}



-(void)didReceiveLocalbeaconNotification:(NSDictionary *)userInfo withApplicationState:(UIApplicationState)appState
{
    
    if(self.debug)
        NSLog(@"RECEIVE LOCAL NOTIFICATION -- %@", userInfo);
    
    
    if(![userInfo isKindOfClass:[NSDictionary class]])
        return;
    
    NSMutableDictionary * dicoUserInfo = [NSMutableDictionary new];
    
    if(_bubbleInstance.delegate && [_bubbleInstance.delegate respondsToSelector:@selector(bubblesDidReceiveNotification:)])
    {
        dicoUserInfo = [userInfo mutableCopy];
        
        if (appState == UIApplicationStateActive)
            [dicoUserInfo setObject:@"1" forKey:@"foreground"];
        else
            [dicoUserInfo setObject:@"0" forKey:@"foreground"];
        
        
        // TYPE SERVICES
        if ([[userInfo objectForKey:@"type"]isEqualToString:@"SRV"])
        {
            NSMutableDictionary * services = [[NSUserDefaults standardUserDefaults] objectForKey:@"services"];
            
            if(services)
            {
                NSMutableDictionary * service = [services objectForKey:@"service"];
                
                bool flag = NO;
                for (NSMutableDictionary * srv in service) {
                    
                    if ([[srv objectForKey:@"id"] isEqualToString:[dicoUserInfo objectForKey:@"service_id"]])
                    {
                        flag = YES;
                        
                        [dicoUserInfo setObject:[srv objectForKey:@"open_url"] forKey:@"open_url"];
                        [dicoUserInfo setObject:[srv objectForKey:@"background_image"] forKey:@"background_image"];
                        [dicoUserInfo setObject:[srv objectForKey:@"background_type"] forKey:@"background_type"];
                        [dicoUserInfo setObject:[srv objectForKey:@"name"] forKey:@"name"];
                        [dicoUserInfo setObject:[srv objectForKey:@"picto"] forKey:@"picto"];
                        [dicoUserInfo setObject:[srv objectForKey:@"picto_color"] forKey:@"picto_color"];
                        [dicoUserInfo setObject:[srv objectForKey:@"picto_splashscreen"] forKey:@"picto_splashscreen"];
                        [dicoUserInfo setObject:[srv objectForKey:@"picto_thumb"] forKey:@"picto_thumb"];
                        [dicoUserInfo setObject:[srv objectForKey:@"fullscreen"] forKey:@"fullscreen"];
                        
                        
                        [_bubbleInstance.delegate bubblesDidReceiveNotification:dicoUserInfo];
                        
                        if (appState == UIApplicationStateActive)
                            [self launchNotificationServiceWithData:dicoUserInfo withApplicationState:appState andWithServicesInstances:nil];
                        
                        break;
                    }
                }
                
                if (!flag)
                    [self getServiceListForService:service withApplicationState:appState];
                
            }
        }
        
        // OTHER TYPE
        else
        {
            if([[dicoUserInfo allKeys]containsObject:@"type"] && [[dicoUserInfo allKeys]containsObject:@"notification_text"])
            {
                [_bubbleInstance.delegate bubblesDidReceiveNotification:dicoUserInfo];
                
                if (appState == UIApplicationStateActive)
                    [self launchNotificationImageWithData:dicoUserInfo];
            }
        }
    }
    
    
    if([[userInfo allKeys]containsObject:@"scenario_history_id"])
    {
        NSDictionary * params = @{@"scenario_history_id" : [userInfo objectForKey:@"scenario_history_id"]};
        
        [DATA requestPOSTWithUrl:@"ibeacon/confirm" andDictionaryPost:params success:^(NSURLSessionDataTask *sessionDataTask, id response) {
        } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
            if(self.debug)
                NSLog(@"ERROR - request confirm -- %@", error);
        }];
    }
}











-(void)launchNotificationServiceWithData:(NSDictionary*)data withApplicationState:(UIApplicationState)appState andWithServicesInstances:(NSDictionary *)instances
{
    
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0ul);
    dispatch_async(queue, ^(void) {
        
        NSData *imageData = [NSData dataWithContentsOfURL:[NSURL URLWithString:[data objectForKey:@"picto"]]];
        UIImage* image = [[UIImage alloc] initWithData:imageData];
        
        if(image)
        {
            dispatch_async(dispatch_get_main_queue(), ^{
                _imgPicto = image;
                
                
                
                ISMessages* alert = [ISMessages cardAlertWithTitle:[data objectForKey:@"name"]
                                                           message:[data objectForKey:@"notification_text"]
                                                         iconImage:_imgPicto
                                                          duration:3.f
                                                       hideOnSwipe:YES
                                                         hideOnTap:YES
                                                         alertType:ISAlertTypeCustom
                                                     alertPosition:ISAlertPositionTop];
                
                
                alert.titleLabelFont = [UIFont boldSystemFontOfSize:16.f];
                alert.titleLabelTextColor = [UIColor blackColor];
                
                alert.messageLabelFont = [UIFont italicSystemFontOfSize:14.f];
                alert.messageLabelTextColor = [UIColor blackColor];
                
                alert.alertViewBackgroundColor = [UIColor colorWithRed:249.f/255.f
                                                                 green:191.f/255.f
                                                                  blue:59.f/255.f
                                                                 alpha:1.f];
                
                [alert show:^{
                    
                    if (instances && instances.count > 0 && [data objectForKey:@"service_id"])
                    {
                        for (NSString * currentService in [instances allKeys])
                        {
                            if ([currentService isEqualToString:[data objectForKey:@"service_id"]])
                            {
                                BridgeServiceHybrid * service = (BridgeServiceHybrid*)[instances objectForKey:currentService];
                                
                            }
                            else
                            {
                                [[NSNotificationCenter defaultCenter] postNotificationName:@"onClickNotification" object:data];
                            }
                        }
                    }
                    else
                    {
                        [[NSNotificationCenter defaultCenter] postNotificationName:@"onClickNotification" object:data];
                    }
                    
                    
                } didHide:^(BOOL finished) {
                }];
            });
        }
    });
}






-(void)launchNotificationImageWithData:(NSDictionary*)data
{
    
    ISMessages* alert = [ISMessages cardAlertWithTitle:[data objectForKey:@"notification_text"]
                                               message:nil
                                             iconImage:nil
                                              duration:3.f
                                           hideOnSwipe:YES
                                             hideOnTap:YES
                                             alertType:ISAlertTypeCustom
                                         alertPosition:ISAlertPositionTop];
    
    
    alert.titleLabelFont = [UIFont boldSystemFontOfSize:14.f];
    alert.titleLabelTextColor = [UIColor blackColor];
    
    //   alert.messageLabelFont = [UIFont boldSystemFontOfSize:8.f];
    //   alert.messageLabelTextColor = [UIColor blackColor];
    
    alert.alertViewBackgroundColor = [UIColor colorWithRed:197.f/255.f
                                                     green:239.f/255.f
                                                      blue:247.f/255.f
                                                     alpha:1.f];
    
    [alert show:^{
        
        [[NSNotificationCenter defaultCenter]postNotificationName:@"onClickNotification" object:data];
        
        
    } didHide:^(BOOL finished) {
    }];
    
}




#pragma mark - Usefull functions



- (NSData *)httpBodyForParamsDictionary:(NSDictionary *)paramDictionary
{
    NSMutableArray *parameterArray = [NSMutableArray array];
    
    [paramDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *obj, BOOL *stop) {
        NSString *param = [NSString stringWithFormat:@"%@=%@", key, [self percentEscapeString:obj]];
        [parameterArray addObject:param];
    }];
    
    NSString *string = [parameterArray componentsJoinedByString:@"&"];
    
    return [string dataUsingEncoding:NSUTF8StringEncoding];
}



- (NSString *)percentEscapeString:(NSString *)string
{
    NSString *result = CFBridgingRelease(CFURLCreateStringByAddingPercentEscapes(kCFAllocatorDefault,
                                                                                 (CFStringRef)string,
                                                                                 (CFStringRef)@" ",
                                                                                 (CFStringRef)@":/?@!$&'()*+,;=",
                                                                                 kCFStringEncodingUTF8));
    return [result stringByReplacingOccurrencesOfString:@" " withString:@"+"];
}






@end
