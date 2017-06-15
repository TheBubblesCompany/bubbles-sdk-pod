//
//  DataAccess.m
//  BubblesTwo
//
//  Created by Pierre RACINE on 30/03/2016.
//  Copyright © 2016 Absolutlabs. All rights reserved.
//

#import "AFNetworkReachabilityManager.h"
#include <sys/types.h>
#include <sys/sysctl.h>
#import "DataAccess.h"
#import "PDKeychainBindings.h"


@interface DataAccess()
{
    NSString * keyLanguage;
}

@property (nonatomic, strong) NSString * urlServer;

@property (nonatomic) BOOL requestDeviceIdFinish;

@end


@implementation DataAccess


#pragma mark - Init


static DataAccess * _dataAccess;


+ (DataAccess *) dataAccess
{
    if(!_dataAccess)
        _dataAccess = [[DataAccess alloc]init];
    
    return _dataAccess;
}





-(instancetype)init
{
    self = [super init];
    if(self)
    {
        [[AFNetworkReachabilityManager sharedManager]startMonitoring];
        [[AFNetworkReachabilityManager sharedManager]setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status) {
            [[NSNotificationCenter defaultCenter]postNotificationName:@"ReachabilityStatusChange" object:@(status)];
        }];
        
        _apiVersion = 2;
        
        NSString * language = [[NSLocale preferredLanguages] objectAtIndex:0];
        _applicationLanguage = [language substringToIndex:2];
        
        NSLog(@"AppLanguageTest %@", _applicationLanguage);
    }
    
    return self;
    
}




- (void)mode:(BOOL)isProd withAPIkey:(NSString*)apiKey andUserId:(NSString*)userID
{
    if (isProd)
    {
        _urlServer = @"https://api-sdk.prod.bubbles-company.com";
    }
    else
    {
        _urlServer = @"https://api-sdk.staging.bubbles-company.com";
    }
    
    _userId = userID;
    _apiKey = apiKey;
    
    NSLog(@"data mode %d, userID %@, apiKey %@", isProd, _userId, _apiKey);
    
}




-(void)requestDeviceId
{
    _deviceId = [[NSUserDefaults standardUserDefaults]objectForKey:@"device_id"];
    
    
    
    //////////////////////////// UUID GENERATION ///////////////////////
    
    NSString * appUUID = [[NSUUID UUID] UUIDString];
    NSString * newAppUUID = [appUUID stringByReplacingOccurrencesOfString:@"-" withString:@""];
    NSLog(@"newAppUUID %@", newAppUUID);
    
    NSString * bundleIdentifier = [[NSBundle mainBundle] bundleIdentifier];
    NSLog(@"strUUID %@", bundleIdentifier);
    
    PDKeychainBindings * bindings = [PDKeychainBindings sharedKeychainBindings];
    NSString * currentUUID = [bindings objectForKey:bundleIdentifier];
    
    if (currentUUID.length > 0)
    {
        NSLog(@"currentUUID is %@", currentUUID);
    }
    else {
        
        [bindings setObject:newAppUUID forKey:bundleIdentifier];
        currentUUID = newAppUUID;
    }
    /////////////////////////////////////////////////////////////////////
    
    _uniqueId = currentUUID;
    
    
    NSDictionary *parameters = @{@"device" : @{
                                         @"unique_id" : currentUUID,
                                         @"language" : [[NSLocale currentLocale]localeIdentifier],
                                         @"country" : [[NSLocale currentLocale]objectForKey:NSLocaleCountryCode],
                                         @"type" : @"iOS",
                                         @"scale" : [NSString stringWithFormat:@"%f", [UIScreen mainScreen].scale],
                                         @"ios" : @{
                                                 @"name" : [[UIDevice currentDevice]name],
                                                 @"system_name": [[UIDevice currentDevice]systemName],
                                                 @"system_version": [[UIDevice currentDevice]systemVersion],
                                                 @"model" : [[UIDevice currentDevice]model],
                                                 @"machine_id" : [self platformString],
                                                 @"localized_model" : [[UIDevice currentDevice]localizedModel],
                                                 @"user_interface_idiom" : [[UIDevice currentDevice]userInterfaceIdiom] == -1 ? @"UIUserInterfaceIdiomUnspecified" : [[UIDevice currentDevice]    userInterfaceIdiom] == 0 ? @"UIUserInterfaceIdiomPhone" : @"UIUserInterfaceIdiomPad",
                                                 @"identifier_for_vendor" : [[[UIDevice currentDevice]identifierForVendor]UUIDString]
                                                 }
                                         }
                                 };
    
    NSLog(@"param Device ID %@", parameters);
    
    [self requestPUTWithUrl:@"device/register" andDictionaryPost:parameters success:^(NSURLSessionDataTask *sessionDataTask, id response)
     {
         
         _requestDeviceIdFinish = YES;
         
         if([[response objectForKey:@"success"] boolValue])
         {
             _deviceId = [response objectForKey:@"id"];
             
             if(_deviceId)
             {
                 [[NSUserDefaults standardUserDefaults]setObject:_deviceId forKey:@"device_id"];
                 [[NSUserDefaults standardUserDefaults]synchronize];
                 
                 [self requestServices];
             }
             
             NSLog(@"device_id OK %@", _deviceId);
         }
         else
         {
             NSHTTPURLResponse* res = (NSHTTPURLResponse*)sessionDataTask.response;
             NSLog( @"error.code: %ld", res.statusCode );
             NSLog( @"error.description: %@", res.description );
             NSLog( @"error.debugDescription: %@", res.debugDescription);
             NSLog( @"res: %@", res.debugDescription);
         }
         
     } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
         
         NSLog(@"erroDeviceID = %@", error.description);
         NSHTTPURLResponse* res = (NSHTTPURLResponse*)sessionDataTask.response;
         NSLog( @"error.code: %ld", res.statusCode );
         NSLog( @"error.description: %@", res.description );
         NSLog( @"error.debugDescription: %@", res.debugDescription);
         NSLog( @"res: %@", res.debugDescription);
         
     }];
}


