//
//  CutLocalVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/7/3.
//

import SwiftUI

struct WidthPreferenceKey: PreferenceKey {
    typealias Value = CGFloat
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CutLocalVideoView: View {
    @EnvironmentObject var localVideoLibrary: LocalVideoLibrary
    
    @State private var navigationActive = false
    @State private var cutFilePath: String?

    var body: some View {
        List {
            ForEach(localVideoLibrary.localVideos) { value in
                CutListRowView(videoInfo: value, navigationActive: $navigationActive, cutFilePath: $cutFilePath)
                    .buttonStyle(PlainButtonStyle())
            }
        }.background(
            NavigationLink(destination: VideoPlayerView(filePath: cutFilePath), isActive: $navigationActive) {
                EmptyView()
            }
        )
    }
}

struct CutListRowView: View {
    var videoInfo: LocalVideoInfo

    @State private var imageWidth: CGFloat = 0
    
    @State private var startTime: Double = 0
    @State private var endTime: Double = 0
    
    @State private var showAlert = false
    
    @Binding var navigationActive: Bool
    @Binding var cutFilePath: String?
    
    var body: some View {
        HStack {
            ZStack {
                Image(uiImage: videoInfo.thumbnail!)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .frame(width: 50, height: 70)
                    .clipped()
                    .background(
                        GeometryReader(content: { imageGermetry in
                            Color.clear
                                .preference(key: WidthPreferenceKey.self, value: imageGermetry.size.width)
                        }))
                VStack {
                    Spacer()
                    Text("\(Int(round(videoInfo.duration)))秒")
                        .font(.system(size: 12))
                        .foregroundColor(.black)
                        .frame(width: imageWidth)
                        .background(Color.white.opacity(0.5))
                }
            }.onPreferenceChange(WidthPreferenceKey.self) { width in
                self.imageWidth = width
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
                    VideoTools.cutVideo(withFilePath: videoInfo.filePath ?? "", start: Int32(startTime), end: Int32(endTime)) { success, filePath in
                        if success {
                            cutFilePath = filePath
                            navigationActive = true
                        }
                    }
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
}
