//
//  BrowsePhotoVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/26.
//

import Combine
import Photos
import SwiftUI

struct BrowsePhotoVideoView: View {
    @StateObject private var videoLibrary = VideoLibrary()
    @State private var authorizationStatus = PHAuthorizationStatus.notDetermined
    
    @State private var cancellabel: AnyCancellable?
    
    @State private var videoFile: String = ""
    
    @State private var navigationActive = false
    
    @State private var isLoading = false
    
    var body: some View {
        ZStack {
            if videoLibrary.status {
                List {
                    ForEach(self.videoLibrary.photoVideos) { value in
                        
                        Button {
                            self.videoSelected(value.id)
                        } label: {
                            HStack {
                                Image(uiImage: value.thumbnail!)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .padding(.leading, 5)
                                    .frame(width: 100, height: 60)
                                    
                                Text("\(Int(round(value.duration))) 秒")
                                    .font(.body)
                                    .foregroundColor(.black)
                            }
                        }
                    }
                }
                
                NavigationLink(destination: PreviewPhotosView(videoFilePath: self.videoFile), isActive: self.$navigationActive) {
                    EmptyView()
                }
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
                    Text("拷贝视频中...")
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
                            if status {}
                        })
                }
            }
        }
    }
    
    private func videoSelected(_ id: String) {
        DispatchQueue.main.async {
            isLoading = true
        }
        
        DispatchQueue.global().async {
            self.videoLibrary.savePhotoVideoToTempDirectory(withID: id) { fileURL, success in
                if success {
                    DispatchQueue.main.async {
                        videoFile = fileURL?.path ?? ""
                        navigationActive = true
                        isLoading = false
                    }
                }
            }
        }
    }
}
