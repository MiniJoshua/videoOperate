//
//  MergeAVideo.m
//  VideoOperate
//
//  Created by 刘维 on 2024/6/12.
//

#import "MergeAVideo.h"
#import "log.h"
#import "avutil.h"
#import "avformat.h"
#import "avcodec.h"
#import "swscale.h"
#import "parseutils.h"
#import "imgutils.h"
#import "swresample.h"
#import "avdevice.h"
#import "opt.h"
#import "mem.h"
#import "intreadwrite.h"

@interface MergeAVideo() {
    
    NSString *_megreDirectiorPath;
    NSString *_videoFilePath;
    NSString *_audioFilePath;
    
    NSString *_mergeFilePath;
    
    AVFormatContext *_videoInFmtCtx;
    NSInteger _videoIndex;
    AVCodecContext *_videoDecoderCtx;
    AVCodecContext *_videoEncoderCtx;
    AVFrame *_videoConvertFrame;
    struct SwsContext *_videoFmtSwsCtx;
    
    AVFormatContext *_audioInFmtCtx;
    NSInteger _audioIndex;
    AVCodecContext *_audioDecoderCtx;
    AVCodecContext *_audioEncoderCtx;
    AVFrame *_audioConvertFrame;
    SwrContext *_audioFmtSwrCtx;
    
    AVFormatContext *_outputFmtCtx;
    
    BOOL _decoderStatus;
}

@end

@implementation MergeAVideo

- (instancetype)init {
    
    self = [super init];
    if (self) {
        
        av_log_set_level(AV_LOG_INFO);
        
        NSString *documentPath = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
        _megreDirectiorPath = [documentPath stringByAppendingPathComponent:@"Merge"];
        
        NSFileManager *fileManager = [NSFileManager defaultManager];
        BOOL createStatus = [fileManager createDirectoryAtPath:_megreDirectiorPath withIntermediateDirectories:YES attributes:NULL error:NULL];
        if (!createStatus) {
            NSLog(@"创建Merge的文件夹失败");
        }
        
        [self removeAllMergeVideoFile];
    }
    
    return self;
}

- (void)removeAllMergeVideoFile {
    
    NSFileManager *fileManager = [NSFileManager defaultManager];
    
    NSArray *files = [fileManager contentsOfDirectoryAtPath:_megreDirectiorPath error:NULL];
    for(NSString *filePath in files) {
        NSString *fullFilePath = [NSString stringWithFormat:@"%@/%@",_megreDirectiorPath,filePath];
        NSLog(@"FilePath:%@",fullFilePath);
        [fileManager removeItemAtPath:fullFilePath error:NULL];
    }
}

- (NSString *)mergeAVideoFilePath {
    
    NSDate *date = [NSDate date];
    NSString *mergeFilePath = [_megreDirectiorPath stringByAppendingPathComponent:[NSString stringWithFormat:@"%f.mp4",date.timeIntervalSince1970]];
    
//    BOOL existStatus = [fileManager fileExistsAtPath:mergeFilePath];
//    if (existStatus) {
//        NSError *error;
//            BOOL success = [fileManager removeItemAtPath:saveFilePath error:&error];
//
//            if (success) {
//                NSLog(@"文件已经被成功删除");
//            } else {
//                NSLog(@"删除文件时出错: %@", error.localizedDescription);
//            }
//    }
    return mergeFilePath;
    
}

- (void)megreVideoComplete:(void(^)(NSString *mergeFilePath,BOOL success))complete {
    
    [self megreVideoNeedDecoder:YES complete:complete];
}

- (void)megreVideoNeedDecoder:(BOOL)status complete:(void(^)(NSString *mergeFilePath,BOOL success))complete {
    
    _decoderStatus = status;
    BOOL success = NO;
    
    if (status) {
        success = [self startMerge];
    }else {
        success = [self startMergeWithNoCoder];
    }
    
    !complete?:complete(_mergeFilePath,success);
}

- (void)mergeVideoFilePath:(NSString *)videoFilePath audioFilePath:(NSString *)audioFilePath {
    
    if(!videoFilePath || [videoFilePath length] == 0 || !audioFilePath || [audioFilePath length] == 0) {
        NSLog(@"Merge video Error: video file or audio file is wrong");
        return;
    }
    
    _videoFilePath = videoFilePath;
    _audioFilePath = audioFilePath;
}

