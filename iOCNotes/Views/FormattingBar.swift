// SPDX-FileCopyrightText: Nextcloud GmbH
// SPDX-License-Identifier: GPL-3.0-or-later

import UIKit

///
/// The editor's formatting bar above the keyboard, modeled on the menu bar of Nextcloud Text.
///
/// The groups scroll sideways on narrow screens and spread out when there is room.
///
final class FormattingBar: UIInputView {
    /// Without a software keyboard the bar sits on the home indicator, whose safe area is far taller than it needs.
    private static let homeIndicatorClearance: CGFloat = 14

    private var bottomConstraint: NSLayoutConstraint?

    init(groups: [[UIButton]]) {
        super.init(frame: CGRect(x: 0, y: 0, width: 320, height: 52), inputViewStyle: .keyboard)

        allowsSelfSizing = true
        autoresizingMask = .flexibleHeight

        let row = UIStackView()
        row.axis = .horizontal
        row.alignment = .center
        row.distribution = .equalSpacing
        row.spacing = 2
        row.translatesAutoresizingMaskIntoConstraints = false

        for (index, group) in groups.enumerated() {
            if index > 0 {
                row.addArrangedSubview(Self.divider())
            }

            group.forEach(row.addArrangedSubview)
        }

        let scrollView = ButtonScrollView()
        scrollView.showsHorizontalScrollIndicator = false
        scrollView.delaysContentTouches = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.addSubview(row)
        addSubview(scrollView)

        let hairline = UIView()
        hairline.backgroundColor = .separator
        hairline.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hairline)

        let bottomConstraint = scrollView.bottomAnchor.constraint(equalTo: bottomAnchor)
        self.bottomConstraint = bottomConstraint

        NSLayoutConstraint.activate([
            bottomConstraint,
            hairline.topAnchor.constraint(equalTo: topAnchor),
            hairline.leadingAnchor.constraint(equalTo: leadingAnchor),
            hairline.trailingAnchor.constraint(equalTo: trailingAnchor),
            hairline.heightAnchor.constraint(equalToConstant: 1 / traitCollection.displayScale),

            scrollView.topAnchor.constraint(equalTo: topAnchor),
            scrollView.heightAnchor.constraint(equalToConstant: 52),
            scrollView.leadingAnchor.constraint(equalTo: safeAreaLayoutGuide.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: safeAreaLayoutGuide.trailingAnchor),

            row.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -8),
            row.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
            row.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
            row.heightAnchor.constraint(equalTo: scrollView.frameLayoutGuide.heightAnchor),
            row.widthAnchor.constraint(greaterThanOrEqualTo: scrollView.frameLayoutGuide.widthAnchor, constant: -16)
        ])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var intrinsicContentSize: CGSize {
        CGSize(width: UIView.noIntrinsicMetric, height: UIView.noIntrinsicMetric)
    }

    override func safeAreaInsetsDidChange() {
        super.safeAreaInsetsDidChange()

        bottomConstraint?.constant = safeAreaInsets.bottom > 0 ? -Self.homeIndicatorClearance : 0
    }

    /// Selected buttons show the format at the cursor as active, like Nextcloud Text does.
    static func button(_ symbol: String, _ label: String) -> UIButton {
        var configuration = UIButton.Configuration.plain()
        configuration.image = UIImage(systemName: symbol, withConfiguration: UIImage.SymbolConfiguration(pointSize: 17, weight: .medium))
        configuration.cornerStyle = .medium
        configuration.contentInsets = NSDirectionalEdgeInsets(top: 8, leading: 9, bottom: 8, trailing: 9)

        let button = UIButton(configuration: configuration)
        button.accessibilityLabel = label
        button.configurationUpdateHandler = { button in
            button.configuration?.baseForegroundColor = button.isEnabled ? (button.isSelected ? .tintColor : .label) : .tertiaryLabel
            button.configuration?.background.backgroundColor = button.isSelected ? .tintColor.withAlphaComponent(0.15) : .clear
        }

        return button
    }

    /// Opens `menu` on tap; it is rebuilt every time so check marks follow the text.
    static func menuButton(_ symbol: String, _ label: String, menu: @escaping () -> [UIMenuElement]) -> UIButton {
        let button = button(symbol, label)
        button.showsMenuAsPrimaryAction = true
        button.menu = UIMenu(children: [UIDeferredMenuElement.uncached { completion in completion(menu()) }])

        return button
    }

    /// Buttons cover almost the whole row, so a swipe must be able to take the touch from them to scroll.
    private final class ButtonScrollView: UIScrollView {
        override func touchesShouldCancel(in view: UIView) -> Bool {
            true
        }
    }

    private static func divider() -> UIView {
        let divider = UIView()
        divider.backgroundColor = .separator
        divider.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.heightAnchor.constraint(equalToConstant: 22)
        ])

        return divider
    }
}
