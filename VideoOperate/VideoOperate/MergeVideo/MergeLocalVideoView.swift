//
//  LocalVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/23.
//

import SwiftUI

struct MergeLocalVideoView: View {
    @EnvironmentObject var videoLibrary: LocalVideoLibrary
    
    @State private var videoToggleStates = [Bool]()
    @State private var audioToggleStates = [Bool]()
    
    @State private var currentVideo: LocalVideoInfo?
    @State private var currentAudio: LocalVideoInfo?
    
    @State private var videoFileURL: URL?
    @State private var audioFileURL: URL?
    @State private var mergeFilePath = ""
    
    @State private var navigationActive = false
    @State private var isInitialized = false
    
    @State private var isLoading = false
    
    var body: some View {
        
        ZStack {
            
            VStack {
                List {
                    if isInitialized {
                        ForEach(videoLibrary.localVideos.indices, id: \.self) { index in
                            
                            let value = videoLibrary.localVideos[index]
                            
                            VideoThumbnailView(thumbnail: value.thumbnail, index: index, videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
                                self.updateVideoToggleStates(index: index, newValue: newValue)
                            }, audioIsOn: audioToggleStates[index]) { newValue in
                                self.updateAudioToggleStates(index: index, newValue: newValue)
                            }
                            .frame(height: 60)
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
                    
                    self.merge()
                    
                } label: {
                    Text("合并")
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
            self.initalizeData()
        }
    }

    private func initalizeData() {
        // videoLibrary.localVideos.count
        guard !isInitialized else { return }
        videoToggleStates = Array(repeating: false, count: videoLibrary.localVideos.count)
        audioToggleStates = Array(repeating: false, count: videoLibrary.localVideos.count)
        
        isInitialized = true
    }
    
    private func updateVideoToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentVideo = videoLibrary.localVideos[index]
        } else {
            currentVideo = nil
        }
        
        for i in 0..<videoToggleStates.count {
            videoToggleStates[i] = (i == index) ? newValue : false
        }
    }
    
    private func updateAudioToggleStates(index: Int, newValue: Bool) {
        if newValue {
            currentAudio = videoLibrary.localVideos[index]
        } else {
            currentAudio = nil
        }
        
        for i in 0..<audioToggleStates.count {
            audioToggleStates[i] = (i == index) ? newValue : false
        }
    }
    
    private func merge() {
        
        DispatchQueue.main.async {
            isLoading = true
        }
        
        let objCInstance = MergeAVideo()
        objCInstance.mergeFilePath(currentVideo?.filePath ?? "", audioFilePath: currentAudio?.filePath ?? "")
        
        DispatchQueue.global().async {
            
            objCInstance.megreVideoNeedDecoder(false) { filePath, status in
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

// struct LocalVideoView_Previews: PreviewProvider {
//    static var previews: some View {
//        MergeLocalVideoView()
//    }
// }