- (BOOL)startMerge {
    
    _mergeFilePath = @"";
    
    if ([self openVideoInfo] < 0) {
        return NO;
    }
    
    if ([self openAudioInfo] < 0) {
        return NO;
    }
    
    if ([self createVideoCoder] < 0) {
        return NO;
    }
    
    if ([self createVideoSwsContext] < 0) {
        return NO;
    }
    
    if ([self createAudioCoder] < 0) {
        return NO;
    }
    
    if ([self createAudioSwsContext] < 0) {
        return NO ;
    }
    
    //创建输出流
    NSString *tempMergeFilePath = [self mergeAVideoFilePath];
    const char * saveFilePath = [tempMergeFilePath UTF8String];
    _outputFmtCtx = NULL;
    int ret = avformat_alloc_output_context2(&_outputFmtCtx, NULL, NULL, saveFilePath);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "output format context alloc failed:%s\n",av_err2str(ret));
        return NO;
    }
    
    //视频输出流
    AVStream *videoStream = avformat_new_stream(_outputFmtCtx, NULL);
    if(videoStream == NULL) {
        av_log(NULL, AV_LOG_ERROR, "alloc video stream failed!\n");
        return NO;
    }
//    avcodec_parameters_copy(videoStream->codecpar, _videoInFmtCtx->streams[_videoIndex]->codecpar);
    avcodec_parameters_from_context(videoStream->codecpar, _videoEncoderCtx);
    videoStream -> time_base = _videoEncoderCtx -> time_base;
    
    //音频输出流
    AVStream *audioStream = avformat_new_stream(_outputFmtCtx, NULL);
    if(audioStream == NULL) {
        av_log(NULL, AV_LOG_ERROR, "alloc audio stream failed!\n");
        return NO;
    }
    
