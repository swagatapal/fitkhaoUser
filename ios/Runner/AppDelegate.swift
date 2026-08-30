import Flutter
import UIKit
import GoogleMaps

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // google_maps_flutter renders a blank grey tile on iOS unless the SDK is keyed
    // before the first map view is created. Matches com.google.android.geo.API_KEY
    // in AndroidManifest.xml / AppConfig.googleMapsApiKey.
    GMSServices.provideAPIKey("AIzaSyDp2r7Do-Z-cwgxiYpE1yzZecBHFz0ocaw")
    GeneratedPluginRegistrant.register(with: self)
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }
}
