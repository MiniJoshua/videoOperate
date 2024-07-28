//
//  MixAudioView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/7/24.
//

import SwiftUI

struct MixAudioView: View {
    var body: some View {
       
        TabView {
            
            MixAudioLocalView()
                .tabItem {
                    Label("本地", systemImage: "plus.viewfinder")
                }
            
            MixAudioPhotoView()
                .tabItem {
                    Label("相册", systemImage: "photo")
                }
            
        }
        .navigationTitle("混合音频")
    }
}

