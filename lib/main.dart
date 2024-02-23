import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

const AndroidNotificationChannel foregroundChannel = AndroidNotificationChannel(
  'aplus_thread_nofitications', // id
  'フォアグラウンド通知', // title
  importance: Importance.high,
);

// クイズの状態を保存/読み込むためのキー
const String quizPassedKey = 'quizPassed';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final bool quizPassed = prefs.getBool(quizPassedKey) ?? false;
  
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  runApp(MyApp(quizPassed: quizPassed));
  // runApp(
  //   const MaterialApp(
  //     home: WebViewApp(),
  //   ),
  // );
}

class MyApp extends StatelessWidget {
  final bool quizPassed;

  const MyApp({Key? key, required this.quizPassed}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: quizPassed ? WebViewApp() : QuizPage(),
    );
  }
}

class QuizPage extends StatefulWidget {
  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final TextEditingController _controller = TextEditingController(); // 入力を管理するコントローラ
  // クイズの回答をチェックするメソッド
  void checkAnswer() async {
    if (_controller.text.toUpperCase() == 'ITF') {
      // 正解の場合、その情報を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(quizPassedKey, true);
      // WebViewAppに遷移
      Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => WebViewApp()));
    } else {
      // 不正解の場合、フィードバックを提供
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('不正解です'),
          content: Text('正しい答えを入力してください。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: Text('閉じる'),
            ),
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // クイズページのUIを構築
    return Scaffold(
      appBar: AppBar(title: Text('あんた何者？')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                '筑波大学といえば？',
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextField(
                controller: _controller,
                decoration: InputDecoration(
                  labelText: '答えを入力',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: checkAnswer, // チェックボタンが押された時の処理
              child: Text('答えを確認'),
            ),
          ],
        ),
      ),
    );
  }
}

class WebViewApp extends StatefulWidget {
  const WebViewApp({super.key});

  @override
  State<WebViewApp> createState() => _WebViewAppState();
}

const String aplusUrl = "https://9.ngrok-free.app";

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController controller;
  String currentUrl = "";
  bool showButton = false; // ボタンの表示状態を管理する2値の状態変数

  void initNotification() async {
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
      onDidReceiveNotificationResponse: (notification) async {
        // 通知をタップした時の処理（フォアグラウンド）
        final payload = notification.payload;
        if (payload != null) {
          final Map<String, dynamic> data = json.decode(payload);
          handleNotificationTap(data);
        }
      },
    );
  }

  @override
  void initState() {
    super.initState();
    initNotification();
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
          payload: json.encode(message.data),
        );
      }
    });

    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage? message) {
      if (message != null) {
        handleNotificationTap(message.data);
      }
    });

    FirebaseMessaging.instance
        .getInitialMessage()
        .then((RemoteMessage? message) {
      if (message != null) {
        handleNotificationTap(message.data);
      }
    });
  }

  void handleNotificationTap(Map<String, dynamic> payload) {
    // payloadに含まれる値を取得
    final String threadId = payload['thread_id'] ?? '';
    if (threadId.isEmpty) {
      return;
    }

    // URLを生成
    final String targetUrl = '${aplusUrl}threads/$threadId/';

    // WebViewを指定されたURLにロード
    controller.loadRequest(Uri.parse(targetUrl));
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
