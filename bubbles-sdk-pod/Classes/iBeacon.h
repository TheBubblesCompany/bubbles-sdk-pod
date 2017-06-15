//
//  iBeacon.h
//  Bubbles
//
//  Created by Karim Koriche on 07/04/2016.
//  Copyright © 2016 AbsolutLabs. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreLocation/CoreLocation.h>
#import "Bubbles.h"

@interface iBeacon : NSObject <CLLocationManagerDelegate>

@property BOOL debug;
@property BOOL bluetoothEnable;
@property BOOL inBackground;

@property (nonatomic) UIBackgroundTaskIdentifier backgroundTask;

@property (nonatomic, strong) NSString * bubblesUUID;
@property (nonatomic, strong) CLLocationManager * locationManager;
@property (nonatomic, strong) Bubbles * bubbleInstance;
@property (nonatomic, weak) id<BubblesDelegate> delegate;
@property (nonatomic, strong) CLBeaconRegion * beaconRegion;
@property (nonatomic, strong) NSDateFormatter * dateFormatterYYYYMMDD;
@property (nonatomic, strong) NSDateFormatter * dateFormatterGMT;
@property (nonatomic, strong) NSUserDefaults * standardUserDefaults;
@property (strong, nonatomic) NSTimer * beaconTimer;
@property (strong, nonatomic) UIImage * imgPicto;

- (void) initBeacon;
- (void) initialize;
- (void) extendBackgroundRunningTime;
- (void) didReceiveLocalbeaconNotification:(NSDictionary *)userInfo withApplicationState:(UIApplicationState)appState;
- (void) setDebugLogBeaconEnabled:(BOOL)enable;

@end
