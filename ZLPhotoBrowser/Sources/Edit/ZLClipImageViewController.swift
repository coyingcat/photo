//
//  ZLClipImageViewController.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/27.
//
//  Copyright (c) 2020 Long Zhang <495181165@qq.com>
//
//  Permission is hereby granted, free of charge, to any person obtaining a copy
//  of this software and associated documentation files (the "Software"), to deal
//  in the Software without restriction, including without limitation the rights
//  to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
//  copies of the Software, and to permit persons to whom the Software is
//  furnished to do so, subject to the following conditions:
//
//  The above copyright notice and this permission notice shall be included in
//  all copies or substantial portions of the Software.
//
//  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
//  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
//  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
//  AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
//  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
//  OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
//  THE SOFTWARE.

import UIKit

extension ZLClipImageViewController {
    
    enum ClipPanEdge {
        case none
        case top
        case bottom
        case left
        case right
        case topLeft
        case topRight
        case bottomLeft
        case bottomRight
    }
    
}


class ZLClipImageViewController: UIViewController {

    static let bottomToolViewH: CGFloat = 90
    
    static let clipRatioItemSize: CGSize = CGSize(width: 60, height: 70)
    
    var animate = true
    
    /// 用作进入裁剪界面首次动画frame
    var presentAnimateFrame: CGRect?
    
    /// 用作进入裁剪界面首次动画和取消裁剪时动画的image
    var presentAnimateImage: UIImage?
    
    /// 取消裁剪时动画frame
    var cancelClipAnimateFrame: CGRect = .zero
    
    var viewDidAppearCount = 0
    
    let originalImage: UIImage
    
    let clipRatios: ZLImageClipRatio
    
    var editImage: UIImage
    
    /// 初次进入界面时候，裁剪范围
    var editRect: CGRect
    
    var scrollView: UIScrollView!
    
    var containerView: UIView!
    
    var imageView: UIImageView!
    
    var bottomToolView: UIView!
    
    var bottomShadowLayer: CAGradientLayer!
    
    var bottomToolLineView: UIView!
    
    var cancelBtn: UIButton!
    
    var doneBtn: UIButton!
    
    var rotateBtn: UIButton!
    
    var shouldLayout = true
    
    var panEdge: ZLClipImageViewController.ClipPanEdge = .none
    
    var beginPanPoint: CGPoint = .zero
    
    var clipBoxFrame: CGRect = .zero
    
    var clipOriginFrame: CGRect = .zero
    
    var isRotating = false
    
    var angle: CGFloat = 0
    
    var selectedRatio: ZLImageClipRatio
    
    var thumbnailImage: UIImage?
    
    lazy var maxClipFrame: CGRect = {
        var insets = deviceSafeAreaInsets()
        insets.top +=  20
        var rect = CGRect.zero
        rect.origin.x = 15
        rect.origin.y = insets.top
        rect.size.width = UIScreen.main.bounds.width - 15 * 2
        rect.size.height = UIScreen.main.bounds.height - insets.top - ZLClipImageViewController.bottomToolViewH - ZLClipImageViewController.clipRatioItemSize.height - 25
        return rect
    }()
    
    var minClipSize = CGSize(width: 45, height: 45)
    
    var resetTimer: Timer?
    
    var dismissAnimateFromRect: CGRect = .zero
    
    var dismissAnimateImage: UIImage? = nil
    
    /// 传回旋转角度，图片编辑区域的rect
    var clipDoneBlock: ( (CGFloat, CGRect) -> Void )?
    
