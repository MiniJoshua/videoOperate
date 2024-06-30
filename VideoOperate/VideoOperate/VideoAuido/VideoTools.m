//
//  VideoTools.m
//  VideoOperate
//
//  Created by 刘维 on 2024/6/20.
//

#import "VideoTools.h"
#import "imgutils.h"
#import "log.h"

@implementation DecodeFrame

+ (DecodeFrame *)decodeFrameWithAVFrame:(AVFrame *)frame {
    
    DecodeFrame *dFrame = [[DecodeFrame alloc] init];
    
    // 为新的 AVFrame 分配内存
    AVFrame *newFrame = av_frame_alloc();
    if (!newFrame) {
        NSLog(@"Error allocating AVFrame");
        return nil;
    }
    
    // 设置新帧的参数
    newFrame -> format = frame -> format;
    newFrame -> width = frame -> width;
    newFrame -> height = frame -> height;
    newFrame -> ch_layout = frame -> ch_layout;
//    newFrame->channels = frame->channels;
//    newFrame->channel_layout = frame->channel_layout;
    newFrame -> nb_samples = frame -> nb_samples;
    
    // 分配新的缓冲区以存储图像数据
    int buffer_size = av_image_get_buffer_size((enum AVPixelFormat)newFrame->format, newFrame->width, newFrame->height, 1);
    uint8_t *buffer = av_malloc(buffer_size);
    if (!buffer) {
        NSLog(@"Error allocating buffer");
        av_frame_free(&newFrame);
        return nil;
    }
    
    // 将数据填充到新的帧中
    av_image_fill_arrays(newFrame->data, newFrame->linesize, buffer, (enum AVPixelFormat)newFrame->format, newFrame->width, newFrame->height, 1);
    av_image_copy(newFrame->data, newFrame->linesize, (const uint8_t **)frame->data, frame->linesize, (enum AVPixelFormat)newFrame->format, newFrame->width, newFrame->height);
    
    dFrame.frame = newFrame;
    return dFrame;
}

@end

@implementation VideoTools


+ (UIImage *)imageFromFrame:(AVFrame *)frame {
    
    if (!frame)
        return nil;
    
    int width = frame -> width;
    int height = frame -> height;
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    int bytesPreRow = frame->linesize[0];
    int dataSize = bytesPreRow * height;
    
    uint8_t *data = (uint8_t *)malloc(dataSize);//frame -> data[0];
    if (!data) {
        return nil;
    }
    
    memcpy(data, frame -> data[0], dataSize);
    
    CGDataProviderRef provider = CGDataProviderCreateWithData(NULL, data, bytesPreRow * height, NULL);
    if (!provider) {
        CGColorSpaceRelease(colorSpace);
        return nil;
    }
    
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       4*8,
                                       bytesPreRow,
                                       colorSpace,
                                       kCGBitmapByteOrderDefault|kCGImageAlphaNoneSkipLast,
                                       provider,
                                       NULL,
                                       true,
                                       kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    if (!cgImage) {
        return nil;
    }
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    
    return image;
}

+ (AVFormatContext *)openInputFormatContextWithFilePath:(NSString *)path {
    
    if (!path || [path length] == 0) {
        av_log(NULL, AV_LOG_ERROR, "inputFormatContextWithFilePath: file is nil!\n");
        return nil;
    }
    
    const char *filePath = [path UTF8String];
    
    AVFormatContext *inputFmtCtx = NULL;
    
    int ret = avformat_open_input(&inputFmtCtx, filePath, NULL, NULL);
    if (ret != 0){
        av_log(NULL, AV_LOG_ERROR, "open input format context failed:%s\n",av_err2str(ret));
        return nil;
    }
    
    return inputFmtCtx;
}

+ (double)durationWithFormatContext:(AVFormatContext *)formatContext {
    
    int ret = avformat_find_stream_info(formatContext, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "find stream info failed:%s\n",av_err2str(ret));
        avformat_close_input(&formatContext);
        return -1;
    }
    
    int64_t duration = formatContext -> duration;
    double durationSeconds = (double)duration / AV_TIME_BASE;
    
    avformat_close_input(&formatContext);
    
    return durationSeconds;
}

+ (double)durationWithFilePath:(NSString *)path {
    
    AVFormatContext *fmtCtx = [self openInputFormatContextWithFilePath:path];
    return [self durationWithFormatContext:fmtCtx];
}

+ (int)streamIndexWithFormatContext:(AVFormatContext *)formatContext mediaType:(enum AVMediaType)type {
    
    int ret = avformat_find_stream_info(formatContext, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "find stream info failed:%s\n",av_err2str(ret));
        return -1;
    }
    
    ret = av_find_best_stream(formatContext, type, -1, -1, NULL, 0);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "find video stream index failed:%s\n", av_err2str(ret));
        return -1;
    }
    
    return ret;
}

