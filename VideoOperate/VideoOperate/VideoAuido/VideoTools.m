//
//  VideoTools.m
//  VideoOperate
//
//  Created by 刘维 on 2024/6/20.
//

#import "VideoTools.h"
#import "imgutils.h"
#import "swresample.h"
#import "opt.h"
#import "log.h"
#import "avfilter.h"
#import "buffersink.h"
#import "buffersrc.h"

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

+ (void)removeAllOutFileWithName:(NSString *)name {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *directiorPath = [documentPath stringByAppendingPathComponent:name];
    
    NSArray *files = [fileManager contentsOfDirectoryAtPath:directiorPath error:NULL];
    for(NSString *filePath in files) {
        NSString *fullFilePath = [NSString stringWithFormat:@"%@/%@",directiorPath,filePath];
        [fileManager removeItemAtPath:fullFilePath error:NULL];
    }
}

+ (NSString *)outFilePathWithName:(NSString *)name {
    
    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
    NSString *directiorPath = [documentPath stringByAppendingPathComponent:name];
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    BOOL createStatus = [fileManager createDirectoryAtPath:directiorPath withIntermediateDirectories:YES attributes:NULL error:NULL];
    if (!createStatus) {
        return @"";
    }
    
    
    NSDate *date = [NSDate date];
    NSString *outFilePath = [directiorPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%f.mp4",date.timeIntervalSince1970]];
    
    return outFilePath;
}

@end

@implementation VideoTools(Base)

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

@end

@implementation VideoTools(Fetch)

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

@implementation VideoTools(Cut)

+ (void)removeAllCutOutFile {
    
    [self removeAllOutFileWithName:@"Cut"];
    
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//
//    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//    NSString *directiorPath = [documentPath stringByAppendingPathComponent:@"Cut"];
//
//    NSArray *files = [fileManager contentsOfDirectoryAtPath:directiorPath error:NULL];
//    for(NSString *filePath in files) {
//        NSString *fullFilePath = [NSString stringWithFormat:@"%@/%@",directiorPath,filePath];
//        [fileManager removeItemAtPath:fullFilePath error:NULL];
//    }
}

+ (NSString *)cutOutFilePtah {
    
    return [self outFilePathWithName:@"Cut"];
    
//    NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
//    NSString *directiorPath = [documentPath stringByAppendingPathComponent:@"Cut"];
//
//    NSFileManager *fileManager = [NSFileManager defaultManager];
//    BOOL createStatus = [fileManager createDirectoryAtPath:directiorPath withIntermediateDirectories:YES attributes:NULL error:NULL];
//    if (!createStatus) {
//        NSLog(@"创建Cut的文件夹失败");
//        return @"";
//    }
//
//
//    NSDate *date = [NSDate date];
//    NSString *cutOutFilePath = [directiorPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%f.mp4",date.timeIntervalSince1970]];
//
//    return cutOutFilePath;
}

+ (void)cutVideoWithFilePath:(NSString *)path start:(int)start end:(int)end complete:(void(^)(BOOL success, NSString *outFilePath))complete {
    
    [self removeAllCutOutFile];
    
    NSString *cutOutFilePath = [self cutOutFilePtah];
    AVFormatContext *outFmtCtx = NULL;
    
    AVFormatContext *inFmtCtx = [self openInputFormatContextWithFilePath:path];
    if (!inFmtCtx || inFmtCtx == NULL) {
        return;
    }
    
    int ret = avformat_alloc_output_context2(&outFmtCtx, NULL, NULL, [cutOutFilePath UTF8String]);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "output format context alloc failed:%s \n", av_err2str(ret));
        goto fail;
    }
    
    for (int i = 0; i < inFmtCtx -> nb_streams; i++) {
        
        AVStream *in_stream = inFmtCtx -> streams[i];
        AVStream *out_stream = avformat_new_stream(outFmtCtx, NULL);
        
        if (out_stream == NULL) {
            av_log(NULL, AV_LOG_ERROR, "new stream failed! \n");
            goto fail;
        }
        
        ret = avcodec_parameters_copy(out_stream -> codecpar, in_stream -> codecpar);
        if (ret < 0) {
            
            av_log(NULL, AV_LOG_ERROR, "copy codec parameters failed!\n");
            goto fail;
        }
        
        out_stream -> codecpar -> codec_tag = 0;
        
        //设置输出流音频帧的大小
        if (in_stream->codecpar->codec_type == AVMEDIA_TYPE_AUDIO) {
            const struct AVCodec *codec = avcodec_find_decoder(in_stream->codecpar->codec_id);
            if (!codec) {
                av_log(NULL, AV_LOG_ERROR, "can not find audio code!\n");
                goto fail;
            }
            AVCodecContext *codecCtx = avcodec_alloc_context3(codec);
            if (!codecCtx) {
                av_log(NULL, AV_LOG_ERROR, "alloc audio codec context failed!\n");
                goto fail;
            }
            if ((ret = avcodec_parameters_to_context(codecCtx, in_stream->codecpar)) < 0) {
                av_log(NULL, AV_LOG_ERROR, "audio copy parameters failed!\n");
                avcodec_free_context(&codecCtx);
                goto fail;
            }
            if ((ret = avcodec_open2(codecCtx, codec, NULL)) < 0) {
                av_log(NULL, AV_LOG_ERROR, "open audio codec fialed\n");
                avcodec_free_context(&codecCtx);
                goto fail;
            }
            out_stream->codecpar->frame_size = codecCtx->frame_size;
            avcodec_free_context(&codecCtx);
        }
    }
    
    if (!(outFmtCtx -> oformat -> flags & AVFMT_NOFILE)) {
        if(avio_open(&outFmtCtx -> pb, [cutOutFilePath UTF8String], AVIO_FLAG_WRITE) < 0) {
            av_log(NULL, AV_LOG_ERROR, "could not open output file!\n");
            goto fail;
        }
    }
    
    if(avformat_write_header(outFmtCtx, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Write output file header occured error \n");
        goto fail;
    }
    
    int64_t start_time = start * AV_TIME_BASE;
    int64_t end_time = end * AV_TIME_BASE;
    
    ret = av_seek_frame(inFmtCtx, -1, start_time, AVSEEK_FLAG_BACKWARD); // | AVSEEK_FLAG_ANY
    if ( ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "seek time frame failed: %s \n",av_err2str(ret));
        goto fail;
    }
    
    AVPacket *packet = av_packet_alloc();
    int64_t start_video_pts = AV_NOPTS_VALUE;
    int64_t start_audio_pts = AV_NOPTS_VALUE;
    
    while (av_read_frame(inFmtCtx, packet) >= 0) {
        
        AVStream *in_stream = inFmtCtx -> streams[packet -> stream_index];
        AVStream *out_stream = outFmtCtx -> streams[packet -> stream_index];
        
        int64_t packet_time = av_rescale_q(packet -> pts, in_stream->time_base, AV_TIME_BASE_Q);

        //低于这个时间的丢弃
        if (packet_time < start_time) {
            av_packet_unref(packet);
            continue;
        }
        //高于这个时间的时候结束
        if (packet_time > end_time) {
            av_packet_unref(packet);
            break;
        }
        
        if(in_stream -> codecpar -> codec_type == AVMEDIA_TYPE_VIDEO) {
            
            if(start_video_pts == AV_NOPTS_VALUE) {
                start_video_pts = packet -> pts;
            }
            packet -> pts = av_rescale_q_rnd(packet -> pts - start_video_pts, in_stream -> time_base, out_stream -> time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            packet -> dts = av_rescale_q_rnd(packet -> dts - start_video_pts, in_stream -> time_base, out_stream -> time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            packet -> duration = av_rescale_q(packet -> duration, in_stream -> time_base, out_stream -> time_base);
            
        }else if (in_stream -> codecpar -> codec_type == AVMEDIA_TYPE_AUDIO) {
            
            if(start_audio_pts == AV_NOPTS_VALUE) {
                start_audio_pts = packet -> pts;
            }
            packet -> pts = av_rescale_q_rnd(packet -> pts - start_audio_pts, in_stream -> time_base, out_stream -> time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            packet -> dts = av_rescale_q_rnd(packet -> dts - start_audio_pts, in_stream -> time_base, out_stream -> time_base, AV_ROUND_NEAR_INF|AV_ROUND_PASS_MINMAX);
            packet -> duration = av_rescale_q(packet -> duration, in_stream -> time_base, out_stream -> time_base);
            
        }else {
            continue;
        }
        packet -> pos = -1;

        // 写入数据包
        if (av_interleaved_write_frame(outFmtCtx, packet) < 0) {
            av_log(NULL, AV_LOG_ERROR, "Error muxing packet \n");
            goto fail;
        }

        av_packet_unref(packet);
    }
    
    av_write_trailer(outFmtCtx);
    
    if (inFmtCtx) {
        avformat_close_input(&inFmtCtx);
        avformat_free_context(inFmtCtx);
    }
    if (outFmtCtx) {
        avformat_close_input(&outFmtCtx);
        avformat_free_context(outFmtCtx);
    }
    !complete?:complete(YES, cutOutFilePath);
    return;
    
fail:
    if (inFmtCtx) {
        avformat_close_input(&inFmtCtx);
        avformat_free_context(inFmtCtx);
    }
    if (outFmtCtx) {
        avformat_close_input(&outFmtCtx);
        avformat_free_context(outFmtCtx);
    }
    !complete?:complete(NO, @"");
    return;
}

@end

@implementation VideoTools(Merge)

+ (void)removeAllMergeOutFile {
    
    [self removeAllOutFileWithName:@"Merge"];
}

+ (NSString *)mergeOutFilePtah {
    
    return [self outFilePathWithName:@"Merge"];
}

+ (void)mergeAudioWithVideoFilePath:(NSString *)path audioFilePath:(NSString *)audioPath volume1:(CGFloat)volume1 volume2:(CGFloat)volume2 complete:(void(^)(BOOL success, NSString *outFilePath))complete {
    
    NSString *mergeOutFilePath = [self mergeOutFilePtah];
    const char *mergeOutFile = [mergeOutFilePath UTF8String];
    
    int videoIndex = -1;
    int videoAudioIndex = -1;
    int audioIndex = -1;
    
    AVFormatContext *outFmtCtx = NULL;
    
    
    //视频文件的上下文
    AVFormatContext *inFmtCtx = [self openInputFormatContextWithFilePath:path];
    if (!inFmtCtx || inFmtCtx == NULL) {
        goto fail;
    }
    
    videoIndex = [self streamIndexWithFormatContext:inFmtCtx mediaType:AVMEDIA_TYPE_VIDEO];
    
    videoAudioIndex = av_find_best_stream(inFmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    if (videoAudioIndex < 0) {
        av_log(NULL, AV_LOG_ERROR, "find video stream index failed:%s\n", av_err2str(videoAudioIndex));
        goto fail;;
    }
//    videoAudioIndex = [self streamIndexWithFormatContext:inFmtCtx mediaType:AVMEDIA_TYPE_AUDIO];
    AVCodecContext *videoAudioDecoderCtx = [self openDecodeWithFormatContext:inFmtCtx streamIndex:videoAudioIndex];
    
    if (videoAudioDecoderCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "video file audio decoder alloc failed!\n");
        goto fail;
    }

    //音频的上下文
    AVFormatContext *inAFmtCtx = [self openInputFormatContextWithFilePath:audioPath];
    if (!inAFmtCtx || inAFmtCtx == NULL) {
        goto fail;
    }
    
    audioIndex = [self streamIndexWithFormatContext:inAFmtCtx mediaType:AVMEDIA_TYPE_AUDIO];
    AVCodecContext *audioDecoderCtx = [self openDecodeWithFormatContext:inAFmtCtx streamIndex:audioIndex];
    
    if (audioDecoderCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "audio decoder alloc failed! \n");
        goto fail;
    }
    
    //音频aac编码器
    const struct AVCodec *audioEncoder = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if (!audioEncoder) {
        av_log(NULL, AV_LOG_ERROR, "not find aac encoder!\n");
        goto fail;
    }
    AVCodecContext *audioEncoderCtx = avcodec_alloc_context3(audioEncoder);
    audioEncoderCtx -> sample_rate = videoAudioDecoderCtx -> sample_rate;
    audioEncoderCtx -> sample_fmt = AV_SAMPLE_FMT_FLTP;
//    audioEncoderCtx -> ch_layout = AV_CHANNEL_LAYOUT_MONO;//videoAudioDecoderCtx -> ch_layout;
    av_channel_layout_copy(&audioEncoderCtx->ch_layout, &(AVChannelLayout)AV_CHANNEL_LAYOUT_MONO);
    audioEncoderCtx -> frame_size = 1024;
//    AV_CH_LAYOUT_MONO  AV_CHANNEL_LAYOUT_MONO
    audioEncoderCtx -> bit_rate = videoAudioDecoderCtx -> bit_rate;
    
    if(avcodec_open2(audioEncoderCtx, audioEncoder, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "can not open audio encoder! \n");
        goto fail;
    }
    
    //输出上下文
    avformat_alloc_output_context2(&outFmtCtx, NULL, NULL, mergeOutFile);
    if (outFmtCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "could not create output context \n");
        goto fail;
    }
    
    AVStream *inVideoStream = inFmtCtx -> streams[videoIndex];
    AVStream *inVideoAudioStream = inFmtCtx -> streams[videoAudioIndex];
    AVStream *inAudioStream = inAFmtCtx -> streams[audioIndex];
    AVStream *outVideoStream = avformat_new_stream(outFmtCtx, NULL);
    avcodec_parameters_copy(outVideoStream -> codecpar, inVideoStream -> codecpar);
    
    AVStream *outAudioStream = avformat_new_stream(outFmtCtx, NULL);
    avcodec_parameters_from_context(outAudioStream -> codecpar, audioEncoderCtx);
    
    if (outFmtCtx -> oformat -> flags & AVFMT_GLOBALHEADER) {
        audioEncoderCtx -> flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
    }
    
    
    //打开输出文件
    if (!(outFmtCtx->oformat->flags & AVFMT_NOFILE)) {
        if(avio_open(&outFmtCtx->pb, mergeOutFile, AVIO_FLAG_WRITE) < 0) {
            av_log(NULL, AV_LOG_ERROR, "could not open output file!\n");
            goto fail;
        }
    }
    
    //写入文件头
    if(avformat_write_header(outFmtCtx, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Write output file header occured error \n");
        goto fail;
    }
    
    
//    SwrContext *videoAudioSwrCtx = swr_alloc();
//    SwrContext *audioSwrCtx = swr_alloc();
//
//    av_opt_set_chlayout(videoAudioSwrCtx, "in_chlayout", &videoAudioDecoderCtx->ch_layout, 0);
//    av_opt_set_int(videoAudioSwrCtx, "in_sample_rate", videoAudioDecoderCtx->sample_rate, 0);
//    av_opt_set_sample_fmt(videoAudioSwrCtx, "in_sample_fmt", videoAudioDecoderCtx->sample_fmt, 0);
//
//    av_opt_set_chlayout(videoAudioSwrCtx, "out_chlayout", &audioEncoderCtx->ch_layout, 0);
//    av_opt_set_int(videoAudioSwrCtx, "out_sample_rate", audioEncoderCtx->sample_rate, 0);
//    av_opt_set_sample_fmt(videoAudioSwrCtx, "out_sample_fmt", audioEncoderCtx->sample_fmt, 0);
//
//    av_opt_set_chlayout(audioSwrCtx, "in_chlayout", &audioDecoderCtx->ch_layout, 0);
//    av_opt_set_int(audioSwrCtx, "in_sample_rate", audioDecoderCtx->sample_rate, 0);
//    av_opt_set_sample_fmt(audioSwrCtx, "in_sample_fmt", audioDecoderCtx->sample_fmt, 0);
//
//    av_opt_set_chlayout(audioSwrCtx, "out_chlayout", &audioEncoderCtx->ch_layout, 0);
//    av_opt_set_int(audioSwrCtx, "out_sample_rate", audioEncoderCtx->sample_rate, 0);
//    av_opt_set_sample_fmt(audioSwrCtx, "out_sample_fmt", audioEncoderCtx->sample_fmt, 0);
    
//    int64_t video_channels_layout = av_get_default_channel_layout(videoAudioDecoderCtx->channels);
//    int64_t audio_decoder_layout = av_get_default_channel_layout(audioDecoderCtx->channels);
//    int64_t audio_encoder_layout = av_get_default_channel_layout(audioEncoderCtx->ch_layout.nb_channels);
//
//
    SwrContext *videoAudioSwrCtx = swr_alloc_set_opts(NULL,
                                                      AV_CH_LAYOUT_MONO,//av_get_default_channel_layout(audioEncoderCtx -> channels), //AV_CH_LAYOUT_MONO
                                                      audioEncoderCtx->sample_fmt,
                                                      audioEncoderCtx -> sample_rate,
                                                      av_get_default_channel_layout(videoAudioDecoderCtx -> channels), //AV_CH_LAYOUT_STEREO
                                                      videoAudioDecoderCtx -> sample_fmt,
                                                      videoAudioDecoderCtx -> sample_rate,
                                                      0,
                                                      NULL);

    SwrContext *audioSwrCtx = swr_alloc_set_opts(NULL,
                                                 AV_CH_LAYOUT_MONO,//av_get_default_channel_layout(audioEncoderCtx -> channels), //AV_CH_LAYOUT_MONO
                                                 audioEncoderCtx->sample_fmt,
                                                 audioEncoderCtx -> sample_rate,
                                                 av_get_default_channel_layout(audioDecoderCtx -> channels), //AV_CH_LAYOUT_STEREO
                                                 audioDecoderCtx -> sample_fmt,
                                                 audioDecoderCtx -> sample_rate,
                                                 0,
                                                 NULL);

    if(swr_init(videoAudioSwrCtx) < 0) {
        av_log(NULL, AV_LOG_ERROR, "init videoAudioSwrCtx swr failed!\n");
        goto fail;
    }

    if(swr_init(audioSwrCtx) < 0) {
        av_log(NULL, AV_LOG_ERROR, "init audioSwrCtx swr failed!\n");
        goto fail;
    }
    
    AVFrame *video_audio_frame = av_frame_alloc();
    AVFrame *video_audio_covert_frame = av_frame_alloc();
    AVFrame *audio_frame = av_frame_alloc();
    AVFrame *audio_covert_frame = av_frame_alloc();
    
//    AVFrame *outAudioFrame = av_frame_alloc();
//    outAudioFrame -> format = audioEncoderCtx -> sample_fmt;
//    outAudioFrame -> ch_layout = audioEncoderCtx -> ch_layout;
//    outAudioFrame -> sample_rate = 44100;//audioEncoderCtx -> sample_rate;
////    outAudioFrame -> nb_samples = audioEncoderCtx -> frame_size;
//    int nbsamples = (int)av_rescale_rnd(swr_get_delay(audioSwrCtx, 44100) + 1024, 44100, 44100, AV_ROUND_UP);
//    outAudioFrame -> nb_samples = 1024;//nbsamples;
//
//    int resu = av_frame_get_buffer(outAudioFrame, 1);
//
//    if (resu < 0) {
//        av_log(NULL, AV_LOG_ERROR, "outAudioFrame buffer alloc failed:%s\n", av_err2str(resu));
//        goto fail;
//    }
    
    video_audio_covert_frame -> format = audioEncoderCtx -> sample_fmt;
    video_audio_covert_frame -> ch_layout = audioEncoderCtx -> ch_layout;
    video_audio_covert_frame -> sample_rate = 44100;//audioEncoderCtx -> sample_rate;
//    outAudioFrame -> nb_samples = audioEncoderCtx -> frame_size;
//    int nbsamples = (int)av_rescale_rnd(swr_get_delay(audioSwrCtx, 44100) + 1024, 44100, 44100, AV_ROUND_UP);
    video_audio_covert_frame -> nb_samples = 1024;//nbsamples;
    
    av_frame_get_buffer(video_audio_covert_frame, 1);
    
    audio_covert_frame -> format = audioEncoderCtx -> sample_fmt;
    audio_covert_frame -> ch_layout = audioEncoderCtx -> ch_layout;
    audio_covert_frame -> sample_rate = 44100;//audioEncoderCtx -> sample_rate;
//    outAudioFrame -> nb_samples = audioEncoderCtx -> frame_size;
//    int nbsamples = (int)av_rescale_rnd(swr_get_delay(audioSwrCtx, 44100) + 1024, 44100, 44100, AV_ROUND_UP);
    audio_covert_frame -> nb_samples = 1024;//nbsamples;
    
    av_frame_get_buffer(audio_covert_frame, 1);
    
    // 初始化滤镜图
    AVFilterGraph *graph = avfilter_graph_alloc();
    AVFilterContext *src0 = NULL;    //第一路音频
    AVFilterContext *src1 = NULL;   //第二路音频
    AVFilterContext *sink = NULL;   //输出混流后的
    if (init_filter_graph(graph, &src0, &src1, &sink, volume1, volume2) < 0) {
        av_log(NULL, AV_LOG_ERROR, "init filter graph failed \n");
        goto fail;
    }
    
    int64_t audio_pts = 0;
    
    AVPacket *v_pkt = av_packet_alloc();
    AVPacket *a_pkt = av_packet_alloc();
    
    int ret_a = 0;
    
    while (1) {
        
        int ret_v = av_read_frame(inFmtCtx, v_pkt);
        
        //需要都读取完才能结束
        if (ret_v < 0 || ret_a < 0) {
            break;
        }
        
//        //处理视频
        if (ret_v >=0 && v_pkt -> stream_index == videoIndex) {
            //视频流直接写入 无须处理
            v_pkt -> pts = av_rescale_q(v_pkt -> pts, inVideoStream -> time_base, outVideoStream -> time_base);
            v_pkt -> dts = av_rescale_q(v_pkt -> dts, inVideoStream -> time_base, outVideoStream -> time_base);
            v_pkt -> duration = av_rescale_q(v_pkt -> duration, inVideoStream -> time_base, outVideoStream -> time_base);
            v_pkt -> pos = -1;

            int write_ret = av_interleaved_write_frame(outFmtCtx, v_pkt);

            av_packet_unref(v_pkt);
            if(write_ret < 0) {
                av_log(NULL, AV_LOG_ERROR, "write video frame failed :%s!\n", av_err2str(write_ret));
                goto fail;
            }
        }
        
        /**
         `先读取到视频文件中的音频帧,然后解码出来通过swr转成固定的音频数据格式 并添加到src0的buffer中,
         `再去读取第二个视频文件中的音频帧 做同样的处理 `
         `最后得到一个混合后的音频AVFrame
         */
        if (ret_v >= 0 && v_pkt -> stream_index == videoAudioIndex) {
            //先读取到视频文件中音频帧
            //解码
            int ret = avcodec_send_packet(videoAudioDecoderCtx, v_pkt);
            if(ret < 0) {
                av_packet_unref(v_pkt);
                av_log(NULL, AV_LOG_ERROR, "send audio frame to decoder failed:%s!\n",av_err2str(ret));
                goto fail;
            }
            
            while (ret >= 0) {
                ret = avcodec_receive_frame(videoAudioDecoderCtx, video_audio_frame);
                
                int swrRet = swr_convert_frame(audioSwrCtx, video_audio_covert_frame, video_audio_frame);
                if(swrRet < 0) {
                    av_log(NULL, AV_LOG_ERROR, "audio swr covert frame failed:%s \n", av_err2str(swrRet));
                }
                
                if (av_buffersrc_add_frame_flags(src0, video_audio_covert_frame, AV_BUFFERSRC_FLAG_KEEP_REF) < 0) {
                       fprintf(stderr, "Error feeding the video_audio_covert_frame to the filtergraph\n");
                       break;
                   }
                
                //开始读第二个视频文件中的音频数据
                ret_a = av_read_frame(inAFmtCtx, a_pkt);
                
                while (ret_a >= 0 && a_pkt -> stream_index != audioIndex) {
                    av_packet_unref(a_pkt);
                    ret_a = av_read_frame(inAFmtCtx, a_pkt);
                }
                
                    ret = avcodec_send_packet(audioDecoderCtx, a_pkt);
                    if(ret < 0) {
                        av_packet_unref(a_pkt);
                        av_log(NULL, AV_LOG_ERROR, "send audio frame to decoder failed:%s!\n",av_err2str(ret));
                        goto fail;
                    }
                    
                    while (ret >= 0) {
                        ret = avcodec_receive_frame(audioDecoderCtx, audio_frame);
                        
                        int swrRet1 = swr_convert_frame(audioSwrCtx, audio_covert_frame, audio_frame);
                        if(swrRet1 < 0) {
                            av_log(NULL, AV_LOG_ERROR, "swrAudioRet covert frame failed:%s \n", av_err2str(swrRet1));
                        }
                        
                        if (av_buffersrc_add_frame_flags(src1, audio_covert_frame, AV_BUFFERSRC_FLAG_KEEP_REF) < 0) {
                               fprintf(stderr, "Error feeding the audio_covert_frame to the filtergraph\n");
                               break;
                           }
                        
                        // 从滤镜图中拉取混合后的帧
                        AVFrame *filt_frame = av_frame_alloc();
                        while (1) {
                            int ret = av_buffersink_get_frame(sink, filt_frame);
                            if (ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                                break;
                            }
                            if (ret < 0) {
                                fprintf(stderr, "Error during filtering\n");
                                break;
                            }
                        }
                        
                        
                        filt_frame -> pts = audio_pts;
                        audio_pts += filt_frame -> nb_samples;
                        
                        filt_frame -> pts = av_rescale_q(filt_frame -> pts, videoAudioDecoderCtx -> time_base, audioEncoderCtx -> time_base);
                        
                        ret = avcodec_send_frame(audioEncoderCtx, filt_frame);
                        if(ret < 0) {
                            av_log(NULL, AV_LOG_ERROR, "send audio frame to encoder failed:%s!\n",av_err2str(ret));
                            goto fail;
                        }
                        AVPacket *pkt_out = av_packet_alloc();
                        while (ret >= 0) {
                            ret = avcodec_receive_packet(audioEncoderCtx, pkt_out);
                            
                            if(ret == AVERROR(EAGAIN) || ret == AVERROR_EOF) {
                                break;
                            }else if (ret < 0) {
                                av_log(NULL, AV_LOG_ERROR, "encoder audio frame failed:%s \n", av_err2str(ret));
                                goto fail;
                            }
                            
                            pkt_out -> stream_index = outAudioStream -> index;
                            
                            pkt_out->pts = av_rescale_q(pkt_out->pts, inVideoAudioStream->time_base, outAudioStream->time_base);
                            pkt_out->dts = av_rescale_q(pkt_out->dts, inVideoAudioStream->time_base, outAudioStream->time_base);
                            pkt_out -> duration = av_rescale_q(pkt_out -> duration, inVideoAudioStream->time_base, outAudioStream->time_base);
                            
//                            NSLog(@"写入audio数据 pts:%ld", pkt_out -> pts);
                            int write_ret = av_interleaved_write_frame(outFmtCtx, pkt_out);
                            
                            av_frame_free(&filt_frame);
                            av_packet_unref(pkt_out);
                            if(write_ret < 0) {
                                av_log(NULL, AV_LOG_ERROR, "write audio frame failed :%s!\n", av_err2str(write_ret));
                                goto fail;
                            }
                        }
                    }
            }
            
            av_packet_unref(v_pkt);
            av_packet_unref(a_pkt);
        }
        
    }
    
    // 写入文件尾部
    av_write_trailer(outFmtCtx);
    
    if (video_audio_frame) {
        av_frame_free(&video_audio_frame);
    }
    if (video_audio_covert_frame) {
        av_frame_free(&video_audio_covert_frame);
    }
    
    if (audio_frame) {
        av_frame_free(&audio_frame);
    }
    
    if (audio_covert_frame) {
        av_frame_free(&audio_covert_frame);
    }
    
    if (inFmtCtx) {
        avformat_close_input(&inFmtCtx);
        avformat_free_context(inFmtCtx);
    }
    if (inAFmtCtx) {
        avformat_close_input(&inAFmtCtx);
        avformat_free_context(inAFmtCtx);
    }
    if (outFmtCtx) {
        avformat_close_input(&outFmtCtx);
        avformat_free_context(outFmtCtx);
    }
    !complete?:complete(YES, mergeOutFilePath);
    return;
    
fail:
    
    if (inFmtCtx) {
        avformat_close_input(&inFmtCtx);
        avformat_free_context(inFmtCtx);
    }
    if (inAFmtCtx) {
        avformat_close_input(&inAFmtCtx);
        avformat_free_context(inAFmtCtx);
    }
    if (outFmtCtx) {
        avformat_close_input(&outFmtCtx);
        avformat_free_context(outFmtCtx);
    }
   
    if (videoAudioDecoderCtx) {
        avcodec_free_context(&videoAudioDecoderCtx);
    }
    
    if (video_audio_frame) {
        av_frame_free(&video_audio_frame);
    }
    if (video_audio_covert_frame) {
        av_frame_free(&video_audio_covert_frame);
    }
    
    if (audio_frame) {
        av_frame_free(&audio_frame);
    }
    
    if (audio_covert_frame) {
        av_frame_free(&audio_covert_frame);
    }
    
    !complete?:complete(NO, @"");
    return;
}

//创建混合音频的滤镜
static int init_filter_graph(AVFilterGraph *graph, AVFilterContext **src0, AVFilterContext **src1, AVFilterContext **sink, float volume1, float volume2) {
    
    const AVFilter *abuffersrc = avfilter_get_by_name("abuffer");
    const AVFilter *abuffersink = avfilter_get_by_name("abuffersink");
    const AVFilter *volume = avfilter_get_by_name("volume");
    const AVFilter *amix = avfilter_get_by_name("amix");

    char args[512];
    int ret;

    // 创建输入音频流 A 的滤镜节点
    AVFilterContext *buffersrc_ctx0 = avfilter_graph_alloc_filter(graph, abuffersrc, "in0");
    snprintf(args, sizeof(args), "time_base=1/44100:sample_rate=44100:sample_fmt=fltp:channel_layout=mono");
    if ((ret = avfilter_init_str(buffersrc_ctx0, args)) < 0) {
        return ret;
    }

    // 创建输入音频流 B 的滤镜节点并设置音量
    AVFilterContext *buffersrc_ctx1 = avfilter_graph_alloc_filter(graph, abuffersrc, "in1");
    snprintf(args, sizeof(args), "time_base=1/44100:sample_rate=44100:sample_fmt=fltp:channel_layout=mono");
    if ((ret = avfilter_init_str(buffersrc_ctx1, args)) < 0) {
        return ret;
    }

    //音量的滤镜
    AVFilterContext *volume_ctx0 = avfilter_graph_alloc_filter(graph, volume, "volume0");
    snprintf(args, sizeof(args), "volume=%f",volume1);
    if ((ret = avfilter_init_str(volume_ctx0, args)) < 0) {
        return ret;
    }
    
    AVFilterContext *volume_ctx1 = avfilter_graph_alloc_filter(graph, volume, "volume1");
    snprintf(args, sizeof(args), "volume=%f",volume2);
    if ((ret = avfilter_init_str(volume_ctx1, args)) < 0) {
        return ret;
    }

    // 创建输出的滤镜节点
    AVFilterContext *buffersink_ctx = avfilter_graph_alloc_filter(graph, abuffersink, "out");
    if ((ret = avfilter_init_str(buffersink_ctx, NULL)) < 0) {
        return ret;
    }

    // 创建音频混合的滤镜节点
    AVFilterContext *amix_ctx = avfilter_graph_alloc_filter(graph, amix, "amix");
    snprintf(args, sizeof(args), "inputs=2");
    if ((ret = avfilter_init_str(amix_ctx, args)) < 0) {
        return ret;
    }

    // 连接滤镜链
    if ((ret = avfilter_link(buffersrc_ctx0, 0, volume_ctx0, 0)) < 0) {
        return ret;
    }
    if ((ret = avfilter_link(volume_ctx0, 0, amix_ctx, 0)) < 0) {
        return ret;
    }
    if ((ret = avfilter_link(buffersrc_ctx1, 0, volume_ctx1, 0)) < 0) {
        return ret;
    }
    if ((ret = avfilter_link(volume_ctx1, 0, amix_ctx, 1)) < 0) {
        return ret;
    }
    if ((ret = avfilter_link(amix_ctx, 0, buffersink_ctx, 0)) < 0) {
        return ret;
    }

    *src0 = buffersrc_ctx0;
    *src1 = buffersrc_ctx1;
    *sink = buffersink_ctx;

    return avfilter_graph_config(graph, NULL);
}

@end

