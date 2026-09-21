import UIKit
import ARKit
import SceneKit
import AVFoundation

final class ScannerController: UIViewController, ARSessionDelegate {
    var onFinish: (([String: Any]) -> Void)?
    private let ar = ARSCNView()
    private let status = UILabel()
    private let target = UILabel()
    private let add = UIButton(type:.system)
    private let undo = UIButton(type:.system)
    private let finish = UIButton(type:.system)
    private var points: [RoomPoint] = []
    private var markers: [SCNNode] = []
    private var timer: Timer?
    private var interrupted = false
    private var active = false

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Scan room"
        view.backgroundColor = .black
        ar.frame = view.bounds
        ar.autoresizingMask = [.flexibleWidth,.flexibleHeight]
        ar.scene = SCNScene()
        ar.preferredFramesPerSecond = 30
        ar.antialiasingMode = .none
        ar.session.delegate = self
        ar.session.delegateQueue = .main
        view.addSubview(ar)
        target.text = "+"
        target.font = .systemFont(ofSize:48,weight:.light)
        target.textColor = .white
        target.isAccessibilityElement = false
        target.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(target)
        status.textColor = .white
        status.numberOfLines = 0
        status.textAlignment = .center
        status.text = "Move slowly and aim at a floor corner."
        let buttons = UIStackView(arrangedSubviews:[undo,add,finish])
        buttons.distribution = .fillEqually
        buttons.spacing = 10
        for (button,name,action) in [(undo,"Undo",#selector(undoCorner)),(add,"Add corner",#selector(addCorner)),(finish,"Finish",#selector(finishScan))] {
            button.configuration = .filled()
            button.setTitle(name,for:.normal)
            button.addTarget(self,action:action,for:.touchUpInside)
        }
        let panel = UIStackView(arrangedSubviews:[status,buttons])
        panel.axis = .vertical
        panel.spacing = 14
        panel.backgroundColor = UIColor.black.withAlphaComponent(0.75)
        panel.isLayoutMarginsRelativeArrangement = true
        panel.layoutMargins = UIEdgeInsets(top:16,left:12,bottom:16,right:12)
        panel.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(panel)
        NSLayoutConstraint.activate([target.centerXAnchor.constraint(equalTo:ar.centerXAnchor),target.centerYAnchor.constraint(equalTo:ar.centerYAnchor),
            panel.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:8),
            panel.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-8),
            panel.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor,constant:-8)])
        navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Restart",style:.plain,target:self,action:#selector(confirmRestart))
        NotificationCenter.default.addObserver(self,selector:#selector(backgrounded),name:UIApplication.willResignActiveNotification,object:nil)
        NotificationCenter.default.addObserver(self,selector:#selector(foregrounded),name:UIApplication.didBecomeActiveNotification,object:nil)
    }
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        active = true
        guard ARWorldTrackingConfiguration.isSupported else { status.text = "This device cannot run ARKit world tracking."; return }
        AVCaptureDevice.requestAccess(for:.video) { [weak self] allowed in
            DispatchQueue.main.async {
                guard let self, self.active else { return }
                if allowed { self.run(reset:true) }
                else {
                    self.status.text = "Allow camera access in Settings to scan."
                    self.navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Settings",style:.plain,target:self,action:#selector(self.openSettings))
                }
            }
        }
    }
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        active = false
        stop()
    }
    deinit { NotificationCenter.default.removeObserver(self) }
    private func stop() { timer?.invalidate(); timer = nil; ar.session.pause(); add.isEnabled = false; finish.isEnabled = false }
    private func run(reset: Bool) {
        guard active, ARWorldTrackingConfiguration.isSupported, AVCaptureDevice.authorizationStatus(for:.video) == .authorized else { return }
        if reset { points.removeAll(); markers.forEach { $0.removeFromParentNode() }; markers.removeAll() }
        interrupted = false
        let configuration = ARWorldTrackingConfiguration()
        configuration.planeDetection = [.horizontal]
        ar.session.run(configuration,options:reset ? [.resetTracking,.removeExistingAnchors] : [])
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval:0.1,repeats:true) { [weak self] _ in self?.refresh() }
    }
    private var trackingOK: Bool {
        guard active, !interrupted, let frame = ar.session.currentFrame,
              ProcessInfo.processInfo.systemUptime - frame.timestamp < 0.5 else { return false }
        if case .normal = frame.camera.trackingState { return true }
        return false
    }
    private func floorPoint() -> RoomPoint? {
        guard trackingOK, let query = ar.raycastQuery(from:CGPoint(x:ar.bounds.midX,y:ar.bounds.midY),allowing:.existingPlaneGeometry,alignment:.horizontal),
              let hit = ar.session.raycast(query).first else { return nil }
        let p = hit.worldTransform.columns.3
        if let floor = points.first?.y, abs(Double(p.y)-floor) > 0.15 { return nil }
        return RoomPoint(x:Double(p.x),y:points.first?.y ?? Double(p.y),z:Double(p.z))
    }
    private func refresh() {
        let ready = floorPoint() != nil
        add.isEnabled = ready && points.count < 256
        undo.isEnabled = !points.isEmpty
        finish.isEnabled = trackingOK && points.count >= 3
        target.textColor = ready ? .systemGreen : .white
        status.text = interrupted ? "Tracking interrupted. Restart the scan to keep all corners aligned." :
            "\(points.count) corners • \(ready ? "Aim at the floor corner and tap Add corner." : "Move slowly; aim at the detected floor.")"
    }
    @objc private func addCorner() {
        guard let p = floorPoint(), points.count < 256 else { return }
        guard !points.contains(where:{ ScanGeometry.distance($0,p) < 0.05 }) else { return }
        points.append(p)
        let sphere = SCNSphere(radius:0.025)
        sphere.firstMaterial?.diffuse.contents = UIColor.systemGreen
        sphere.firstMaterial?.lightingModel = .constant
        let marker = SCNNode(geometry:sphere)
        marker.position = SCNVector3(Float(p.x),Float(p.y),Float(p.z))
        ar.scene.rootNode.addChildNode(marker)
        markers.append(marker)
        UIImpactFeedbackGenerator(style:.light).impactOccurred()
        refresh()
    }
    @objc private func undoCorner() {
        guard !points.isEmpty else { return }
        points.removeLast()
        markers.removeLast().removeFromParentNode()
        refresh()
    }
    @objc private func finishScan() {
        guard trackingOK else { return }
        do { let result = try ScanGeometry.contract(points); stop(); onFinish?(result) }
        catch { showError(error.localizedDescription) }
    }
    @objc private func confirmRestart() {
        let alert = UIAlertController(title:"Restart scan?",message:"The current corners will be cleared.",preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"Cancel",style:.cancel))
        alert.addAction(UIAlertAction(title:"Restart",style:.destructive) { [weak self] _ in self?.run(reset:true) })
        present(alert,animated:true)
    }
    @objc private func openSettings() {
        if let url = URL(string:UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
    }
    @objc private func backgrounded() { guard active else { return }; interrupted = true; stop() }
    @objc private func foregrounded() {
        guard active else { return }
        if AVCaptureDevice.authorizationStatus(for:.video) == .authorized {
            navigationItem.rightBarButtonItem = UIBarButtonItem(title:"Restart",style:.plain,target:self,action:#selector(confirmRestart))
            status.text = "Tap Restart to begin a new scan after returning to the app."
        }
    }
    func sessionWasInterrupted(_ session: ARSession) { interrupted = true; refresh() }
    func sessionInterruptionEnded(_ session: ARSession) { interrupted = true; refresh() }
    func session(_ session: ARSession, didFailWithError error: Error) { interrupted = true; stop(); showError(error.localizedDescription) }
    private func showError(_ text: String) {
        let alert = UIAlertController(title:"Scan needs attention",message:text,preferredStyle:.alert)
        alert.addAction(UIAlertAction(title:"OK",style:.default))
        present(alert,animated:true)
    }
}
