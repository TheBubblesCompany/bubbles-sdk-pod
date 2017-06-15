//
//  Bubbles.h
//  bubblesFramework
//
//  Created by Pierre RACINE on 08/10/2015.
//  Copyright © 2015 AbsolutLabs. All rights reserved.
//  @version 1.0


#import <UIKit/UIKit.h>
#import <WebKit/WebKit.h>
#import "BubbleServiceView.h"

@protocol BubblesDelegate <NSObject>

@optional

/****************** SERVICES ******************/
- (void) onServicesListLoaded: (NSDictionary*) services;
- (void) onServicesListFailed;
- (void) onHybridServiceReady;
- (void) onHybridServiceTimeout;
- (void) onClickNotification:(NSDictionary*)infos;
- (void) onOpenService:(NSString*)serviceId;
- (void) onCloseService;
/**********************************************/

-(void) bubblesDidReceiveNotification : (NSDictionary *) infos;

-(void) bleDidReceiveInfos:(NSString *)infos withKey:(NSString *)key; // a virer

-(void) onNetworkAvailable:(BOOL)status;


@end



@interface Bubbles : NSObject


@property (nonatomic, weak) id<BubblesDelegate> delegate;



+ (void) initWithAPIKey : (NSString *) APIKey andUserId:(NSString*)userID andUUID:(NSArray*)UUID andRegistrationId:(NSString *)registrationId andIsProd :(BOOL) isProd andEnableStatsScenario:(BOOL)stats;

+ (void)updateUserId:(NSString *)userId;

+ (void)setDebugLogBeaconEnabled:(BOOL)enable;



+ (void)didReceiveLocalNotification:(NSDictionary *)userInfo withApplicationState:(UIApplicationState)appState;


/****************** SERVICES ******************/

+ (void) getServices;

+ (void) loadServiceWithId:(NSString*)serviceId;

+ (BubbleServiceView *) getWebviewService;

+ (void)releaseService;

/**********************************************/


+ (void) setDelegate:(id<BubblesDelegate>)delegate;

+ (void)didEnterBackground;
+ (void)didBecomeActive;





@end
