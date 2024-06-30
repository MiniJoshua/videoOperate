//
//  VideoItemRow.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/11.
//

import SwiftUI

struct VideoItemRow: View {
    
    var videoIsOn: Bool
    var videoToggleChanged: (Bool) -> Void
    
    var audioIsOn: Bool
    var audioToggleChanged: (Bool) -> Void
    
    var body: some View {
        let videoBinding = Binding<Bool> {
            self.videoIsOn
        } set: {
            self.videoToggleChanged($0)
        }
        
        let audioBinding = Binding {
            self.audioIsOn
        } set: {
            self.audioToggleChanged($0)
        }

        HStack {
            Image(systemName: "star")
                .padding()
                .frame(width: 100, height: 55)
            
            Spacer()
            
            Toggle("视频", isOn: videoBinding)
                .onChange(of: videoIsOn) { newValue in
                    toggleChanged(newValue, true)
                }
            
            Toggle("音频", isOn: audioBinding)
                .onChange(of: audioIsOn) { newValue in
                    toggleChanged(newValue, false)
                }
        }
        .padding()
    }
    
    func toggleChanged(_ newValue: Bool, _ isVideo:Bool) {
        if newValue && isVideo {
            //记录选择的视频
            
        } else if newValue && !isVideo {
            //记录选择的音频
            
        }
    }
}

struct VideoItemRow_Previews: PreviewProvider {
    static var previews: some View {
        VideoItemRow(videoIsOn: false, videoToggleChanged: { _ in
            
        }, audioIsOn: false) { _ in
            
        }
    }
}
