//
//  ZLEditImageViewController.swift
//  ZLPhotoBrowser
//
//  Created by long on 2020/8/26.
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

public class ZLEditImageModel: NSObject {
    
    
    public let editRect: CGRect?
    
    public let angle: CGFloat
    
    public let selectRatio: ZLImageClipRatio?

    init(editRect: CGRect?, angle: CGFloat, selectRatio: ZLImageClipRatio?) {

        self.editRect = editRect
        self.angle = angle
        self.selectRatio = selectRatio

        super.init()
    }
    
}

public class ZLEditImageViewController: UIViewController {

    static let filterColViewH: CGFloat = 80
    
    static let maxDrawLineImageWidth: CGFloat = 600
    
    static let ashbinNormalBgColor = zlRGB(40, 40, 40).withAlphaComponent(0.8)
    
    var animate = false
    
    var originalImage: UIImage
    
    // 第一次进入界面时，布局后frame，裁剪dimiss动画使用
    var originalFrame: CGRect = .zero
    
    // 图片可编辑rect
    var editRect: CGRect
    
    let tools: [ZLEditImageViewController.EditImageTool]
    
    var selectRatio: ZLImageClipRatio?
    
    var editImage: UIImage
    
    var cancelBtn: UIButton!
    
    var scrollView: UIScrollView!
    
    var containerView: UIView!
    
    // Show image.
    var imageView: UIImageView!
    
    // 处理好的马赛克图片
    var mosaicImage: UIImage?
    
    // 显示马赛克图片的layer
    var mosaicImageLayer: CALayer?
    
    // 显示马赛克图片的layer的mask
    var mosaicImageLayerMaskLayer: CAShapeLayer?
    
    // 上方渐变阴影层
    var topShadowView: UIView!
    
    var topShadowLayer: CAGradientLayer!
     
    // 下方渐变阴影层
    var bottomShadowView: UIView!
    
    var bottomShadowLayer: CAGradientLayer!
    
    var doneBtn: UIButton!
    
    var revokeBtn: UIButton!
    
    var selectedTool: ZLEditImageViewController.EditImageTool?
    
    var editToolCollectionView: UICollectionView!
    
    var filterCollectionView: UICollectionView!
    
    var ashbinView: UIView!
    
    var ashbinImgView: UIImageView!
    
    var drawLineWidth: CGFloat = 5
    
    var mosaicLineWidth: CGFloat = 25
    
    // collectionview 中的添加滤镜的小图
    var thumbnailFilterImages: [UIImage] = []
    
    // 选择滤镜后对原图添加滤镜后的图片
    var filterImages: [String: UIImage] = [:]
    
    var isScrolling = false
    
    var shouldLayout = true
    
    var imageStickerContainerIsHidden = true
    
    var angle: CGFloat
    
    var imageSize: CGSize {
        if self.angle == -90 || self.angle == -270 {
            return CGSize(width: self.originalImage.size.height, height: self.originalImage.size.width)
        }
        return self.originalImage.size
    }
    
    @objc public var editFinishBlock: ( (UIImage, ZLEditImageModel?) -> Void )?
    
    public override var prefersStatusBarHidden: Bool {
        return true
    }
    
