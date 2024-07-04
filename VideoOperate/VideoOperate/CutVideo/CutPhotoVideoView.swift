//
//  CutPhotoVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/7/3.
//

import Combine
import Photos
import SwiftUI

struct CutPhotoVideoView: View {
    @StateObject private var videoLibrary = VideoLibrary()
    @State private var authorizationStatus = PHAuthorizationStatus.notDetermined
    
    @State private var cancellabel: AnyCancellable?
    
    @State private var cutVideoFile: String?
    @State private var navigationActive = false
    @State private var isLoading = false

    
    var body: some View {
        ZStack {
            if videoLibrary.status {
                List {
                    ForEach(videoLibrary.photoVideos) { value in

                        CutListPhotoRowView(videoLibrary: videoLibrary,
                                            videoInfo: value,
                                            navigationActive: $navigationActive,
                                            cutFilePath: $cutVideoFile,
                                            loading: $isLoading)
                        .buttonStyle(PlainButtonStyle())
                            
                        
                    }
                }.background(
                    NavigationLink(destination: VideoPlayerView(filePath: self.cutVideoFile), isActive: self.$navigationActive) {
                        EmptyView()
                    }
                )
            } else {
                Text("相册视频读取中")
                    .padding()
            }
            
            if self.isLoading {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack {
                    LoadingView()
                    Text("视频处理中...")
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
                        
                        self.cancellabel = self.videoLibrary.$status
                            .compactMap { $0 }
                            .sink(receiveValue: { status in
                                if status {}
                            })
                    }
                }
            }
        }
    }
}


struct CutListPhotoRowView: View {
    var videoLibrary: VideoLibrary
    var videoInfo: PhotoVideoInfo
    
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    
    @State private var showAlert = false
    
    @Binding var navigationActive: Bool
    @Binding var cutFilePath: String?
    @Binding var loading: Bool
    
    var body: some View {
        HStack {
            ZStack {
                Image(uiImage: videoInfo.thumbnail!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .frame(width: 50, height: 70)
                    .clipped()

                VStack {
                    Spacer()
                    Text("\(Int(round(videoInfo.duration)))秒")
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                        .frame(width: 50)
                        .background(Color.white.opacity(0.5))
                }
            }
            
            VStack {
                HStack {
                    Text("起:\(Int(round(startTime)))")
                        .font(.body)
                    Slider(value: $startTime, in: 1 ... Double(round(videoInfo.duration)), step: 1) { isEditing in
                        if !isEditing {}
                    }
                }
                
                Spacer()
                
                HStack {
                    Text("结:\(Int(round(endTime)))")
                        .font(.body)
                    Slider(value: $endTime, in: 1 ... Double(round(videoInfo.duration)), step: 1) { isEditing in
                        if !isEditing {}
                    }
                }
            }
            
            Spacer()
            
            Button {
                if startTime < endTime {
                    videoCut(videoInfo.id)
                } else {
                    showAlert = true
                }
            } label: {
                Text("裁剪")
                    .font(.system(size: 12))
                    .padding()
                    .background(Color.gray)
            }
            .contentShape(Rectangle())
            
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("提示"),
                message: Text("起始时间不能大于等于结束时间"),
                dismissButton: .default(Text("确定"))
            )
        }
        .onAppear{
            endTime = Double(round(videoInfo.duration))
        }
    }
    
    private func videoCut(_ id: String) {
        DispatchQueue.main.async {
            loading = true
        }
        
        DispatchQueue.global().async {
            self.videoLibrary.savePhotoVideoToTempDirectory(withID: id) { fileURL, success in
                if success {
                    VideoTools.cutVideo(withFilePath: fileURL?.path ?? "", start: Int32(startTime), end: Int32(endTime)) { success, filePath in
                        if success {
                            DispatchQueue.main.async {
                                cutFilePath = filePath
                                navigationActive = true
                                loading = false
                            }
                        }
                    }
                }
            }
        }
    }
}