+ (AVCodecContext *)openDecodeWithFormatContext:(AVFormatContext *)formatContext streamIndex:(int)index {
    
    AVCodecContext *decoderCtx = avcodec_alloc_context3(NULL);
    if (decoderCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "decoder context alloc failed!\n");
        return nil;
    }
    
    int ret = avcodec_parameters_to_context(decoderCtx, formatContext -> streams[index] -> codecpar);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "copy decoder parameter to context failed:%s\n", av_err2str(ret));
        return nil;
    }
    
    const AVCodec *decoder = avcodec_find_decoder(decoderCtx -> codec_id);
    if (decoder == NULL) {
        av_log(NULL, AV_LOG_ERROR, "can not find decoder: %d\n", decoderCtx -> codec_id);
        return nil;
    }
    
    ret = avcodec_open2(decoderCtx, decoder, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "open decoder failed:%s\n", av_err2str(ret));
        return nil;
    }
    
    return decoderCtx;
}

+ (int64_t)totalVideoFrameCountWithFormatContext:(AVFormatContext *)formatContext streamIndex:(int)index {
    
    // 获取时间基和视频时长
    AVRational timeBase = formatContext -> streams[index] -> time_base;
    int64_t videoDuration = formatContext -> streams[index] -> duration;
    // 获取帧率
    AVRational framerate = av_guess_frame_rate(formatContext, formatContext -> streams[index], NULL);
    // 计算总帧数
    double videoDurationSeconds = (double)videoDuration * av_q2d(timeBase);
    double fps = av_q2d(framerate);
    int64_t totalFrameCount = (int64_t)(videoDurationSeconds * fps);
    return totalFrameCount;
}

