//
//  ExtractAVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/7/29.
//

import SwiftUI

/**
 
 提取视频/音频都会被存为mp4格式的文件
 
 */

struct ExtractAVideoView: View {
    var body: some View {
        TabView {
            
            ExtractAVideoLocalView()
                .tabItem {
                    Label("本地", systemImage: "plus.viewfinder")
                }
            
            ExtractAVideoPhotoView()
                .tabItem {
                    Label("相册", systemImage: "photo")
                }
        }
        .navigationTitle("提取音视频")
    }
}

