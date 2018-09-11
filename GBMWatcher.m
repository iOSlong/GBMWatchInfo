//
//  GBMWatcher.m
//  GBMWatchInfo
//
//  Created by lxw on 2018/9/11.
//

#import "GBMWatcher.h"
#import "pthread.h"

typedef NS_ENUM(NSInteger, GBMWatchState) {
    GBMWatchStateInitial = 0,
    GBMWatchStateRuning,
    GBMWatchStateStop,
};


@interface GBMWatcher ()
@property (nonatomic) CFTimeInterval startTimeInterval;
@property (nonatomic) CFTimeInterval temporaryTimeInterval;
@property (nonatomic) CFTimeInterval stopTimeInterval;
@property (nonatomic, strong) NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *mutableSplits;
@property (nonatomic) GBMWatchState state;
@property (nonatomic) pthread_mutex_t lock;
@property (nonatomic) GBMWatchInfo *watchInfo;

@end

@implementation GBMWatcher

+ (instancetype)sharedStopwatch {
    static GBMWatcher* stopwatch;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        stopwatch = [[GBMWatcher alloc] init];
    });
    
    return stopwatch;
}

- (void)dealloc {
    pthread_mutex_destroy(&_lock);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        _mutableSplits  = [NSMutableArray array];
        _watchInfo = [GBMWatchInfo new];
        pthread_mutex_init(&_lock, NULL);
    }
    return self;
}

- (NSArray *)splits {
    pthread_mutex_lock(&_lock);
    NSMutableArray<NSDictionary<NSString *, NSNumber *> *> *array = [self.mutableSplits copy];
    pthread_mutex_unlock(&_lock);
    return array;
}

- (NSString *)prettyPrintedSplits {
    NSMutableString *output = [[NSMutableString alloc] init];
    pthread_mutex_lock(&_lock);
    [self.mutableSplits enumerateObjectsUsingBlock:^(NSDictionary<NSString *, NSNumber *> *obj, NSUInteger idx, BOOL *stop) {
        [output appendFormat:@"%@: %.3f\n", obj.allKeys.firstObject, obj.allValues.firstObject.doubleValue];
    }];
    pthread_mutex_unlock(&_lock);
    
    return [output copy];
}

- (NSTimeInterval)elapseTimeInterval {
    switch (self.state) {
        case GBMWatchStateInitial:
            return 0;
        case GBMWatchStateRuning:
            return CACurrentMediaTime() - self.startTimeInterval;
        case GBMWatchStateStop:
            return self.stopTimeInterval - self.startTimeInterval;
    }
}

- (void)start {
    self.state = GBMWatchStateRuning;
    self.startTimeInterval = CACurrentMediaTime();
    self.temporaryTimeInterval = self.startTimeInterval;
}

- (void)splitWithDescription:(NSString * _Nullable)description {
    [self splitWithType:GBMWatchSplitTypeMedian description:description];
}

- (void)splitWithType:(GBMWatchSplitType)type description:(NSString * _Nullable)description {
    if (self.state != GBMWatchStateRuning) {
        return;
    }
    
    //如果事件点重复，保留以一次的。
    if ([self judgeDulpliacteDesc:description]) {
        return;
    }
    
    NSTimeInterval temporaryTimeInterval = CACurrentMediaTime();
    CFTimeInterval splitTimeInterval = type == GBMWatchSplitTypeMedian ? temporaryTimeInterval - self.temporaryTimeInterval : temporaryTimeInterval - self.startTimeInterval;
    
    NSInteger count = self.mutableSplits.count + 1;
    
    NSMutableString *finalDescription = [NSMutableString stringWithFormat:@"#%@", @(count)];
    if (description) {
        [finalDescription appendFormat:@" %@", description];
    }
    
    pthread_mutex_lock(&_lock);
    [self.mutableSplits addObject:@{finalDescription : @(splitTimeInterval)}];
    pthread_mutex_unlock(&_lock);
    self.temporaryTimeInterval = temporaryTimeInterval;
}

- (BOOL)judgeDulpliacteDesc:(NSString *)description {
    for (NSDictionary<NSString *,NSNumber *> *obj in self.mutableSplits) {
        if ([obj.allKeys.firstObject containsString:description]) {
            return YES;
        }
    }
    return NO;
}

- (void)refreshMedianTime {
    self.temporaryTimeInterval = CACurrentMediaTime();
}

- (void)stop {
    self.state = GBMWatchStateStop;
    self.stopTimeInterval = CACurrentMediaTime();
}

- (void)reset {
    self.state = GBMWatchStateInitial;
    pthread_mutex_lock(&_lock);
    [self.mutableSplits removeAllObjects];
    pthread_mutex_unlock(&_lock);
    self.startTimeInterval = 0;
    self.stopTimeInterval = 0;
    self.temporaryTimeInterval = 0;
}

- (void)stopAndPresentResultsThenReset {
    if (self.state == GBMWatchStateStop) {
        return;
    }
    [[GBMWatcher sharedStopwatch] stop];
    NSString *version = [UIDevice currentDevice].systemVersion;
    if (version.intValue >= 9) {
        UIAlertController *alertC = [[UIAlertController alloc] init];
        [alertC setTitle:@"GBMWatch 结果"];
        [alertC setMessage:[[GBMWatcher sharedStopwatch] prettyPrintedSplits]];
        UIAlertAction *action = [UIAlertAction actionWithTitle:@"OK" style:UIAlertActionStyleCancel handler:^(UIAlertAction * _Nonnull action) {
            [alertC dismissViewControllerAnimated:YES completion:nil];
        }];
        [alertC addAction:action];
        UIWindow *window = [UIApplication sharedApplication].keyWindow;
        [window.rootViewController presentViewController:alertC animated:YES completion:nil];
    }else{
        [[[UIAlertView alloc] initWithTitle:@"GBMWatch 结果"
                                    message:[[GBMWatcher sharedStopwatch] prettyPrintedSplits]
                                   delegate:nil
                          cancelButtonTitle:@"确定"
                          otherButtonTitles:nil] show];
    }
    [self saveWatchInfo];
    [[GBMWatcher sharedStopwatch] reset];
    [GBMWatchInfo readAllWatchInfo];
}


#pragma mark - database control
- (NSInteger )readWatchInfoLaunchCount {
    NSArray<GBMWatchInfo *> *infos = [GBMWatchInfo searchWithSQL:@"select * from @t order by launchTimes desc LIMIT 1"];
    GBMWatchInfo *lastOne = infos.lastObject;
    NSInteger launchTimes =  lastOne.launchTimes;
    return launchTimes + 1;
}

/** 保存当前下载信息到本地 */
- (void)saveWatchInfo {
    NSInteger launchTimes = [self readWatchInfoLaunchCount];
    if (launchTimes > 20) {
        [GBMWatchInfo clearAllWatchInfo];
        launchTimes = 1;
    }
    self.watchInfo.launchTimes = launchTimes;
    for (NSDictionary *info in self.mutableSplits) {
        AppendItem *aItem  = [[AppendItem alloc] initWith:info];
        [self.watchInfo.appendItems addObject:aItem];
    }
    
    if ([self.watchInfo isSaveValidLaunch]) {
        BOOL suc = [self.watchInfo saveToDB];
        if (suc) {
            [self.watchInfo.appendItems removeAllObjects];
        }
    }
}

@end
