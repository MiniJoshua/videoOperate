//
//  MergeAudioVideoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/20.
//

import SwiftUI

struct MergeAudioVideoView: View {
    var body: some View {
        
        TabView {
            
            MergeLocalVideoView()
                .tabItem {
                    Label("本地", systemImage: "plus.viewfinder")
                }
            
            MergePhotoVideoView()
                .tabItem {
                    Label("相册", systemImage: "photo")
                }
        }
        .navigationTitle("本地")
//        .navigationBarTitleDisplayMode(.inline)
        
    }
}

struct MergeAudioVideoView_Previews: PreviewProvider {
    static var previews: some View {
        MergeAudioVideoView()
    }
}
