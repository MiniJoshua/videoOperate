//
//  PhotoVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/11.
//

import Combine
import Photos
import SwiftUI

struct MergePhotoVideoView: View {
    @StateObject private var videoLibrary = VideoLibrary()
    @State private var authorizationStatus = PHAuthorizationStatus.notDetermined
    
    @State private var videoToggleStates = [Bool]()
    @State private var audioToggleStates = [Bool]()
    
    @State private var cancellabel: AnyCancellable?
    
    @State private var currentVideo: PhotoVideoInfo?
    @State private var currentAudio: PhotoVideoInfo?
    
    @State private var videoCopyStatus = false
    @State private var audioCopyStatus = false
    @State private var videoFileURL: URL? //= URL(string: "")
    @State private var audioFileURL: URL? // = URL(string: "")
    @State private var mergeFilePath = ""
    
    @State private var navigationActive = false
    
    @State private var isLoading = false
    
    var body: some View {
        
        ZStack {
            
            VStack {
                if videoLibrary.status {
                    
                    List {
                        ForEach(videoLibrary.photoVideos.indices, id: \.self) { index in
                            let value = videoLibrary.photoVideos[index]
                            
                            VideoThumbnailView(thumbnail: value.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
                                self.updateVideoToggleStates(index: index, newValue: newValue)
                            },
                                               audioIsOn: audioToggleStates[index], audioToggleChanged: { newValue in
                                self.updateAudioToggleStates(index: index, newValue: newValue)
                            })
                            .frame(height: 60)
                        }
                    }
                    
                    Button {
                        
                        DispatchQueue.main.async {
                            isLoading = true
                        }
                        
                        self.videoLibrary.savePhotoVideoToTempDirectory(withID: self.currentVideo?.id ?? "") { fileURL, success in
                            
                            if success {
                                print("从相册拷贝选择的视频文件成功")
                                self.videoCopyStatus = true
                                self.videoFileURL = fileURL
                                self.merge()
                            }else {
                                print("从相册拷贝选择的视频文件失败")
                            }
                        }
                        
                        self.videoLibrary.savePhotoVideoToTempDirectory(withID: self.currentAudio?.id ?? "") { fileURL, success in
                            
                            if success {
                                print("从相册拷贝选择的音频文件成功")
                                self.audioCopyStatus = true
                                self.audioFileURL = fileURL
                                self.merge()
                            } else {
                                print("从相册拷贝选择的音频文件失败")
                            }
                        }
                        
                    } label: {
                        Text("合并")
                            .padding()
                            .frame(width: 200)
                            .foregroundColor(.white)
                            .background(
                                RoundedRectangle(cornerRadius: 10)
                            )
                            .font(.body)
                        
                    }
                    .frame(width: 200,height: 55.0)
                    
                    NavigationLink(destination: VideoPlayerView(filePath: mergeFilePath), isActive: $navigationActive) {
                        EmptyView()
                    }
                    
                } else {
                    Text("相册视频读取中")
                        .padding()
                }
            }
            
            if isLoading {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack {
                    LoadingView()
                    Text ("处理中...")
                        .font(.body)
                }
                .foregroundColor(.black)
                .frame(width: 150, height: 150)
                .background(.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            
        }
        .onAppear {
            PhotoLibraryAccess.requestAuthorization { status in
                authorizationStatus = status
                
                if status == .authorized {
                    self.videoLibrary.fetchVideos()
                    
                    self.cancellabel = self.videoLibrary.$status
                        .compactMap { $0 }
                        .sink(receiveValue: { status in
                            if status {
                                self.initalizeData()
                            }
                        })
                }
            }
        }
    }
    
    private func initalizeData() {
        videoToggleStates = Array(repeating: false, count: videoLibrary.photoVideos.count)
        audioToggleStates = Array(repeating: false, count: videoLibrary.photoVideos.count)
    }
    
    private func updateVideoToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentVideo = videoLibrary.photoVideos[index]
        } else {
            currentVideo = nil
        }
        
        for i in 0..<videoToggleStates.count {
            videoToggleStates[i] = (i == index) ? newValue : false
        }
    }
    
    private func updateAudioToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentAudio = videoLibrary.photoVideos[index]
        } else {
            currentAudio = nil
        }
        
        for i in 0..<audioToggleStates.count {
            audioToggleStates[i] = (i == index) ? newValue : false
        }
    }
    
    func merge() {
        
        if self.videoCopyStatus && self.audioCopyStatus {
            
            let objCInstance = MergeAVideo()
            objCInstance.mergeFilePath(self.videoFileURL?.path ?? "", audioFilePath: self.audioFileURL?.path ?? "")
            
            DispatchQueue.global().async {
                
                objCInstance.megreVideoComplete { filePath, status in
                    if status {
                        DispatchQueue.main.async {
                            print("视频合并完成")
                            isLoading = false
                            mergeFilePath = filePath
                            navigationActive = true
                        }
                    }
                }
            }
        }
    }
}

struct VideoThumbnailView: View {
    var thumbnail: UIImage?
    var index: Int
    
    var videoIsOn: Bool
    var videoToggleChanged: (Bool) -> Void
    
    var audioIsOn: Bool
    var audioToggleChanged: (Bool) -> Void
    
    var body: some View {
        let videoBinding = Binding<Bool> {
            self.videoIsOn
        } set: {
            self.videoToggleChanged($0)
        }
        
        let audioBinding = Binding {
            self.audioIsOn
        } set: {
            self.audioToggleChanged($0)
        }
        
        HStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 66, height: 55)
            } else {
                Color.gray
                    .frame(width: 66, height: 55)
            }
            
            Spacer()
            
            Toggle("视频", isOn: videoBinding)
                .onChange(of: videoIsOn) { newValue in
                    toggleChanged(newValue, true)
                }
            
            Toggle("音频", isOn: audioBinding)
                .onChange(of: audioIsOn) { newValue in
                    toggleChanged(newValue, false)
                }
        }
    }

//    private func generateThumbnail() {
//
//        let manager = PHImageManager.default()
//        let options = PHImageRequestOptions()
//        options.isSynchronous = true
//
//        manager.requestImage(for: asset, targetSize: CGSize(width: 200, height: 200), contentMode: .aspectFill, options: options) { image, _ in
//            self.thumbnail = image
//        }
//    }
        
    func toggleChanged(_ newValue: Bool, _ isVideo: Bool) {
        if newValue && isVideo {
            // 记录选择的视频
                
        } else if newValue && !isVideo {
            // 记录选择的音频
        }
    }
}

// struct PhotoVidewoView_Previews: PreviewProvider {
//    static var previews: some View {
//        PhotoVideoView()
//    }
// }
