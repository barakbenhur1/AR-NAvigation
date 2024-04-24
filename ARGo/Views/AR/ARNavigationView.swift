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

internal class ARNavigationViewViewModel: NSObject {
    private let flashLavel: Float!
    private var alt: CGFloat!
    
    override init() {
        flashLavel = 2500
        super.init()
    }
    
    func trackAltitude(sceneView: SceneLocationView, maxDiff: CGFloat, didChangeAltitud: @escaping () -> ()) {
        Timer.stopTimer(key: "trackAltitud")
        Timer.setTimer(key: "trackAltitud",time: 0.2) { [weak self] in
            guard let self else { return }
            guard let altitude = sceneView.sceneLocationManager.currentLocation?.altitude else { return }
            let currentLocation = abs(altitude)
            if alt == nil {
                alt = currentLocation
            }
            else if abs(alt - currentLocation) > maxDiff {
                alt = currentLocation
                didChangeAltitud()
            }
        }
    }
    
    func bearing(coordinate: CLLocationCoordinate2D, coordinate2: CLLocationCoordinate2D) -> CGFloat {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let location2 = CLLocation(latitude: coordinate2.latitude, longitude: coordinate2.longitude)
        
        let bearing = location.getBearingBetweenTwoPoints1(point1: location, point2: location2)
        return bearing
    }
    
    func toggleFlashIfNeeded() {
        Timer.setTimer(key: "toggleFlash", time: 2, repeats: false) {  [weak self] in
            guard let self else { return }
            guard let device = AVCaptureDevice.default(for: .video) else { return }
            guard device.hasTorch else { return }
            guard device.iso >= flashLavel  else {
                turnFlashOff()
                return
            }
            try? device.lockForConfiguration()
            try? device.setTorchModeOn(level: 1.0)
            device.torchMode = .on
            device.unlockForConfiguration()
        }
    }
    
    func turnFlashOff() {
        let device = AVCaptureDevice.default(for: .video)
        guard let device = device, device.hasTorch else { return }
        Timer.stopTimer(key: "toggleFlash")
        try? device.lockForConfiguration()
        device.torchMode = .off
        device.unlockForConfiguration()
    }
}

class ARNavigationView: UIView {
    private enum NodeType {
        case label(text: String, offset: CGFloat), image(name: String, offset: CGFloat)
    }
    
    //MARK: - Properties
    private let displayDebugging = false
    private var sceneView: SceneLocationView!
    private let viewModel: ARNavigationViewViewModel!
    private var currentRegion: Int!
    private let goToStart: GoToStartView!
    
    private var location: CLLocationCoordinate2D?
    private var routes: [MKRoute]!
    
    //MARK: - hepler blocks
    private lazy var annotationNode: (_ type: NodeType, _ coordinate: CLLocationCoordinate2D) -> (LocationAnnotationNode?) = { [ weak self] type, coordinate in
        guard let self = self else { return nil }
        let altitude = sceneView.sceneLocationManager.currentLocation!.altitude
        switch type {
        case .image(let imageName, let offset):
            return buildNode(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: altitude - offset, imageName: imageName)
        case .label(let text, let offset):
            return buildViewNode(latitude: coordinate.latitude, longitude: coordinate.longitude, altitude: altitude - offset, text: text)
        }
    }
    
    //    private var nodeAlpha: (_ current: Int, _ index: Int) -> (CGFloat) = { current, index in
    //        let currentIndex = abs(current - index)
    //        return max(0.8 - Double(currentIndex) * 0.1, 0.1)
    //    }
    //
    