//    avcodec_parameters_copy(audioStream->codecpar, _audioInFmtCtx->streams[_audioIndex]->codecpar);
    avcodec_parameters_from_context(audioStream->codecpar, _audioEncoderCtx);
    
    //打开输出文件
    if (!(_outputFmtCtx->oformat->flags & AVFMT_NOFILE)) {
        if(avio_open(&_outputFmtCtx->pb, saveFilePath, AVIO_FLAG_WRITE) < 0) {
            av_log(NULL, AV_LOG_ERROR, "could not open output file!\n");
            return NO;
        }
    }
    
    //写入文件头
    if(avformat_write_header(_outputFmtCtx, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Write output file header occured error \n");
        return NO;
    }
    
    //用于存放读取出来的pkt
    AVPacket *pkt = av_packet_alloc();
    //存放解码后的数据
    AVFrame *decoderFrame = av_frame_alloc();
    //存放编码后的数据
    AVPacket *encoderPkt = av_packet_alloc();
    
    int64_t last_video_pts = 0;
    int64_t last_audio_pts = 0;
    
    int videoPts = 0;
    int audioPts = 0;
    
    while (1) {
        
        AVFormatContext *currentFmtCtx = NULL;
        AVStream *current_in_stream = NULL;
        AVStream *current_out_stream = NULL;
        NSInteger current_stream_index;
        
        //音频帧跟视频帧交叉写入
        if(av_compare_ts(last_video_pts, videoStream->time_base, last_audio_pts, audioStream->time_base) <= 0) {
            
            ret = av_read_frame(_videoInFmtCtx, pkt);
            currentFmtCtx = _videoInFmtCtx;
            current_in_stream = _videoInFmtCtx -> streams[_videoIndex];
            current_stream_index = _videoIndex;
            current_out_stream = videoStream;
            
        }else {
            //读取音频数据
            ret = av_read_frame(_audioInFmtCtx, pkt);
            currentFmtCtx = _audioInFmtCtx;
            current_in_stream = _audioInFmtCtx -> streams[_audioIndex];
            current_stream_index = _audioIndex;
            current_out_stream = audioStream;
        }
        
        //两者之一中的一个全部读取完则结束
        if (ret < 0) {
            break;
        }
            
        if(pkt -> stream_index == current_stream_index) {
            
            if (currentFmtCtx == _videoInFmtCtx) {
                
                //编解码视频数据
                ret = avcodec_send_packet(_videoDecoderCtx, pkt);
                
                if (ret < 0) {
                    av_log(NULL, AV_LOG_ERROR, "send video frame decoder failed:%s \n", av_err2str(ret));
                    return NO;
                }
                
                if (ret >= 0) {
                    
                    while (avcodec_receive_frame(_videoDecoderCtx, decoderFrame) == 0) {
                        
                        sws_scale(_videoFmtSwsCtx,
                                    (const uint8_t *const *)decoderFrame -> data,
                                    decoderFrame -> linesize,
                                    0,
                                    _videoDecoderCtx -> height,
                                    _videoConvertFrame -> data,
                                    _videoConvertFrame -> linesize);
                        
                        _videoConvertFrame -> pts = videoPts;
                        videoPts++;
                        
                        int ret1 = avcodec_send_frame(_videoEncoderCtx, _videoConvertFrame);
                        if(ret1 < 0) {
                            av_log(NULL, AV_LOG_ERROR, "send video frame encoder failed:%s \n", av_err2str(ret1));
                            return NO;
                        }
                        
                        while(ret1 >= 0) {
                            ret1 = avcodec_receive_packet(_videoEncoderCtx, encoderPkt);
                            if(ret1 == AVERROR(EAGAIN) || ret1 == AVERROR_EOF) {
                                break;
                            }else if (ret1 < 0) {
                                av_log(NULL, AV_LOG_ERROR, "encoder video frame failed:%s \n", av_err2str(ret));
                                return NO;
                            }
                            
                            encoderPkt->stream_index = current_out_stream -> index;
                            
                            //在将编码后的数据写入输出时，将 PTS、DTS 和 duration 从编码器上下文的时间基转换为对应流的时间基。
                            encoderPkt->pts = av_rescale_q(encoderPkt->pts, _videoEncoderCtx->time_base, current_out_stream->time_base);
                            encoderPkt->dts = av_rescale_q(encoderPkt->dts, _videoEncoderCtx->time_base, current_out_stream->time_base);
                            encoderPkt->duration = av_rescale_q(encoderPkt->duration, _videoEncoderCtx->time_base, current_out_stream->time_base);
                            
                            last_video_pts = encoderPkt -> pts;
                            
                            ret1 = av_interleaved_write_frame(_outputFmtCtx, encoderPkt);
                            if (ret1 < 0) {
                                av_log(NULL, AV_LOG_ERROR, "write video frame failed:%s \n", av_err2str(ret1));
                                return NO;
                            }
                            
                            av_packet_unref(encoderPkt);
                        }
                    }
                }
                
            } else {
                
                ret = avcodec_send_packet(_audioDecoderCtx, pkt);
                
                if (ret < 0) {
                    av_log(NULL, AV_LOG_ERROR, "send audio frame decoder failed:%s \n", av_err2str(ret));
                    return NO;
                }
                
                if(ret >= 0) {
                    while (avcodec_receive_frame(_audioDecoderCtx, decoderFrame) == 0) {
                        
                        //frame里面存放的就是解码后的音频数据 pcm s16le packed格式
                        int swrRet = swr_convert_frame(_audioFmtSwrCtx, _audioConvertFrame, decoderFrame);
                        if(swrRet < 0) {
                            av_log(NULL, AV_LOG_ERROR, "audio swr covert frame failed:%s \n", av_err2str(swrRet));
                        }
                        
                        _audioConvertFrame->pts = audioPts;
                        audioPts += _audioConvertFrame->nb_samples;
                        
                        //开始音频编码
                        int ret1 = avcodec_send_frame(_audioEncoderCtx, _audioConvertFrame);
                        while (ret1 >= 0) {
                            ret1 = avcodec_receive_packet(_audioEncoderCtx, encoderPkt);
                            if(ret1 == AVERROR(EAGAIN) || ret1 == AVERROR_EOF) {
                                break;
                            }else if (ret1 < 0) {
                                av_log(NULL, AV_LOG_ERROR, "encoder audio frame failed:%s \n", av_err2str(ret1));
                                return NO;
                            }
                            //写入音频帧
                            encoderPkt->stream_index = current_out_stream -> index;
                        
                            //在将编码后的数据写入输出时，将 PTS、DTS 和 duration 从编码器上下文的时间基转换为对应流的时间基。
                            encoderPkt->pts = av_rescale_q(encoderPkt->pts, _audioEncoderCtx->time_base, current_out_stream->time_base);
                            encoderPkt->dts = av_rescale_q(encoderPkt->dts, _audioEncoderCtx->time_base, current_out_stream->time_base);
                            encoderPkt->duration = av_rescale_q(encoderPkt->duration, _audioEncoderCtx->time_base, current_out_stream->time_base);
                            
                            last_audio_pts = encoderPkt -> pts;
                            
                            int ret1 = av_interleaved_write_frame(_outputFmtCtx, encoderPkt);
                            if (ret1 < 0) {
                                av_log(NULL, AV_LOG_ERROR, "write video frame failed:%s \n", av_err2str(ret1));
                                return NO;
                            }
                            
                            av_packet_unref(encoderPkt);
                        }
                        
                    }
                }
            }
        }
        av_packet_unref(pkt);
    }
    
    //写入文件尾
    av_write_trailer(_outputFmtCtx);
    if(_videoInFmtCtx) {
        avformat_close_input(&_videoInFmtCtx);
    }
    if (_audioInFmtCtx) {
        avformat_close_input(&_audioInFmtCtx);
    }
    
    _mergeFilePath = tempMergeFilePath;
    
    avformat_free_context(_videoInFmtCtx);
    avformat_free_context(_audioInFmtCtx);
    av_frame_free(&decoderFrame);
    av_frame_free(&_videoConvertFrame);
    av_frame_free(&_audioConvertFrame);
    
    avcodec_free_context(&_videoEncoderCtx);
    avcodec_free_context(&_audioEncoderCtx);
    if (_audioFmtSwrCtx) {
        swr_close(_audioFmtSwrCtx);
        swr_free(&_audioFmtSwrCtx);
    }
    
    return YES;
}

