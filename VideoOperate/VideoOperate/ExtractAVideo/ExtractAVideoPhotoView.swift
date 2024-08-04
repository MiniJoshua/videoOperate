//
//  ExtractAVideoPhotoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/8/4.
//

import SwiftUI
import Photos
import Combine

struct ExtractAVideoPhotoView: View {
    
    @StateObject private var videoLibrary = VideoLibrary()
    @State private var authorizationStatus = PHAuthorizationStatus.notDetermined
    
    @State private var videoToggleStates = [Bool]()
    @State private var audioToggleStates = [Bool]()
    
    @State private var currentVideo: PhotoVideoInfo?
    
    @State private var cancelAble: AnyCancellable?
    
    @State private var videoFileURL: URL?
    @State private var extractFilePath = ""
    
    @State private var videoCopyStatus = false
    
    @State private var navigationActive = false
    @State private var isLoading = false
    
    @State private var isVideo = true
    
    var body: some View {
        ZStack {
            VStack {
                if videoLibrary.status {
                    List {
                        ForEach(videoLibrary.photoVideos.indices, id: \.self) { index in
                            
                            var photoVideoInfo = videoLibrary.photoVideos[index]

                            ExtractAVideoItemView(thumbnail: photoVideoInfo.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
                                updateVideoToggleStates(index: index, newValue: newValue)
                            }, audioIsOn: audioToggleStates[index]) { newValue in
                                updateAudioToggleStates(index: index, newValue: newValue)
                            }
                            .frame(height: 77)
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
                                self.extractVideo()
                            } else {
                                print("从相册拷贝选择的视频文件失败")
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
                    .frame(width: 200, height: 55.0)
                    
                    NavigationLink(destination: VideoPlayerView(filePath: extractFilePath), isActive: $navigationActive) {
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
                    Text("处理中...")
                        .font(.body)
                }
                .foregroundColor(.black)
                .frame(width: 150, height: 150)
                .background(.white.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
        }
        .onAppear {
            if videoLibrary.photoVideos.count == 0 {
                PhotoLibraryAccess.requestAuthorization { status in
                    authorizationStatus = status
                    
                    if status == .authorized {
                        self.videoLibrary.fetchVideos()
                        
                        self.cancelAble = self.videoLibrary.$status
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
    }
    
    private func initalizeData() {
        videoToggleStates = Array(repeating: false, count: videoLibrary.photoVideos.count)
        audioToggleStates = Array(repeating: false, count: videoLibrary.photoVideos.count)
    }
    
    private func updateVideoToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentVideo = videoLibrary.photoVideos[index]
            isVideo = true
        } else {
            currentVideo = nil
        }
        
        for i in 0..<videoToggleStates.count {
            videoToggleStates[i] = (i == index) ? newValue : false
            audioToggleStates[i] = false
        }
    }
    
    private func updateAudioToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentVideo = videoLibrary.photoVideos[index]
            isVideo = false
        } else {
            currentVideo = nil
        }
        
        for i in 0..<audioToggleStates.count {
            audioToggleStates[i] = (i == index) ? newValue : false
            videoToggleStates[i] = false
        }
    }
    
    
    private func extractVideo() {
        if self.videoCopyStatus {
            
            DispatchQueue.main.async {
                isLoading = true
            }
            
            DispatchQueue.global().async {
                
                VideoTools.extractFilePath(self.videoFileURL?.path ?? "", videoStatus: isVideo) { success, filePath in
                    if success {
                        DispatchQueue.main.async {
                            print("音频合并完成")
                            isLoading = false
                            extractFilePath = filePath
                            navigationActive = true
                        }
                    }
                }
            }
        }
    }
}