+ (NSArray <DecodeFrame *> *)decodeFramesWithVideoFilePath:(NSString *)path count:(int64_t)count{
    
    AVFormatContext *inFmtCtx = [self openInputFormatContextWithFilePath:path];
    if (!inFmtCtx || inFmtCtx == NULL) {
        return nil;
    }
    
    int videoIndex = [self streamIndexWithFormatContext:inFmtCtx mediaType:AVMEDIA_TYPE_VIDEO];
    if (videoIndex == -1) {
        avformat_close_input(&inFmtCtx);
        return nil;
    }
    
    AVCodecContext *decodeCtx = [self openDecodeWithFormatContext:inFmtCtx streamIndex:videoIndex];
    
    //用于存放转码成RGB像素格式的帧
    AVFrame *rgbFrame = av_frame_alloc();
    rgbFrame -> format = AV_PIX_FMT_RGBA;
    rgbFrame -> width = decodeCtx -> width;
    rgbFrame -> height = decodeCtx -> height;
    
    int bytes = av_image_get_buffer_size(AV_PIX_FMT_RGBA, rgbFrame -> width, rgbFrame -> height, 1);
    uint8_t *buffer = (uint8_t *)av_malloc(bytes * sizeof(uint8_t));
    
    int code = av_image_fill_arrays(rgbFrame -> data,
                         rgbFrame -> linesize,
                         buffer,
                         AV_PIX_FMT_RGBA,
                         decodeCtx -> width,
                         decodeCtx -> height,
                         1);
    
    if (code < 0) {
        av_log(NULL, AV_LOG_ERROR, "av_image_fill_arrays failed:%s\n",av_err2str(code));
        return @[];
    }
    
//    print_image_data(rgbFrame->data[0], decodeCtx -> width, decodeCtx -> height, rgbFrame->linesize[0], 10);
    
    struct SwsContext *sws_ctx = sws_getContext(decodeCtx -> width,
                                                decodeCtx -> height,
                                                decodeCtx -> pix_fmt,
                                                decodeCtx -> width,
                                                decodeCtx -> height,
                                                AV_PIX_FMT_RGBA,
                                                SWS_FAST_BILINEAR,
                                                NULL ,
                                                NULL,
                                                NULL);
    
    //读取的packet
    AVPacket *pkt = av_packet_alloc();
    //解码出来的视频帧
    AVFrame *videoFrame = av_frame_alloc();
    //存放需要的frame
    NSMutableArray *framesArray = [NSMutableArray array];
    //当前解码得到的视频帧数
//    int64_t frameCount = 0;
//    //总的视频帧数
//    int64_t totalFrameCount = [self totalVideoFrameCountWithFormatContext:inFmtCtx streamIndex:videoIndex];
//    int64_t frameBase = 1;
//    if (count > 1) {
//        frameBase = totalFrameCount / count;
//    }
//    int64_t temp = 0;
    
    int64_t videoDuration = inFmtCtx -> streams[videoIndex] -> duration;
    int64_t interval = videoDuration / count;
    
    for (int i = 0; i < count; i++) {
        
        int64_t timestamp = interval * i;
        av_log(NULL, AV_LOG_INFO, "timestamp:%lld \n", timestamp);
        int seekRet = av_seek_frame(inFmtCtx, videoIndex, timestamp,AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_ANY);
        if (seekRet < 0) {
            av_log(NULL, AV_LOG_ERROR, "seek frame to timestamp failed:%s \n", av_err2str(seekRet));
        }
        avcodec_flush_buffers(decodeCtx);
        
        BOOL readStatus = YES;
        while(readStatus && av_read_frame(inFmtCtx, pkt) >= 0) {
            
            if (pkt -> stream_index == videoIndex) {
                
                int ret = avcodec_send_packet(decodeCtx, pkt);
                if (ret < 0) {
                    av_log(NULL, AV_LOG_ERROR, "send video frame decoder failed:%s\n",av_err2str(ret));
                    continue;;
                }

                while (ret >= 0) {
                    
                    ret = avcodec_receive_frame(decodeCtx, videoFrame);
                    if (ret >= 0) {
                        sws_scale(sws_ctx,
                                  (const uint8_t *const *)videoFrame -> data,
                                  videoFrame -> linesize,
                                  0,
                                  decodeCtx -> height,
                                  rgbFrame -> data,
                                  rgbFrame -> linesize);
                        
                        
                        DecodeFrame *decodeFrame = [DecodeFrame decodeFrameWithAVFrame:rgbFrame];
                        [framesArray addObject:decodeFrame];
                        readStatus = NO;
                    }else if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                        // 继续读取包
                        break;
                    }else {
                        av_log(NULL, AV_LOG_ERROR, "Error during decoding: %s\n", av_err2str(ret));
                        readStatus = NO;
                        break;
                    }
                }
            }
        }
        av_packet_unref(pkt);
    }
    /*
    //开始读取数据
    while (av_read_frame(inFmtCtx, pkt) >= 0) {
        
        if (pkt -> stream_index == videoIndex) {
            //只处理视频数据
            int ret = avcodec_send_packet(decodeCtx, pkt);
            if (ret < 0) {
                av_log(NULL, AV_LOG_ERROR, "send video frame decoder failed:%s\n",av_err2str(ret));
                break;
            }
            
            if (count == 1) {
                //只取首帧
                if( avcodec_receive_frame(decodeCtx, videoFrame) >= 0) {
                    sws_scale(sws_ctx,
                              (const uint8_t *const *)videoFrame -> data,
                              videoFrame -> linesize,
                              0,
                              decodeCtx -> height,
                              rgbFrame -> data,
                              rgbFrame -> linesize);
                    
                    print_image_data(rgbFrame->data[0], decodeCtx -> width, decodeCtx -> height, rgbFrame->linesize[0], 10);
                    
//                    UIImage *img = [self imageFromFrame:rgbFrame];
                    
                    DecodeFrame *decodeFrame = [DecodeFrame decodeFrameWithAVFrame:rgbFrame];
                    [framesArray addObject:decodeFrame];
                    
                    break;
                }
                
            }else if (count > 1){
                
                BOOL finished = NO;
                
                
                while (avcodec_receive_frame(decodeCtx, videoFrame) == 0) {
                    
                    if (frameCount == frameBase * temp) {
                        
                        temp ++;
                        
                        sws_scale(sws_ctx,
                                  (uint8_t const *const *)videoFrame -> data,
                                  videoFrame -> linesize,
                                  0,
                                  decodeCtx -> height,
                                  rgbFrame -> data,
                                  rgbFrame -> linesize);
                        
                        //rgbFrame即为需要的帧
                        DecodeFrame *decodeFrame = [DecodeFrame decodeFrameWithAVFrame:rgbFrame];
                        [framesArray addObject:decodeFrame];
                        
                        if (frameBase * temp > totalFrameCount) {
                            finished = YES;
                            break;
                        }
                    }
                    
                    frameCount ++;
                }
                
                if (finished) {
                    break;
                }
            }
        }
        
        av_packet_unref(pkt);
    }
    */
//    av_free(buffer);
    av_frame_free(&videoFrame);
//    av_frame_free(&rgbFrame);
    avcodec_close(decodeCtx);
    avformat_close_input(&inFmtCtx);
    avformat_free_context(inFmtCtx);
    
    return [framesArray copy];
}

