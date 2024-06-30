//
//  SaveVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/11.
//

import SwiftUI
import Photos

struct SaveVideoView: View {
    
    @State private var isVideoSaved = false
    
    @State private var isNavigationActive = false
    
    @State private var mergeFilePath = ""
    
    var body: some View {
        VStack {
            if isVideoSaved {
                Text("视频已经保存到相册")
            } else {
                Text("点击按钮保存视频到相册")
            }
            
            Button {
                
//                let objCInstance = MergeAVideo()
//                objCInstance.mergeFilePath(Bundle.main.path(forResource: "99", ofType: "mp4")!, audioFilePath: Bundle.main.path(forResource: "1999", ofType: "mp4")!)
//                objCInstance.megreVideoComplete { filePath, status in
//                    if status {
//                            print("视频合并完成")
//                            mergeFilePath = filePath
//                            isNavigationActive = true
//                    }
//                }
                
//                objCInstanc
//                saveVideoAlbum(videoURL: URL(filePath: Bundle.main.path(forResource: "1999", ofType: "mp4")!))
            } label: {
                Text("保存视频")
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
            }
            
//            NavigationLink(destination:VideoPlayerView(filePath: mergeFilePath), isActive: $isNavigationActive, label: {
//                EmptyView()
//            })

        }
        .padding()
    }
    
    func saveVideoAlbum(videoURL: URL) {
        PHPhotoLibrary.requestAuthorization { status in
            
            if status == .authorized {
                PHPhotoLibrary.shared().performChanges {
                    
                    let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
                    request?.creationDate = Date()
                    
                } completionHandler: { success, error in
                    
                    DispatchQueue.main.async {
                        if success {
                            self.isVideoSaved = true
                        } else {
                            print("视频保存失败: \(String(describing: error))")
                        }
                    }
                }

            } else {
                print("用户未授权访问相册")
            }
        }
    }
}