    //MARK: - life cycle
    override init(frame: CGRect) {
        currentRegion = 0
        sceneView = SceneLocationView()
        goToStart = GoToStartView()
        viewModel = ARNavigationViewViewModel()
        
        super.init(frame: frame)
        initSceneView()
        initGoToStart()
        toggleFlashIfNeeded()
        turnFlashOff()
        sceneView.run()
        sceneView.pause()
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    //MARK: - Private Helpers
    //    func ajustAlpha() {
    //        let polylineNodes = sceneView.polylineNodes
    //        for i in 0..<polylineNodes.count {
    //            let node = polylineNodes[i]
    //            let alpha = nodeAlpha(currentRegion, i)
    //            node.geometry?.firstMaterial?.transparency = alpha
    //        }
    //
    //        let locationNodes = sceneView.locationNodes
    //        for i in 0..<locationNodes.count {
    //            if let node = locationNodes[i] as? LocationAnnotationNode {
    //                let alpha = nodeAlpha(currentRegion, i)
    //                node.annotationNode.view?.alpha = alpha
    //                node.geometry?.firstMaterial?.transparency = alpha
    //            }
    //        }
    //    }
    
    //MARK: - Helpers
    func stopTimers() {
        Timer.stopTimers()
    }
    
    func toggleFlashIfNeeded() {
        viewModel.toggleFlashIfNeeded()
    }
    
    func turnFlashOff() {
        viewModel.turnFlashOff()
    }
    
    private func initGoToStart() {
        goToStart.isHidden = true
        sceneView.addSubview(goToStart)
        goToStart.translatesAutoresizingMaskIntoConstraints = false
        
        NSLayoutConstraint.activate([
            goToStart.topAnchor.constraint(equalTo: sceneView.topAnchor),
            goToStart.leadingAnchor.constraint(equalTo: sceneView.leadingAnchor),
            goToStart.trailingAnchor.constraint(equalTo: sceneView.trailingAnchor),
            goToStart.bottomAnchor.constraint(equalTo: sceneView.bottomAnchor)
        ])
    }
    
    private func initSceneView() {
        sceneView.addTo(view: self)
        sceneView.autoenablesDefaultLighting = true
        sceneView.automaticallyUpdatesLighting = true
        sceneView.orientToTrueNorth = true
        sceneView.moveSceneHeadingClockwise()
        sceneView.locationEstimateMethod = .mostRelevantEstimate
        sceneView.showAxesNode = false
        sceneView.showFeaturePoints = displayDebugging
        sceneView.arViewDelegate = self
    }
    
    private func buildUI(routes: [MKRoute]?, complition: @escaping (_ showMap: Bool) -> ()) {
        // 1. Don't try to add the models to the scene until we have a current location
        guard sceneView.sceneLocationManager.currentLocation != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }
                buildUI(routes: routes, complition: complition)
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            guard let routes, let route = routes.first else { return }
//            if let step = route.steps.first {
//                guard sceneView.sceneLocationManager.currentLocation!.distance(from: CLLocation(latitude: step.polyline.coordinate.latitude, longitude: step.polyline.coordinate.longitude)) <= 10 else {
//                    goToStart.isHidden = false
//                    complition(true)
//                    return
//                }
//            }
            complition(false)
            addRoutes(routes: routes)
            addARViews(route: route)
            addARArrow()
        }
    }
    
    private func addRoutes(routes: [MKRoute]) {
        let routeColor: UIColor = {
            let isAll = UserDefaults.standard.bool(forKey: "isAllColors")
            if let hex = UserDefaults.standard.value(forKey: isAll ? "mapRouteColor" : "arRouteColor") as? String {
                return UIColor(hexString: hex)
            }
            return .systemYellow
        }()
        
        let polylines = routes.map { AttributedType(type: $0.polyline, attribute: $0.name) }
        sceneView.addRoutes(polylines: polylines, Δaltitude: -12) { distance in
            let box = SCNBox(width: 20, height: 0.4, length: distance, chamferRadius: 0.25)
            box.firstMaterial?.diffuse.contents = routeColor.withAlphaComponent(0.92)
            return box
        }
        
        sceneView.polylineNodes.forEach { node in node.scalingScheme = .linear(threshold: 0.1) }
        sceneView.locationNodes.forEach { node in node.scalingScheme = .linear(threshold: 0.1) }
    }
    
    private func addARArrow() {
        let arrow = ARArrow.sheard.arrow
        let color = {
            let isAll = UserDefaults.standard.bool(forKey: "isAllColors")
            if let hex = UserDefaults.standard.value(forKey: isAll ? "mapRouteColor" : "arArrowColor") as? String {
                return UIColor(hexString: hex)
            }
            return .systemYellow
        }()
        arrow.geometry?.firstMaterial?.diffuse.contents = color.withAlphaComponent(0.8)
        sceneView.scene.rootNode.addChildNode(ARArrow.sheard.arrow)
    }
    
    private func addARViews(route: MKRoute) {
        guard !route.steps.isEmpty else { return }
        addNode(route: route, coordinate:  route.steps.first!.polyline.coordinate, type: .image(name: "startHere", offset: 11), alpha: 1)
        addWayViews(route: route)
        guard route.steps.count > 1 else { return }
        addNode(route: route, coordinate:  route.steps.last!.polyline.coordinate, type: .image(name: "destination", offset: 11), alpha: 1)
    }
    
    private func addNode(route: MKRoute, coordinate: CLLocationCoordinate2D, type: NodeType, alpha: CGFloat) {
        guard let annotationNode = annotationNode(type, coordinate) else { return }
        annotationNode.camera?.wantsDepthOfField = true
        annotationNode.scaleRelativeToDistance = true
        annotationNode.scalingScheme = .linear(threshold: 0.6)
        annotationNode.annotationNode.view?.alpha = alpha
        annotationNode.annotationNode.geometry?.firstMaterial?.transparency = alpha
        sceneView.addLocationNodeWithConfirmedLocation(locationNode: annotationNode)
    }
    
    private func addWayViews(route: MKRoute) {
        guard !route.steps.isEmpty else { return }
        //        var count = 0
        for step in route.steps {
            let alpha = 1.0
            //            count += 1
            let coordinate = step.polyline.coordinate
            let text = step == route.steps.first && step.instructions.isEmpty ? NSLocalizedString("start here", comment: "") : step.instructions
            addNode(route: route, coordinate: coordinate, type: .label(text: text, offset: -2), alpha: alpha)
            guard step != route.steps.first && step != route.steps.last else { continue }
            addNode(route: route, coordinate: coordinate, type: .image(name: "info", offset: 9), alpha: alpha)
        }
    }
    
    private func buildNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                           altitude: CLLocationDistance, imageName: String) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        let image = UIImage(named: imageName)!
        return LocationAnnotationNode(location: location, image: image)
    }
    
    private func buildViewNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                               altitude: CLLocationDistance, text: String) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        
        let label = UILabel(frame: CGRect(x: 50, y: 0, width: 400, height: 300))
        
        label.text = text
        label.font = .boldSystemFont(ofSize: 28)
        label.numberOfLines = 0
        label.adjustsFontSizeToFitWidth = true
        label.textAlignment = .center
        
        label.backgroundColor = .white.withAlphaComponent(0.9)
        label.layer.cornerRadius = 150
        label.layer.masksToBounds = true
        label.layer.borderColor = UIColor(hexString: "#DD7867").withAlphaComponent(0.8).cgColor
        label.layer.borderWidth = 4
        
        return LocationAnnotationNode(location: location, view: label)
    }
    
    private func buildLayerNode(latitude: CLLocationDegrees, longitude: CLLocationDegrees,
                                altitude: CLLocationDistance, layer: CALayer) -> LocationAnnotationNode {
        let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        let location = CLLocation(coordinate: coordinate, altitude: altitude)
        return LocationAnnotationNode(location: location, layer: layer)
    }
    
    func updateMonitoredRegion(index: Int, count: Int) {
        currentRegion = index
    }
    
    func updateMonitoredRegionWithDistance(index: Int) {
        currentRegion = index
    }
    
    func startAtNext() {
        currentRegion = 1
    }
    
    func removeAllRoutesAndNodes(routes: [MKRoute]?) {
        guard let routes else { return }
        sceneView.removeRoutes(routes: routes)
        sceneView.removeAllNodes()
    }
    
    func run() {
        sceneView.run()
    }
    
    func pause() {
        sceneView.pause()
    }
    
    func destroy() {
        goToStart.stopBlinking()
        sceneView.pause()
        sceneView.stop(nil)
        removeAllRoutesAndNodes(routes: routes)
        sceneView = nil
    }
    
    func addRoutes(routes: [MKRoute]?, complition: @escaping (_ showMap: Bool) -> ()) {
        guard let routes = routes else { return }
        removeAllRoutesAndNodes(routes: self.routes)
        self.routes = routes
        buildUI(routes: routes, complition: complition)
    }
    
    func arrived() {
        removeAllRoutesAndNodes(routes: routes)
        guard let route = routes.first else { return }
        addNode(route: route, coordinate:  route.steps.last!.polyline.coordinate, type: .image(name: "destination", offset: 11), alpha: 1)
    }
    
    func arriveToStart() -> Bool {
        guard !goToStart.isHidden else { return false }
        guard let routes, let route = routes.first else { return false }
        goToStart.isHidden = true
        addRoutes(routes: routes)
        addARViews(route: route)
        addARArrow()
        return true
    }
}