#pragma mark - Services

-(void)requestServices
{
    [DATA requestGETWithUrl:@"service/list" andDictionaryPost:nil success:^(NSURLSessionDataTask *sessionDataTask, id response) {
        
        NSMutableDictionary * service = response;
        
        if(service)
        {
            NSLog(@"serviceLISTE return %@", service);
            
            [[NSUserDefaults standardUserDefaults]setObject:[NSDate date] forKey:@"serviceRequestLastDate"];
            
            [[NSUserDefaults standardUserDefaults]setObject:service forKey:@"services"];
            [[NSUserDefaults standardUserDefaults]synchronize];
            
            [self callbackServicesLoaded];
        }
        
    } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
        
        [self callbackServicesFailed];
        
    }];
}




-(void)callbackServicesLoaded
{
    Class class = NSClassFromString(@"Bubbles");
    SEL selector = NSSelectorFromString(@"onRequestServicesLoaded");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [class performSelector:selector];
#pragma clang diagnostic pop
}


-(void)callbackServicesFailed
{
    Class class = NSClassFromString(@"Bubbles");
    SEL selector = NSSelectorFromString(@"onRequestServicesFailed");
    
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Warc-performSelector-leaks"
    [class performSelector:selector];
#pragma clang diagnostic pop
}



-(NSString *) platformString {
    // Gets a string with the device model
    size_t size;
    sysctlbyname("hw.machine", NULL, &size, NULL, 0);
    char *machine = malloc(size);
    sysctlbyname("hw.machine", machine, &size, NULL, 0);
    NSString *platform = [NSString stringWithCString:machine encoding:NSUTF8StringEncoding];
    free(machine);
    
    return platform;
}




-(void)confirmLocalization
{
    [self requestPUTWithUrl:@"device/confirm_localization" andDictionaryPost:nil success:^(NSURLSessionDataTask *sessionDataTask, id response) {
        NSLog(@"confirm_localization success");
        
        [[NSUserDefaults standardUserDefaults]setObject:@"ok" forKey:@"confirm_localization"];
        [[NSUserDefaults standardUserDefaults]synchronize];
        
    } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
        NSLog(@"confirm_localization error %@", error);
    }];
}


- (void) confirmNotification
{
    [self requestPUTWithUrl:@"device/confirm_notification" andDictionaryPost:nil success:^(NSURLSessionDataTask *sessionDataTask, id response) {
        NSLog(@"confirm_notification success");
        
        [[NSUserDefaults standardUserDefaults]setObject:@"ok" forKey:@"confirm_notification"];
        [[NSUserDefaults standardUserDefaults]synchronize];
        
    } failure:^(NSURLSessionDataTask *sessionDataTask, NSString *error) {
        NSLog(@"confirm_notification error %@", error);
    }];
}




#pragma mark - Request







