//
//  SaveFileManager.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/29.
//

import Foundation
import Photos

struct SaveFileManager {
    
    static func saveVideoAlbum(videoURL: URL, complete: @escaping (_ success: Bool) -> ()) {
        PHPhotoLibrary.requestAuthorization { status in
            
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges {
                    
                    let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    request?.creationDate = Date()
                    
                } completionHandler: { success, error in
                    
                    DispatchQueue.main.async {
                        if success {
                            complete(true)
                        } else {
                            complete(false)
                            print("视频保存失败: \(String(describing: error))")
                        }
                    }
                }

            } else {
                
                print("用户未授权访问相册")
                complete(false)
            }
        }
    }
    
    static func saveImageAlbum(image: UIImage, complete:@escaping (_ success: Bool) -> ()) {
        
        PHPhotoLibrary.requestAuthorization { status in
            
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges {
                    
                    let request = PHAssetChangeRequest.creationRequestForAsset(from: image)
                    request.creationDate = Date()
                    
                } completionHandler: { success, error in
                    
                    DispatchQueue.main.async {
                        if success {
                            complete(true)
                        } else {
                            complete(false)
                            print("视频保存失败: \(String(describing: error))")
                        }
                    }
                }

            } else {
                
                print("用户未授权访问相册")
                complete(false)
            }
        }
    }
}
