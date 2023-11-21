//
//  CameraManager.swift
//  ARGo
//
//  Created by Barak Ben Hur on 20/11/2023.
//

import AVFoundation
import UIKit

class CameraManager: NSObject {
    static var isAuthorized: Bool {
        return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
    
    static var authorizationPopup: UIAlertController = {
        let popup = UIAlertController(title: NSLocalizedString("camera title", comment: ""), message: NSLocalizedString("camera body", comment: ""), preferredStyle: .alert)
        let ok = UIAlertAction(title: NSLocalizedString("ok", comment: ""), style: .destructive)
        let settings = UIAlertAction(title: NSLocalizedString("settings", comment: ""), style: .default) { _ in
            guard let url = URL(string: UIApplication.openSettingsURLString),
                  UIApplication.shared.canOpenURL(url) else {
                assertionFailure("Not able to open App settings")
                return
            }
            
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
        popup.addAction(ok)
        popup.addAction(settings)
        
        return popup
    }()
    
    static func askforCameraPermission(_ complition: @escaping (_ granted: Bool) -> ()) {
        if AVCaptureDevice.authorizationStatus(for: .video) == .authorized {
            complition(true)
        } else {
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { (granted: Bool) -> Void in
                complition(granted)
            })
        }
    }
}
