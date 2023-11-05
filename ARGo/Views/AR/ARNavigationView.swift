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
    private var timers: [String: Timer?]!
    
    override init() {
        timers = [:]
        flashLavel = 2500
        super.init()
    }
    
    func stopTimers() {
        timers.values.forEach({ timer in
            timer?.invalidate()
        })
        
        timers = [:]
    }
    
    private func stopTimer(key: String) {
        let timer = timers[key]
        timer??.invalidate()
        timers[key] = nil
    }
    
    func setTimer(key: String, time: CGFloat ,repeats: Bool = true, function: @escaping () -> ()) {
        let timer = Timer(timeInterval: time, repeats: repeats, block: { timer in
            function()
        })
        
        timers[key] = timer
        RunLoop.main.add(timer, forMode: .common)
    }
    
    func trackAltitude(sceneView: SceneLocationView, maxDiff: CGFloat, didChangeAltitud: @escaping () -> ()) {
        stopTimer(key: "trackAltitud")
        setTimer(key: "trackAltitud",time: 0.2) { [weak self] in
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
        setTimer(key: "toggleFlash", time: 2, repeats: false) {  [weak self] in
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
        stopTimer(key: "toggleFlash")
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
    private var routeColor: UIColor {
        let isAll = UserDefaults.standard.bool(forKey: "isAllColors")
        if let hex = UserDefaults.standard.value(forKey: isAll ? "mapRouteColor" : "arRouteColor") as? String {
            return UIColor(hexString: hex)
        }
        return .systemYellow
    }
    
    //    private var regionManager: RegionManager {
    //        let rm = RegionManager()
    //        rm.startMonitoringRegions(with: routes)
    //
    //        rm.trackRegion { [weak self] index, count, state in
    //            guard let self else { return }
    //            switch state {
    //            case .enter:
    //                currentRegion = index
    //                ajustAlpha()
    //            case .exit:
    //                currentRegion = index + 1
    //                ajustAlpha()
    //            default:
    //                break
    //            }
    //        }
    //
    //        return rm
    //    }
    
    private var location: CLLocationCoordinate2D?
    private var routes: [MKRoute]! {
        didSet {
            removeAllRoutesAndNodes(routes: oldValue)
        }
    }
    
    private var isValid: Bool?
    
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
        viewModel = ARNavigationViewViewModel()
       
        super.init(frame: frame)
        initSceneView()
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
        viewModel.stopTimers()
    }
    
    func toggleFlashIfNeeded() {
        viewModel.toggleFlashIfNeeded()
    }
    
    func turnFlashOff() {
        viewModel.turnFlashOff()
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
    
    func trackAltitud() {
        viewModel.trackAltitude(sceneView: sceneView, maxDiff: 0.1) { [weak self] in
            guard let self else { return }
            removeAllRoutesAndNodes(routes: routes)
            buildUI(routes: routes)
        }
    }
    
    func valid() {
        isValid = true
        buildUI(routes: routes)
    }
    
    private func buildUI(routes: [MKRoute]?) {
        guard let isValid, isValid else { return }
        // 1. Don't try to add the models to the scene until we have a current location
        guard sceneView.sceneLocationManager.currentLocation != nil else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                self?.buildUI(routes: routes)
            }
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            guard let routes = routes, let route = routes.first else { return }
            addRoutes(routes: routes)
            addARViews(route: route)
            //            trackRoute()
            //            trackAltitud()
        }
    }
    
    func removeAllRoutesAndNodes(routes: [MKRoute]?) {
        guard let routes else { return }
        sceneView.removeRoutes(routes: routes)
        sceneView.removeAllNodes()
    }
    
    private func addRoutes(routes: [MKRoute]) {
//        var count = 0
        let polylines = routes.map { AttributedType(type: $0.polyline, attribute: $0.name) }
        sceneView.addRoutes(polylines: polylines, Δaltitude: -12) { [weak self] distance in
            guard let self else { return SCNBox(width: 0, height: 0, length: 0, chamferRadius: 0) }
            let box = SCNBox(width: 10, height: 0.2, length: distance, chamferRadius: 0.25)
            let alpha = 1.0
//            count += 1
            box.firstMaterial?.diffuse.contents = routeColor
            box.firstMaterial?.transparency = alpha
            return box
        }
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
            addNode(route: route, coordinate: coordinate, type: .label(text: text, offset: 4), alpha: alpha)
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
    
    
//    func trackRoute() {
//        viewModel.setTimer(key: "trackRoute", time: 1) { [weak self] in
//            guard let self = self else { return }
//            ajustAlpha()
//        }
//    }
    
    func run() {
        sceneView.run()
    }
    
    func pause() {
        sceneView.pause()
    }
    
    func destroy() {
        sceneView.pause()
        removeAllRoutesAndNodes(routes: routes)
    }

    func addRoutes(routes: [MKRoute]?) {
        guard let routes = routes else { return }
        self.routes = routes
    }
    
    func arrived() {
        removeAllRoutesAndNodes(routes: routes)
        guard let route = routes.first else { return }
        addNode(route: route, coordinate:  route.steps.last!.polyline.coordinate, type: .image(name: "destination", offset: 11), alpha: 1)
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
}

extension DispatchQueue {
    func asyncAfter(timeInterval: TimeInterval, execute: @escaping () -> Void) {
        self.asyncAfter(
            deadline: DispatchTime.now() + Double(Int64(timeInterval * Double(NSEC_PER_SEC))) / Double(NSEC_PER_SEC),
            execute: execute)
    }
}
