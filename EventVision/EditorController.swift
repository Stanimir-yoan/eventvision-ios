import UIKit
import WebKit

final class EditorController: UIViewController, WKNavigationDelegate {
    private let scan: [String: Any]
    private var web: WKWebView!
    private let status = UILabel()
    private var timeout: DispatchWorkItem?
    private var generation = 0
    init(scan: [String: Any]) { self.scan = scan; super.init(nibName:nil,bundle:nil) }
    required init?(coder: NSCoder) { fatalError("Use init(scan:)") }
    override func viewDidLoad() {
        super.viewDidLoad()
        title = "Floorplan"
        view.backgroundColor = .systemBackground
        let configuration = WKWebViewConfiguration()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        web = WKWebView(frame:.zero,configuration:configuration)
        web.navigationDelegate = self
        web.translatesAutoresizingMaskIntoConstraints = false
        status.numberOfLines = 0
        status.textAlignment = .center
        status.font = .preferredFont(forTextStyle:.footnote)
        let stack = UIStackView(arrangedSubviews:[status,web])
        stack.axis = .vertical
        stack.spacing = 6
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)
        NSLayoutConstraint.activate([stack.topAnchor.constraint(equalTo:view.safeAreaLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo:view.safeAreaLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo:view.leadingAnchor),stack.trailingAnchor.constraint(equalTo:view.trailingAnchor)])
        navigationItem.rightBarButtonItems = [UIBarButtonItem(title:"Share scan",style:.plain,target:self,action:#selector(shareScan)),
            UIBarButtonItem(title:"Reload",style:.plain,target:self,action:#selector(loadEditor))]
        loadEditor()
    }
    @objc private func loadEditor() {
        generation += 1
        timeout?.cancel()
        status.text = "Loading floorplan editor…"
        guard let url = Bundle.main.url(forResource:"index",withExtension:"html",subdirectory:"Web") else {
            status.text = "The bundled editor is missing. Rebuild with the Web folder included."; return
        }
        web.loadFileURL(url,allowingReadAccessTo:url.deletingLastPathComponent())
    }
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let current = generation
        // Module readiness can occur after the document's navigation completes.
        importWhenReady(attempt:0,generation:current)
    }
    private func importWhenReady(attempt: Int,generation current: Int) {
        guard current == generation else { return }
        web.callAsyncJavaScript("return !!window.EventVisionScan;",arguments:[:],in:nil,in:.page) { [weak self] result in
            guard let self, current == self.generation else { return }
            if case let .success(value) = result, value as? Bool == true {
                self.deliverScan(generation:current)
            } else if attempt < 60 {
                let work = DispatchWorkItem { [weak self] in self?.importWhenReady(attempt:attempt+1,generation:current) }
                self.timeout = work
                DispatchQueue.main.asyncAfter(deadline:.now()+0.5,execute:work)
            } else { self.status.text = "Editor did not load. Try Reload. Your scan is still available with Share scan." }
        }
    }
    private func deliverScan(generation current: Int) {
        web.callAsyncJavaScript("return window.EventVisionScan.receive(scan);",arguments:["scan":scan],in:nil,in:.page) { [weak self] result in
            guard let self, current == self.generation else { return }
            switch result {
            case .success(let value):
                if let reply = value as? [String:Any], reply["accepted"] as? Bool == true {
                    self.status.text = "Native scan imported • Floorplan editing preview"
                } else { self.status.text = "Editor rejected the scan. Share scan to preserve it, then scan again." }
            case .failure(let error): self.status.text = "Could not import scan: \(error.localizedDescription)"
            }
        }
    }
    func webView(_ webView: WKWebView, decidePolicyFor action: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // No arbitrary remote page gets access to the native scan. The editor and engine are bundled.
        guard let url = action.request.url, action.targetFrame?.isMainFrame == true,
              let root = Bundle.main.resourceURL?.appendingPathComponent("Web").standardizedFileURL.path,
              url.isFileURL, url.standardizedFileURL.path == root + "/index.html" else {
            decisionHandler(.cancel); return
        }
        decisionHandler(.allow)
    }
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) { status.text = error.localizedDescription }
    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) { status.text = error.localizedDescription }
    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) { status.text = "Editor stopped. Reload to restore the scanned room; unsaved layout edits will be lost." }
    @objc private func shareScan() {
        do {
            let data = try JSONSerialization.data(withJSONObject:scan,options:[.prettyPrinted,.sortedKeys])
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("eventvision-scan.json")
            try data.write(to:url,options:.atomic)
            let share = UIActivityViewController(activityItems:[url],applicationActivities:nil)
            share.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItems?.first
            present(share,animated:true)
        } catch { status.text = "Could not save scan: \(error.localizedDescription)" }
    }
    deinit { timeout?.cancel() }
}
