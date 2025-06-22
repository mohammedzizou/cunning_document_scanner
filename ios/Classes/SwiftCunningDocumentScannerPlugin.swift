import Flutter
import UIKit
import Vision
import VisionKit

@available(iOS 13.0, *)
public class SwiftCunningDocumentScannerPlugin: NSObject, FlutterPlugin, VNDocumentCameraViewControllerDelegate {
  var resultChannel: FlutterResult?
  var presentingController: VNDocumentCameraViewController?
  var scannerOptions: CunningScannerOptions = CunningScannerOptions()

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: "cunning_document_scanner", binaryMessenger: registrar.messenger())
    let instance = SwiftCunningDocumentScannerPlugin()
    registrar.addMethodCallDelegate(instance, channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    if call.method == "getPictures" {
            scannerOptions = CunningScannerOptions.fromArguments(args: call.arguments)
            let presentedVC: UIViewController? = UIApplication.shared.keyWindow?.rootViewController
            self.resultChannel = result
            if VNDocumentCameraViewController.isSupported {
                self.presentingController = VNDocumentCameraViewController()
                self.presentingController!.delegate = self
                presentedVC?.present(self.presentingController!, animated: true) { [weak self] in
                    // Show the notification after the document camera is presented
                    self?.showNotification(on: UIApplication.shared.keyWindow, message: "Enable Flash and clean your camera for better scanning.")
                }
            } else {
                result(FlutterError(code: "UNAVAILABLE", message: "Document camera is not available on this device", details: nil))
            }
        } else {
            result(FlutterMethodNotImplemented)
            return
        }
  }


    func getDocumentsDirectory() -> URL {
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
        let tempDirPath = self.getDocumentsDirectory()
        let currentDateTime = Date()
        let df = DateFormatter()
        df.dateFormat = "yyyyMMdd-HHmmss"
        let formattedDate = df.string(from: currentDateTime)
        var filenames: [String] = []
        for i in 0 ..< scan.pageCount {
            let page = scan.imageOfPage(at: i)
            let url = tempDirPath.appendingPathComponent(formattedDate + "-\(i).\(scannerOptions.imageFormat.rawValue)")
            switch scannerOptions.imageFormat {
            case CunningScannerImageFormat.jpg:
                try? page.jpegData(compressionQuality: scannerOptions.jpgCompressionQuality)?.write(to: url)
                break
            case CunningScannerImageFormat.png:
                try? page.pngData()?.write(to: url)
                break
            }
            
            filenames.append(url.path)
        }
        resultChannel?(filenames)
        presentingController?.dismiss(animated: true)
    }

    public func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
        resultChannel?(nil)
        presentingController?.dismiss(animated: true)
    }

    public func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
        resultChannel?(FlutterError(code: "ERROR", message: error.localizedDescription, details: nil))
        presentingController?.dismiss(animated: true)
    }
     // Function to show a brief notification message
    private func showNotification(on window: UIWindow?, message: String) {
        guard let window = window else { return }
        
        // Create a notification view
        let notificationView = UIView(frame: CGRect(x: 20, y: -60, width: UIScreen.main.bounds.width - 40, height: 80))
        notificationView.backgroundColor = UIColor(hex: 0x06C671)
        notificationView.layer.cornerRadius = 12
        notificationView.clipsToBounds = true
        
        // Add a label to the notification view
        let label = UILabel(frame: notificationView.bounds)
        label.text = message
        label.textColor = .white
        label.textAlignment = .center
        label.font = UIFont.systemFont(ofSize: 14, weight: .medium)
        label.numberOfLines = 0
        notificationView.addSubview(label)
        
        // Add the notification view to the key window
        window.addSubview(notificationView)
        
        // Animate the notification to slide in
        UIView.animate(withDuration: 0.2, animations: {
            notificationView.frame = CGRect(x: 20, y: 40, width: UIScreen.main.bounds.width - 40, height: 80)
        }) { _ in
            // Wait for 2 seconds before sliding out
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                UIView.animate(withDuration: 0.3, animations: {
                    notificationView.frame = CGRect(x: 20, y: -60, width: UIScreen.main.bounds.width - 40, height: 80)
                }) { _ in
                    // Remove the notification view
                    notificationView.removeFromSuperview()
                }
            }
        }
    }
}

extension UIColor {
    convenience init(hex: Int, alpha: CGFloat = 1.0) {
        let red = CGFloat((hex >> 16) & 0xFF) / 255.0
        let green = CGFloat((hex >> 8) & 0xFF) / 255.0
        let blue = CGFloat(hex & 0xFF) / 255.0
        self.init(red: red, green: green, blue: blue, alpha: alpha)
    }
}
