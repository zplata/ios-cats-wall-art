//
//  RiveWallArt.swift
//  cats-wall-art
//
//  Created by Zach Plata on 12/11/23.
//

import SwiftUI
import RiveRuntime

struct RiveWallArt: View {
    
    @StateObject private var horizRvm = EventRvm(fileName: "picture_frame_update_v4", autoPlay: true, artboardName: "Picture 2")
    @StateObject private var vertRvm1 = EventRvm(fileName: "picture_frame_update_v4", autoPlay: true, artboardName: "Picture 1")
    @StateObject private var vertRvm2 = EventRvm(fileName: "picture_frame_update_v4", autoPlay: true, artboardName: "Picture 1")
    @State private var isDragging = false
    @State private var dragPct = 0.0
    
    private var SCREEN_WIDTH = UIScreen.main.bounds.width

    
    func setupDrag(riveVm: RiveViewModel, geo: GeometryProxy) -> some Gesture {
        return (
            DragGesture(coordinateSpace: .local)
                .onChanged { val in
                    if (dragPct >= -100 && dragPct <= 100) {
                        self.isDragging = true
                        let dragDistance = val.translation.width
                        // Once dragged 60% of the view width, transition to state for switching images
                        let dragProgress = (dragDistance / (geo.size.width * 0.6)) * 110
                        // State Machine is setup to drag in opposite direction numerically
                        dragPct = dragProgress * -1
                        riveVm.setInput("Swipe", value: dragPct)
                        
                        // Reset when the 100% or -100% reached
                        if (dragPct <= -100 || dragPct >= 100) {
                            dragPct = 0
                            self.isDragging = false
                        }
                    } else {
                        self.isDragging = false
                    }
                }
                .onEnded { val in
                    self.isDragging = false
                    if (dragPct > -100 || dragPct < 100) {
                        dragPct = 0
                        riveVm.setInput("Swipe", value: dragPct)
                    }
                }
        )
    }
    
    var body: some View {
        ZStack {
            RiveViewModel(fileName: "picture_frame_update_v4", fit: .fitHeight, autoPlay: false, artboardName: "bg").view().ignoresSafeArea(edges: .vertical)
            VStack {
                GeometryReader { geo in
                    VStack {
                        vertRvm1.view()
                            .frame(maxHeight: 400, alignment: .topLeading)
                            .offset(x: -60)
                            .gesture(setupDrag(riveVm: vertRvm1, geo: geo))
                        horizRvm.view()
                            .frame(maxHeight: 200)
                            .offset(x: 60)
                            .gesture(setupDrag(riveVm: horizRvm, geo: geo))
                        vertRvm2.view()
                            .frame(maxHeight: 400)
                            .offset(x: -60)
                            .gesture(setupDrag(riveVm: vertRvm2, geo: geo))
                    }
                }
            }.padding(.horizontal, 20)
        }
    }
}


class EventRvm: RiveViewModel {
    private var assetLoader = CatAssetLoader()
    
    init(fileName: String, autoPlay: Bool, artboardName: String) {
        super.init(fileName: fileName, autoPlay: autoPlay, artboardName: artboardName, loadCdn: false, customLoader: assetLoader.loader)
    }
    
    // TODO: Call this somewhere
    func cleanup() {
        assetLoader.cleanup()
    }
    
    @objc func onRiveEventReceived(onRiveEvent riveEvent: RiveEvent) {
        if riveEvent.name() == "Switch Image"  {
            let properties = riveEvent.properties()
            properties["isNext"] as! Bool ? assetLoader.nextCat() : assetLoader.prevCat()
        }
    }
}

class CatAssetLoader {
    init() {
        factory = RenderContextManager.shared()!.getDefaultFactory();
    }
    // Maintain a list of cached images we pull
    var imageCache: [RiveRenderImage] = [];
    var cacheIdx = 0
    
    // Maintain reference to the RiveImageAsset, which we use to set new RenderImages on
    var onDemandImage: RiveImageAsset?;
    var factory: RiveFactory?;

    // pretty naive way to clean up any outstanding requests.
    var tasks: [URLSessionDataTask] = [];
    
    func cachedImageAsset(asset: RiveImageAsset) {
        let image = imageCache[cacheIdx] as RiveRenderImage
        debugPrint("\(image)")
        asset.renderImage(image);
    }
    
    func getCatImageAsset(asset: RiveImageAsset, factory: RiveFactory) {
        guard let folderUrl = Bundle.main.url(forResource: "cat\(cacheIdx - 1)", withExtension: "webp") else {
            fatalError("Could not find 'cats' folder")
        }
        do {
            let imageData = try Data(contentsOf: folderUrl)
            let renderImage = factory.decodeImage(imageData)
            imageCache.append(renderImage)
            asset.renderImage(renderImage)
        } catch {
            fatalError("Could not parse images in the cats folder")
        }
    }
    
    func loader (asset: RiveFileAsset, data: Data, factory: RiveFactory) -> Bool {
        if (data.count > 0) {return false;}
        if (asset.cdnUuid().count > 0) {return false;}
        switch (asset.name()) {
            case "cat.webp":
                guard let url = (.main as Bundle).url(forResource: "cat-994546", withExtension: "webp") else {
                    fatalError("Failed to locate 'cat-994546' in bundle.")
                }
                guard let data = try? Data(contentsOf: url) else {
                    fatalError("Failed to load \(url) from bundle.")
                }
                onDemandImage = (asset as! RiveImageAsset)
                let renderImage = factory.decodeImage(data)
                imageCache.append(renderImage)
                onDemandImage!.renderImage(renderImage)
                return true;
            default: break
        }
        return false;
    }
    
    func nextCat(){
        cacheIdx = cacheIdx + 1 >= 7 ? 0 : cacheIdx + 1
        if cacheIdx < imageCache.count {
            cachedImageAsset(asset: onDemandImage!)
        } else if let asset=onDemandImage, let factory = factory {
            getCatImageAsset(asset: (asset), factory: factory);
        }
    }
    
    func prevCat() {
        if let asset = onDemandImage {
            cacheIdx = cacheIdx - 1 < 0 ? imageCache.count - 1 : cacheIdx - 1
            cachedImageAsset(asset: asset)
        }
    }
    func cleanup(){
        for task in tasks {
            task.cancel();
        }
    }
}