- (BOOL)startMergeWithNoCoder {
    
    _mergeFilePath = @"";
    
    if ([self openVideoInfo] < 0) {
        return NO;
    }
    
    if ([self openAudioInfo] < 0) {
        return NO;
    }
    
    //创建输出流
    NSString *tempMergeFilePath = [self mergeAVideoFilePath];
    const char * saveFilePath = [tempMergeFilePath UTF8String];
    _outputFmtCtx = NULL;
    int ret = avformat_alloc_output_context2(&_outputFmtCtx, NULL, NULL, saveFilePath);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "output format context alloc failed:%s\n",av_err2str(ret));
        return NO;
    }
    
    //视频输出流
    AVStream *videoStream = avformat_new_stream(_outputFmtCtx, NULL);
    if(videoStream == NULL) {
        av_log(NULL, AV_LOG_ERROR, "alloc video stream failed!\n");
        return NO;
    }
    avcodec_parameters_copy(videoStream->codecpar, _videoInFmtCtx->streams[_videoIndex]->codecpar);
    videoStream->time_base = _videoInFmtCtx->streams[_videoIndex] -> time_base;
    
    //音频输出流
    AVStream *audioStream = avformat_new_stream(_outputFmtCtx, NULL);
    if(audioStream == NULL) {
        av_log(NULL, AV_LOG_ERROR, "alloc audio stream failed!\n");
        return NO;
    }
    
    avcodec_parameters_copy(audioStream->codecpar, _audioInFmtCtx->streams[_audioIndex]->codecpar);
    audioStream->time_base = _audioInFmtCtx->streams[_audioIndex] -> time_base;
    
    //打开输出文件
    if (!(_outputFmtCtx->oformat->flags & AVFMT_NOFILE)) {
        if(avio_open(&_outputFmtCtx->pb, saveFilePath, AVIO_FLAG_WRITE) < 0) {
            av_log(NULL, AV_LOG_ERROR, "could not open output file!\n");
            return NO;
        }
    }
    
    //写入文件头
    if(avformat_write_header(_outputFmtCtx, NULL) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Write output file header occured error \n");
        return NO;
    }
    
    //用于存放读取出来的pkt
    AVPacket *pkt = av_packet_alloc();
    
    int64_t last_pts = 0;
    int64_t last_audio_pts = 0;
    
    while (1) {
        AVFormatContext *currentFmtCtx = NULL;
        AVStream *current_in_stream = NULL;
        AVStream *current_out_stream = NULL;
        NSInteger current_stream_index;
        //先判断现在应该写入音频帧还是视频帧
        
        if(av_compare_ts(last_pts, videoStream->time_base, last_audio_pts, audioStream->time_base) <= 0) {
            //先读取视频数据
            ret = av_read_frame(_videoInFmtCtx, pkt);
            currentFmtCtx = _videoInFmtCtx;
            current_in_stream = _videoInFmtCtx->streams[_videoIndex];
            current_out_stream = videoStream;
            current_stream_index = _videoIndex;
        }else {
            //读取音频数据
            ret = av_read_frame(_audioInFmtCtx, pkt);
            currentFmtCtx = _audioInFmtCtx;
            current_in_stream = _audioInFmtCtx->streams[_audioIndex];
            current_out_stream = audioStream;
            current_stream_index = _audioIndex;
        }
        
        //只要是其中一个读取结束 就当这个mp4文件写入结束了
        if(ret < 0) {
            break;
        }
        
        if(pkt->stream_index == current_stream_index) {
            
            if(currentFmtCtx == _videoInFmtCtx) {
                
                // 视频时间戳偏移调整
                pkt->pts = av_rescale_q(pkt->pts, current_in_stream->time_base, current_out_stream->time_base);
                pkt->dts = av_rescale_q(pkt->dts, current_in_stream->time_base, current_out_stream->time_base);
                pkt->duration = av_rescale_q(pkt->duration, current_in_stream->time_base, current_out_stream->time_base);

                last_pts = pkt->pts;
                
            }else {
                
                // 音频时间戳偏移调整
                pkt->pts = av_rescale_q(pkt->pts, current_in_stream->time_base, current_out_stream->time_base);
                pkt->dts = av_rescale_q(pkt->dts, current_in_stream->time_base, current_out_stream->time_base);
                pkt->duration = av_rescale_q(pkt->duration, current_in_stream->time_base, current_out_stream->time_base);

               last_audio_pts = pkt->pts;
                
            }
            
            pkt->pos = -1;
            
            if ((ret = av_interleaved_write_frame(_outputFmtCtx, pkt)) < 0) {
                av_log(NULL, AV_LOG_INFO, "Error muxing packet \n");
                break;
            }
        }
        
        av_packet_unref(pkt);
    }
    
    av_write_trailer(_outputFmtCtx);
    
    if(_videoInFmtCtx) {
        avformat_close_input(&_videoInFmtCtx);
    }
    if (_audioInFmtCtx) {
        avformat_close_input(&_audioInFmtCtx);
    }
    
    _mergeFilePath = tempMergeFilePath;
    
    avformat_free_context(_videoInFmtCtx);
    avformat_free_context(_audioInFmtCtx);
    
    return YES;
}

