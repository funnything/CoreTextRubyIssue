//
//  ViewController.swift
//  CoreTextRubyIssue
//
//  Created by Yosaku Toyama on 2019/11/17.
//  Copyright © 2019 Yosaku Toyama. All rights reserved.
//

import Cartography
import Then
import UIKit

class ViewController: UIViewController {
    let good = """
    行をまたぐパターンを試したいのだけど、調べてみたら東京箱根間往復大学駅伝競走《とうきょうはこねかんおうふくだいがくえきでんきょうそう》が長い
    |忠《ちゆう》
    """

    let bad = """
    行をまたぐパターンを試したいのだけど、調べてみたら東京箱根間往復大学駅伝競走《とうきょうはこねかんおうふくだいがくえきでんきょうそう》が長い
    |忠《ちゆ》
    """
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationController?.isToolbarHidden = true
        
        let sv = UIStackView().then {
            $0.axis = .vertical
            $0.spacing = 16
            view.addSubview($0)
            constrain($0, car_topLayoutGuide) { v, top in
                let sv = v.superview!
                v.top == top.bottom
                v.leading == sv.leading + 16
                v.trailing == sv.trailing - 16
            }
        }

        _ = RubyLabel().then {
            $0.font = UIFont(name: "HiraKakuProN-W3", size: UIFont.systemFontSize - 2)!
            $0.set(text: good)
            sv.addArrangedSubview($0)
        }

        _ = RubyLabel().then {
            $0.font = UIFont(name: "HiraKakuProN-W3", size: UIFont.systemFontSize - 2)!
            $0.set(text: bad)
            sv.addArrangedSubview($0)
        }
    }
}

class RubyLabel: UILabel {
    func set(text: String) {
        attributedText = processRuby(string: text)
    }

    typealias MatchRange = (whole: Range<Int>, rubyText: Range<Int>?)

    func processRuby(string: String) -> NSAttributedString {
        let ret = NSMutableAttributedString()
        
        // NOTE:
        // この正規表現だと
        // - 対応していない括弧のペアにもマッチしてしまう
        // - ネストした括弧をうまく扱えない可能性がある
        let matches: [MatchRange] = re("(《|\\(|（)(.+?)(》|\\)|）)").matches(in: string).map { (Range($0.range)!, Range($0.range(at: 2))!) }
        let withEnds = [(0..<0, nil)] + matches // + [(NSRange(location: string.count, length: 0), nil)]
        withEnds.forEachWithNext { before, current in
            let beforeUpper = before.whole.upperBound
            
            if let current = current {
                ret.append(processRubySegment(string: string, beforeUpper: beforeUpper, current: current))
            } else {
                ret.append(NSAttributedString(string: string[beforeUpper..<string.count]))
            }
        }
        
        return ret
    }
    
    func processRubySegment(string: String, beforeUpper: Int, current: MatchRange) -> NSAttributedString {
        let currentLower = current.whole.lowerBound
        let middleText = string[beforeUpper..<currentLower]
        let rubyText = string[current.rubyText!.lowerBound..<current.rubyText!.upperBound]
        
        let usualPart: String
        let rubyPart: String?
        if let bar = middleText.range(of: "|", options: .backwards) ?? middleText.range(of: "｜", options: .backwards) {
            let barPos = middleText.offset(bar)
            
            usualPart = middleText[0..<barPos.lowerBound]
            rubyPart = middleText[barPos.upperBound..<middleText.count]
        } else {
            if let match = re("[\\p{Han}]+$").firstMatch(in: middleText).map({ Range($0.range)! }) {
                usualPart = middleText[0..<match.lowerBound]
                rubyPart = middleText[match]
            } else {
                // NOTE: irregular case
                usualPart = string[beforeUpper..<current.whole.upperBound]
                rubyPart = nil
            }
        }
        
        let ret = NSMutableAttributedString()
        ret.append(NSAttributedString(string: usualPart))
        
        if let rubyPart = rubyPart {
            var text: [Unmanaged<CFString>?] = [Unmanaged<CFString>.passRetained(rubyText as CFString) as Unmanaged<CFString>, .none, .none, .none]
            let annotation = CTRubyAnnotationCreate(.auto, .auto, 0.5, &text[0])
            
            ret.append(NSAttributedString(string: rubyPart, attributes: [kCTRubyAnnotationAttributeName as NSAttributedString.Key: annotation]))
        }
        
        return ret
    }

    override func draw(_ rect: CGRect) {
        guard let context = UIGraphicsGetCurrentContext(),
            let attributed = self.attributedText else {
                return
        }

        context.setFillColor(UIColor.gray.withAlphaComponent(0.1).cgColor)
        context.fill(bounds)

        context.translateBy(x: 0, y: bounds.height)
        context.scaleBy(x: 1.0, y: -1.0)
        context.textMatrix = CGAffineTransform.identity

        let frame = CTFramesetterCreateFrame(
            CTFramesetterCreateWithAttributedString(attributed),
            CFRangeMake(0, attributed.length),
            CGPath(rect: bounds, transform: nil),
            nil
        )

        CTFrameDraw(frame, context)
    }

    override var intrinsicContentSize: CGSize {
        guard let svWidth = superview?.bounds.width else {
            return CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
        }

        // TODO: should consider margin
        let width = svWidth
        let attributed = attributedText!
        let setter = CTFramesetterCreateWithAttributedString(attributed)
        return CTFramesetterSuggestFrameSizeWithConstraints(
            setter,
            CFRange(location: 0, length: attributed.length),
            nil,
            CGSize(width: width, height: CGFloat.greatestFiniteMagnitude),
            nil
        )
    }

    // quick-fix umm...
    override func layoutSubviews() {
        super.layoutSubviews()
        invalidateIntrinsicContentSize()
    }
}

func re(_ pattern: String) -> NSRegularExpression {
    // swiftlint:disable:next force_try
    return try! NSRegularExpression(pattern: pattern)
}

extension NSRegularExpression {
    func matches(in string: String) -> [NSTextCheckingResult] {
        return matches(in: string, range: NSRange(location: 0, length: string.count))
    }

    func firstMatch(in string: String) -> NSTextCheckingResult? {
        return firstMatch(in: string, range: NSRange(location: 0, length: string.count))
    }
}

extension String {
    func offset(_ index: String.Index) -> Int {
        return distance(from: startIndex, to: index)
    }

    func offset(_ range: Range<String.Index>) -> Range<Int> {
        return offset(range.lowerBound)..<offset(range.upperBound)
    }

    subscript(_ r: Range<Int>) -> String {
        let from = index(startIndex, offsetBy: r.lowerBound)
        let to = index(startIndex, offsetBy: r.upperBound)
        return String(self[from..<to])
    }
}

extension Sequence {
    func mapWithNext<T>(_ transform: (Element, Element?) -> T) -> [T] {
        var mapped = [T]()

        var prev: Element?

        forEach { current in
            if let prev = prev {
                mapped.append(transform(prev, current))
            }
            prev = current
        }

        if let prev = prev {
            mapped.append(transform(prev, nil))
        }

        return mapped
    }

    func forEachWithNext(_ body: (Element, Element?) -> Void) {
        _ = mapWithNext(body)
    }
}
