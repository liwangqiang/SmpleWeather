//
//  WXClient.m
//  SimpleWeather
//
//  Created by 李王强 on 15/12/19.
//  Copyright © 2015年 personal. All rights reserved.
//

#import "WXClient.h"
#import "WXCondition.h"
#import "WXDailyForecast.h"

static NSString *const appid = @"2de143494c0b295cca9337e1e96b00e0";

@interface WXClient ()

@property (nonatomic, strong) NSURLSession *session;

@end

@implementation WXClient

- (instancetype)init
{
    if (self = [super init]) {
        NSURLSessionConfiguration *config = [NSURLSessionConfiguration defaultSessionConfiguration];
        _session = [NSURLSession sessionWithConfiguration:config];
    }
    return self;
}

- (RACSignal *)fetchDailyForecastForLocation:(CLLocationCoordinate2D)coordinate
{
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/forecast/daily?lat=%f&lon=%f&cnt=7&units=metric", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:[self appendAppID:urlString]];
    return [[self fetchJSONFromURL:url] map:^id(NSDictionary *json) {
        RACSequence *list = [json[@"list"] rac_sequence];
        
        return [[list map:^id(NSDictionary *item) {
            return [MTLJSONAdapter modelOfClass:[WXDailyForecast class] fromJSONDictionary:item error:nil];
        }] array];
    }];
}

- (RACSignal *)fetchHourlyForecastForLocation:(CLLocationCoordinate2D)coordinate
{
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/forecast?lat=%f&lon=%f&units=metric", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:[self appendAppID:urlString]];
    
    return [[self fetchJSONFromURL:url] map:^id(NSDictionary *json) {
        RACSequence *list = [json[@"list"] rac_sequence];
        
        return [[list map:^id(NSDictionary *item) {
            return [MTLJSONAdapter modelOfClass:[WXCondition class] fromJSONDictionary:item error:nil];
        }]array];
    }];
}

- (RACSignal *)fetchCurrentConditionsForLocation:(CLLocationCoordinate2D)coordinate
{
    NSString *urlString = [NSString stringWithFormat:@"http://api.openweathermap.org/data/2.5/weather?lat=%f&lon=%f&units=metric", coordinate.latitude, coordinate.longitude];
    NSURL *url = [NSURL URLWithString:[self appendAppID:urlString]];
    
    return [[self fetchJSONFromURL:url]
            flattenMap:^id(NSDictionary *json) {
                NSError *error = nil;
                WXCondition *condition =
                condition = [MTLJSONAdapter modelOfClass:[WXCondition class] fromJSONDictionary:json error:&error];
                if (error) {
                   return  [RACSignal error:error];
                } else {
                    return [RACSignal return:condition];
                }
    }];
}

- (RACSignal *)fetchJSONFromURL:(NSURL *)url
{
    NSLog(@"will fetch JSON From url: %@", url);
    return [[RACSignal createSignal:^RACDisposable *(id<RACSubscriber> subscriber) {
       NSURLSessionDataTask *dataTask = [self.session dataTaskWithURL:url completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
           if (!error) {
               NSError *jsonError = nil;
               id json = [NSJSONSerialization JSONObjectWithData:data options:kNilOptions error:&jsonError];
               NSLog(@"%s: %@", __func__, json);
               if (!jsonError) {
                   [subscriber sendNext:json];
               } else {
                   [subscriber sendError:jsonError];
               }
           } else {
               [subscriber sendError:error];
           }
           [subscriber sendCompleted];
       }];
        [dataTask resume];
        
        return [RACDisposable disposableWithBlock:^{
            [dataTask cancel];
        }];
    }]doError:^(NSError *error) {
        NSLog(@"%@", error);
    }];
}

- (NSString *)appendAppID:(NSString *)origin
{
    return [NSString stringWithFormat:@"%@&appid=%@", origin, appid];
}

@end