- (int)openVideoInfo {
    
    //打开视频上下文
    _videoInFmtCtx = avformat_alloc_context();
    if(_videoInFmtCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "alloc video in format context failed!\n");
        return -1;
    }
    
    int ret = avformat_open_input(&_videoInFmtCtx, [_videoFilePath UTF8String], NULL, NULL);
    if(ret != 0) {
        av_log(NULL, AV_LOG_ERROR, "open video input format failed:%s\n",av_err2str(ret));
        return -1;
    }
    
    //解析流信息
    ret = avformat_find_stream_info(_videoInFmtCtx, NULL);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "find video stream info failed: %s\n",av_err2str(ret));
        return -1;
    }
    
    ret = av_find_best_stream(_videoInFmtCtx, AVMEDIA_TYPE_VIDEO, -1, -1, NULL, 0);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "find video stream index failed :%s\n", av_err2str(ret));
        return -1;
    }
    
    _videoIndex = ret;
    
    return 0;
}

- (int)openAudioInfo {
    
    //打开音频上下文
    _audioInFmtCtx = avformat_alloc_context();
    if(_audioInFmtCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "alloc audio informat context failed!\n");
        return -1;
    }
    
    int ret = avformat_open_input(&_audioInFmtCtx, [_audioFilePath UTF8String], NULL, NULL);
    if(ret != 0) {
        av_log(NULL, AV_LOG_ERROR, "open audio input format failed:%s\n",av_err2str(ret));
        return -1;
    }
    
    ret = avformat_find_stream_info(_audioInFmtCtx, NULL);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "find audio stream info failed:%s\n",av_err2str(ret));
        return -1;
    }
    
    ret = av_find_best_stream(_audioInFmtCtx, AVMEDIA_TYPE_AUDIO, -1, -1, NULL, 0);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "find audio stream index failed:%s\n",av_err2str(ret));
        return -1;
    }
    
    _audioIndex = ret;
    
    return 0;
}

