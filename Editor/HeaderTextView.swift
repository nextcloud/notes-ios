//
//  PBHHeaderTextView.swift
//  iOCNotes
//
//  Created by Peter Hedlund on 6/20/16.
//  Copyright © 2022 Peter Hedlund. All rights reserved.
//

import UIKit

class HeaderTextView: UITextView {

    let smallPadding: CGFloat = 20.0

    private var noteTextStorage = MarkdownTextStorage()
    private var checkBoxTapHandler = CheckBoxTapHandler()

    private var containerInset = UIEdgeInsets(top: 20, left: 20, bottom: 20, right: 20);

    /// Sits above the text, hidden until the note is pulled down past it.
    let dateLabel: UILabel = {
        let label = UILabel()
        label.translatesAutoresizingMaskIntoConstraints = false
        label.textAlignment = .center
        label.font = .preferredFont(forTextStyle: .subheadline)
        label.adjustsFontForContentSizeCategory = true

        return label
    }()

    private var isDateShown = false {
        didSet {
            contentInset.top = isDateShown ? dateHeight : 0
        }
    }

    /// The date plus padding to keep it off the navigation bar.
    private var dateHeight: CGFloat {
        ceil(dateLabel.font.lineHeight) + smallPadding
    }

    override init(frame: CGRect, textContainer: NSTextContainer?) {
        let attributedString = NSAttributedString(string: "")
        noteTextStorage.setAttributedString(attributedString)

        let containerSize = CGSize(width: frame.size.width, height:CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer(size: containerSize)
        container.widthTracksTextView = true

        let layoutManager = LayoutManager()
        layoutManager.delegate = layoutManager
        layoutManager.addTextContainer(container)
        noteTextStorage.addLayoutManager(layoutManager)

        super.init(frame: frame, textContainer: container)
        self.addGestureRecognizer(checkBoxTapHandler.tapGestureRecognizer)
        checkBoxTapHandler.textView = self
        checkBoxTapHandler.layoutManager = layoutManager
        self.textContainerInset = containerInset
        self.translatesAutoresizingMaskIntoConstraints = false
        self.setUpDateLabel()
        self.backgroundColor = UIColor.systemBackground
        self.tintColor = UIColor.systemBlue
        self.traitCollectionDidChange(nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    func setup() {
        self.textContainerInset = containerInset
        self.translatesAutoresizingMaskIntoConstraints = false
        self.setUpDateLabel()
        
        let attributedString = NSAttributedString(string: "")
        noteTextStorage.setAttributedString(attributedString)
        
        let textViewRect = self.frame;
        let layoutManager = LayoutManager()
        
        let containerSize = CGSize(width:textViewRect.size.width, height:CGFloat.greatestFiniteMagnitude)
        let container = NSTextContainer.init(size: containerSize)
        container.widthTracksTextView = true
        
        layoutManager.addTextContainer(container)
        noteTextStorage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        self.backgroundColor = UIColor.systemBackground
        self.tintColor = UIColor.systemBlue
        self.traitCollectionDidChange(nil)
    }
    
    private func setUpDateLabel() {
        // Lets short notes be pulled down too.
        alwaysBounceVertical = true

        addSubview(dateLabel)

        NSLayoutConstraint.activate([
            dateLabel.bottomAnchor.constraint(equalTo: contentLayoutGuide.topAnchor),
            dateLabel.leadingAnchor.constraint(equalTo: frameLayoutGuide.leadingAnchor, constant: smallPadding),
            dateLabel.trailingAnchor.constraint(equalTo: frameLayoutGuide.trailingAnchor, constant: -smallPadding)
        ])
    }

    /// Call when a drag ends: pulling past half the date shows or hides it, and it never rests half visible.
    func settleDate(targetContentOffset: UnsafeMutablePointer<CGPoint>) {
        let minY = -adjustedContentInset.top
        let maxY = max(minY, contentSize.height + adjustedContentInset.bottom - bounds.height)
        let target = targetContentOffset.pointee.y

        // While rubber-banding, the target is just the nearest edge, so use how far the user pulled instead.
        let pulledY = (minY...maxY).contains(contentOffset.y) ? target : contentOffset.y

        if isDateShown {
            let height = contentInset.top

            // Scrolling on into the text keeps the date for when the user comes back up.
            guard target <= minY + height else { return }

            if pulledY > minY + height / 2 {
                targetContentOffset.pointee.y = minY + height
                isDateShown = false
            } else {
                targetContentOffset.pointee.y = minY
            }
        } else if pulledY < minY - dateHeight / 2 {
            targetContentOffset.pointee.y = minY - dateHeight
            isDateShown = true
        }
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        if (self.traitCollection.horizontalSizeClass == .regular) {
            if (self.traitCollection.userInterfaceIdiom == .pad) {
                if (UIScreen.main.bounds.size.width > UIScreen.main.bounds.size.height) {
                    self.updateInsets(size: 178)
                } else {
                    self.updateInsets(size: 50)
                }
            } else {
                self.updateInsets(size: smallPadding)
            }
        } else {
            self.updateInsets(size: smallPadding)
        }
        self.isScrollEnabled = false
        self.isScrollEnabled = true
    }

    override var text: String! {
        get {
            return noteTextStorage.string
        }
        set {
            noteTextStorage.beginEditing()
            let attributedString = newValue != nil ? NSAttributedString(string: newValue) : NSAttributedString()
            noteTextStorage.setAttributedString(attributedString)
            noteTextStorage.endEditing()
        }
    }

    open func updateInsets(size: CGFloat) {
        self.textContainerInset = UIEdgeInsets(top: smallPadding, left: size, bottom: smallPadding, right: size)
    }

}

extension HeaderTextView: UITextDropDelegate {

    func textDroppableView(_ textDroppableView: UIView & UITextDroppable, proposalForDrop drop: UITextDropRequest) -> UITextDropProposal {
        if drop.isSameView {
            return UITextDropProposal(operation: .move)
        } else {
            return UITextDropProposal(operation: .copy)
        }
    }
        
}
