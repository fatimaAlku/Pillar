import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate {
  private var quizReportShareChannel: FlutterMethodChannel?
  private var googleOauthChannel: FlutterMethodChannel?
  /// OAuth can return before FlutterViewController exists; deliver after channel is ready.
  private var pendingGoogleOAuthUrl: String?

  private func findFlutterViewController(start: UIViewController?) -> FlutterViewController? {
    guard let start else { return nil }

    if let flutterVC = start as? FlutterViewController {
      return flutterVC
    }

    if let nav = start as? UINavigationController {
      return findFlutterViewController(start: nav.visibleViewController)
    }

    if let tab = start as? UITabBarController {
      return findFlutterViewController(start: tab.selectedViewController)
    }

    if let presented = start.presentedViewController {
      return findFlutterViewController(start: presented)
    }

    return nil
  }

  private func rootViewController() -> UIViewController? {
    if #available(iOS 13.0, *) {
      let scenes = UIApplication.shared.connectedScenes
      for scene in scenes {
        if let windowScene = scene as? UIWindowScene {
          // Prefer FlutterViewController if it's already attached.
          for window in windowScene.windows {
            if let flutterVC = window.rootViewController as? FlutterViewController {
              return flutterVC
            }
          }
          // Fallback to the first root view controller we find.
          for window in windowScene.windows {
            if let root = window.rootViewController {
              return root
            }
          }
        }
      }
      return nil
    } else {
      // Deprecated but kept for iOS 12 fallback.
      return UIApplication.shared.keyWindow?.rootViewController
    }
  }

  private func registerQuizReportShareChannel() {
    guard quizReportShareChannel == nil else { return }

    // Helps us diagnose iOS runtime registration issues.
    print("QuizReportShareChannel: attempting registration")

    let root = rootViewController()
    let flutterViewController = findFlutterViewController(start: root)

    guard let flutterViewController else {
      // Root view controller may not be available yet; retry shortly.
      print("QuizReportShareChannel: FlutterViewController not ready, retrying")
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        self?.registerQuizReportShareChannel()
      }
      return
    }

    quizReportShareChannel = FlutterMethodChannel(
      name: "pillar.quiz_report_share",
      binaryMessenger: flutterViewController.binaryMessenger
    )

    print("QuizReportShareChannel: handler set")
    quizReportShareChannel?.setMethodCallHandler { [weak self] call, result in
      guard call.method == "sharePdf" else {
        result(FlutterMethodNotImplemented)
        return
      }

      guard
        let args = call.arguments as? [String: Any],
        let filePath = args["filePath"] as? String
      else {
        result(
          FlutterError(
            code: "INVALID_ARGUMENTS",
            message: "Missing filePath",
            details: nil
          )
        )
        return
      }

      let fileURL = URL(fileURLWithPath: filePath)
      DispatchQueue.main.async {
        guard let presenter = self?.rootViewController() else {
          result(
            FlutterError(
              code: "NO_PRESENTER",
              message: "Could not find root view controller",
              details: nil
            )
          )
          return
        }

        let activityVC = UIActivityViewController(activityItems: [fileURL], applicationActivities: nil)
        presenter.present(activityVC, animated: true) {
          result(nil)
        }
      }
    }
  }

  private func registerGoogleOauthChannel() {
    guard googleOauthChannel == nil else { return }
    let root = rootViewController()
    let flutterViewController = findFlutterViewController(start: root)
    guard let flutterViewController else {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
        self?.registerGoogleOauthChannel()
      }
      return
    }
    googleOauthChannel = FlutterMethodChannel(
      name: "pillar.google_oauth",
      binaryMessenger: flutterViewController.binaryMessenger
    )
    googleOauthChannel?.setMethodCallHandler { call, result in
      let key = "pillar_pending_google_oauth_url"
      if call.method == "consumePendingOAuthUrl" {
        let url = UserDefaults.standard.string(forKey: key)
        UserDefaults.standard.removeObject(forKey: key)
        result(url)
        return
      }
      if call.method == "clearPendingOAuthUrl" {
        UserDefaults.standard.removeObject(forKey: key)
        result(nil)
        return
      }
      result(FlutterMethodNotImplemented)
    }
    flushPendingGoogleOAuthIfNeeded()
  }

  private func flushPendingGoogleOAuthIfNeeded() {
    guard let url = pendingGoogleOAuthUrl, !url.isEmpty else { return }
    guard googleOauthChannel != nil else { return }
    pendingGoogleOAuthUrl = nil
    googleOauthChannel?.invokeMethod(
      "onGoogleAuthRedirect",
      arguments: ["url": url]
    )
  }

  private func deliverGoogleOAuthRedirect(_ urlString: String) {
    UserDefaults.standard.set(urlString, forKey: "pillar_pending_google_oauth_url")
    pendingGoogleOAuthUrl = urlString
    if googleOauthChannel == nil {
      registerGoogleOauthChannel()
    }
    flushPendingGoogleOAuthIfNeeded()
  }

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    let ok = super.application(
      application,
      didFinishLaunchingWithOptions: launchOptions
    )

    // Register after Flutter root view controller exists.
    DispatchQueue.main.async { [weak self] in self?.registerQuizReportShareChannel() }
    DispatchQueue.main.async { [weak self] in self?.registerGoogleOauthChannel() }
    // Fallback retry (sometimes root view controller isn't available immediately).
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.registerQuizReportShareChannel()
      self?.registerGoogleOauthChannel()
    }

    return ok
  }

  /// Google sends the redirect_uri string exactly as configured; iOS compares URL
  /// schemes case-insensitively in practice, but we must not require exact casing here.
  private func isGoogleCalendarOAuthScheme(_ scheme: String) -> Bool {
    let s = scheme.lowercased()
    return s == "pillarstudycoach" || s == "com.example.pillarstudycoach"
  }

  override func application(
    _ app: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey : Any] = [:]
  ) -> Bool {
    let scheme = url.scheme ?? ""
    if isGoogleCalendarOAuthScheme(scheme) {
      deliverGoogleOAuthRedirect(url.absoluteString)
      return true
    }
    return super.application(app, open: url, options: options)
  }

}
