//
//  LaunchViewController.swift
//  The One
//
//  Created by ברק בן חור on 16/04/2022.
//

import UIKit
import SwiftyGif

class LaunchViewController: UIViewController {
    @IBOutlet weak var logoAnimationView: LogoAnimationView!
    @IBOutlet weak var arTitle: UILabel!
    
    private var gifDidFinsih = false
    
    override func viewDidLoad() {
        super.viewDidLoad()
        logoAnimationView.delegate = self
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        animateBeginning()
    }
    
    private func animateBeginning() {
        UIView.animate(withDuration: 1) { [weak self] in
            self?.arTitle.alpha = 0
        }
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 0.4) { [weak self] in
            UIView.animate(withDuration: 0.1) { [weak self] in
                self?.logoAnimationView.alpha = 1
            }
        }
    }
}

extension LaunchViewController: SwiftyGifDelegate {
    func gifDidLoop(sender: UIImageView) {
        gifDidFinsih = true
        let sb = UIStoryboard(name: "Main", bundle: nil)
        let containerViewController = sb.instantiateViewController(withIdentifier: "search")
        containerViewController.modalPresentationStyle = .fullScreen
        containerViewController.modalTransitionStyle = .crossDissolve
        present(containerViewController, animated: true)
        
       let appDelegate = UIApplication.shared.delegate as? AppDelegate
        appDelegate?.setRootViewController(vc: containerViewController)
        
        self.logoAnimationView?.isHidden = true
        self.logoAnimationView?.removeFromSuperview()
    }
}
