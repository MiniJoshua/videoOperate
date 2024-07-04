//
//  CutVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/7/3.
//

import SwiftUI

struct CutVideoView: View {
    var body: some View {
        TabView {
            
            CutLocalVideoView()
                .tabItem {
                    Label("本地", systemImage: "plus.viewfinder")
                }
            
            CutPhotoVideoView()
                .tabItem {
                    Label("相册", systemImage: "photo")
                }
        }
        .navigationTitle("裁剪")
    }
}

