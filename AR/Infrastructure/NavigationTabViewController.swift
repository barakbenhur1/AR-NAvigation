//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

protocol TabBarViewController: UIViewController {
    func setRoutes(routes: [MKRoute])
}

class NavigationTabViewController: UIViewController {
    private var tabBar: UITabBarController!
    private var viewControllers: [TabBarViewController]!
    
    private var routes: [MKRoute]!
    private var location: CLLocationCoordinate2D!

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar = UITabBarController()
        
        let map = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "map") as! RegularNavigationViewController
        let ar = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ar") as! ARNavigationViewController
        viewControllers = [map, ar]
       
        tabBar.setViewControllers(viewControllers, animated: true)
        
        tabBar.view.addTo(view: view)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateRoute(notification:)), name: .init("updateRoute"), object: nil)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateRoute(notification: Notification) {
        guard let routes = notification.object as? [MKRoute] else { return }
        guard self.routes == nil else { return }
        self.routes = routes
        viewControllers.forEach({ viewController in
            viewController.setRoutes(routes: routes)
        })
    }
}
