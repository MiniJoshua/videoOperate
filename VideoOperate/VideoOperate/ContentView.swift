//
//  ContentView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/10.
//

import SwiftUI

class VideoSelected: ObservableObject {

}

struct ContentView: View {
    
    @StateObject private var videoLibrary = VideoLibrary()
    
    @State private var videoToggleStates: [Bool]
    @State private var audioToggleStates: [Bool]
    
    init() {
        _videoToggleStates = State(initialValue: Array(repeating: false, count: 6))
        _audioToggleStates = State(initialValue: Array(repeating: false, count: 6))
    }
    
    @StateObject var selectedVideo  = VideoSelected()

    
    var body: some View {
//        NavigationView {
            List {
                Section{
                    ForEach(0 ..< videoToggleStates.count, id: \.self){ index in
                        
                        VideoItemRow(videoIsOn: videoToggleStates[index], videoToggleChanged: { newValue in
                            updateVideoToggleStates(index: index, newValue: newValue)
                        }, audioIsOn: audioToggleStates[index]) { newValue in
                            updateAudioToggleStates(index: index, newValue: newValue)
                        }
                    }
                }
            }
//            .navigationTitle("本地")
//            .navigationBarTitleDisplayMode(.inline)
//        }
        .onAppear{
            loadVideoItems()
        }
    }
    
    private func updateVideoToggleStates(index: Int, newValue: Bool) {
        videoToggleStates.append(false)
        for i in 0..<videoToggleStates.count {
            videoToggleStates[i] = (i == index) ? newValue : false
            print(videoToggleStates)
        }
    }
    
    private func updateAudioToggleStates(index: Int, newValue: Bool) {
        
        for i in 0..<audioToggleStates.count {
            audioToggleStates[i] = (i == index) ? newValue : false
        }
    }
    
    private func loadVideoItems() {
        
        
        
    }
}