// MARK: - extensions

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
    
    func renderer(_ renderer: SCNSceneRenderer, willRenderScene scene: SCNScene, atTime time: TimeInterval) {
        guard let pointOfView = sceneView.pointOfView else { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let transform = pointOfView.transform // transformation matrix
            let orientation = SCNVector3(-transform.m31, -transform.m32, -transform.m33) // camera rotation
            let location = SCNVector3(transform.m41, transform.m42, transform.m43) // camera translation
            let currentPostionOfCamera = orientation + location
            let arrow = ARArrow.sheard.arrow
            arrow.position = currentPostionOfCamera
            let look = currentRegion < sceneView.locationNodes.count ? currentRegion : sceneView.locationNodes.count - 1
            let index = currentRegion + 1 < sceneView.locationNodes.count ? currentRegion + 1 : sceneView.locationNodes.count - 1
            guard look! >= 0 else { return }
            let distantNode = sceneView.locationNodes[index]
            arrow.eulerAngles = SCNVector3Make(0, distantNode.orientation.y - .pi/2 + 0.5, 0)
            arrow.isHidden = sceneView.isNode(sceneView.locationNodes[look!], insideFrustumOf: pointOfView)
        }
    }
}

extension DispatchQueue {
    func asyncAfter(timeInterval: TimeInterval, execute: @escaping () -> Void) {
        self.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(timeInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
            execute: execute)
    }
}
