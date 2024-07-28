//
//  MixAudioLocalView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/7/24.
//

import SwiftUI

struct MixAudioLocalView: View {
    @EnvironmentObject var localVideoLibrary: LocalVideoLibrary
    
    @State private var videoToggleStates = [Bool]()
    @State private var audioToggleStates = [Bool]()
    @State private var volumeValues = [Float]()
    
    // 会获取第一个视频中的音频流
    @State private var currentVideo: LocalVideoInfo?
    @State private var currentAudio: LocalVideoInfo?
    
    @State private var videoFileURL: URL?
    @State private var audioFileURL: URL?
    @State private var mergeFilePath = ""
    
    @State private var navigationActive = false
    @State private var isInitialized = false
    @State private var isOutVideo = false
    @State private var isLoading = false
    
    @State private var videoIndex = 0
    @State private var audioIndex = 0
    @State private var volume1: Float = 0.0
    @State private var volume2: Float = 0.0
    
    var body: some View {
        ZStack {
            VStack {
                List {
                    if isInitialized {
                        ForEach(localVideoLibrary.localVideos.indices, id: \.self) { index in
                            
                            let value = localVideoLibrary.localVideos[index]
                            
//                            MixAudioItemView(thumbnail: value.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
//                                // 更新video的值
//                                self.updateVideoToggleStates(index: index, newValue: newValue)
//                            }, audioIsOn: audioToggleStates[index],audioToggleChanged:{ newValue in
//                                // 更新audio的值
//                                self.updateAudioToggleStates(index: index, newValue: newValue)
//                            }, volume: volumeValues[index]) { volume in
//                                //
//                                self.updateVolumeValue(index: index, newValue: volume)
//                            }
//                            .frame(height: 77)
                            
                            MixAudioItemView(thumbnail: value.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
                                self.updateVideoToggleStates(index: index, newValue: newValue)
                            }, audioIsOn: audioToggleStates[index], audioToggleChanged: { newValue in
                                self.updateAudioToggleStates(index: index, newValue: newValue)
                            }, volume: volumeValues[index]) { volume in
                                self.updateVolumeValue(index: index, newValue: volume)
                            }.frame(height: 77)
                        }
                    }
                }
                
                Button {
                    guard self.currentVideo != nil else {
                        print("还没选择视频")
                        return
                    }
                    
                    guard self.currentAudio != nil else {
                        print("还没选择音频")
                        return
                    }
                    
                    DispatchQueue.main.async {
                        isLoading = true
                    }
                    
                    DispatchQueue.global().async {
                        VideoTools.mergeAudio(withVideoFilePath: currentVideo?.filePath ?? "", audioFilePath: currentAudio?.filePath ?? "", volume1: self.videoVolumeValue(), volume2: self.audioVolumeValue()) { success, filePath in
                            if success {
                                DispatchQueue.main.async {
                                    print("音频合并完成")
                                    isLoading = false
                                    mergeFilePath = filePath
                                    navigationActive = true
                                }
                            }
                        }
                    }
                    
                } label: {
                    Text("混合")
                        .padding()
                        .frame(width: 200)
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 10))
                        .font(.body)
                }
                .frame(width: 200, height: 55)
                
                NavigationLink(destination: VideoPlayerView(filePath: mergeFilePath), isActive: $navigationActive) {
                    EmptyView()
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
            self.initalizeData()
        }
    }
    
    private func initalizeData() {
        // videoLibrary.localVideos.count
        guard !isInitialized else { return }
        videoToggleStates = Array(repeating: false, count: localVideoLibrary.localVideos.count)
        audioToggleStates = Array(repeating: false, count: localVideoLibrary.localVideos.count)
        volumeValues = Array(repeating: 1.0, count: localVideoLibrary.localVideos.count)
        
        isInitialized = true
    }
    
    private func updateVideoToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentVideo = localVideoLibrary.localVideos[index]
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
            currentAudio = localVideoLibrary.localVideos[index]
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
//        if newValue {
//            currentAudio = localVideoLibrary.localVideos[index]
//        } else {
//            currentAudio = nil
//        }
//
//        for i in 0..<audioToggleStates.count {
//            audioToggleStates[i] = (i == index) ? newValue : false
//        }
    }
}

struct MixAudioItemView: View {
    var thumbnail: UIImage?
    var index: Int
    
    var videoIsOn: Bool
    var videoToggleChanged: (Bool) -> Void
    
    var audioIsOn: Bool
    var audioToggleChanged: (Bool) -> Void

    var volume: Float
    
    var volumeValueChanged: (Float) -> Void
    
    var body: some View {
        let videoBinding = Binding<Bool> {
            self.videoIsOn
        } set: {
            self.videoToggleChanged($0)
        }
        
        let audioBinding = Binding<Bool> {
            self.audioIsOn
        } set: {
            self.audioToggleChanged($0)
        }
        
        let volumeBinding = Binding<Float> {
            self.volume
        } set: {
            self.volumeValueChanged($0)
        }
        
        HStack {
            if let thumbnail = thumbnail {
                Image(uiImage: thumbnail)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 66, height: 66)
                
            } else {
                Color.purple
                    .frame(width: 66, height: 66)
            }
            
            Spacer()
            
            VStack {
                HStack {
                    Toggle("视频", isOn: videoBinding)
                        .onChange(of: videoIsOn) { newValue in
                            toggleChanged(newValue, true)
                        }
                        .font(.system(size: 13))
                    
                    Toggle("音频", isOn: audioBinding)
                        .onChange(of: audioIsOn) { newValue in
                            toggleChanged(newValue, false)
                        }.font(.system(size: 13))
                }
                
                Spacer()
                
                HStack {
                    Text(String(format: "音量:%.1f", volume))
                        .font(.system(size: 15))
                    Slider(value: volumeBinding, in: 0 ... 1, step: 0.1) { isEditing in
                        if !isEditing {
                            
//                            print("Volume: \(volumeBinding)")
                        }
                    }
                }
            }
        }
    }
    
    func toggleChanged(_ newValue: Bool, _ isVideo: Bool) {
        if newValue && isVideo {
            // 记录选择的视频
                
        } else if newValue && !isVideo {
            // 记录选择的音频
        }
    }
}
