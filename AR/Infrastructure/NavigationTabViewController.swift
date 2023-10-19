//
//  NavigationTabViewController.swift
//  AR
//
//  Created by ברק בן חור on 18/10/2023.
//

import UIKit
import MapKit

protocol TabBarViewController: UIViewController {
    func setRoute(route: MKRoute)
    func setLocation(location: CLLocationCoordinate2D)
}

class NavigationTabViewController: UIViewController {
    private var tabBar: UITabBarController!
    private var viewControllers: [TabBarViewController]!
    
    private var route: MKRoute!
    private var location: CLLocationCoordinate2D!

    override func viewDidLoad() {
        super.viewDidLoad()
        tabBar = UITabBarController()
        tabBar.delegate = self
        
        let map = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "map") as! RegularNavigationViewController
        let ar = UIStoryboard(name: "Main", bundle: nil).instantiateViewController(withIdentifier: "ar") as! ARNavigationViewController
        viewControllers = [map, ar]
       
        tabBar.setViewControllers(viewControllers, animated: true)
        
        tabBar.view.addTo(view: view)
        
        NotificationCenter.default.addObserver(self, selector: #selector(updateRoute(notification:)), name: .init("updateRoute"), object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(updateLocation(notification:)), name: .init("updateLocation"), object: nil)
        
        tabBarController(tabBar, didSelect: viewControllers[0])
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func updateRoute(notification: Notification) {
        guard let route = notification.object as? MKRoute else { return }
        self.route = route
        viewControllers.forEach({ viewController in
            viewController.setRoute(route: route)
        })
    }
    
    @objc func updateLocation(notification: Notification) {
        guard let location = notification.object as? CLLocationCoordinate2D else { return }
        self.location = location
        viewControllers[tabBar.selectedIndex].setLocation(location: location)
    }
}

extension NavigationTabViewController: UITabBarControllerDelegate {
    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        guard let viewController = viewController as? TabBarViewController else { return }
        guard let location = location else { return }
        viewController.setLocation(location: location)
    }
}