    public override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }
    
    @objc public class func showEditImageVC(parentVC: UIViewController?, animate: Bool = false, image: UIImage, editModel: ZLEditImageModel? = nil, completion: ( (UIImage, ZLEditImageModel?) -> Void )? ) {
        let tools = ZLPhotoConfiguration.default().editImageTools
        if ZLPhotoConfiguration.default().showClipDirectlyIfOnlyHasClipTool, tools.count == 1, tools.contains(.clip) {
            let vc = ZLClipImageViewController(image: image, editRect: editModel?.editRect, angle: editModel?.angle ?? 0, selectRatio: editModel?.selectRatio)
            vc.clipDoneBlock = { (angle, editRect, ratio) in
                let m = ZLEditImageModel(editRect: editRect, angle: angle, selectRatio: ratio)
                completion?(image.clipImage(angle, editRect) ?? image, m)
            }
            vc.animate = animate
            vc.modalPresentationStyle = .fullScreen
            parentVC?.present(vc, animated: animate, completion: nil)
        } else {
            let vc = ZLEditImageViewController(image: image, editModel: editModel)
            vc.editFinishBlock = {  (ei, editImageModel) in
                completion?(ei, editImageModel)
            }
            vc.animate = animate
            vc.modalPresentationStyle = .fullScreen
            parentVC?.present(vc, animated: animate, completion: nil)
        }
    }
    
    @objc public init(image: UIImage, editModel: ZLEditImageModel? = nil) {
        self.originalImage = image
        self.editImage = image
        self.editRect = editModel?.editRect ?? CGRect(origin: .zero, size: image.size)
        
        self.angle = editModel?.angle ?? 0
        self.selectRatio = editModel?.selectRatio
        

        self.tools = ZLPhotoConfiguration.default().editImageTools
        
        super.init(nibName: nil, bundle: nil)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupUI()
        
        self.rotationImageView()
    }
    
    public override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        guard self.shouldLayout else {
            return
        }
        self.shouldLayout = false
        zl_debugPrint("edit image layout subviews")
        var insets = UIEdgeInsets(top: 20, left: 0, bottom: 0, right: 0)
        if #available(iOS 11.0, *) {
            insets = self.view.safeAreaInsets
        }
        insets.top = max(20, insets.top)
        
        self.scrollView.frame = self.view.bounds
        self.resetContainerViewFrame()
        
        self.topShadowView.frame = CGRect(x: 0, y: 0, width: self.view.frame.width, height: 150)
        self.topShadowLayer.frame = self.topShadowView.bounds
        self.cancelBtn.frame = CGRect(x: 30, y: insets.top+10, width: 28, height: 28)
        
        self.bottomShadowView.frame = CGRect(x: 0, y: self.view.frame.height-140-insets.bottom, width: self.view.frame.width, height: 140+insets.bottom)
        self.bottomShadowLayer.frame = self.bottomShadowView.bounds
        
        self.revokeBtn.frame = CGRect(x: self.view.frame.width - 15 - 35, y: 30, width: 35, height: 30)
        
        let toolY: CGFloat = 85
        
        let doneBtnH = ZLLayout.bottomToolBtnH
        let doneBtnW = localLanguageTextValue(.editFinish).boundingRect(font: ZLLayout.bottomToolTitleFont, limitSize: CGSize(width: CGFloat.greatestFiniteMagnitude, height: doneBtnH)).width + 20
        self.doneBtn.frame = CGRect(x: self.view.frame.width-20-doneBtnW, y: toolY-2, width: doneBtnW, height: doneBtnH)
        
        self.editToolCollectionView.frame = CGRect(x: 20, y: toolY, width: self.view.bounds.width - 20 - 20 - doneBtnW - 20, height: 30)
        
    
    }

    
    func resetContainerViewFrame() {
        
        self.imageView.image = self.editImage
        
        let editSize = self.editRect.size
        let scrollViewSize = self.scrollView.frame.size
        let ratio = min(scrollViewSize.width / editSize.width, scrollViewSize.height / editSize.height)
        let w = ratio * editSize.width * self.scrollView.zoomScale
        let h = ratio * editSize.height * self.scrollView.zoomScale
        self.containerView.frame = CGRect(x: max(0, (scrollViewSize.width-w)/2), y: max(0, (scrollViewSize.height-h)/2), width: w, height: h)
        
        let scaleImageOrigin = CGPoint(x: -self.editRect.origin.x*ratio, y: -self.editRect.origin.y*ratio)
        let scaleImageSize = CGSize(width: self.imageSize.width * ratio, height: self.imageSize.height * ratio)
        self.imageView.frame = CGRect(origin: scaleImageOrigin, size: scaleImageSize)
        self.mosaicImageLayer?.frame = self.imageView.bounds
        self.mosaicImageLayerMaskLayer?.frame = self.imageView.bounds

        // 针对于长图的优化
        if (self.editRect.height / self.editRect.width) > (self.view.frame.height / self.view.frame.width * 1.1) {
            let widthScale = self.view.frame.width / w
            self.scrollView.maximumZoomScale = widthScale
            self.scrollView.zoomScale = widthScale
            self.scrollView.contentOffset = .zero
        } else if self.editRect.width / self.editRect.height > 1 {
            self.scrollView.maximumZoomScale = max(3, self.view.frame.height / h)
        }
        
        self.originalFrame = self.view.convert(self.containerView.frame, from: self.scrollView)
        self.isScrolling = false
    }
    
    func setupUI() {
        self.view.backgroundColor = .black
        
        self.scrollView = UIScrollView()
        self.scrollView.backgroundColor = .black
    
        self.scrollView.delegate = self
        self.view.addSubview(self.scrollView)
        
        self.containerView = UIView()
        self.containerView.clipsToBounds = true
        self.scrollView.addSubview(self.containerView)
        
        self.imageView = UIImageView(image: self.originalImage)
        self.imageView.contentMode = .scaleAspectFit
        self.imageView.clipsToBounds = true
        self.imageView.backgroundColor = .black
        self.containerView.addSubview(self.imageView)
        
        let color1 = UIColor.black.withAlphaComponent(0.35).cgColor
        let color2 = UIColor.black.withAlphaComponent(0).cgColor
        self.topShadowView = UIView()
        self.view.addSubview(self.topShadowView)
        
        self.topShadowLayer = CAGradientLayer()
        self.topShadowLayer.colors = [color1, color2]
        self.topShadowLayer.locations = [0, 1]
        self.topShadowView.layer.addSublayer(self.topShadowLayer)
        
        self.cancelBtn = UIButton(type: .custom)
        self.cancelBtn.setImage(getImage("zl_retake"), for: .normal)
        self.cancelBtn.addTarget(self, action: #selector(cancelBtnClick), for: .touchUpInside)
        self.cancelBtn.adjustsImageWhenHighlighted = false
        self.cancelBtn.zl_enlargeValidTouchArea(inset: 30)
        self.topShadowView.addSubview(self.cancelBtn)
        
        self.bottomShadowView = UIView()
        self.view.addSubview(self.bottomShadowView)
        
        self.bottomShadowLayer = CAGradientLayer()
        self.bottomShadowLayer.colors = [color2, color1]
        self.bottomShadowLayer.locations = [0, 1]
        self.bottomShadowView.layer.addSublayer(self.bottomShadowLayer)
        
        let editToolLayout = UICollectionViewFlowLayout()
        editToolLayout.itemSize = CGSize(width: 30, height: 30)
        editToolLayout.minimumLineSpacing = 20
        editToolLayout.minimumInteritemSpacing = 20
        editToolLayout.scrollDirection = .horizontal
        self.editToolCollectionView = UICollectionView(frame: .zero, collectionViewLayout: editToolLayout)
        self.editToolCollectionView.backgroundColor = .clear
        self.editToolCollectionView.delegate = self
        self.editToolCollectionView.dataSource = self
        self.editToolCollectionView.showsHorizontalScrollIndicator = false
        self.bottomShadowView.addSubview(self.editToolCollectionView)
        
        ZLEditToolCell.zl_register(self.editToolCollectionView)
        
        self.doneBtn = UIButton(type: .custom)
        self.doneBtn.titleLabel?.font = ZLLayout.bottomToolTitleFont
        self.doneBtn.backgroundColor = .bottomToolViewBtnNormalBgColor
        self.doneBtn.setTitle(localLanguageTextValue(.editFinish), for: .normal)
        self.doneBtn.addTarget(self, action: #selector(doneBtnClick), for: .touchUpInside)
        self.doneBtn.layer.masksToBounds = true
        self.doneBtn.layer.cornerRadius = ZLLayout.bottomToolBtnCornerRadius
        self.bottomShadowView.addSubview(self.doneBtn)
        
        self.revokeBtn = UIButton(type: .custom)
        self.revokeBtn.setImage(getImage("zl_revoke_disable"), for: .disabled)
        self.revokeBtn.setImage(getImage("zl_revoke"), for: .normal)
        self.revokeBtn.adjustsImageWhenHighlighted = false
        self.revokeBtn.isEnabled = false
        self.revokeBtn.isHidden = true
   
        self.bottomShadowView.addSubview(self.revokeBtn)
        
        let ashbinSize = CGSize(width: 160, height: 80)
        self.ashbinView = UIView(frame: CGRect(x: (self.view.frame.width-ashbinSize.width)/2, y: self.view.frame.height-ashbinSize.height-40, width: ashbinSize.width, height: ashbinSize.height))
        self.ashbinView.backgroundColor = ZLEditImageViewController.ashbinNormalBgColor
        self.ashbinView.layer.cornerRadius = 15
        self.ashbinView.layer.masksToBounds = true
        self.ashbinView.isHidden = true
        self.view.addSubview(self.ashbinView)
        
        self.ashbinImgView = UIImageView(image: getImage("zl_ashbin"), highlightedImage: getImage("zl_ashbin_open"))
        self.ashbinImgView.frame = CGRect(x: (ashbinSize.width-25)/2, y: 15, width: 25, height: 25)
        self.ashbinView.addSubview(self.ashbinImgView)
        
        let asbinTipLabel = UILabel(frame: CGRect(x: 0, y: ashbinSize.height-34, width: ashbinSize.width, height: 34))
        asbinTipLabel.font = getFont(12)
        asbinTipLabel.textAlignment = .center
        asbinTipLabel.textColor = .white
        asbinTipLabel.text = localLanguageTextValue(.textStickerRemoveTips)
        asbinTipLabel.numberOfLines = 2
        asbinTipLabel.lineBreakMode = .byCharWrapping
        self.ashbinView.addSubview(asbinTipLabel)
        
    }
    
    func rotationImageView() {
        let transform = CGAffineTransform(rotationAngle: self.angle.toPi)
        self.imageView.transform = transform
    }
    
    @objc func cancelBtnClick() {
        self.dismiss(animated: self.animate, completion: nil)
    }
    
    
    func clipBtnClick() {
        let currentEditImage = editImage
        let vc = ZLClipImageViewController(image: currentEditImage, editRect: self.editRect, angle: self.angle, selectRatio: self.selectRatio)
        let rect = self.scrollView.convert(self.containerView.frame, to: self.view)
        vc.presentAnimateFrame = rect
        vc.presentAnimateImage = currentEditImage.clipImage(self.angle, self.editRect)
        vc.modalPresentationStyle = .fullScreen
        
        vc.clipDoneBlock = { [weak self] (angle, editFrame, selectRatio) in
            guard let `self` = self else { return }
        
            if self.angle != angle {
                self.angle = angle
                self.rotationImageView()
            }
            self.editRect = editFrame
            self.selectRatio = selectRatio
            self.resetContainerViewFrame()
         
        }
        
        vc.cancelClipBlock = { [weak self] () in
            self?.resetContainerViewFrame()
        }
        
        self.present(vc, animated: false) {
            self.scrollView.alpha = 0
            self.topShadowView.alpha = 0
            self.bottomShadowView.alpha = 0
        }
    }

    
    @objc func doneBtnClick() {
        
        var hasEdit = true
        if self.editRect.size == self.imageSize, self.angle == 0{
            hasEdit = false
        }
        
        var resImage = self.originalImage
        var editModel: ZLEditImageModel? = nil
        if hasEdit {
            resImage = editImage
            resImage = resImage.clipImage(self.angle, self.editRect) ?? resImage
            editModel = ZLEditImageModel(editRect: self.editRect, angle: self.angle, selectRatio: self.selectRatio)
        }
        self.editFinishBlock?(resImage, editModel)
        
        self.dismiss(animated: self.animate, completion: nil)
    }
  
    
    func finishClipDismissAnimate() {
        self.scrollView.alpha = 1
        UIView.animate(withDuration: 0.1) {
            self.topShadowView.alpha = 1
            self.bottomShadowView.alpha = 1
        }
    }

}


extension ZLEditImageViewController: UIGestureRecognizerDelegate {
    
    public func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard self.imageStickerContainerIsHidden else {
            return false
        }
        if gestureRecognizer is UITapGestureRecognizer {
            if self.bottomShadowView.alpha == 1 {
                let p = gestureRecognizer.location(in: self.view)
                return !self.bottomShadowView.frame.contains(p)
            } else {
                return true
            }
        } else if gestureRecognizer is UIPanGestureRecognizer {
            guard let st = self.selectedTool else {
                return false
            }
            return (st == .draw || st == .mosaic) && !self.isScrolling
        }
        
        return true
    }
    
}


