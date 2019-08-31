//
//  AutoCompleteVC.swift
//  Beiwe
//
//  Created by He Yifei on 8/31/19.
//  Copyright © 2019 Rocketfarm Studios. All rights reserved.
//

import Foundation
import ResearchKit
import WebKit
import SearchTextField

class SearchTextFieldStep: ORKActiveStep {
	override func stepViewControllerClass() -> AnyClass {
		return SearchTextFieldStepViewController.self
	}
}

class SearchTextFieldStepViewController: ORKActiveStepViewController {
	override func viewDidLoad() {
		super.viewDidLoad()

		let newView = UIView();
		newView.translatesAutoresizingMaskIntoConstraints = false;
		self.customView = newView;
		newView.bindFrameToSuperviewBounds()

		let ttt = SearchTextField();
		ttt.filterStrings(DemoName.names)
		ttt.borderStyle = .roundedRect
		ttt.font = UIFont.systemFont(ofSize: 30)
		ttt.placeholder = "Enter the name...            "	// spaces are necessary somehow
		ttt.theme.font = UIFont.systemFont(ofSize: 20)
		ttt.theme.bgColor = .white;
		ttt.translatesAutoresizingMaskIntoConstraints = false;
		self.customView?.addSubview(ttt)
		ttt.topAnchor.constraint(equalTo: self.customView!.topAnchor, constant: 0).isActive = true
		ttt.leadingAnchor.constraint(equalTo: self.customView!.leadingAnchor, constant: 10).isActive = true
		ttt.trailingAnchor.constraint(equalTo: self.customView!.trailingAnchor, constant: -10).isActive = true
	}
}


extension UIView {

	/// Adds constraints to this `UIView` instances `superview` object to make sure this always has the same size as the superview.
	/// Please note that this has no effect if its `superview` is `nil` – add this `UIView` instance as a subview before calling this.
	func bindFrameToSuperviewBounds() {
		guard let superview = self.superview else {
			print("Error! `superview` was nil – call `addSubview(view: UIView)` before calling `bindFrameToSuperviewBounds()` to fix this.")
			return
		}

		self.translatesAutoresizingMaskIntoConstraints = false
		self.topAnchor.constraint(equalTo: superview.topAnchor, constant: 0).isActive = true
		self.bottomAnchor.constraint(equalTo: superview.bottomAnchor, constant: 0).isActive = true
		self.leadingAnchor.constraint(equalTo: superview.leadingAnchor, constant: 0).isActive = true
		self.trailingAnchor.constraint(equalTo: superview.trailingAnchor, constant: 0).isActive = true
	}
}
