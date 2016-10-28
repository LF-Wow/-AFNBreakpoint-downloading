//
//  ViewController.m
//  文件断点下载Demo
//
//  Created by 周君 on 16/9/20.
//  Copyright © 2016年 周君. All rights reserved.
//

#import "ViewController.h"
#import <AFNetworking.h>

#define defaultPath [NSHomeDirectory() stringByAppendingPathComponent:@"Documents/resume.plist"]

typedef enum : NSUInteger {
    beign,
    pasue,
    resume,
} ButtonStates;

@interface ViewController ()
/** 开始下载的按钮**/
@property (weak, nonatomic) IBOutlet UIButton *downButton;
/** 进度条**/
@property (weak, nonatomic) IBOutlet UIProgressView *progressView;
/** 任务**/
@property (nonatomic, strong) NSURLSessionDownloadTask *downTask;
/** 记录暂停时的数据**/
@property (nonatomic, strong) NSData *resumeData;
/** 创建一个文件管理对象**/
@property (nonatomic, strong) NSFileManager *manager;
/** 创建一个字典用来保存数据路径和下载进度**/
@property (nonatomic, strong) NSMutableDictionary *dataDic;

@end

@implementation ViewController

#pragma mark - 懒加载
- (NSFileManager *)manager
{
    if(!_manager
       )
    {
        _manager = [NSFileManager defaultManager];
    }
    
    return _manager;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    
    //网络监控句柄
    AFNetworkReachabilityManager *manager = [AFNetworkReachabilityManager sharedManager];
    
    //要监控网络连接状态，必须要先调用单例的startMonitoring方法
    [manager startMonitoring];
    
    [manager setReachabilityStatusChangeBlock:^(AFNetworkReachabilityStatus status)
    {
        //status:
        //AFNetworkReachabilityStatusUnknown          = -1,  未知
        //AFNetworkReachabilityStatusNotReachable     = 0,   未连接
        //AFNetworkReachabilityStatusReachableViaWWAN = 1,   3G
        //AFNetworkReachabilityStatusReachableViaWiFi = 2,   无线连接
        
        NSLog(@"%lu", status);
    }];
    
    [self initView];

}

#pragma mark - 初始化视图
- (void)initView
{
    self.dataDic = (NSMutableDictionary *)[NSDictionary dictionaryWithContentsOfFile:defaultPath];
    
    //如果有以前的数据就更改UI,给数据赋值
    if (_dataDic)
    {
        self.resumeData = _dataDic[@"resumeData"];
        self.progressView.progress = [_dataDic[@"progress"] floatValue];
        [self changeStates:resume];
    }
}
#pragma mark - 按钮点击事件
- (IBAction)clickButton:(UIButton *)sender
{
    switch (sender.tag)
    {
        case 101:
        {
            [self downLoad];
            [self changeStates:pasue];
        }
            break;
        case 102:
        {
            [self pasue];
        }
            break;
        case 103:
        {
            [self resume];
        }
            break;
            
        default:
            break;
    }
}

- (void)changeStates:(ButtonStates)states
{
    switch (states) {
        case beign:
        {
            [_downButton setTitle:@"开始下载" forState:UIControlStateNormal];
            _downButton.tag = 101;
        }
            break;
        case pasue:
        {
            [_downButton setTitle:@"暂停下载" forState:UIControlStateNormal];
            _downButton.tag = 102;
        }
            break;
        case resume:
        {
            [_downButton setTitle:@"继续下载" forState:UIControlStateNormal];
            _downButton.tag = 103;
        }
            break;
        default:
            break;
    }
}