+ (NSArray <UIImage *> *)imagesWithVideoFilePath:(NSString *)path count:(int64_t)count quality:(EnumVideoImageQuality)quality{
    
    AVFormatContext *inFmtCtx = [self openInputFormatContextWithFilePath:path];
    if (!inFmtCtx || inFmtCtx == NULL) {
        return nil;
    }
    
    int videoIndex = [self streamIndexWithFormatContext:inFmtCtx mediaType:AVMEDIA_TYPE_VIDEO];
    if (videoIndex == -1) {
        avformat_close_input(&inFmtCtx);
        return nil;
    }
    
    AVCodecContext *decodeCtx = [self openDecodeWithFormatContext:inFmtCtx streamIndex:videoIndex];
    
    int ratio = 1;
    if (quality == EnumVideoImageQualityLow) {
        ratio = 10;
    }else if (quality == EnumVideoImageQualityMedium) {
        ratio = 6;
    }
    
    //用于存放转码成RGB像素格式的帧
    AVFrame *rgbFrame = av_frame_alloc();
    rgbFrame -> format = AV_PIX_FMT_RGBA;
    rgbFrame -> width = decodeCtx -> width / ratio;
    rgbFrame -> height = decodeCtx -> height / ratio;
    
    int bytes = av_image_get_buffer_size(AV_PIX_FMT_RGBA, rgbFrame -> width, rgbFrame -> height, 1);
    uint8_t *buffer = (uint8_t *)av_malloc(bytes * sizeof(uint8_t));
    
    int code = av_image_fill_arrays(rgbFrame -> data,
                                    rgbFrame -> linesize,
                                    buffer,
                                    AV_PIX_FMT_RGBA,
                                    rgbFrame -> width,
                                    rgbFrame -> height,
                                    1);
    
    if (code < 0) {
        av_log(NULL, AV_LOG_ERROR, "av_image_fill_arrays failed:%s\n",av_err2str(code));
        return @[];
    }
    
//    print_image_data(rgbFrame->data[0], decodeCtx -> width, decodeCtx -> height, rgbFrame->linesize[0], 10);
    
    struct SwsContext *sws_ctx = sws_getContext(decodeCtx -> width,
                                                decodeCtx -> height,
                                                decodeCtx -> pix_fmt,
                                                rgbFrame -> width,
                                                rgbFrame -> height,
                                                AV_PIX_FMT_RGBA,
                                                SWS_BILINEAR,
                                                NULL ,
                                                NULL,
                                                NULL);
    
    //读取的packet
    AVPacket *pkt = av_packet_alloc();
    //解码出来的视频帧
    AVFrame *videoFrame = av_frame_alloc();
    //存放需要的frame
    NSMutableArray *imagesArray = [NSMutableArray array];
    
    int64_t videoDuration = inFmtCtx -> streams[videoIndex] -> duration;
    int64_t interval = videoDuration / count;
    
    for (int i = 0; i < count; i++) {
        
        int64_t timestamp = interval * i;
        int seekRet = av_seek_frame(inFmtCtx, videoIndex, timestamp,AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_ANY);
        if (seekRet < 0) {
            av_log(NULL, AV_LOG_ERROR, "seek frame to timestamp failed:%s \n", av_err2str(seekRet));
        }
        avcodec_flush_buffers(decodeCtx);
        
        BOOL readStatus = YES;
        while(readStatus && av_read_frame(inFmtCtx, pkt) >= 0) {
            
            if (pkt -> stream_index == videoIndex) {
                
                int ret = avcodec_send_packet(decodeCtx, pkt);
                if (ret < 0) {
                    av_log(NULL, AV_LOG_ERROR, "send video frame decoder failed:%s\n",av_err2str(ret));
                    continue;;
                }

                while (ret >= 0) {
                    
                    ret = avcodec_receive_frame(decodeCtx, videoFrame);
                    if (ret >= 0) {
                        sws_scale(sws_ctx,
                                  (const uint8_t *const *)videoFrame -> data,
                                  videoFrame -> linesize,
                                  0,
                                  decodeCtx -> height,
                                  rgbFrame -> data,
                                  rgbFrame -> linesize);
                        
                        UIImage *img = [self imageFromFrame:rgbFrame];
                        if (img) {
                            [imagesArray addObject:img];
                        }
                        readStatus = NO;
                    }else if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                        // 继续读取包
                        break;
                    }else {
                        av_log(NULL, AV_LOG_ERROR, "Error during decoding: %s\n", av_err2str(ret));
                        readStatus = NO;
                        break;
                    }
                }
            }
        }
        av_packet_unref(pkt);
    }
  
//    av_free(buffer);
    av_frame_free(&videoFrame);
//    av_frame_free(&rgbFrame);
    avcodec_close(decodeCtx);
    avformat_close_input(&inFmtCtx);
    avformat_free_context(inFmtCtx);
    
    return [imagesArray copy];
}

@end
