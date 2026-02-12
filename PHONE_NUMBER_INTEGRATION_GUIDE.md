# Phone Number Auto-Fetch Integration Guide

## Overview
This guide explains how to integrate actual device phone number fetching from SIM cards in your Flutter app. The current implementation uses a PhoneNumberService with platform channels that gracefully falls back to mock numbers for development.

---

## 🎯 Current Implementation Status

### ✅ What's Implemented (Flutter Side)
- `PhoneNumberService` with platform channel setup
- Permission handling using `permission_handler` package
- Mock phone numbers for development/testing
- Beautiful UI with bottom sheet selection
- Loading states and error handling
- Automatic phone number formatting
- Graceful fallback mechanism
- **No third-party phone packages needed** - uses native platform channels directly

### 🔧 What Needs Implementation (Native Side)
- Android: Kotlin/Java implementation to read SIM card numbers
- iOS: Swift/Objective-C implementation (note: iOS has limitations)

---

## 📱 Platform-Specific Implementation

### Android Implementation

#### Step 1: Update AndroidManifest.xml

Add the following permissions to `android/app/src/main/AndroidManifest.xml`:

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <application>
        <!-- Your existing application config -->
    </application>

    <!-- Add these permissions before </manifest> -->
    <uses-permission android:name="android.permission.READ_PHONE_STATE" />
    <uses-permission android:name="android.permission.READ_PHONE_NUMBERS" />

    <!-- For Android 10+ -->
    <uses-permission android:name="android.permission.READ_PRIVILEGED_PHONE_STATE"
                     tools:ignore="ProtectedPermissions" />
</manifest>
```

#### Step 2: Create MainActivity.kt

Update `android/app/src/main/kotlin/com/fitkhao/user/MainActivity.kt`:

```kotlin
package com.fitkhao.user

import android.Manifest
import android.content.pm.PackageManager
import android.telephony.SubscriptionManager
import android.telephony.TelephonyManager
import android.os.Build
import androidx.core.app.ActivityCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity: FlutterActivity() {
    private val CHANNEL = "com.fitkhao.user/phone_number"

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler {
            call, result ->

            if (call.method == "getPhoneNumbers") {
                val phoneNumbers = getPhoneNumbers()
                if (phoneNumbers.isNotEmpty()) {
                    result.success(phoneNumbers)
                } else {
                    result.error("NO_PHONE_NUMBERS", "No phone numbers found", null)
                }
            } else {
                result.notImplemented()
            }
        }
    }

    private fun getPhoneNumbers(): List<String> {
        val phoneNumbers = mutableListOf<String>()

        // Check if we have the required permissions
        if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
            != PackageManager.PERMISSION_GRANTED) {
            return phoneNumbers
        }

        try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP_MR1) {
                // For Android 5.1+ with dual SIM support
                val subscriptionManager = getSystemService(TELEPHONY_SUBSCRIPTION_SERVICE) as SubscriptionManager

                if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_STATE)
                    == PackageManager.PERMISSION_GRANTED) {

                    val subscriptionInfoList = subscriptionManager.activeSubscriptionInfoList

                    if (subscriptionInfoList != null) {
                        for (subscriptionInfo in subscriptionInfoList) {
                            val phoneNumber = subscriptionInfo.number
                            if (!phoneNumber.isNullOrEmpty()) {
                                // Clean the phone number (remove country code if present)
                                val cleanedNumber = cleanPhoneNumber(phoneNumber)
                                if (cleanedNumber.length == 10) {
                                    phoneNumbers.add(cleanedNumber)
                                }
                            }
                        }
                    }
                }
            }

            // Fallback to TelephonyManager for single SIM devices
            if (phoneNumbers.isEmpty()) {
                val telephonyManager = getSystemService(TELEPHONY_SERVICE) as TelephonyManager

                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                    if (ActivityCompat.checkSelfPermission(this, Manifest.permission.READ_PHONE_NUMBERS)
                        == PackageManager.PERMISSION_GRANTED) {
                        val phoneNumber = telephonyManager.line1Number
                        if (!phoneNumber.isNullOrEmpty()) {
                            val cleanedNumber = cleanPhoneNumber(phoneNumber)
                            if (cleanedNumber.length == 10) {
                                phoneNumbers.add(cleanedNumber)
                            }
                        }
                    }
                } else {
                    @Suppress("DEPRECATION")
                    val phoneNumber = telephonyManager.line1Number
                    if (!phoneNumber.isNullOrEmpty()) {
                        val cleanedNumber = cleanPhoneNumber(phoneNumber)
                        if (cleanedNumber.length == 10) {
                            phoneNumbers.add(cleanedNumber)
                        }
                    }
                }
            }
        } catch (e: Exception) {
            e.printStackTrace()
        }

        return phoneNumbers
    }

    private fun cleanPhoneNumber(phoneNumber: String): String {
        // Remove all non-digit characters
        var cleaned = phoneNumber.replace(Regex("[^0-9]"), "")

        // Remove country code if present
        // For India: +91 or 91
        if (cleaned.startsWith("91") && cleaned.length > 10) {
            cleaned = cleaned.substring(2)
        }

        // Get last 10 digits
        if (cleaned.length > 10) {
            cleaned = cleaned.substring(cleaned.length - 10)
        }

        return cleaned
    }
}
```

#### Step 3: Update build.gradle

Ensure `android/app/build.gradle` has the correct configuration:

```gradle
android {
    compileSdkVersion 34

    defaultConfig {
        minSdkVersion 21
        targetSdkVersion 34
    }
}
```

---

### iOS Implementation

⚠️ **Important Note**: iOS has severe limitations for accessing phone numbers due to privacy restrictions. Apple does not allow apps to directly access the device's phone number from the SIM card.

#### Alternative Approaches for iOS:

1. **SMS Autofill (iOS 12+)**
   - Use iOS's one-time code autofill
   - Does not reveal the phone number to the app
   - User must manually enter initially

2. **Contact Picker**
   - Let user select their own number from contacts
   - Requires user action

3. **Manual Entry Only**
   - Recommended approach for iOS
   - Better UX and privacy compliance

#### iOS Platform Channel (Limited)

Update `ios/Runner/AppDelegate.swift`:

```swift
import UIKit
import Flutter

