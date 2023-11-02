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
import ARKit

class ARNavigationView: UIView {
    private var sceneView: SceneLocationView!
    private var location: CLLocationCoordinate2D?
    private var routes: [MKRoute]! {
        didSet {
            addSceneModels()
        }
    }
    
    var userAnnotation: MKPointAnnotation?
    var locationEstimateAnnotation: MKPointAnnotation?
    
    var updateUserLocationTimer: Timer?
    var updateInfoLabelTimer: Timer?
    
    var centerMapOnUserLocation: Bool = true
    
    let displayDebugging = false
    
    let adjustNorthByTappingSidesOfScreen = false
    let addNodeByTappingScreen = true
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        sceneView = SceneLocationView()
        sceneView.addTo(view: self)
        
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        
        sceneView.orientToTrueNorth = true
        sceneView.moveSceneHeadingClockwise()
        sceneView.locationEstimateMethod = .mostRelevantEstimate
        sceneView.showAxesNode = false
        sceneView.showFeaturePoints = displayDebugging
        sceneView.arViewDelegate = self
        
        toggleFlashIfNeeded()
        turneFlashOff()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    private let flashLavel: Float = 2500
    func toggleFlashIfNeeded() {
        DispatchQueue.main.asyncAfter(wallDeadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            guard let device = AVCaptureDevice.default(for: .video), device.iso >= self.flashLavel, device.hasTorch else { return }
            try? device.lockForConfiguration()
            try? device.setTorchModeOn(level: 1.0)
            device.torchMode = .on
            device.unlockForConfiguration()
        }
    }
    
    func turneFlashOff() {
        let device = AVCaptureDevice.default(for: .video)
        guard let device = device, device.hasTorch else { return }
        try? device.lockForConfiguration()
        device.torchMode = .off
        device.unlockForConfiguration()
    }
}

// MARK: - Implementation

@available(iOS 11.0, *)
extension ARNavigationView {
    
    /// Adds the appropriate ARKit models to the scene.  Note: that this won't
    /// do anything until the scene has a `currentLocation`.  It "polls" on that
    /// and when a location is finally discovered, the models are added.
    func addSceneModels() {
        // 1. Don't try to add the models to the scene until we have a current location
        guard sceneView.sceneLocationManager.currentLocation != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.addSceneModels()
            }
            return
        }
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            if let routes = routes {
                sceneView.addRoutes(routes: routes) { distance -> SCNBox in
                    let box = SCNBox(width: 8, height: 0.2, length: distance, chamferRadius: 0.25)
                    box.firstMaterial?.diffuse.contents = UIColor.yellow.withAlphaComponent(0.9)
                    return box
                }
                
                guard let route = routes.first else { return }
                var lastBearing = 0.00
                for i in 1..<route.steps.count {
                    let step = route.steps[i]
                    let coordinate = step.polyline.coordinate
                    let altitude = sceneView.sceneLocationManager.currentLocation?.altitude ?? 0
                    
                    let annotationNode = self.buildViewNode(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: altitude, text:  step.instructions)
                    annotationNode.scaleRelativeToDistance = true
                    annotationNode.scalingScheme = .normal
                    self.sceneView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
                    
                    if route.steps.last == step {
                        let coordinate = step.polyline.coordinate
                        let altitude = sceneView.sceneLocationManager.currentLocation?.altitude ?? 4
                        let annotationNode = self.buildNode(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: altitude - 2, imageName: "destination")
                        annotationNode.scaleRelativeToDistance = true
                        annotationNode.scalingScheme = .normal
                        self.sceneView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
                    }
                    else {
                        let forword = {
                            let location = CLLocation(latitude: step.polyline.coordinate.latitude, longitude: step.polyline.coordinate.longitude)
                            let location2 = CLLocation(latitude: route.steps[i + 1].polyline.coordinate.latitude, longitude:  route.steps[i + 1].polyline.coordinate.longitude)
                            
                            let bearing = location.getBearingBetweenTwoPoints1(point1: location, point2: location2)
                            let isForword = bearing < lastBearing
                            lastBearing = bearing
                            return isForword
                        }()
                        
                        let imageName = forword ? "arrow" : "arrow_reversed"
                        let arrowNode = self.buildNode(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: altitude - 2, imageName: imageName)
                        arrowNode.scaleRelativeToDistance = true
                        arrowNode.scalingScheme = .normal
                        arrowNode.camera?.automaticallyAdjustsZRange = true
                        arrowNode.camera?.wantsDepthOfField = true
                        self.sceneView.addLocationNodeWithConfirmedLocation(locationNode: arrowNode)
                    }
                }
            }
        }
    }
    
    func buildNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                   altitude: CLLocationDistance, imageName: String) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        let image = UIImage(named: imageName)!
        return LocationAnnotationNode(location: location, image: image)
    }
    
    func buildViewNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                       altitude: CLLocationDistance, text: String) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        let label = UILabel(frame: CGRect(x: 0, y: 0, width: 200, height: 100))
        label.text = text
        label.adjustsFontSizeToFitWidth = true
        label.backgroundColor = .white.withAlphaComponent(0.9)
        label.textAlignment = .center
        label.layer.cornerRadius = 50
        label.layer.masksToBounds = true
        label.layer.borderColor = UIColor.black.cgColor
        label.layer.borderWidth = 1
        return LocationAnnotationNode(location: location, view: label)
    }
    
    func buildLayerNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                        altitude: CLLocationDistance, layer: CALayer) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        return LocationAnnotationNode(location: location, layer: layer)
    }
    
    func run() {
        sceneView.run()
    }
    
    func pause() {
        sceneView.pause()
    }
    
    func addRoutes(routes: [MKRoute]?) {
        guard let routes = routes else { return }
        self.routes = routes
    }
}

@available(iOS 11.0, *)
extension ARNavigationView: ARSCNViewDelegate {
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        print("Added SCNNode: \(node)")    // you probably won't see this fire
    }
    
    func renderer(_ renderer: SCNSceneRenderer, willUpdate node: SCNNode, for anchor: ARAnchor) {
        print("willUpdate: \(node)")    // you probably won't see this fire
    }
    
    func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
        print("Camera: \(camera)")
    }
    
}

// MARK: - Helpers

extension DispatchQueue {
    func asyncAfter(timeInterval: TimeInterval, execute: @escaping () -> Void) {
        self.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(timeInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
            execute: execute)
    }
}







