//
//  ARNavigationViewController.swift
//  AR
//
//  Created by ברק בן חור on 17/10/2023.
//

import UIKit
import ARCL
import CoreLocation
import SceneKit
import MapKit

class ARNavigationView: UIView {
    private var sceneView: SceneLocationView!
    private var location: CLLocationCoordinate2D?
    private var to: CLLocationCoordinate2D?
    private var route: MKRoute!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sceneView = SceneLocationView()
        sceneView.addTo(view: self)
        sceneView.locationNodeTouchDelegate = self
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func run() {
        sceneView.run()
    }
    
    func pause() {
        sceneView.pause()
    }
    
    func addRoute(route: MKRoute?) {
        guard let route = route else { return }
        if let route = self.route {
            sceneView.removeRoutes(routes: [route])
        }
        self.route = route
        sceneView.addRoutes(routes: [route])
    }
}

extension ARNavigationView: LNTouchDelegate {
    func annotationNodeTouched(node: AnnotationNode) {
        // Do stuffs with the node instance
        
        if let nodeLayer = node.layer {
            // Do stuffs with the nodeLayer
            // ...
        }
        
        // node could have either node.view or node.image
        if let nodeView = node.view {
            // Do stuffs with the nodeView
            // ...
        }
        if let nodeImage = node.image {
            // Do stuffs with the nodeImage
            // ...
        }
    }
    
    func locationNodeTouched(node: LocationNode) {
        guard let name = node.tag else { return }
        guard let selectedNode = node.childNodes.first(where: { $0.geometry is SCNBox }) else { return }
        
        // Interact with the selected node
    }
}
