//
//  GBMWatchinfo.h
//  GBMWatchInfo
//
//  Created by lxw on 2018/9/11.
//

#import <Foundation/Foundation.h>

#define WATCH_FINISHLAUNCH0     @"FL0"
#define WATCH_FINISHLAUNCH1     @"FL1"
#define WATCH_VIEWDIDLOAD0      @"VDL0"
#define WATCH_VIEWDIDLOAD1      @"VDL1"
#define WATCH_VIEWDIDAPPEAR     @"VDAP"


@protocol AppendItem<NSObject>
@end

@interface AppendItem : NSObject
@property (nonatomic, strong) NSString *desc;
@property (nonatomic, assign) CFTimeInterval time;
- (instancetype)initWithTime:(CFTimeInterval)time msg:(NSString *)message;
- (instancetype)initWith:(NSDictionary<NSString *, NSNumber *> *)info;
@end



@interface GBMWatchInfo : NSObject
@property (nonatomic, assign) NSInteger     launchTimes;//标记启动次数。
@property (nonatomic, strong) NSMutableArray<AppendItem> *appendItems;
+ (NSDate *)watchDate;
//+ (void)clearAllWatchInfo;
//+ (NSArray *)readAllWatchInfo;
- (BOOL)isSaveValidLaunch;
+ (void)logParse:(NSURL *)fileUrl;
@end
