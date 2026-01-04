# Firebase Cloud Messaging Setup Guide

This guide explains how to configure Firebase Cloud Messaging (FCM) for push notifications in the Fitkhao app.

## ✅ What's Already Implemented

1. **Firebase Notification Service** - Complete FCM integration with:
   - Foreground, background, and terminated state message handling
   - Local notifications for foreground messages
   - Token management and refresh
   - Topic subscription support

2. **Device Registration API** - Automatically registers device after OTP verification:
   - Sends FCM token to backend
   - Includes device info (type, ID, app version, userType)

3. **Service Integration**:
   - DeviceInfoService gets FCM token
   - Main.dart initializes notification service on app start
   - Auth provider calls device registration after login

## 📱 Platform-Specific Configuration

### Android Configuration

#### 1. Update `android/app/build.gradle`

Add the following inside the `android` block:

```gradle
android {
    // ... existing config

    defaultConfig {
        // ... existing config
        minSdkVersion 21  // FCM requires minimum API 21
    }
}
```

#### 2. Update `android/app/src/main/AndroidManifest.xml`

Add these permissions and service configurations:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <!-- Add permissions -->
    <uses-permission android:name="android.permission.INTERNET"/>
    <uses-permission android:name="android.permission.POST_NOTIFICATIONS"/>
    <uses-permission android:name="android.permission.VIBRATE" />
    <uses-permission android:name="android.permission.WAKE_LOCK" />

    <application>
        <!-- ... existing activity config -->

        <!-- FCM Default Channel for Android 8.0+ -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_channel_id"
            android:value="fitkhao_notifications" />

        <!-- FCM Icon (optional, uses app icon by default) -->
        <meta-data
            android:name="com.google.firebase.messaging.default_notification_icon"
            android:resource="@mipmap/ic_launcher" />
    </application>
</manifest>
```

#### 3. Notification Icon (Optional)

For a custom notification icon, create small notification icons:
- `android/app/src/main/res/drawable/ic_notification.xml`
- Use vector drawable or PNG (white icon on transparent background)
- Sizes: 24x24dp for mdpi, 36x36dp for hdpi, 48x48dp for xhdpi, etc.

### iOS Configuration

#### 1. Enable Push Notifications in Xcode

1. Open `ios/Runner.xcworkspace` in Xcode
2. Select the Runner target
3. Go to "Signing & Capabilities"
4. Click "+ Capability"
5. Add "Push Notifications"
6. Add "Background Modes" and check:
   - ✅ Remote notifications
   - ✅ Background fetch

#### 2. Update `ios/Runner/AppDelegate.swift`

Replace the content with:

```swift
import UIKit
import Flutter
import firebase_messaging

@main
@objc class AppDelegate: FlutterAppDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    GeneratedPluginRegistrant.register(with: self)

    // Request notification permissions
    if #available(iOS 10.0, *) {
      UNUserNotificationCenter.current().delegate = self as UNUserNotificationCenterDelegate
    }

    // Register for remote notifications
    application.registerForRemoteNotifications()

    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  // Handle APNs token registration
  override func application(_ application: UIApplication,
                            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
    print("APNs token registered: \\(deviceToken)")
  }

  // Handle APNs registration failure
  override func application(_ application: UIApplication,
                            didFailToRegisterForRemoteNotificationsWithError error: Error) {
    print("APNs registration failed: \\(error.localizedDescription)")
  }
}
```

#### 3. Update `ios/Runner/Info.plist`

Add notification permissions:

```xml
<key>UIBackgroundModes</key>
<array>
    <string>fetch</string>
    <string>remote-notification</string>
</array>
```

#### 4. APNs Certificate Setup

1. Go to [Apple Developer Portal](https://developer.apple.com)
2. Navigate to Certificates, Identifiers & Profiles
3. Create APNs Authentication Key:
   - Keys → Create a new key
   - Enable "Apple Push Notifications service (APNs)"
   - Download the .p8 key file
4. Upload to Firebase Console:
   - Go to Firebase Console → Project Settings
   - Cloud Messaging tab
   - Upload your APNs .p8 key
   - Enter Team ID and Key ID

## 🔧 Testing Push Notifications

### Test via Firebase Console

1. Go to Firebase Console → Engage → Messaging
2. Click "New campaign" → "Firebase notification messages"
3. Enter notification title and text
4. Click "Send test message"
5. Enter your FCM token (check logs when app runs)
6. Click "Test"

### Test via Backend

Your backend can send notifications using the Firebase Admin SDK:

```javascript
// Node.js example
const admin = require('firebase-admin');

