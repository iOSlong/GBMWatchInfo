//
//  GBMGBMWatchInfo.m
//  GBMGBMWatchInfo
//
//  Created by lxw on 2018/9/11.
//

#import "GBMWatchInfo.h"

NSArray * logComponentsFrom(NSString *fileContent, NSString *prefix){
    @try {
        NSString *pattern = prefix;
        NSRegularExpression *regexExp = [NSRegularExpression regularExpressionWithPattern:pattern options:0 error:nil];
        NSArray *matches = [regexExp matchesInString:fileContent options:0 range:NSMakeRange(0, fileContent.length)];
        
        NSMutableArray  *logComponents = [NSMutableArray array];
        for (int i = 0;  i < matches.count - 1 ; i++ ) {
            NSTextCheckingResult *crH = matches[i];
            NSTextCheckingResult *crT = matches[i+1];
            NSRange rangeH = [crH range];
            NSRange rangeT = [crT range];
            NSRange groupRange = NSMakeRange(rangeH.location, rangeT.location - rangeH.location);
            NSString *logGroup = [fileContent substringWithRange:groupRange];
            [logComponents addObject:logGroup];
            if (i+1 == matches.count - 1) {
                [logComponents addObject:[fileContent substringFromIndex:rangeT.location]];
            }
        }
        return logComponents;
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    }
}

NSString * purelyRowLog(NSString *rowlog) {
    NSString *purely = [rowlog stringByReplacingOccurrencesOfString:@"\t" withString:@""];
    purely = [rowlog stringByReplacingOccurrencesOfString:@"milliseconds" withString:@""];
    return purely;
}

NSDictionary * parseInfoFromPre_mainLog(NSString *logcomponent) {
    @try {
        NSArray *logrows = [logcomponent componentsSeparatedByString:@"\n"];
        NSMutableDictionary *validrowlog = [NSMutableDictionary dictionary];
        for (NSString *rowlog in logrows) {
            if ([rowlog containsString:@":"]) {
                NSString *purelyRow = purelyRowLog(rowlog);
                NSArray *rowcomponents = [purelyRow componentsSeparatedByString:@":"];
                [validrowlog setObject:rowcomponents.lastObject forKey:rowcomponents.firstObject];
            }
        }
        return validrowlog;
    } @catch (NSException *exception) {
        NSLog(@"%@",exception);
    }
}

NSString *fileDocumentPath() {
    NSArray  *directoryArr      = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
    NSString *documentDirectory = directoryArr.firstObject;
    return documentDirectory;
}




@implementation AppendItem
- (instancetype)initWith:(NSDictionary<NSString *,NSNumber *> *)info {
    self = [super init];
    if (self) {
        _time = info.allValues.firstObject.doubleValue;
        _desc = info.allKeys.firstObject;
    }
    return self;
}
- (instancetype)initWithTime:(CFTimeInterval)time msg:(NSString *)message {
    self = [super init];
    if (self) {
        _time = time;
        _desc = message;
    }
    return self;
}

@end


#define GBMWatchInfoFile  @"watchInfoFile"

@implementation GBMWatchInfo

//+ (LKDBHelper *)getUsingLKDBHelper {
//    static id db;
//    static dispatch_once_t onceToken;
//    dispatch_once(&onceToken, ^{
//        NSString *dbPath = [fileDocumentPath() stringByAppendingPathComponent:GBMWatchInfoFile];
//        dbPath = [dbPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.db",NSStringFromClass([self class])]];
//        db = [[LKDBHelper alloc] initWithDBPath:dbPath];
//    });
//    return db;
//}

+ (NSString *)getTableName {
    return @"GBMWatchInfo";
}