// MARK: scroll view delegate
extension ZLEditImageViewController: UIScrollViewDelegate {

    
    public func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        self.isScrolling = true
    }
    
    public func scrollViewDidEndDragging(_ scrollView: UIScrollView, willDecelerate decelerate: Bool) {
        guard scrollView == self.scrollView else {
            return
        }
        self.isScrolling = decelerate
    }
    
    public func scrollViewDidEndDecelerating(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        self.isScrolling = false
    }
    
    public func scrollViewDidEndScrollingAnimation(_ scrollView: UIScrollView) {
        guard scrollView == self.scrollView else {
            return
        }
        self.isScrolling = false
    }
    
}


extension ZLEditImageViewController: UICollectionViewDataSource, UICollectionViewDelegate {
    
    public func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
      
        return 1
    }
    
    public func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {

            let cell = collectionView.dequeueReusableCell(withReuseIdentifier: ZLEditToolCell.zl_identifier(), for: indexPath) as! ZLEditToolCell
            
            let toolType = self.tools[indexPath.row]
            cell.icon.isHighlighted = false
            cell.toolType = toolType
            cell.icon.isHighlighted = toolType == self.selectedTool
            
            return cell
      
    }
    
    public func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
            clipBtnClick()
     
    }
    
}



extension ZLEditImageViewController {
    
