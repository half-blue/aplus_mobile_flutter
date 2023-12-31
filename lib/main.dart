import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel foregroundChannel = AndroidNotificationChannel(
  'aplus_thread_nofitications', // id
  'フォアグラウンド通知', // title
  importance: Importance.high,
);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      badge: true, alert: true, sound: true);
  final fcmToken = await FirebaseMessaging.instance.getToken();
  if (fcmToken != null) {
    print("your token is $fcmToken");
  } else {
    print("token is null");
  }
  //Androidの場合は通知許可を求める
  if (Platform.isAndroid) {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.requestNotificationsPermission();
  }
  var initializationSettingsIOS = const DarwinInitializationSettings(
    requestAlertPermission: true,
    requestBadgePermission: true,
    requestSoundPermission: true,
  );
  await flutterLocalNotificationsPlugin.initialize(
    InitializationSettings(
      android: const AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: initializationSettingsIOS,
    ),
  );

  runApp(
    const MaterialApp(
      home: WebViewApp(),
    ),
  );
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController controller;
  String currentUrl = "";
  bool showButton = false; // ボタンの表示状態を管理する2値の状態変数

  @override
  void initState() {
    super.initState();
    const String aplusUrl = "うるる";
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent("A+Tsukuba-flutter-App")
      ..setNavigationDelegate(
        NavigationDelegate(
          onProgress: (int progress) {
            // Update loading bar.
          },
          onPageStarted: (String url) {},
          onPageFinished: (String url) {
            setState(() {
              currentUrl = url;
              showButton =
                  currentUrl.contains("threads"); // URLに'threads'が含まれているかチェック
            });
          },
          onWebResourceError: (WebResourceError error) {},
          onNavigationRequest: (NavigationRequest request) async {
            if (request.url.startsWith(aplusUrl)) {
              return NavigationDecision.navigate;
            } else {
              if (await canLaunchUrlString(request.url)) {
                await launchUrlString(
                  request.url,
                  mode: LaunchMode.externalApplication,
                );
              }
              return NavigationDecision.prevent;
            }
          },
        ),
      )
      ..loadRequest(
        Uri.parse(aplusUrl),
      );
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final notification = message.notification;
      final android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          notification.hashCode,
          notification.title,
          notification.body,
          NotificationDetails(
            android: AndroidNotificationDetails(
              foregroundChannel.id,
              foregroundChannel.name,
              channelDescription: foregroundChannel.description,
            ),
          ),
          //後でペイロードの設定をすること
          //payload: json.encode(message.data),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const EmptyAppBar(),
      body: Stack(
        children: <Widget>[
          WebViewWidget(
            controller: controller,
          ),
          if (showButton) // 条件に基づいてボタンを表示
            Positioned(
              left: 20,
              bottom: 25.5,
              child: FloatingActionButton(
                onPressed: () {
                  // ボタンが押された時の処理
                },
                child: const Icon(Icons.notifications),
              ),
            ),
        ],
      ),
    );
  }
}

class EmptyAppBar extends StatelessWidget implements PreferredSizeWidget {
  const EmptyAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color.fromARGB(0xFF, 0x31, 0x9D, 0xA0),
    );
  }

  @override
  Size get preferredSize => const Size(0.0, 0.0);
}
