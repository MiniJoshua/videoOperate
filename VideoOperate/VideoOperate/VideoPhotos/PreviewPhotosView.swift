//
//  BrowsePhotosView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/26.
//

import SwiftUI

struct PreviewPhotosView: View {
    var videoFilePath: String
    
    @State private var photos: [UIImage] = []
    @State private var count: Double = 9
    
    let columns = [
        GridItem(.fixed(100)),
        GridItem(.fixed(100)),
        GridItem(.fixed(100)),
    ]
    
    private let videoQualitys = ["Low", "Medium", "High"]
    @State private var quality = 1
    
    @State private var isLoading = true
    @State private var selectedIndex: Int = 0
    @State private var navigationActive = false
    
    var body: some View {
        ZStack {
            VStack {
                ScrollView {
                    LazyVGrid(columns: columns, spacing: 20) {
                        ForEach(photos.indices, id: \.self) { index in
                            
                            let img = photos[index]
                            
                            Button {
                                selectedIndex = index
                                navigationActive = true
                                print("点击的Index:\(index)")
                            } label: {
                                Image(uiImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    
                            }
                            .background(
                                NavigationLink(destination: BrowsePhotosView(photos: photos, currentPage: $selectedIndex), isActive: $navigationActive, label: {
                                    EmptyView()
                                })
                            )
                        }
                    }
                    .padding(.horizontal)
                }

                
                Spacer()
                
                HStack {
                    Spacer().frame(width: 10)
                    Text("质量:")
                        .font(.body)
                    
                    Picker("quality:", selection: $quality) {
                        ForEach(videoQualitys.indices, id: \.self) { index in
                            Text("\(videoQualitys[index])").tag(index)
                        }
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: quality) { _ in
                        self.updatePhotos(count)
                    }
                    Spacer().frame(width: 10)
                }
                .padding()
                
                Text("\(Int(count))张")
                    .font(.body)
                Slider(value: $count, in: 1 ... 90, step: 1) { isEditing in
                    if !isEditing {
                        self.updatePhotos(count)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.top, 5)
                .padding(.bottom, 20)
                
                //            Spacer().frame(height: 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            
            if isLoading {
                Color.black.opacity(0.6)
                    .ignoresSafeArea()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                VStack {
//                    ProgressView("处理中...")
//                        .progressViewStyle(CircularProgressViewStyle())
//                        .tint(.gray)
//                        .padding()
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
            
            if photos.count == 0 {
                self.updatePhotos(count)
            }
        }
        .navigationTitle("视频图片")
    }
    
    private func updatePhotos(_ count: Double) {
        DispatchQueue.main.async {
            isLoading = true
        }
        
        var videoQuality = EnumVideoImageQuality.high

        if quality == 0 {
            videoQuality = EnumVideoImageQuality.low
        } else if quality == 1 {
            videoQuality = EnumVideoImageQuality.medium
        }

        DispatchQueue.global().async {
            let imgs = VideoTools.images(withVideoFilePath: videoFilePath, count: Int64(count), quality: videoQuality)
            
            DispatchQueue.main.async {
                photos.removeAll()
                for img in imgs {
                    photos.append(img)
                }
                isLoading = false
            }
        }
    }
}
