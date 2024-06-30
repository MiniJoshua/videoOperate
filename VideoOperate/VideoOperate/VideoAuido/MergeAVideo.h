//
//  MergeAVideo.h
//  VideoOperate
//
//  Created by 刘维 on 2024/6/12.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MergeAVideo : NSObject

- (void)mergeVideoFilePath:(NSString *)videoFilePath audioFilePath:(NSString *)audioFilePath;
//合并音视频 默认会执行解码编码的流程
- (void)megreVideoComplete:(void(^)(NSString *mergeFilePath,BOOL success))complete;
- (void)megreVideoNeedDecoder:(BOOL)status complete:(void(^)(NSString *mergeFilePath,BOOL success))complete;

@end

NS_ASSUME_NONNULL_END
