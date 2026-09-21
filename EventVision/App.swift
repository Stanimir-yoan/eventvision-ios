import UIKit

@main
final class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions options: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let window = UIWindow(frame: UIScreen.main.bounds)
        window.rootViewController = UINavigationController(rootViewController: HomeController())
        window.makeKeyAndVisible()
        self.window = window
        return true
    }
}

final class HomeController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "EventVision"
        view.backgroundColor = .systemBackground
        let explanation = UILabel()
        explanation.text = "Scan your room\n\nAim at each floor corner in order, then open the floorplan editor.\n\nNative iPhone preview: AR furniture photos are not available in this build."
        explanation.numberOfLines = 0
        explanation.textAlignment = .center
        let scan = UIButton(type:.system)
        scan.configuration = .filled()
        scan.setTitle("Start room scan", for:.normal)
        scan.addTarget(self, action:#selector(startScan), for:.touchUpInside)
        let stack = UIStackView(arrangedSubviews:[explanation,scan])
        stack.axis = .vertical
        stack.spacing = 28
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.centerYAnchor.constraint(equalTo:view.centerYAnchor),
            stack.leadingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.leadingAnchor,constant:24),
            stack.trailingAnchor.constraint(equalTo:view.safeAreaLayoutGuide.trailingAnchor,constant:-24)])
    }
    @objc private func startScan() {
        let scanner = ScannerController()
        scanner.onFinish = { [weak self] data in
            guard let self else { return }
            let editor = EditorController(scan:data)
            self.navigationController?.setViewControllers([self,editor],animated:true)
        }
        navigationController?.pushViewController(scanner,animated:true)
    }
}