    var cancelClipBlock: ( () -> Void )?
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    
    init(image: UIImage, editRect: CGRect?, angle: CGFloat = 0) {
        self.originalImage = image
        self.clipRatios = ZLPhotoConfiguration.default().editImageClipRatios
        self.editRect = editRect ?? .zero
        self.angle = angle
        if angle == -90 {
            self.editImage = image.rotate(orientation: .left)
        } else if self.angle == -180 {
            self.editImage = image.rotate(orientation: .down)
        } else if self.angle == -270 {
            self.editImage = image.rotate(orientation: .right)
        } else {
            self.editImage = image
        }
      
        self.selectedRatio = ZLPhotoConfiguration.default().editImageClipRatios
        
        super.init(nibName: nil, bundle: nil)

            self.calculateClipRect()
        
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupUI()
        self.generateThumbnailImage()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.viewDidAppearCount += 1
        if self.presentingViewController is ZLEditImageViewController {
            self.transitioningDelegate = self
        }
        
        guard self.viewDidAppearCount == 1 else {
            return
        }
        
        if let frame = self.presentAnimateFrame, let image = self.presentAnimateImage {
            let animateImageView = UIImageView(image: image)
            animateImageView.contentMode = .scaleAspectFill
            animateImageView.clipsToBounds = true
            animateImageView.frame = frame
            self.view.addSubview(animateImageView)
            
            self.cancelClipAnimateFrame = self.clipBoxFrame
            UIView.animate(withDuration: 0.25, animations: {
                animateImageView.frame = self.clipBoxFrame
                self.bottomToolView.alpha = 1
                self.rotateBtn.alpha = 1
            }) { (_) in
                UIView.animate(withDuration: 0.1, animations: {
                    self.scrollView.alpha = 1
                }) { (_) in
                    animateImageView.removeFromSuperview()
                }
            }
        } else {
            self.bottomToolView.alpha = 1
            self.rotateBtn.alpha = 1
            self.scrollView.alpha = 1
        }
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        
        guard self.shouldLayout else {
            return
        }
        self.shouldLayout = false
        
        self.scrollView.frame = self.view.bounds
        
        self.layoutInitialImage()
        
        self.bottomToolView.frame = CGRect(x: 0, y: self.view.bounds.height-ZLClipImageViewController.bottomToolViewH, width: self.view.bounds.width, height: ZLClipImageViewController.bottomToolViewH)
        self.bottomShadowLayer.frame = self.bottomToolView.bounds
        
        self.bottomToolLineView.frame = CGRect(x: 0, y: 0, width: self.view.bounds.width, height: 1/UIScreen.main.scale)
        let toolBtnH: CGFloat = 25
        let toolBtnY = (ZLClipImageViewController.bottomToolViewH - toolBtnH) / 2 - 10
        self.cancelBtn.frame = CGRect(x: 30, y: toolBtnY, width: toolBtnH, height: toolBtnH)
      
        self.doneBtn.frame = CGRect(x: self.view.bounds.width-30-toolBtnH, y: toolBtnY, width: toolBtnH, height: toolBtnH)
        
        let ratioColViewY = self.bottomToolView.frame.minY - ZLClipImageViewController.clipRatioItemSize.height - 5
        self.rotateBtn.frame = CGRect(x: 30, y: ratioColViewY + (ZLClipImageViewController.clipRatioItemSize.height-25)/2, width: 25, height: 25)
        let ratioColViewX = self.rotateBtn.frame.maxX + 15
    }
    
    func setupUI() {
        self.view.backgroundColor = .black
        
        self.scrollView = UIScrollView()
        self.scrollView.alwaysBounceVertical = true
        self.scrollView.alwaysBounceHorizontal = true
        self.scrollView.showsVerticalScrollIndicator = false
        self.scrollView.showsHorizontalScrollIndicator = false
        if #available(iOS 11.0, *) {
            self.scrollView.contentInsetAdjustmentBehavior = .never
        } else {
            // Fallback on earlier versions
        }
        self.scrollView.delegate = self
        self.view.addSubview(self.scrollView)
        
        self.containerView = UIView()
        self.scrollView.addSubview(self.containerView)
        
        self.imageView = UIImageView(image: self.editImage)
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
        self.containerView.addSubview(self.imageView)
        
