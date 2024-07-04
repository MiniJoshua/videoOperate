//
//  MainView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/11.
//

import SwiftUI

struct MainView: View {
    // TODO: 多音频混声 提取视频 提取音频 图片合成视频 添加水印 ...
    @State private var listContents: Array = ["音视频合并", "视频浏览图", "视频裁剪"]
    @StateObject var localVideoLibrary: LocalVideoLibrary = .init()

    var body: some View {
        NavigationView {
            List {
                Section {
                    ForEach(listContents.indices, id: \.self) { index in
                        NavigationLink {
                            if index == 0 {
                                MergeAudioVideoView()
                            } else if index == 1 {
                                BrowseVideoView()
                            } else if index == 2 {
                                CutVideoView()
                            }

                        } label: {
                            Text(listContents[index])
                                .font(.body)
                                .padding()
                        }
                    }
                }
            }
            .navigationTitle("首页")
            .navigationBarTitleDisplayMode(.inline)
        }
        .environmentObject(localVideoLibrary)

//            TabView {
//
//                ContentView()
//                    .tabItem {
//                        Label("本地", systemImage: "plus.viewfinder")
//                    }
//
//                PhotoVideoView()
//                    .tabItem {
//                        Label("相册", systemImage: "photo")
//                    }
//
//                ResultView()
//                    .tabItem {
//                        Label("输出", systemImage: "play.house.fill")
//                    }
//
//                SaveVideoView()
//                    .tabItem {
//                        Label("测试", systemImage: "photo")
//                    }
//            }
//        }

//            TabView {
//                NavigationView {
//                    ContentView()
//                }
//                    .tabItem {
//                        Label("本地", systemImage: "plus.viewfinder")
//                    }
//
//                NavigationView {
//                    PhotoVideoView()
//                }
//                    .tabItem {
//                        Label("相册", systemImage: "photo")
//                    }
//
//                NavigationView {
//                    ResultView()
//                }
//                    .tabItem {
//                        Label("输出", systemImage: "play.house.fill")
//                    }
//                NavigationView {
//                    SaveVideoView()
//                }
//                    .tabItem {
//                        Label("测试", systemImage: "photo")
//                    }
//            }
    }
}
