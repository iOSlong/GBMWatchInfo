//
//  GBMWatcher.h
//  GBMWatchInfo
//
//  Created by lxw on 2018/9/11.
//

#import <Foundation/Foundation.h>
#import "GBMWatchInfo.h"


typedef NS_ENUM(NSInteger, GBMWatchSplitType) {
    GBMWatchSplitTypeMedian = 0, // 记录中间值.
    GBMWatchSplitTypeContinuous // 记录连续值.
};



@interface GBMWatcher : NSObject

+ (instancetype)sharedWatcher;

@property (nonatomic, readonly) NSArray<NSDictionary<NSString *, NSNumber *> *> *splits;
@property (nonatomic, readonly) NSString *prettyPrintedSplits;
@property (nonatomic, readonly) NSTimeInterval elapseTimeInterval;

- (void)start;

/**
 * 打点(默认记录中间值).
 *
 * @param description 描述信息.
 */
- (void)splitWithDescription:(NSString * _Nullable)description;

/**
 * 打点.
 *
 * @param type 记录的类型.
 * @param description 描述信息.
 */
- (void)splitWithType:(GBMWatchSplitType)type description:(NSString * _Nullable)description;

/**
 * 刷新中间值.
 */
- (void)refreshMedianTime;

- (void)stop;
- (void)reset;

- (void)stopAndPresentResultsThenReset;

@end
