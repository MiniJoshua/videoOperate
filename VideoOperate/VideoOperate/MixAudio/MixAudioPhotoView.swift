//
//  MixAudioPhotoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/7/24.
//

import Combine
import Photos
import SwiftUI

struct MixAudioPhotoView: View {
    @StateObject private var videoLibrary = VideoLibrary()
    @State private var authorizationStatus = PHAuthorizationStatus.notDetermined
    
    @State private var videoToggleStates = [Bool]()
    @State private var audioToggleStates = [Bool]()
    @State private var volumeValues = [Float]()
    
    @State private var currentVideo: PhotoVideoInfo?
    @State private var currentAudio: PhotoVideoInfo?
    
    @State private var cancelAble: AnyCancellable?
    
    @State private var videoFileURL: URL?
    @State private var audioFileURL: URL?
    @State private var mixFilePath = ""
    
    @State private var videoCopyStatus = false
    @State private var audioCopyStatus = false
    @State private var volume1: Float = 0.0
    @State private var volume2: Float = 0.0
    @State private var videoIndex = 0
    @State private var audioIndex = 0
    
    @State private var navigationActive = false
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            VStack {
                if videoLibrary.status {
                    List {
                        ForEach(videoLibrary.photoVideos.indices, id: \.self) { index in
                            
                            var photoVideoInfo = videoLibrary.photoVideos[index]
                            
                            
                            MixAudioItemView(thumbnail: photoVideoInfo.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
                                self.updateVideoToggleStates(index: index, newValue: newValue)
                            }, audioIsOn: audioToggleStates[index], audioToggleChanged: { newValue in
                                self.updateAudioToggleStates(index: index, newValue: newValue)
                            }, volume: volumeValues[index]) { volume in
                                self.updateVolumeValue(index: index, newValue: volume)
                            }.frame(height: 77)
                            
//                            MixAudioItemView(thumbnail: photoVideoInfo.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
//                                self.updateVideoToggleStates(index: index, newValue: newValue)
//                            }, audioIsOn: audioToggleStates[index], audioToggleChanged: { newValue in
//                                self.updateAudioToggleStates(index: index, newValue: newValue)
//                            }, vol1: $volume1, vol2: $volume2)
//                                .frame(height: 77)
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
                                self.mixAudio()
                            } else {
                                print("从相册拷贝选择的视频文件失败")
                            }
                        }
                        
                        self.videoLibrary.savePhotoVideoToTempDirectory(withID: self.currentAudio?.id ?? "") { fileURL, success in
                            
                            if success {
                                print("从相册拷贝选择的音频文件成功")
                                self.audioCopyStatus = true
                                self.audioFileURL = fileURL
                                self.mixAudio()
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
                    .frame(width: 200, height: 55.0)
                    
                    NavigationLink(destination: VideoPlayerView(filePath: mixFilePath), isActive: $navigationActive) {
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
        volumeValues = Array(repeating: 1.0, count: videoLibrary.photoVideos.count)
    }
    
    private func updateVideoToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentVideo = videoLibrary.photoVideos[index]
            videoIndex = index
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
            audioIndex = index
        } else {
            currentAudio = nil
        }
        
        for i in 0..<audioToggleStates.count {
            audioToggleStates[i] = (i == index) ? newValue : false
        }
    }
    
    private func videoVolumeValue() -> CGFloat {
        let formattedString = String(format: "%.1f", volumeValues[videoIndex])
        if let floatRoundedValue = Float(formattedString) {
            let cgFloatValue = CGFloat(floatRoundedValue)
            return cgFloatValue
        }
        return 1.0
    }
    
    private func audioVolumeValue() -> CGFloat {
        let formattedString = String(format: "%.1f", volumeValues[audioIndex])
        if let floatRoundedValue = Float(formattedString) {
            let cgFloatValue = CGFloat(floatRoundedValue)
            return cgFloatValue
        }
        return 1.0
    }
    
    private func updateVolumeValue(index: Int, newValue: Float) {
        
        print("volume:%f",newValue)
        volumeValues[index] = newValue
    }
    
    private func mixAudio() {
        if self.videoCopyStatus && self.audioCopyStatus {
            
            DispatchQueue.main.async {
                isLoading = true
            }
            
            DispatchQueue.global().async {
                VideoTools.mergeAudio(withVideoFilePath: self.videoFileURL?.path ?? "", audioFilePath: self.audioFileURL?.path ?? "", volume1: self.videoVolumeValue(), volume2: self.audioVolumeValue()) { success, filePath in
                    if success {
                        DispatchQueue.main.async {
                            print("音频合并完成")
                            isLoading = false
                            mixFilePath = filePath
                            navigationActive = true
                        }
                    }
                }
            }
        }
    }
}
