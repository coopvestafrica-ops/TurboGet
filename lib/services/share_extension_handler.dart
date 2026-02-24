import 'dart:async';
import 'package:flutter/services.dart';

class ShareExtensionHandler {
  static ShareExtensionHandler? _instance;
  static ShareExtensionHandler get instance => _instance ??= ShareExtensionHandler._();
  ShareExtensionHandler._();

  static const MethodChannel _channel = MethodChannel('com.example.turboget/share');
  
  Function(String url)? onSharedUrl;
  StreamController<String>? _urlController;

  Future<void> initialize() async {
    _urlController = StreamController<String>.broadcast();
    
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onShareReceived') {
        final url = call.arguments as String?;
        if (url != null) {
          _urlController?.add(url);
          onSharedUrl?.call(url);
        }
      }
    });
  }

  Stream<String> get sharedUrls => _urlController?.stream ?? const Stream.empty();

  // For iOS: Add to AppDelegate.swift
  // For Android: Add intent-filter in AndroidManifest.xml
  
  String get androidIntentFilter => '''
<intent-filter>
    <action android:name="android.intent.action.SEND" />
    <category android:name="android.intent.category.DEFAULT" />
    <data android:mimeType="text/plain" />
</intent-filter>
''';

  void dispose() {
    _urlController?.close();
  }
}

// iOS AppDelegate code to add:
// Add this to your AppDelegate.swift:
//
// import Flutter
// import UIKit
//
// @UIApplicationMain
// @objc class AppDelegate: FlutterAppDelegate {
//   override func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
//     let controller = window?.rootViewController as! FlutterViewController
//     let channel = FlutterMethodChannel(name: "com.example.turboget/share", binaryMessenger: controller.binaryMessenger)
//     
//     if url.absoluteString.contains("http") {
//       channel.invokeMethod("onShareReceived", arguments: url.absoluteString)
//     }
//     
//     return super.application(app, open: url, options: options)
//   }
// }