+ (NSDate *)watchDate {
    NSDate *date = [NSDate date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSInteger interval = [zone secondsFromGMTForDate: date];
    NSDate *localeDate = [date  dateByAddingTimeInterval: interval];
    return localeDate;
}

//+ (NSArray *)readAllGBMWatchInfo {
//    NSArray<GBMWatchInfo *> *infos = [GBMWatchInfo searchWithSQL:@"select * from @t order by launchTimes ASC"];//! 逆序 DESC
//
//    [self formatInfos:infos];
//
//    NSMutableArray *muArr = [NSMutableArray array];
//    for (GBMWatchInfo *info in infos) {
//        [muArr addObject:[info toJSONString]];
//    }
//    return muArr;
//}

+ (void)formatInfos:(NSArray<GBMWatchInfo *> *)infos {
    NSMutableString *formatString = [NSMutableString string];
    for (AppendItem *item in [infos firstObject].appendItems) {
        [formatString appendFormat:@"%@ \b",item.desc];
    }
    [formatString appendString:@"\n"];
    for (int i = 1; i <= infos.count; i ++) {
        GBMWatchInfo *info = infos[i - 1];
        NSMutableString *rowString = [NSMutableString stringWithFormat:@"%d \b",i];
        [rowString appendString:[info rowFormatString]];
        [rowString appendString:@"\n"];
        [formatString appendString:rowString];
    }
    NSError *error = nil;
    NSString *dbPath = [fileDocumentPath() stringByAppendingPathComponent:GBMWatchInfoFile];
    [formatString writeToFile:[dbPath stringByAppendingPathComponent:@"static_funtime"] atomically:YES encoding:NSUTF8StringEncoding error:&error];
}

//+ (void)clearAllGBMWatchInfo {
//    [GBMWatchInfo deleteWithWhere:nil];
//}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _appendItems = (NSMutableArray<AppendItem> *)[NSMutableArray array];
    }
    return self;
}

- (BOOL)isSaveValidLaunch {
    for (AppendItem *item in self.appendItems) {
        if ([item.desc containsString:WATCH_FINISHLAUNCH0]) {
            return YES;
        }
    }
    return NO;
}

- (CFTimeInterval)timeDock:(NSString *)dock {
    for (AppendItem *item in self.appendItems) {
        if ([item.desc containsString:dock]) {
            return item.time;
        }
    }
    return 0.0;
}
- (NSString *)rowFormatString {
    //@"FL1"  @"VDL0"  @"VDL1"  @"VDAP"
    CFTimeInterval FL0  = [self timeDock:WATCH_FINISHLAUNCH0];
    CFTimeInterval FL1  = [self timeDock:WATCH_FINISHLAUNCH1];
    CFTimeInterval VDL0 = [self timeDock:WATCH_VIEWDIDLOAD0];
    CFTimeInterval VDL1 = [self timeDock:WATCH_VIEWDIDLOAD1];
    CFTimeInterval VDAP = [self timeDock:WATCH_VIEWDIDAPPEAR];
    return [NSString stringWithFormat:@"%.4f \t %.4f \t %.4f \t %.4f \t %.4f ",FL0,FL1,VDL0,VDL1,VDAP];
}

#pragma mark - Pre-main log parse
+ (void)logParse:(NSURL *)fileUrl {
    NSURL *url = fileUrl;
    if (!url) {
        NSString *path = [[NSBundle mainBundle] pathForResource:@"logfile" ofType:nil];
        url = [NSURL fileURLWithPath:path];
    }
    NSError *error = nil;
    NSString *fileContent = [NSString stringWithContentsOfURL:url encoding:NSUTF8StringEncoding error:&error];
    if (!error) {
        NSArray *logrows = logComponentsFrom(fileContent, @"Total pre-main");
        NSMutableArray *logcomponents = [NSMutableArray arrayWithCapacity:logrows.count];
        for (NSString *rowlog in logrows) {
            [logcomponents addObject:parseInfoFromPre_mainLog(rowlog)];
        }
        [logcomponents sortUsingComparator:^NSComparisonResult(NSDictionary *obj1, NSDictionary *obj2) {
            return obj1.allKeys.count < obj2.allKeys.count;
        }];
        NSDictionary *bigcomponent = logcomponents.firstObject;
        NSMutableString *formatLog = [NSMutableString string];
        [formatLog appendString:[bigcomponent.allKeys componentsJoinedByString:@"\t"]];
        [formatLog appendString:@"\n"];
        for (NSDictionary *logcomponent in logcomponents) {
            for (NSString *key in bigcomponent.allKeys) {
                [formatLog appendString:[logcomponent objectForKey:key]?:@"0"];
                [formatLog appendString:@"\t"];
            }
            [formatLog appendString:@"\n"];
        }
        
        NSLog(@"%@",formatLog);
        NSError *error = nil;
        NSString *dbPath = [fileDocumentPath() stringByAppendingPathComponent:GBMWatchInfoFile];
        [formatLog writeToFile:[dbPath stringByAppendingPathComponent:@"pre-main_static"] atomically:YES encoding:NSUTF8StringEncoding error:&error];
    }
}
@end
