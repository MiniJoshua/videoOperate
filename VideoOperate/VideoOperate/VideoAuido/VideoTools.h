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

@end

@interface VideoTools(Base)

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

@end

@interface VideoTools(Fetch)

+ (UIImage *)imageFromFrame:(AVFrame *)frame;
//获取多少帧解码后的数据 用于获取视频画面 取帧方式是每隔 总帧数/count 的间隔
+ (NSArray <DecodeFrame *> *)decodeFramesWithVideoFilePath:(NSString *)path count:(int64_t)count;
//直接获取视频的图片 每 总时间/count 的间隔取一张图片
+ (NSArray <UIImage *> *)imagesWithVideoFilePath:(NSString *)path count:(int64_t)count quality:(EnumVideoImageQuality)quality;

@end

@interface VideoTools(Cut)

/// 裁剪音视频
/// - Parameters:
///   - path: 音/视频文件的路径
///   - start: 开始的时间点 单位秒
///   - end: 结束的时间点 单位秒
///   - complete: 裁剪完成的回调
+ (void)cutVideoWithFilePath:(NSString *)path start:(int)start end:(int)end complete:(void(^)(BOOL success, NSString *outFilePath))complete;

@end

@interface VideoTools(Merge)

/// 将音频混合到视频的音频中去
/// - Parameters:
///   - path: 视频文件的路径
///   - audioPath: 需要混入的音频文件 视频文件会提取里面的音频数据
///   - volume1: 视频中的声音音量
///   - volum2: 音频中的声音音量
///   - complete: success 状态  outFilePath 混合后输出的文件路径
+ (void)mergeAudioWithVideoFilePath:(NSString *)path audioFilePath:(NSString *)audioPath volume1:(CGFloat)volume1 volume2:(CGFloat)volume2 complete:(void(^)(BOOL success, NSString *outFilePath))complete;

@end

@interface VideoTools(Extract)

/// 提取视频文件中的音频/视频流  视频使用h264重新编码  视频使用aac重新编码
/// - Parameters:
///   - path: 文件的路径
///   - status:  YES 提取视频  NO 提取音频
///   - complete: 提取成功的回调
+ (void)extractFilePath:(NSString *)path videoStatus:(BOOL)status complete:(void(^)(BOOL success, NSString *extractFilePath))complete;

@end

NS_ASSUME_NONNULL_END
