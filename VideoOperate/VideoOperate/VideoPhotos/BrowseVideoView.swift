//
//  BrowseVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/26.
//

import SwiftUI

struct BrowseVideoView: View {
    var body: some View {
        TabView {
            
            BrowseLocalVideoView()
                .tabItem {
                    Label("本地", systemImage: "plus.viewfinder")
                }
            
            BrowsePhotoVideoView()
                .tabItem {
                    Label("相册", systemImage: "photo")
                }
        }
        .navigationTitle("本地")
    }
}

