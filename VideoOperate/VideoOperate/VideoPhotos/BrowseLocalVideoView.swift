//
//  BrowseLocalPhotoView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/26.
//

import SwiftUI

struct BrowseLocalVideoView: View {
    
    @EnvironmentObject var localVideoLibrary: LocalVideoLibrary
    
    var body: some View {
        List {
            ForEach(localVideoLibrary.localVideos) { value in
                
                NavigationLink {
                    PreviewPhotosView(videoFilePath: value.filePath!)
                } label: {
                    HStack {
                        Image(uiImage: value.thumbnail!)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .padding(.leading, 5)
                            .frame(width: 100 ,height: 60)
                        
                        Text("\(Int(round(value.duration))) 秒")
                            .font(.body)
                            .foregroundColor(.black)
                    }
                }

            }
        }
    }
}

