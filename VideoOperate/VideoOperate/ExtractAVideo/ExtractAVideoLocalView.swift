//
//  ExtractAVideoLocalView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/8/4.
//

import SwiftUI

struct ExtractAVideoLocalView: View {
    
    @EnvironmentObject var localVideoLibrary: LocalVideoLibrary
    
    @State private var videoToggleStates = [Bool]()
    @State private var audioToggleStates = [Bool]()
    
    @State private var currentVideo: LocalVideoInfo?
    
    @State private var videoFileURL: URL?
    @State private var extractFilePath = ""
    
    @State private var navigationActive = false
    @State private var isInitialized = false
    @State private var isOutVideo = false
    @State private var isLoading = false
    
    @State private var videoStatus = true
    
    var body: some View {
        ZStack {
            VStack {
                List{
                    if isInitialized {
                        
                        ForEach(localVideoLibrary.localVideos.indices, id: \.self) { index in
                            
                            let value = localVideoLibrary.localVideos[index]
                            
                            ExtractAVideoItemView(thumbnail: value.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newvalue in
                                updateVideoToggleStates(index: index, newValue: newvalue)
                            }, audioIsOn: audioToggleStates[index]) { newValue in
                                updateAudioToggleStates(index: index, newValue: newValue)
                            }
                            
                        }
                    }
                }
                
                Button {
                    guard self.currentVideo != nil else {return}
                    
                    DispatchQueue.main.async {
                        isLoading = true
                    }
                    
                    DispatchQueue.global().async {
                        
                        VideoTools.extractFilePath(currentVideo?.filePath ?? "", videoStatus: videoStatus) { success, filePath in
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
                    
                }label: {
                    Text("提取")
                        .padding()
                        .frame(width: 200)
                        .foregroundColor(.white)
                        .background(RoundedRectangle(cornerRadius: 10))
                        .font(.body)
                }
                .frame(width: 200, height: 55)
                
                NavigationLink(destination: VideoPlayerView(filePath: extractFilePath), isActive: $navigationActive) {
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
        .onAppear{
            self.initalizeData()
        }
    }
    
    private func initalizeData() {
        
        guard !isInitialized else {return}
        
        videoToggleStates = Array(repeating: false, count: localVideoLibrary.localVideos.count)
        audioToggleStates = Array(repeating: false, count: localVideoLibrary.localVideos.count)
        
        isInitialized = true
        
    }
    
    private func updateVideoToggleStates(index: Int, newValue: Bool) {
        
        if newValue {
            currentVideo = localVideoLibrary.localVideos[index]
            videoStatus = true
        }else {
            currentVideo = nil
        }
        
        for i in 0..<videoToggleStates.count {
            videoToggleStates[i] = (i == index) ? newValue : false
            audioToggleStates[i] = false
        }
    }
    
    private func updateAudioToggleStates(index: Int, newValue: Bool) {
        
        if newValue {
            currentVideo = localVideoLibrary.localVideos[index]
            videoStatus = false
        }else {
            currentVideo = nil
        }
        
        for i in 0..<audioToggleStates.count {
            
            audioToggleStates[i] = (i == index) ? newValue : false
            videoToggleStates[i] = false
        }
    }
}

//MARK: - Item view
struct ExtractAVideoItemView: View {
    
    var thumbnail: UIImage?
    var index: Int
    
    var videoIsOn: Bool
    var videoToggleChanged: (Bool) -> Void
    
    var audioIsOn: Bool
    var audioToggleChanged: (Bool) -> Void
    
    
    var body: some View {
        
        let videoBinding = Binding<Bool> {
            self.videoIsOn
        } set: { newValue in
            self.videoToggleChanged(newValue)
        }
        
        let audioBinding = Binding<Bool> {
            self.audioIsOn
        } set: {
            self.audioToggleChanged($0)
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
            
            Spacer().frame(width: 50)
            
            VStack {
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
        
    }
    
    func toggleChanged(_ newValue: Bool, _ isVideo: Bool) {
        
        if newValue && isVideo {
            //选择了视频
            
        }else if newValue && !isVideo {
            //选择了音频
        }
    }
}
