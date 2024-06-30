//
//  LocalVideoLibrary.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/22.
//

import Foundation
import UIKit

struct LocalVideoInfo: Identifiable, Hashable {
    
    let id = UUID()
    let thumbnail: UIImage?
    let filePath: String?
    let duration: TimeInterval
    
    init(thumbnail: UIImage?, duration: TimeInterval, filePath: String) {
        self.thumbnail = thumbnail
        self.duration = duration
        self.filePath = filePath
    }
}

class LocalVideoLibrary: ObservableObject {
    @Published var localVideos: [LocalVideoInfo] = []
    
    init() {
        loadVideos()
    }
    
    func loadVideos() {
        
        let filePath1 = Bundle.main.path(forResource: "1999", ofType: "mp4")!
        let images1 = VideoTools.images(withVideoFilePath: filePath1, count: 1, quality: EnumVideoImageQuality.medium)
        let duration1 = VideoTools.duration(withFilePath: filePath1)
        if images1.count == 1 {
            let image = images1[0]
            let videoInfo = LocalVideoInfo(thumbnail: image, duration: duration1, filePath:filePath1)
            localVideos.append(videoInfo)
        }
        
        
        let filePath2 = Bundle.main.path(forResource: "500", ofType: "mp4")!
        let images2 = VideoTools.images(withVideoFilePath: filePath2, count: 2, quality: EnumVideoImageQuality.medium)
        let duration2 = VideoTools.duration(withFilePath: filePath2)
        if images2.count == 2 {
            let image = images2[1]
            let videoInfo = LocalVideoInfo(thumbnail: image, duration: duration2, filePath:filePath2)
            localVideos.append(videoInfo)
        }
        
        let filePath3 = Bundle.main.path(forResource: "99", ofType: "mp4")!
        let images3 = VideoTools.images(withVideoFilePath: filePath3, count: 2, quality: EnumVideoImageQuality.medium)
        let duration3 = VideoTools.duration(withFilePath: filePath3)
        if images3.count == 2 {
            let image = images3[1]
            let videoInfo = LocalVideoInfo(thumbnail: image, duration: duration3, filePath:filePath3)
            localVideos.append(videoInfo)
        }
    }
}