@UIApplicationMain
@objc class AppDelegate: FlutterAppDelegate {
    override func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
    ) -> Bool {

        let controller : FlutterViewController = window?.rootViewController as! FlutterViewController
        let phoneChannel = FlutterMethodChannel(name: "com.fitkhao.user/phone_number",
                                                binaryMessenger: controller.binaryMessenger)

        phoneChannel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) -> Void in

            if call.method == "getPhoneNumbers" {
                // iOS does not allow accessing phone numbers
                // Return empty array to trigger fallback
                result([])
            } else {
                result(FlutterMethodNotImplemented)
            }
        })

        GeneratedPluginRegistrant.register(with: self)
        return super.application(application, didFinishLaunchingWithOptions: launchOptions)
    }
}
```

---

## 🔐 Permission Handling

### Android Runtime Permissions

The `permission_handler` package is already integrated. The flow is:

1. User clicks "Auto Fetch Phone Number"
2. `PhoneNumberService` checks for `Permission.phone`
3. If not granted, requests permission
4. If granted, calls platform channel
5. If denied, falls back to mock numbers

### Required Permissions:

- **Android**:
  - `READ_PHONE_STATE`: Read basic phone state
  - `READ_PHONE_NUMBERS`: Read phone numbers (Android 6+)

- **iOS**:
  - No permissions needed (feature not available)

---

## 🧪 Testing

### Development Mode (Current Implementation)

Currently, the app works with **mock phone numbers**:

```dart
// These are returned when platform channel fails
['9876543210', '8765432109', '7654321098']
```

### Testing on Real Device

1. **Android**:
   ```bash
   flutter run --release
   ```
   - Grant phone permission when prompted
   - Actual SIM numbers will be fetched (once native code is implemented)

2. **iOS**:
   ```bash
   flutter run --release
   ```
   - Will always show mock numbers (iOS limitation)

### Testing Platform Channel

Add this to test the platform channel:

```dart
// In phone_number_service.dart, add debug method
Future<void> testPlatformChannel() async {
  try {
    final result = await platform.invokeMethod('getPhoneNumbers');
    print('Platform channel result: $result');
  } catch (e) {
    print('Platform channel error: $e');
  }
}
```

---

## 📋 Implementation Checklist

### Android
- [ ] Update `AndroidManifest.xml` with permissions
- [ ] Implement `MainActivity.kt` with platform channel
- [ ] Update `build.gradle` (min SDK 21+)
- [ ] Test on real Android device with SIM card
- [ ] Test on dual SIM device
- [ ] Test permission denial flow
- [ ] Test with no SIM card inserted

### iOS
- [ ] Update `AppDelegate.swift` (returns empty array)
- [ ] Add user education about iOS limitations
- [ ] Consider alternative approaches (SMS autofill)
- [ ] Test fallback to mock numbers
- [ ] Update UI to show iOS-specific message

### General
- [ ] Test permission flows
- [ ] Test error handling
- [ ] Test loading states
- [ ] Test bottom sheet UI
- [ ] Test phone number formatting
- [ ] Update documentation

---

## 🎨 User Experience Flow

### Successful Flow (Android)

```
1. User clicks "Auto Fetch Phone Number"
   ↓