        self.bottomToolView = UIView()
        self.view.addSubview(self.bottomToolView)
        
        let color1 = UIColor.black.withAlphaComponent(0.15).cgColor
        let color2 = UIColor.black.withAlphaComponent(0.35).cgColor
        
        self.bottomShadowLayer = CAGradientLayer()
        self.bottomShadowLayer.colors = [color1, color2]
        self.bottomShadowLayer.locations = [0, 1]
        self.bottomToolView.layer.addSublayer(self.bottomShadowLayer)
        
        self.bottomToolLineView = UIView()
        self.bottomToolLineView.backgroundColor = zlRGB(240, 240, 240)
        self.bottomToolView.addSubview(self.bottomToolLineView)
        
        self.cancelBtn = UIButton(type: .custom)
        self.cancelBtn.setImage(getImage("zl_close"), for: .normal)
        self.cancelBtn.adjustsImageWhenHighlighted = false
        self.cancelBtn.zl_enlargeValidTouchArea(inset: 20)
        self.cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        self.bottomToolView.addSubview(self.cancelBtn)
        
        
        self.doneBtn = UIButton(type: .custom)
        self.doneBtn.setImage(getImage("zl_right"), for: .normal)
        self.doneBtn.adjustsImageWhenHighlighted = false
        self.doneBtn.zl_enlargeValidTouchArea(inset: 20)
        self.doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        self.bottomToolView.addSubview(self.doneBtn)
        
        self.rotateBtn = UIButton(type: .custom)
        self.rotateBtn.setImage(getImage("zl_rotateimage"), for: .normal)
        self.rotateBtn.adjustsImageWhenHighlighted = false
        self.rotateBtn.zl_enlargeValidTouchArea(inset: 20)
        self.rotateBtn.addTarget(self, action: #selector(rotateBtnClick), for: .touchUpInside)
        self.view.addSubview(self.rotateBtn)
        
        let layout = UICollectionViewFlowLayout()
        layout.itemSize = ZLClipImageViewController.clipRatioItemSize
        layout.scrollDirection = .horizontal
        layout.sectionInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 20)