-(void)requestPOSTWithUrl:(NSString *)stringURL andDictionaryPost:(NSDictionary *)dictionaryPost
                  success:(void (^)(NSURLSessionDataTask * sessionDataTask, id response))success
                  failure:(void (^)(NSURLSessionDataTask * sessionDataTask, NSString *error))failure
{
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString * deviceID = nil;
    if ([[[standardUserDefaults dictionaryRepresentation]allKeys]containsObject:@"device_id"])
        deviceID = [standardUserDefaults objectForKey:@"device_id"];
    
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    [manager.requestSerializer setValue:_apiKey forHTTPHeaderField:@"X-Api-Key"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"%ld", _apiVersion] forHTTPHeaderField:@"X-Api-Version"];
    [manager.requestSerializer setValue:_applicationLanguage forHTTPHeaderField:@"X-Application-Language"];
    if (_deviceId) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _deviceId] forHTTPHeaderField:@"X-Device-ID"];
    if (_uniqueId.length > 1) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _uniqueId] forHTTPHeaderField:@"X-Unique-ID"];
    
    NSString * cookie = nil;
    if ([[[standardUserDefaults dictionaryRepresentation]allKeys]containsObject:@"session"])
        cookie = [standardUserDefaults objectForKey:@"session"];
    
    if (cookie)
        [manager.requestSerializer setValue:cookie forHTTPHeaderField:@"Cookie"];
    
    
    NSLog(@"dico POST %@", dictionaryPost);
    
    [manager POST:[NSString stringWithFormat:@"%@/%@", self.urlServer, stringURL] parameters:dictionaryPost progress:nil
          success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
              
              success(task, responseObject);
              
          } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
              
              NSHTTPURLResponse* res = (NSHTTPURLResponse*)task.response;
              NSLog( @"error.code: %ld", res.statusCode );
              NSLog( @"error.description: %@", res.description );
              NSLog( @"error.debugDescription: %@", res.debugDescription);
              NSLog( @"res: %@", res.debugDescription);
              
              NSString* ErrorResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
              
              printf("ErrorResponse %s", [NSString stringWithFormat: @"%@", ErrorResponse].UTF8String);
              
              failure(task, ErrorResponse);
              
          }];
}







-(void)requestGETWithUrl:(NSString *)stringURL andDictionaryPost:(NSDictionary *)dictionaryPost
                 success:(void (^)(NSURLSessionDataTask * sessionDataTask, id response))success
                 failure:(void (^)(NSURLSessionDataTask * sessionDataTask, NSString *error))failure
{
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString * deviceID = nil;
    if ([[[standardUserDefaults dictionaryRepresentation]allKeys]containsObject:@"device_id"])
        deviceID = [standardUserDefaults objectForKey:@"device_id"];
    
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    [manager.requestSerializer setValue:_apiKey forHTTPHeaderField:@"X-Api-Key"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"%ld", _apiVersion] forHTTPHeaderField:@"X-Api-Version"];
    [manager.requestSerializer setValue:_applicationLanguage forHTTPHeaderField:@"X-Application-Language"];
    if (_deviceId) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _deviceId] forHTTPHeaderField:@"X-Device-ID"];
    if (_uniqueId.length > 1) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _uniqueId] forHTTPHeaderField:@"X-Unique-ID"];
    
    NSString * cookie = nil;
    if ([[[standardUserDefaults dictionaryRepresentation]allKeys]containsObject:@"session"])
        cookie = [standardUserDefaults objectForKey:@"session"];
    
    if (cookie)
        [manager.requestSerializer setValue:cookie forHTTPHeaderField:@"Cookie"];
    
    
    
    
    NSLog(@"get %@ - %ld - %@ - %@ - %@",_apiKey, (long)_apiVersion, _applicationLanguage , _deviceId , dictionaryPost);
    
    
    
    [manager GET:[NSString stringWithFormat:@"%@/%@", self.urlServer, stringURL] parameters:dictionaryPost progress:nil
         success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
             
             success(task, responseObject);
             
         } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
             
             NSHTTPURLResponse* res = (NSHTTPURLResponse*)task.response;
             NSLog( @"error.code: %ld", res.statusCode );
             NSLog( @"error.description: %@", res.description );
             NSLog( @"error.debugDescription: %@", res.debugDescription);
             NSLog( @"res: %@", res.debugDescription);
             
             NSString* ErrorResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
             //  NSLog(@"ErrorResponse %@",ErrorResponse);
             
             printf("ErrorResponse %s", [NSString stringWithFormat: @"%@", ErrorResponse].UTF8String);
             
             failure(task, error.localizedDescription);
         }];
}






