//
//  LoadingView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/27.
//

import SwiftUI

struct LoadingView: View {
    
    @State private var trimStart: CGFloat = 0
    @State private var trimEnd: CGFloat = 0
    @State private var isFirstAnimation = true
    private let time = 1.0
    
    var body: some View {
        
        Circle()
            .trim(from: trimStart, to: trimEnd)
            .stroke(Color.pink, lineWidth: 6)
            .frame(width: 60, height: 60)
            .onAppear {
                self.runFirstAnimation()
            }
    }
    
    private func runFirstAnimation() {
        withAnimation(.easeInOut(duration: time)) {
            self.trimEnd = 1.0
        }
        
        // 在第一个动画完成后，启动第二个动画
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            self.runSecondAnimation()
        }
    }
    
    private func runSecondAnimation() {
        withAnimation(.easeInOut(duration: time)) {
            self.trimStart = 1.0
        }
        
        // 在第二个动画完成后，重置并启动第一个动画
        DispatchQueue.main.asyncAfter(deadline: .now() + time) {
            self.trimStart = 0
            self.trimEnd = 0
            self.runFirstAnimation()
        }
    }
}