    @objc public enum EditImageTool: Int {
        case draw
        case clip
        case imageSticker
        case textSticker
        case mosaic
        case filter
    }
    
}


// MARK: 裁剪比例

public class ZLImageClipRatio: NSObject {
    
    let title: String
    
    let whRatio: CGFloat
    
    @objc public init(title: String, whRatio: CGFloat) {
        self.title = title
        self.whRatio = whRatio
    }
    
}


func ==(lhs: ZLImageClipRatio, rhs: ZLImageClipRatio) -> Bool {
    return lhs.whRatio == rhs.whRatio
}




// MARK: Edit tool cell
class ZLEditToolCell: UICollectionViewCell {
    
    var toolType: ZLEditImageViewController.EditImageTool? {
        didSet {
            switch toolType {
            case .draw?:
                self.icon.image = getImage("zl_drawLine")
                self.icon.highlightedImage = getImage("zl_drawLine_selected")
            case .clip?:
                self.icon.image = getImage("zl_clip")
                self.icon.highlightedImage = getImage("zl_clip")
            case .imageSticker?:
                self.icon.image = getImage("zl_imageSticker")
                self.icon.highlightedImage = getImage("zl_imageSticker")
            case .textSticker?:
                self.icon.image = getImage("zl_textSticker")
                self.icon.highlightedImage = getImage("zl_textSticker")
            case .mosaic?:
                self.icon.image = getImage("zl_mosaic")
                self.icon.highlightedImage = getImage("zl_mosaic_selected")
            case .filter?:
                self.icon.image = getImage("zl_filter")
                self.icon.highlightedImage = getImage("zl_filter_selected")
            default:
                break
            }
        }
    }
    
    var icon: UIImageView!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        
        self.icon = UIImageView(frame: self.contentView.bounds)
        self.contentView.addSubview(self.icon)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
}

