//
//  PhotoVideoLibrary.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/11.
//

import Foundation
import Photos
import UIKit

class PhotoLibraryAccess {
    static func requestAuthorization(competion: @escaping (PHAuthorizationStatus) -> Void) {
        let status = PHPhotoLibrary.authorizationStatus()
        
        switch status {
        case .authorized, .limited:
            DispatchQueue.main.async {
                competion(status)
            }
        case .notDetermined:
            PHPhotoLibrary.requestAuthorization { status in
                DispatchQueue.main.async {
                    competion(status)
                }
            }
        default:
            DispatchQueue.main.async {
                competion(status)
            }
        }
    }
}

struct PhotoVideoInfo: Identifiable, Hashable {
    let id: String
    let thumbnail: UIImage?
    let duration: TimeInterval
    
    init(id: String, thumbnail: UIImage?, duration: TimeInterval) {
        self.id = id
        self.thumbnail = thumbnail
        self.duration = duration
    }
}

class VideoLibrary: ObservableObject {
    @Published var photoVideos: [PhotoVideoInfo] = []
    @Published var status = false
    
    // 相册视频的总数
    private var totalVideoCount = 0

    func fetchVideos() {
        
        //先删除掉tmp里面所有的文件
        self.removeAllTempFile()
        
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        let fetchedVideos = PHAsset.fetchAssets(with: fetchOptions)
        
        totalVideoCount = fetchedVideos.count
        
        print("total videos: \(totalVideoCount)")
        
        fetchedVideos.enumerateObjects { asset, _, _ in
            self.getPhotoVideoInfo(from: asset)
        }
    }
    
    private func getPhotoVideoInfo(from asset: PHAsset) {
        let imageManager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        
        // 获取缩率图
        imageManager.requestImage(for: asset, targetSize: CGSize(width: 128, height: 128), contentMode: .aspectFill, options: options) { image, _ in
            let photoVideoInfo = PhotoVideoInfo(id: asset.localIdentifier, thumbnail: image, duration: asset.duration)
            DispatchQueue.main.async {
                self.photoVideos.append(photoVideoInfo)
                if self.totalVideoCount == self.photoVideos.count {
                    print("total videos count: \(self.photoVideos.count)")
                    self.status = true
                }
            }
        }
    }
    
    // 将相册中的视频保存到临时文件中
    func savePhotoVideoToTempDirectory(withID id: String, complete: @escaping (_ fileURL: URL?, _ success: Bool) -> Void) {
        let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [id], options: nil)
        guard let asset = fetchResult.firstObject else {
            print("无法找到对应的视频资源")
            complete(nil, false)
            return
        }
        
        let resourceOptions = PHAssetResourceRequestOptions()
        resourceOptions.isNetworkAccessAllowed = true
        
        guard let assetResource = PHAssetResource.assetResources(for: asset).first else {
            print("无法获取资源")
            complete(nil, false)
            return
        }
        
        // 获取这个视频文件的扩展名  ？前面是一个可选项 可能为nil 不为nil的时候取它的preferredFilenameExtension值  如果为nil 则通过?? 取 "mov"
        let fileExtension = UTType(filenameExtension: assetResource.uniformTypeIdentifier)?.preferredFilenameExtension ?? "mov"
        
        let tempDirectory = FileManager.default.temporaryDirectory
        let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
        
        let crateFileStatus = FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
        
        if !crateFileStatus {
            print("创建文件失败")
            complete(nil, false)
            return
        }else {
            print("创建临时文件成功")
        }
        
        do {
            let fileHandle = try FileHandle(forWritingTo: outputURL)
            
            PHAssetResourceManager.default().requestData(for: assetResource, options: resourceOptions) { data in
                fileHandle.write(data)
            } completionHandler: { error in
                fileHandle.closeFile()
                
                if let error = error {
                    print("请求数据失败:\(error.localizedDescription)")
                    complete(outputURL, false)
                } else {
                    complete(outputURL, true)
                }
            }

        } catch {
            print("数据写入失败:\(error.localizedDescription)")
            complete(outputURL, false)
            return
        }
    }
    
    private func removeAllTempFile() {
        
        do {
            let tempDirectoryPath = NSTemporaryDirectory()
            // 获取 temp 目录下的所有文件
            let fileURLs = try FileManager.default.contentsOfDirectory(atPath: tempDirectoryPath)
                
            // 遍历所有文件，逐个删除
            for fileURL in fileURLs {
                let filePath = tempDirectoryPath + fileURL
                try FileManager.default.removeItem(atPath: filePath)
            }
            print("All files in the temp directory have been deleted.")
        } catch {
            print("Error while deleting temp directory contents: \(error)")
        }
    }
    
//    private func getVideoData(from asset: PHAsset) {
//        print("getVideoData")
//        let resourceOptions = PHAssetResourceRequestOptions()
//        resourceOptions.isNetworkAccessAllowed = true
//
//        guard let assetResource = PHAssetResource.assetResources(for: asset).first else {
//            print("无法获取资源")
//            return
//        }
//
//        // 获取文件扩展名
//        let fileExtension = UTType(filenameExtension: assetResource.uniformTypeIdentifier)?.preferredFilenameExtension ?? "mov"
//
//        let tempDirectory = FileManager.default.temporaryDirectory
//        let outputURL = tempDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension(fileExtension)
//
//        FileManager.default.createFile(atPath: outputURL.path, contents: nil, attributes: nil)
//
//        do {
//            let fileHandle = try FileHandle(forWritingTo: outputURL)
//
//            PHAssetResourceManager.default().requestData(for: assetResource, options: resourceOptions) { data in
//                // 数据处理 写入临时文件后获取URL
//                fileHandle.write(data)
//            } completionHandler: { [weak self] error in
//
//                print("-----完成一次----")
//
//                fileHandle.closeFile()
//
//                if let errors = error {
//                    print("请求数据失败: \(errors.localizedDescription)")
//                } else {
//                    DispatchQueue.main.async {
//                        let creationDate = asset.creationDate
//                        let duration = asset.duration
//
//                        let videoInfo = VideoInfo1(asset: asset, url: outputURL, creationDate: creationDate, duration: duration)
//                        self?.videos.append(videoInfo)
//
//                        print("videos count:\(self?.videos.count)")
//
//                        if self?.videos.count == self?.totalVideoCount {
//                            self?.status = true
//                        }
//                    }
//                }
//            }
//        } catch {
//            print("数据写入失败: \(error.localizedDescription)")
//            return
//        }
//    }
}