-(void)requestPUTWithUrl:(NSString *)stringURL andDictionaryPost:(NSDictionary *)dictionaryPost
                 success:(void (^)(NSURLSessionDataTask * sessionDataTask, id response))success
                 failure:(void (^)(NSURLSessionDataTask * sessionDataTask, NSString *error))failure
{
    
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString * deviceID = nil;
    if ([[[standardUserDefaults dictionaryRepresentation]allKeys]containsObject:@"device_id"])
        deviceID = [standardUserDefaults objectForKey:@"device_id"];
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    [manager.requestSerializer setValue:_apiKey forHTTPHeaderField:@"X-Api-Key"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"%ld", _apiVersion] forHTTPHeaderField:@"X-Api-Version"];
    [manager.requestSerializer setValue:_applicationLanguage forHTTPHeaderField:@"X-Application-Language"];
    if (_deviceId) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _deviceId] forHTTPHeaderField:@"X-Device-ID"];
    if (_uniqueId.length > 1) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _uniqueId] forHTTPHeaderField:@"X-Unique-ID"];
    
    if ([stringURL isEqualToString:@"device/register"])
    {
        if (_userId.length > 1) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _userId] forHTTPHeaderField:@"X-User-ID"];
    }
    
    
    [manager PUT:[NSString stringWithFormat:@"%@/%@", self.urlServer, stringURL] parameters:dictionaryPost success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        success(task, responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        NSHTTPURLResponse* res = (NSHTTPURLResponse*)task.response;
        NSLog( @"error.code: %ld", res.statusCode );
        NSLog( @"error.description: %@", res.description );
        NSLog( @"error.debugDescription: %@", res.debugDescription);
        NSLog( @"res: %@", res.debugDescription);
        
        NSString* ErrorResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
        
        printf("ErrorResponse %s", [NSString stringWithFormat: @"%@", ErrorResponse].UTF8String);
        
        failure(task, error.localizedDescription);
    }];
}





-(void)requestDELETEwithUrl:(NSString *)stringURL andDictionaryPost:(NSDictionary *)dictionaryPost
                    success:(void (^)(NSURLSessionDataTask * sessionDataTask, id response))success
                    failure:(void (^)(NSURLSessionDataTask * sessionDataTask, NSString *error))failure
{
    NSUserDefaults * standardUserDefaults = [NSUserDefaults standardUserDefaults];
    
    NSString * deviceID = nil;
    if ([[[standardUserDefaults dictionaryRepresentation]allKeys]containsObject:@"device_id"])
        deviceID = [standardUserDefaults objectForKey:@"device_id"];
    
    
    AFHTTPSessionManager * manager = [AFHTTPSessionManager manager];
    manager.securityPolicy.allowInvalidCertificates = YES;
    
    [manager.requestSerializer setValue:_apiKey forHTTPHeaderField:@"X-Api-Key"];
    [manager.requestSerializer setValue:[NSString stringWithFormat:@"%ld", _apiVersion] forHTTPHeaderField:@"X-Api-Version"];
    [manager.requestSerializer setValue:_applicationLanguage forHTTPHeaderField:@"X-Application-Language"];
    if (_deviceId) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _deviceId] forHTTPHeaderField:@"X-Device-ID"];
    if (_uniqueId.length > 1) [manager.requestSerializer setValue:[NSString stringWithFormat:@"%@", _uniqueId] forHTTPHeaderField:@"X-Unique-ID"];
    
    
    NSString * cookie = nil;
    if ([[[standardUserDefaults dictionaryRepresentation]allKeys]containsObject:@"session"])
        cookie = [standardUserDefaults objectForKey:@"session"];
    
    if (cookie)
        [manager.requestSerializer setValue:cookie forHTTPHeaderField:@"Cookie"];
    
    
    [manager DELETE:[NSString stringWithFormat:@"%@/%@", self.urlServer, stringURL] parameters:dictionaryPost success:^(NSURLSessionDataTask * _Nonnull task, id  _Nullable responseObject) {
        success(task, responseObject);
    } failure:^(NSURLSessionDataTask * _Nullable task, NSError * _Nonnull error) {
        
        NSHTTPURLResponse* res = (NSHTTPURLResponse*)task.response;
        NSLog( @"error.code: %ld", res.statusCode );
        NSLog( @"error.description: %@", res.description );
        NSLog( @"error.debugDescription: %@", res.debugDescription);
        NSLog( @"res: %@", res.debugDescription);
        
        NSString* ErrorResponse = [[NSString alloc] initWithData:(NSData *)error.userInfo[AFNetworkingOperationFailingURLResponseDataErrorKey] encoding:NSUTF8StringEncoding];
        
        printf("ErrorResponse %s", [NSString stringWithFormat: @"%@", ErrorResponse].UTF8String);
        
        failure(task, error.localizedDescription);
    }];
}




@end
