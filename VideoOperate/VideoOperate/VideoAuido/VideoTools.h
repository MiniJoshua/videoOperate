//
//  VideoTools.h
//  VideoOperate
//
//  Created by 刘维 on 2024/6/20.
//

#import <UIKit/UIKit.h>
#import "avutil.h"
#import "avformat.h"
#import "swscale.h"
#import "avcodec.h"

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSUInteger, EnumVideoImageQuality) {
    EnumVideoImageQualityLow,
    EnumVideoImageQualityMedium,
    EnumVideoImageQualityHigh,
};

@interface DecodeFrame : NSObject

@property (nonatomic, assign) AVFrame *frame;

+ (DecodeFrame *)decodeFrameWithAVFrame:(AVFrame *)frame;

@end

@interface VideoTools : NSObject

+ (UIImage *)imageFromFrame:(AVFrame *)frame;

//获取一个音视频文件的输入的上下文
+ (AVFormatContext *)openInputFormatContextWithFilePath:(NSString *)path;
//获取时长
+ (double)durationWithFormatContext:(AVFormatContext *)formatContext;
+ (double)durationWithFilePath:(NSString *)path;
//获取到需要流的索引值
+ (int)streamIndexWithFormatContext:(AVFormatContext *)formatContext mediaType:(enum AVMediaType)type;
//获取指定流的解码器上下文
+ (AVCodecContext *)openDecodeWithFormatContext:(AVFormatContext *)formatContext streamIndex:(int)index;
//获取总的视频帧数
+ (int64_t)totalVideoFrameCountWithFormatContext:(AVFormatContext *)formatContext streamIndex:(int)index;
//获取多少帧解码后的数据 用于获取视频画面 取帧方式是每隔 总帧数/count 的间隔 
+ (NSArray <DecodeFrame *> *)decodeFramesWithVideoFilePath:(NSString *)path count:(int64_t)count;
//直接获取视频的图片 每 总时间/count 的间隔取一张图片
+ (NSArray <UIImage *> *)imagesWithVideoFilePath:(NSString *)path count:(int64_t)count quality:(EnumVideoImageQuality)quality;

@end

NS_ASSUME_NONNULL_END