//创建视频的编/解码器
- (int)createVideoCoder {
    
    //创建对应的视频解码器
    _videoDecoderCtx = avcodec_alloc_context3(NULL);
    if(_videoDecoderCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Video decoder alloc fialed!\n");
        return  -1;
    }
    
    int ret = avcodec_parameters_to_context(_videoDecoderCtx, _videoInFmtCtx->streams[_videoIndex]->codecpar);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Copy decoder parameter to context failed: %s", av_err2str(ret));
        return -1;
    }
    
    _videoDecoderCtx->extradata = _videoInFmtCtx->streams[_videoIndex]->codecpar->extradata;
    
    const AVCodec *videoDecoder = avcodec_find_decoder(_videoDecoderCtx->codec_id);
    if (videoDecoder == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Can not find video decoder failed!\n");
        return -1;
    }
    
    ret = avcodec_open2(_videoDecoderCtx, videoDecoder, NULL);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Open video decoder failed:%s",av_err2str(ret));
        return -1;
    }
    
    //创建h264的编码器
    const AVCodec *videoEncoder = avcodec_find_encoder_by_name("h264_videotoolbox");
    if(videoEncoder == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Can not find h264_videotoolbox encoder\n");
        return -1;
    }
    
    _videoEncoderCtx = avcodec_alloc_context3(videoEncoder);
    if(_videoEncoderCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Alloc video encoder failed\n");
        return -1;
    }
    
    
    AVRational time_base = _videoInFmtCtx->streams[_videoIndex]->time_base;
    AVRational framerate = av_guess_frame_rate(_videoInFmtCtx, _videoInFmtCtx->streams[_videoIndex], NULL);

    // 验证时间基和帧率是否一致
    if (time_base.num * framerate.den != time_base.den * framerate.num) {
        // 调整时间基，使其与帧率一致
        time_base.num = framerate.den;
        time_base.den = framerate.num;
    }
    
    enum AVPixelFormat pixFmt = AV_PIX_FMT_YUV420P;
    _videoEncoderCtx -> codec_type = AVMEDIA_TYPE_VIDEO;
    _videoEncoderCtx -> pix_fmt = pixFmt;
    _videoEncoderCtx -> width = _videoDecoderCtx -> width;
    _videoEncoderCtx -> height = _videoDecoderCtx -> height;
    _videoEncoderCtx -> framerate = framerate;
    _videoEncoderCtx -> time_base = time_base;
    _videoEncoderCtx -> max_b_frames = 0;
    _videoEncoderCtx -> gop_size = 10;
    _videoEncoderCtx -> color_range = AVCOL_RANGE_MPEG;
    _videoEncoderCtx -> sample_aspect_ratio = _videoDecoderCtx -> sample_aspect_ratio;
   
    
    ret = avcodec_open2(_videoEncoderCtx, videoEncoder, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Open video encoder failed:%s\n", av_err2str(ret));
        return -1;
    }
    
    return 0;
}

//创建音频的编/解码器
- (int)createAudioCoder {
    
    //创建对应的音频解码器
    _audioDecoderCtx = avcodec_alloc_context3(NULL);
    if(_audioDecoderCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Audio decoder alloc fialed!\n");
        return  -1;
    }
    
    int ret = avcodec_parameters_to_context(_audioDecoderCtx, _audioInFmtCtx->streams[_audioIndex]->codecpar);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Copy decoder parameter to context failed: %s", av_err2str(ret));
        return -1;
    }
    
    const AVCodec *audioDecoder = avcodec_find_decoder(_audioDecoderCtx->codec_id);
    if (audioDecoder == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Can not find audio decoder failed!\n");
        return -1;
    }
    
    ret = avcodec_open2(_audioDecoderCtx, audioDecoder, NULL);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Open audio decoder failed:%s",av_err2str(ret));
        return -1;
    }
    
    //创建aac的编码器
    const AVCodec *audioEncoder = avcodec_find_encoder(AV_CODEC_ID_AAC);
    if(audioEncoder == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Can not find aac encoder\n");
        return -1;
    }
    
    _audioEncoderCtx = avcodec_alloc_context3(audioEncoder);
    if(_videoEncoderCtx == NULL) {
        av_log(NULL, AV_LOG_ERROR, "Alloc audio encoder failed\n");
        return -1;
    }
    
    _audioEncoderCtx->sample_fmt = AV_SAMPLE_FMT_FLTP;
    av_channel_layout_copy(&_audioEncoderCtx->ch_layout, &(AVChannelLayout)AV_CHANNEL_LAYOUT_MONO);
    _audioEncoderCtx->sample_rate = 44100;
    _audioEncoderCtx->bit_rate = 128000;
