//
//  VideoPlayerView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/12.
//

import SwiftUI
import AVKit

struct PlayerView: UIViewControllerRepresentable {

    typealias UIViewControllerType = AVPlayerViewController
    
    let player: AVPlayer
    
    func makeUIViewController(context: Context) -> AVPlayerViewController {
        let playerViewController = AVPlayerViewController()
        playerViewController.player = player
        return playerViewController
    }
    
    func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
        uiViewController.player = player
    }
    
    static func dismantleUIViewController(_ uiViewController: AVPlayerViewController, coordinator:()) {
        uiViewController.player = nil
    }
    
//    class Coordinator{}
//
//    func makeCoordinator() -> Coordinator {
//        return Coordinator()
//    }
}

struct VideoPlayerView: View {
    
    var filePath: String?
    
    var videoInfo: PhotoVideoInfo?
    
    @State private var showAlert = false
    
    
    var body: some View {
        VStack {
//            let videoURL = URL(filePath: Bundle.main.path(forResource: "1999", ofType: "mp4")!)
//            let videoURL = URL(string: "https://media.w3.org/2010/05/sintel/trailer.mp4")
//            URL(filePath: Bundle.main.path(forResource: "1999", ofType: "mp4")!
            
//            let videoURL = videoInfo?.url ?? URL(fileURLWithPath: Bundle.main.path(forResource: "1999", ofType: "mp4")!)
            let videoURL1 = URL(fileURLWithPath: filePath!)
            let player = AVPlayer(url: videoURL1)
            
            PlayerView(player:player)
                .onAppear{
                    player.play()
                }
                .frame(height:400)
        }
        .navigationTitle("视频播放")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            Button("保存") {
                SaveFileManager.saveVideoAlbum(videoURL: URL(fileURLWithPath: filePath ?? "")){ success in
                    if success {
                        showAlert = true
                    }
                }
            }
        }
        .alert(isPresented: $showAlert) {
            Alert(
                title: Text("提示"),
                message: Text("视频已保存到相册"),
                dismissButton: .default(Text("确定"))
            )
        }
    }
}