        self.scrollView.alpha = 0
        self.bottomToolView.alpha = 0
        self.rotateBtn.alpha = 0
    }
    
    func generateThumbnailImage() {
        let size: CGSize
        let ratio = (self.editImage.size.width / self.editImage.size.height)
        let fixLength: CGFloat = 100
        if ratio >= 1 {
            size = CGSize(width: fixLength * ratio, height: fixLength)
        } else {
            size = CGSize(width: fixLength, height: fixLength / ratio)
        }
        self.thumbnailImage = self.editImage.resize_vI(size)
    }
    
    func calculateClipRect() {
        if self.selectedRatio.whRatio == 0 {
            self.editRect = CGRect(origin: .zero, size: self.editImage.size)
        } else {
            let imageSize = self.editImage.size
            let imageWHRatio = imageSize.width / imageSize.height
            
            var w: CGFloat = 0, h: CGFloat = 0
            if self.selectedRatio.whRatio >= imageWHRatio {
                w = imageSize.width
                h = w / self.selectedRatio.whRatio
            } else {
                h = imageSize.height
                w = h * self.selectedRatio.whRatio
            }
            
            self.editRect = CGRect(x: (imageSize.width - w) / 2, y: (imageSize.height - h) / 2, width: w, height: h)
        }
    }
    
    func layoutInitialImage() {
        self.scrollView.minimumZoomScale = 1
        self.scrollView.maximumZoomScale = 1
        self.scrollView.zoomScale = 1
        
        let editSize = self.editRect.size
        self.scrollView.contentSize = editSize
        let maxClipRect = self.maxClipFrame
        
        self.containerView.frame = CGRect(origin: .zero, size: self.editImage.size)
        self.imageView.frame = self.containerView.bounds
        
        // editRect比例，计算editRect所占frame
        let editScale = min(maxClipRect.width/editSize.width, maxClipRect.height/editSize.height)
        let scaledSize = CGSize(width: floor(editSize.width * editScale), height: floor(editSize.height * editScale))
        
        var frame = CGRect.zero
        frame.size = scaledSize
        frame.origin.x = maxClipRect.minX + floor((maxClipRect.width-frame.width) / 2)
        frame.origin.y = maxClipRect.minY + floor((maxClipRect.height-frame.height) / 2)
        
        // 按照edit image进行计算最小缩放比例
        let originalScale = min(maxClipRect.width/self.editImage.size.width, maxClipRect.height/self.editImage.size.height)
        // 将 edit rect 相对 originalScale 进行缩放，缩放到图片未放大时候的clip rect
        let scaleEditSize = CGSize(width: self.editRect.width * originalScale, height: self.editRect.height * originalScale)
        // 计算缩放后的clip rect相对maxClipRect的比例
        let clipRectZoomScale = min(maxClipRect.width/scaleEditSize.width, maxClipRect.height/scaleEditSize.height)
        
        self.scrollView.minimumZoomScale = originalScale
        self.scrollView.maximumZoomScale = 10
        // 设置当前zoom scale
        let zoomScale = (clipRectZoomScale * originalScale)
        self.scrollView.zoomScale = zoomScale
        self.scrollView.contentSize = CGSize(width: self.editImage.size.width * zoomScale, height: self.editImage.size.height * zoomScale)
        
        self.changeClipBoxFrame(newFrame: frame)
        
        if (frame.size.width < scaledSize.width - CGFloat.ulpOfOne) || (frame.size.height < scaledSize.height - CGFloat.ulpOfOne) {
            var offset = CGPoint.zero
            offset.x = -floor((self.scrollView.frame.width - scaledSize.width) / 2)
            offset.y = -floor((self.scrollView.frame.height - scaledSize.height) / 2)
            self.scrollView.contentOffset = offset
        }
        
        // edit rect 相对 image size 的 偏移量
        let diffX = self.editRect.origin.x / self.editImage.size.width * self.scrollView.contentSize.width
        let diffY = self.editRect.origin.y / self.editImage.size.height * self.scrollView.contentSize.height
        self.scrollView.contentOffset = CGPoint(x: -self.scrollView.contentInset.left+diffX, y: -self.scrollView.contentInset.top+diffY)
    }
    
    func changeClipBoxFrame(newFrame: CGRect) {
        guard self.clipBoxFrame != newFrame else {
            return
        }
        if newFrame.width < CGFloat.ulpOfOne || newFrame.height < CGFloat.ulpOfOne {
            return
        }
        var frame = newFrame
        let originX = ceil(self.maxClipFrame.minX)
        let diffX = frame.minX - originX
        frame.origin.x = max(frame.minX, originX)
        if diffX < -CGFloat.ulpOfOne {
            frame.size.width += diffX
        }
        let originY = ceil(self.maxClipFrame.minY)
        let diffY = frame.minY - originY
        frame.origin.y = max(frame.minY, originY)
        if diffY < -CGFloat.ulpOfOne {
            frame.size.height += diffY
        }
        let maxW = self.maxClipFrame.width + self.maxClipFrame.minX - frame.minX
        frame.size.width = max(self.minClipSize.width, min(frame.width, maxW))

        
        let maxH = self.maxClipFrame.height + self.maxClipFrame.minY - frame.minY
        frame.size.height = max(self.minClipSize.height, min(frame.height, maxH))

        
        self.clipBoxFrame = frame

        self.scrollView.contentInset = UIEdgeInsets(top: frame.minY, left: frame.minX, bottom: self.scrollView.frame.maxY-frame.maxY, right: self.scrollView.frame.maxX-frame.maxX)
        
        let scale = max(frame.height/self.editImage.size.height, frame.width/self.editImage.size.width)
        self.scrollView.minimumZoomScale = scale
        

        
        self.scrollView.zoomScale = self.scrollView.zoomScale
    }
    
    @objc func cancelBtnClick() {
        self.dismissAnimateFromRect = self.cancelClipAnimateFrame
        self.dismissAnimateImage = self.presentAnimateImage
        self.cancelClipBlock?()
        self.dismiss(animated: self.animate, completion: nil)
    }
    

    
    @objc func doneBtnClick() {
        let image = self.clipImage()
        self.dismissAnimateFromRect = self.clipBoxFrame
        self.dismissAnimateImage = image.clipImage
        self.clipDoneBlock?(self.angle, image.editRect)
        self.dismiss(animated: self.animate, completion: nil)
    }
    
    @objc func rotateBtnClick() {
        guard !self.isRotating else {
            return
        }
        self.angle -= 90
        if self.angle == -360 {
            self.angle = 0
        }
        
        self.isRotating = true
        
        let animateImageView = UIImageView(image: self.editImage)
        animateImageView.contentMode = .scaleAspectFit
        animateImageView.clipsToBounds = true
        let originFrame = self.view.convert(self.containerView.frame, from: self.scrollView)
        animateImageView.frame = originFrame
        self.view.addSubview(animateImageView)
        
        if self.selectedRatio.whRatio == 0 || self.selectedRatio.whRatio == 1 {
            // 自由比例和1:1比例，进行edit rect转换
            
            // 将edit rect转换为相对edit image的rect
            let rect = self.convertClipRectToEditImageRect()
            // 旋转图片
            self.editImage = self.editImage.rotate(orientation: .left)
            // 将rect进行旋转，转换到相对于旋转后的edit image的rect
            self.editRect = CGRect(x: rect.minY, y: self.editImage.size.height-rect.minX-rect.width, width: rect.height, height: rect.width)
        } else {
            // 其他比例的裁剪框，旋转后都重置edit rect
            
            // 旋转图片
            self.editImage = self.editImage.rotate(orientation: .left)
            self.calculateClipRect()
        }
        
        self.imageView.image = self.editImage
        self.layoutInitialImage()
        
        let toFrame = self.view.convert(self.containerView.frame, from: self.scrollView)
        let transform = CGAffineTransform(rotationAngle: -CGFloat.pi/2)

        self.containerView.alpha = 0
        UIView.animate(withDuration: 0.3, animations: {
            animateImageView.transform = transform
            animateImageView.frame = toFrame
        }) { (_) in
            animateImageView.removeFromSuperview()

            self.containerView.alpha = 1
            self.isRotating = false
        }
        
        self.generateThumbnailImage()
    }
    

    
    func calculatePanEdge(at point: CGPoint) -> ZLClipImageViewController.ClipPanEdge {
        let frame = self.clipBoxFrame.insetBy(dx: -30, dy: -30)
        
        let cornerSize = CGSize(width: 60, height: 60)
        let topLeftRect = CGRect(origin: frame.origin, size: cornerSize)
        if topLeftRect.contains(point) {
            return .topLeft
        }
        
        let topRightRect = CGRect(origin: CGPoint(x: frame.maxX-cornerSize.width, y: frame.minY), size: cornerSize)
        if topRightRect.contains(point) {
            return .topRight
        }
        
        let bottomLeftRect = CGRect(origin: CGPoint(x: frame.minX, y: frame.maxY-cornerSize.height), size: cornerSize)
        if bottomLeftRect.contains(point) {
            return .bottomLeft
        }
        
        let bottomRightRect = CGRect(origin: CGPoint(x: frame.maxX-cornerSize.width, y: frame.maxY-cornerSize.height), size: cornerSize)
        if bottomRightRect.contains(point) {
            return .bottomRight
        }
        
        let topRect = CGRect(origin: frame.origin, size: CGSize(width: frame.width, height: cornerSize.height))
        if topRect.contains(point) {
            return .top
        }
        
        let bottomRect = CGRect(origin: CGPoint(x: frame.minX, y: frame.maxY-cornerSize.height), size: CGSize(width: frame.width, height: cornerSize.height))
        if bottomRect.contains(point) {
            return .bottom
        }
        
        let leftRect = CGRect(origin: frame.origin, size: CGSize(width: cornerSize.width, height: frame.height))
        if leftRect.contains(point) {
            return .left
        }
        
        let rightRect = CGRect(origin: CGPoint(x: frame.maxX-cornerSize.width, y: frame.minY), size: CGSize(width: cornerSize.width, height: frame.height))
        if rightRect.contains(point) {
            return .right
        }
        
        return .none
    }
    
    func updateClipBoxFrame(point: CGPoint) {
        var frame = self.clipBoxFrame
        let originFrame = self.clipOriginFrame
        
        var newPoint = point
        newPoint.x = max(self.maxClipFrame.minX, newPoint.x)
        newPoint.y = max(self.maxClipFrame.minY, newPoint.y)
        
        let diffX = ceil(newPoint.x - self.beginPanPoint.x)
        let diffY = ceil(newPoint.y - self.beginPanPoint.y)
        let ratio = self.selectedRatio.whRatio
        
        switch self.panEdge {
        case .left:
            frame.origin.x = originFrame.minX + diffX
            frame.size.width = originFrame.width - diffX
            if ratio != 0 {
                frame.size.height = originFrame.height - diffX / ratio
            }
            
        case .right:
            frame.size.width = originFrame.width + diffX
            if ratio != 0 {
                frame.size.height = originFrame.height + diffX / ratio
            }
            
        case .top:
            frame.origin.y = originFrame.minY + diffY
            frame.size.height = originFrame.height - diffY
            if ratio != 0 {
                frame.size.width = originFrame.width - diffY * ratio
            }
            
        case .bottom:
            frame.size.height = originFrame.height + diffY
            if ratio != 0 {
                frame.size.width = originFrame.width + diffY * ratio
            }
            
        case .topLeft:
            if ratio != 0 {
                    frame.origin.x = originFrame.minX + diffX
                    frame.size.width = originFrame.width - diffX
                    frame.origin.y = originFrame.minY + diffX / ratio
                    frame.size.height = originFrame.height - diffX / ratio
            } else {
                frame.origin.x = originFrame.minX + diffX
                frame.size.width = originFrame.width - diffX
                frame.origin.y = originFrame.minY + diffY
                frame.size.height = originFrame.height - diffY
            }
            
        case .topRight:
            if ratio != 0 {
                    frame.size.width = originFrame.width + diffX
                    frame.origin.y = originFrame.minY - diffX / ratio
                    frame.size.height = originFrame.height + diffX / ratio

            } else {
                frame.size.width = originFrame.width + diffX
                frame.origin.y = originFrame.minY + diffY
                frame.size.height = originFrame.height - diffY
            }
            
        case .bottomLeft:
            if ratio != 0 {

                    frame.origin.x = originFrame.minX + diffX
                    frame.size.width = originFrame.width - diffX
                    frame.size.height = originFrame.height - diffX / ratio

            } else {
                frame.origin.x = originFrame.minX + diffX
                frame.size.width = originFrame.width - diffX
                frame.size.height = originFrame.height + diffY
            }
            
        case .bottomRight:
            if ratio != 0 {

                    frame.size.width = originFrame.width + diffX
                    frame.size.height = originFrame.height + diffX / ratio

            } else {
                frame.size.width = originFrame.width + diffX
                frame.size.height = originFrame.height + diffY
            }
            
        default:
            break
        }
        
        let minSize: CGSize
        let maxSize: CGSize
        let maxClipFrame: CGRect
        if ratio != 0 {
            if ratio >= 1 {
                minSize = CGSize(width: self.minClipSize.height * ratio, height: self.minClipSize.height)
            } else {
                minSize = CGSize(width: self.minClipSize.width, height: self.minClipSize.width / ratio)
            }
            if ratio > self.maxClipFrame.width / self.maxClipFrame.height {
                maxSize = CGSize(width: self.maxClipFrame.width, height: self.maxClipFrame.width / ratio)
            } else {
                maxSize = CGSize(width: self.maxClipFrame.height * ratio, height: self.maxClipFrame.height)
            }
            maxClipFrame = CGRect(origin: CGPoint(x: self.maxClipFrame.minX + (self.maxClipFrame.width-maxSize.width)/2, y: self.maxClipFrame.minY + (self.maxClipFrame.height-maxSize.height)/2), size: maxSize)
        } else {
            minSize = self.minClipSize
            maxSize = self.maxClipFrame.size
            maxClipFrame = self.maxClipFrame
        }
        
        frame.size.width = min(maxSize.width, max(minSize.width, frame.size.width))
        frame.size.height = min(maxSize.height, max(minSize.height, frame.size.height))
        
        frame.origin.x = min(maxClipFrame.maxX-minSize.width, max(frame.origin.x, maxClipFrame.minX))
        frame.origin.y = min(maxClipFrame.maxY-minSize.height, max(frame.origin.y, maxClipFrame.minY))
        
        if (self.panEdge == .topLeft || self.panEdge == .bottomLeft || self.panEdge == .left) && frame.size.width <= minSize.width + CGFloat.ulpOfOne {
            frame.origin.x = originFrame.maxX - minSize.width
        }
        if (self.panEdge == .topLeft || self.panEdge == .topRight || self.panEdge == .top) && frame.size.height <= minSize.height + CGFloat.ulpOfOne {
            frame.origin.y = originFrame.maxY - minSize.height
        }
        
        self.changeClipBoxFrame(newFrame: frame)
    }
    

    func clipImage() -> (clipImage: UIImage, editRect: CGRect) {
        let frame = self.convertClipRectToEditImageRect()
        
        let origin = CGPoint(x: -frame.minX, y: -frame.minY)
        UIGraphicsBeginImageContextWithOptions(frame.size, false, self.editImage.scale)
        self.editImage.draw(at: origin)
        let temp = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        guard let cgi = temp?.cgImage else {
            return (self.editImage, CGRect(origin: .zero, size: self.editImage.size))
        }
        let newImage = UIImage(cgImage: cgi, scale: self.editImage.scale, orientation: .up)
        return (newImage, frame)
    }
    
    func convertClipRectToEditImageRect() -> CGRect {
        let imageSize = self.editImage.size
        let contentSize = self.scrollView.contentSize
        let offset = self.scrollView.contentOffset
        let insets = self.scrollView.contentInset
        
        var frame = CGRect.zero
        frame.origin.x = floor((offset.x + insets.left) * (imageSize.width / contentSize.width))
        frame.origin.x = max(0, frame.origin.x)
        
        frame.origin.y = floor((offset.y + insets.top) * (imageSize.height / contentSize.height))
        frame.origin.y = max(0, frame.origin.y)
        
        frame.size.width = ceil(self.clipBoxFrame.width * (imageSize.width / contentSize.width))
        frame.size.width = min(imageSize.width, frame.width)
        
        frame.size.height = ceil(self.clipBoxFrame.height * (imageSize.height / contentSize.height))
        frame.size.height = min(imageSize.height, frame.height)
        
        return frame
    }
    
}






extension ZLClipImageViewController: UIScrollViewDelegate {
    
    func viewForZooming(in scrollView: UIScrollView) -> UIView? {
        return self.containerView
    }
    
  
    
}


extension ZLClipImageViewController: UIViewControllerTransitioningDelegate {
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ZLClipImageDismissAnimatedTransition()
    }
    
}