//    _audioEncoderCtx->time_base = (AVRational){1, _audioDecoderCtx->sample_rate};
    // 打开编码器
    ret = avcodec_open2(_audioEncoderCtx, audioEncoder, NULL);
    if (ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "Could not open aac audio codec\n");
        return -1;
    }
    
    return 0;
}

- (int)createVideoSwsContext {
    
    _videoConvertFrame = av_frame_alloc();
    _videoConvertFrame -> format = AV_PIX_FMT_YUV420P;
    _videoConvertFrame -> width = _videoDecoderCtx -> width;
    _videoConvertFrame -> height = _videoDecoderCtx -> height;
    int dataSize = av_image_get_buffer_size(_videoDecoderCtx -> pix_fmt, _videoDecoderCtx -> width, _videoDecoderCtx -> height, 1);
    if(dataSize < 0) {
        av_log(NULL, AV_LOG_ERROR, "Get buffer size failed!\n");
        return -1;
    }
    
    uint8_t *buffer = av_malloc(dataSize);
    
    int ret = av_image_fill_arrays(_videoConvertFrame -> data,
                                   _videoConvertFrame -> linesize,
                                   buffer,
                                   AV_PIX_FMT_YUV420P,
                                   _videoDecoderCtx -> width,
                                   _videoDecoderCtx -> height,
                                   1);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "fill arrays failed:%s \n",av_err2str(ret));
        return -1;
    }
    
    _videoFmtSwsCtx = sws_getContext(_videoDecoderCtx -> width,
                                     _videoDecoderCtx -> height,
                                     _videoDecoderCtx -> pix_fmt,
                                     _videoDecoderCtx -> width,
                                     _videoDecoderCtx -> height,
                                     AV_PIX_FMT_YUV420P,
                                     0,
                                     NULL,
                                     NULL,
                                     NULL);
    
    return 0;
}

- (int)createAudioSwsContext {
    
    _audioFmtSwrCtx = swr_alloc();
    
    av_opt_set_chlayout(_audioFmtSwrCtx, "in_chlayout", &_audioDecoderCtx->ch_layout, 0);
    av_opt_set_int(_audioFmtSwrCtx, "in_sample_rate", _audioDecoderCtx->sample_rate, 0);
    av_opt_set_sample_fmt(_audioFmtSwrCtx, "in_sample_fmt", _audioDecoderCtx->sample_fmt, 0);
    
//    av_opt_set_int(audioSwrCtx, "out_channel_layout", audioEncoderCtx->channel_layout, 0);
    av_opt_set_chlayout(_audioFmtSwrCtx, "out_chlayout", &_audioEncoderCtx->ch_layout, 0);
    av_opt_set_int(_audioFmtSwrCtx, "out_sample_rate", _audioEncoderCtx->sample_rate, 0);
    av_opt_set_sample_fmt(_audioFmtSwrCtx, "out_sample_fmt", _audioEncoderCtx->sample_fmt, 0);
    int ret = swr_init(_audioFmtSwrCtx);
    if(ret < 0) {
        av_log(NULL, AV_LOG_ERROR, "init audio swr failed:%s \n",av_err2str(ret));
        return -1;
    }
    
    _audioConvertFrame = av_frame_alloc();
    int nbsamples = (int)av_rescale_rnd(swr_get_delay(_audioFmtSwrCtx, 44100) + _audioEncoderCtx -> frame_size, 44100, 44100, AV_ROUND_UP);
    _audioConvertFrame -> nb_samples = nbsamples;
    _audioConvertFrame -> format = _audioEncoderCtx -> sample_fmt;
    _audioConvertFrame -> ch_layout = _audioEncoderCtx -> ch_layout;
    _audioConvertFrame -> sample_rate = 44100;
    
    if(av_frame_get_buffer(_audioConvertFrame, 0) < 0) {
        av_log(NULL, AV_LOG_ERROR, "Could not alloc audio data buffers! \n");
        return -1;
    }
    
    return 0;
}

@end