await admin.messaging().send({
  token: 'USER_FCM_TOKEN',
  notification: {
    title: 'Order Ready!',
    body: 'Your food is ready for pickup'
  },
  data: {
    orderId: '12345',
    type: 'order_ready'
  }
});
```

## 🎯 How It Works in the App

### 1. App Initialization (main.dart)
```dart
// Firebase initialized first
await Firebase.initializeApp();

// Then notification service
final notificationService = FirebaseNotificationService.getInstance();
await notificationService.initialize();
```

### 2. After OTP Verification (otp_verification_screen.dart)
```dart
// Device automatically registered
authNotifier.registerDevice().then((success) {
  // FCM token sent to backend with device info
});
```

### 3. Token Sent to Backend
```json
POST /api/device/register
{
  "deviceToken": "FCM_TOKEN_HERE",
  "deviceType": "android",
  "deviceId": "unique_device_id",
  "appVersion": "1.0.0+2",
  "userType": "user"
}
```

### 4. Receiving Notifications

**Foreground (App Open):**
- Shows local notification automatically

**Background (App Minimized):**
- System handles notification display
- Tap opens app and calls handler

**Terminated (App Closed):**
- System handles notification display
- Tap opens app with notification data

## 🔔 Notification States Handled

| App State | Notification Display | Handler |
|-----------|---------------------|---------|
| Foreground | Local notification | `FirebaseMessaging.onMessage` |
| Background | System tray | `onBackgroundMessage` |
| Terminated | System tray | `getInitialMessage` |
| Tap (Background) | Opens app | `onMessageOpenedApp` |
| Tap (Terminated) | Opens app | `getInitialMessage` |

## 🚀 Advanced Features

### Topic Subscription
```dart
// Subscribe to topics for targeted notifications
final notificationService = FirebaseNotificationService.getInstance();
await notificationService.subscribeToTopic('orders');
await notificationService.subscribeToTopic('promotions');
```

### Custom Notification Handling
Modify `firebase_notification_service.dart`:

```dart
void _handleNotificationTap(RemoteMessage message) {
  // Navigate based on notification data
  final data = message.data;

  if (data['type'] == 'order_ready') {
    // Navigate to order details
    navigationService.push('/orders/${data['orderId']}');
  } else if (data['type'] == 'promotion') {
    // Navigate to promo screen
    navigationService.push('/promotions');
  }
}
```

## 📊 Monitoring

Check FCM logs in your app:
```bash
# Android
adb logcat | grep "FCM"

# iOS
# View in Xcode console
```

## ⚠️ Troubleshooting

### Token is empty
- Check Firebase is initialized before notification service
- Verify google-services.json (Android) or GoogleService-Info.plist (iOS) is added
- Check internet connection
- For iOS, verify APNs certificate is uploaded to Firebase

### Notifications not appearing
- Check notification permissions granted
- Verify FCM token is sent to backend
- Test with Firebase Console first
- Check Android notification channel is created
- For iOS, verify background modes enabled

### Token refresh not working
- Token refresh listener is set up automatically
- Implement backend endpoint to update token
- Currently logs new token, add your API call in `_setupTokenRefreshListener`

## 📝 Next Steps

1. ✅ Firebase already configured in project
2. ✅ Notification service implemented
3. ✅ Device registration integrated
4. ⏳ Add platform-specific configurations above
5. ⏳ Test notifications
6. ⏳ Implement custom navigation based on notification type
7. ⏳ Set up backend to send notifications

## 🔗 Resources

- [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging)
- [FlutterFire Messaging](https://firebase.flutter.dev/docs/messaging/overview)
- [Local Notifications](https://pub.dev/packages/flutter_local_notifications)
