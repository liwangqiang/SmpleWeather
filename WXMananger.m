//
//  WXMananger.m
//  SimpleWeather
//
//  Created by 李王强 on 15/12/19.
//  Copyright © 2015年 personal. All rights reserved.
//

#import "WXMananger.h"
#import "WXClient.h"
#import <TSMessages/TSMessage.h>

@interface WXMananger ()

@property (nonatomic, strong, readwrite) CLLocation *currentLocation;
@property (nonatomic, strong, readwrite) WXCondition *currentCondition;
@property (nonatomic, strong, readwrite) NSArray *hourlyForecast;
@property (nonatomic, strong, readwrite) NSArray *dailyForecast;

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, assign) BOOL isFirstUpdate;  //第一次获取的位置一般是来自缓存、无效
@property (nonatomic, strong) WXClient *client;

@end

@implementation WXMananger

+ (instancetype)sharedMananger
{
    static id _sharedManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        _sharedManager = [[self alloc]init];
    });
    
    return _sharedManager;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _locationManager = [[CLLocationManager alloc]init];
        _locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters;
        _locationManager.distanceFilter = 10;
        _locationManager.delegate = self;
        
        _client = [[WXClient alloc]init];
        
        [[[[RACObserve(self, currentLocation)ignore:nil]
        flattenMap:^RACStream *(CLLocation *newLocation) {
            return [RACSignal merge:@[[self updateCurrentConditions],
                                     [self updateDailyForecast],
                                     [self updateHourlyForecast]]];
        }] deliverOn:[RACScheduler mainThreadScheduler]]
        subscribeError:^(NSError *error) {
            [TSMessage showNotificationWithTitle:@"Error" subtitle:@"There was a problem fetching the latest weather" type:TSMessageNotificationTypeError];
        }];
    }
    return self;
}

- (void)findCurrentLocation
{
    self.isFirstUpdate = YES;
    
    //iOS later, you have to ask quthorization first and add corresponding key in info.plist
    if ([UIDevice currentDevice].systemVersion.floatValue >= 8.0) {
        CLAuthorizationStatus status = [CLLocationManager authorizationStatus];
        if (status == kCLAuthorizationStatusNotDetermined) {
            [self.locationManager requestWhenInUseAuthorization];
        } else if (status == kCLAuthorizationStatusDenied){
            NSLog(@"Denies to get location");
        }
    }
    [self.locationManager startUpdatingLocation];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray<CLLocation *> *)locations
{
    if (self.isFirstUpdate) {
        self.isFirstUpdate = NO;
        return;
    }
    
    CLLocation *location = [locations lastObject];
    
    if (location.horizontalAccuracy > 0) {
        self.currentLocation = location;
        [self.locationManager stopUpdatingLocation];
    }
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    NSLog(@"fail to get location: %@", error);
}

- (RACSignal *)updateCurrentConditions
{
    return [[self.client fetchCurrentConditionsForLocation:self.currentLocation.coordinate]
            doNext:^(WXCondition *condition) {
                self.currentCondition = condition;
            }];
}

- (RACSignal *)updateDailyForecast
{
    return [[self.client fetchDailyForecastForLocation:self.currentLocation.coordinate]
            doNext:^(NSArray *conditions) {
                self.dailyForecast = conditions;
            }];
}

- (RACSignal *)updateHourlyForecast
{
    return [[self.client fetchHourlyForecastForLocation:self.currentLocation.coordinate]
            doNext:^(NSArray *conditions) {
                self.hourlyForecast = conditions;
            }];
}

@end
