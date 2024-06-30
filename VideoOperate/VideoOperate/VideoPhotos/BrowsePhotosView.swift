//
//  BrowsePhotosView.swift
//  VideoOperate
//
//  Created by 刘维 on 2024/6/28.
//

import SwiftUI
import UIKit

struct UIKitScrollView: UIViewRepresentable {
    
    var photo: UIImage
    
    private let imgViewTag: Int = 11
    @Binding var resetStatus: Bool
    
    func makeUIView(context: Context) -> UIScrollView {
        let scrollView = UIScrollView()
        scrollView.delegate = context.coordinator
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.showsVerticalScrollIndicator = false
        scrollView.minimumZoomScale = 1.0
        scrollView.maximumZoomScale = 3.0
        scrollView.bounces = true
        
        let imageView = UIImageView(image: photo)
        imageView.contentMode = .scaleAspectFit
        imageView.tag = imgViewTag
        imageView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(imageView)
        
        // 添加约束，使 imageView 的大小和 scrollView 一致
        NSLayoutConstraint.activate([
            imageView.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 5),
            imageView.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -5),
            imageView.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            imageView.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            imageView.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -10),
            imageView.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor)
        ])
        
        let doubleTapGesture = UITapGestureRecognizer(target: context.coordinator, action: #selector(context.coordinator.doubleTap))
        doubleTapGesture.numberOfTapsRequired = 2
        scrollView.addGestureRecognizer(doubleTapGesture)
        
        return scrollView
    }
    
    func updateUIView(_ uiView: UIScrollView, context: Context) {
        if let imageView = uiView.viewWithTag(imgViewTag) as? UIImageView {
            imageView.image = photo
            
            if resetStatus {
                uiView.setZoomScale(1.0, animated: true)
                resetStatus = false
            }
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }
    
    class Coordinator: NSObject, UIScrollViewDelegate {
        var parent: UIKitScrollView
        
        init(parent: UIKitScrollView) {
            self.parent = parent
        }
        
        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            // 滚动代理监听
        }
        
        func viewForZooming(in scrollView: UIScrollView) -> UIView? {
            return scrollView.viewWithTag(parent.imgViewTag)
        }
        
        @objc func doubleTap(gesture: UITapGestureRecognizer) {
            
            guard let scrollView = gesture.view as? UIScrollView else {
                return
            }
            
            scrollView.setZoomScale(1.0, animated: true)
        }
    }
}

struct BrowsePhotosView: View {
    var photos: [UIImage]
    
    @Binding var currentPage: Int
    @State private var status: Bool = false
    @State private var showAlert = false
    
    var body: some View {
        GeometryReader { geometry in
            
            TabView(selection: $currentPage) {
                ForEach(photos.indices, id: \.self) { index in
                    let image = photos[index]
                    UIKitScrollView(photo: image, resetStatus: $status)
                        .tag(index)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .ignoresSafeArea(.all)
                        .onDisappear{
                            status = true
                        }
                }
            }
            .tabViewStyle(PageTabViewStyle(indexDisplayMode: .automatic))
            .background(Color.black.opacity(0.1))
            .navigationTitle("图片")
            .toolbar {
                Button("保存") {
                    let image = photos[currentPage]
                    SaveFileManager.saveImageAlbum(image: image) { success in
                        if success {
                            showAlert = true
                        }
                    }
                }
            }
            .alert(isPresented: $showAlert) {
                Alert(
                    title: Text("提示"),
                    message: Text("图片已保存到相册"),
                    dismissButton: .default(Text("确定"))
                )
            }
        }
    }
}

struct ZoomImageView: View {
    var img: UIImage
    
    @State private var scale: CGFloat = 1.0
    @State private var lastScale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        GeometryReader { geometry in
            
            Image(uiImage: img)
                .resizable()
                .scaledToFit()
                .scaleEffect(scale)
                .offset(x: offset.width, y: offset.height)
                .frame(width: geometry.size.width, height: geometry.size.height)
                .animation(.easeInOut, value: scale)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            self.scale = self.lastScale * value
                        }
                        .onEnded { _ in
                            self.lastScale = self.scale
                        }
                )
                .gesture(
                    TapGesture(count: 2)
                        .onEnded {
                            withAnimation {
                                self.scale = 1.0
                                self.lastScale = 1.0
                                self.offset = .zero
                                self.lastOffset = .zero
                            }
                        }
                )
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if self.scale > 1 {
                                var newOffset = CGSize(
                                    width: self.lastOffset.width + value.translation.width,
                                    height: self.lastOffset.height + value.translation.height
                                )
                                    
                                // 限制拖动范围，使图片内容不会露出边界
                                let halfImageWidth = (geometry.size.width * self.scale - geometry.size.width) / 2
                                let halfImageHeight = (geometry.size.height * self.scale - geometry.size.height) / 2
                                
                                newOffset.width = min(max(newOffset.width, -halfImageWidth), halfImageWidth)
                                newOffset.height = min(max(newOffset.height, -halfImageHeight), halfImageHeight)
                                
                                self.offset = newOffset
                            }
                        }
                        .onEnded { _ in
                            self.lastOffset = self.offset
                        }
                )
        }
    }
}