#pragma mark - 开始下载
- (void)downLoad
{
    NSURL *url = [NSURL URLWithString:@"http://120.25.226.186:32812/resources/videos/minion_01.mp4"];
    
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];

    self.downTask = [manager downloadTaskWithRequest:request progress:^(NSProgress * _Nonnull downloadProgress) {
        
        // @property int64_t totalUnitCount;  需要下载文件的总大小
        // @property int64_t completedUnitCount; 当前已经下载的大小
        
        NSLog(@"%f", (float)downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
        dispatch_sync(<#dispatch_queue_t queue#>, <#^(void)block#>)
        // 回到主队列刷新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.progressView.progress = 1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount;
        });
    
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        
        //返回文件真实存储的路径
        return [NSURL fileURLWithPath:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:response.suggestedFilename]];
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        //如果下载出错会打印一下错误
        NSLog(@"%@", error);
        if (!error)
        {
            
            [self alert:@"下载完成"];
        }
        
    }];
    
    [_downTask resume];

}
#pragma mark - 暂停下载
- (void)pasue
{
//    [_downTask suspend];
    [_downTask cancelByProducingResumeData:^(NSData * _Nullable resumeData) {
        
        _resumeData = resumeData;
        [self saveDownFile];
    }];
    
    [self changeStates:resume];
    
}

- (void)saveDownFile
{
    _dataDic = [NSMutableDictionary dictionary];
    
    //找到下载文件的路径
    //temp文件夹路径
    NSString *tempPath = NSTemporaryDirectory();
    //获取文件夹内所有文件名
    NSArray *subPaths = [self.manager subpathsAtPath:tempPath];
    //拼接下载的文件路径，下载的文件是在最后一个
    NSString *downFilePath = [tempPath stringByAppendingPathComponent:[subPaths lastObject]];
    //caches文件夹
    NSString *cachesPath = [[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:[downFilePath lastPathComponent]];
    //保存一下路径
    [self.dataDic setObject:cachesPath forKey:@"filePath"];
    //移动下载文件到caches文件夹
    [self.manager moveItemAtPath:downFilePath toPath:cachesPath error:nil];
    //保存resumeData，简历数据
    [self.dataDic setObject:self.resumeData forKey:@"resumeData"];
    //保存下载进度
    [self.dataDic setObject:[NSNumber numberWithFloat:self.progressView.progress] forKey:@"progress"];
    
    [self.dataDic writeToFile:defaultPath atomically:YES];

}

#pragma mark - 继续下载
- (void)resume
{
    [self getFile:_dataDic[@"filePath"]];
    
    AFURLSessionManager *manager = [AFHTTPSessionManager manager];
    _downTask = [manager downloadTaskWithResumeData:self.resumeData progress:^(NSProgress * _Nonnull downloadProgress) {
        
        // @property int64_t totalUnitCount;  需要下载文件的总大小
        // @property int64_t completedUnitCount; 当前已经下载的大小
        
        NSLog(@"%f", (float)downloadProgress.completedUnitCount / downloadProgress.totalUnitCount);
        // 回到主队列刷新UI
        dispatch_async(dispatch_get_main_queue(), ^{
            
            self.progressView.progress = 1.0 * downloadProgress.completedUnitCount / downloadProgress.totalUnitCount;
        });
    } destination:^NSURL * _Nonnull(NSURL * _Nonnull targetPath, NSURLResponse * _Nonnull response) {
        
        //返回文件真实存储的路径
        return [NSURL fileURLWithPath:[[NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject] stringByAppendingPathComponent:response.suggestedFilename]];
        
    } completionHandler:^(NSURLResponse * _Nonnull response, NSURL * _Nullable filePath, NSError * _Nullable error) {
        
        NSLog(@"%@", error);
        
        if (!error)
        {
            
            [self alert:@"下载完成"];
        }
    }];
    
    [_downTask resume];
    [self changeStates:pasue];
    
}
#pragma mark - 获取断点的文件
- (void)getFile:(NSString *)filePath
{
    //temp文件夹路径
    NSString *tempPath =[NSTemporaryDirectory() stringByAppendingPathComponent:[filePath lastPathComponent]];
    //移动下载文件到caches文件夹
    [self.manager moveItemAtPath:filePath toPath:tempPath error:nil];
}

- (void)alert:(NSString *)message
{
    UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"提示" message:message delegate:nil cancelButtonTitle:@"确定" otherButtonTitles: nil];
    
    [alert show];
}



/**
 * 问题汇总：
 *  问题一：Code=-1001 "The request timed out."请求超时
 *
 *  第一：先交完整的请求放在浏览器模拟看看是否能请求到，如果能，有可能是你的代码有问题，如果不能，说明接口有问题。
 *  第二：请求超时可能是网络太慢。
 *  第三：请求超时也有可能服务器响应太慢。
 */

@end