2. Loading indicator appears
   ↓
3. Permission check/request (if needed)
   ↓
4. Platform channel fetches SIM numbers
   ↓
5. Bottom sheet shows available numbers
   ↓
6. User selects a number
   ↓
7. Input field auto-fills with selected number
```

### Fallback Flow (Development/iOS)

```
1. User clicks "Auto Fetch Phone Number"
   ↓
2. Loading indicator appears
   ↓
3. Platform channel returns empty/fails
   ↓
4. Mock numbers are shown
   ↓
5. User selects a mock number
   ↓
6. Input field auto-fills
```

---

## 🚨 Common Issues & Solutions

### Issue 1: "No phone numbers found"

**Cause**: SIM card doesn't have number stored, or carrier doesn't provide it

**Solution**:
- Show helpful message to user
- Provide manual entry option
- This is normal for many carriers

### Issue 2: Permission denied

**Cause**: User denied phone permission

**Solution**:
- Fall back to mock numbers in development
- In production, show message explaining why permission is needed
- Provide settings link to enable permission

### Issue 3: Incorrect phone number format

**Cause**: Different countries have different formats

**Solution**:
- The `cleanPhoneNumber()` function handles this
- Adjust regex for your target countries
- Always validate on backend

---

## 📊 Production Considerations

### Should You Use This Feature?

**Pros**:
- Better UX - one tap instead of typing
- Reduces errors in phone number entry
- Faster onboarding

**Cons**:
- Doesn't work on iOS
- Not all SIM cards store numbers
- Requires sensitive permissions
- Can confuse users if number is wrong

### Recommendations:

1. **Make it optional**: Always provide manual entry
2. **Clear messaging**: Explain what will happen
3. **Handle failures**: Graceful fallback to manual entry
4. **Test extensively**: Different devices, carriers, and SIM configurations
5. **Analytics**: Track success rate to determine if worth maintaining

---

## 🔄 Alternative Solutions

If SIM number fetching proves unreliable:

### 1. SMS OTP Autofill
```dart
// Use SMS autofill (works on both platforms)
// Automatically fills OTP from SMS
// User must type phone number once
```

### 2. Truecaller-style Integration
- Partner with phone number verification services
- Better success rate
- Requires third-party integration

### 3. Contact Picker
```dart
// Let user pick their number from contacts
// Works on both platforms
// Requires contact permission
```

---

## 📱 Platform Channel Communication

### Flutter → Native

```dart
final result = await platform.invokeMethod('getPhoneNumbers');
// Returns: List<String> of phone numbers
```

### Native → Flutter

```kotlin
// Android
result.success(listOf("9876543210", "8765432109"))
```

```swift
// iOS
result([]) // Empty array for iOS
```

---

## 🎓 Learning Resources

- [Flutter Platform Channels](https://docs.flutter.dev/development/platform-integration/platform-channels)
- [Android TelephonyManager](https://developer.android.com/reference/android/telephony/TelephonyManager)
- [Android SubscriptionManager](https://developer.android.com/reference/android/telephony/SubscriptionManager)
- [iOS Limitations](https://developer.apple.com/documentation/contacts)
- [Permission Handler Plugin](https://pub.dev/packages/permission_handler)

---

## ✅ Summary

The phone number auto-fetch feature is **fully implemented on the Flutter side** with:
- Service architecture ready
- Permission handling
- UI components
- Error handling
- Graceful fallbacks

**Next steps:**
1. Implement Android native code (copy-paste from this guide)
2. Test on real Android devices
3. Handle iOS limitations appropriately
4. Monitor success rates in production

**For now**, the app works perfectly with mock numbers for development and testing! 🎉

---

*Last Updated: 2025-10-18*
*FitKhao User App - Phone Number Integration*
