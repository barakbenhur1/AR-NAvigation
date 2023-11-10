//
//  LocationApprovalViewController.swift
//  ARGo
//
//  Created by ברק בן חור on 10/11/2023.
//

import UIKit

class LocationApprovalViewController: UIViewController {
    @IBAction func goToSettings(_ sender: UIButton) {
        guard let url = URL(string:UIApplication.openSettingsURLString) else { return }
        guard UIApplication.shared.canOpenURL(url) else { return }
        UIApplication.shared.open(url)
        dismiss(animated: false)
    }
}
