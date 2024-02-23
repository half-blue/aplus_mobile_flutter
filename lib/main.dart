import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'firebase_options.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:convert';
import 'package:fluttertoast/fluttertoast.dart';

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

// DO NOT end with '/'
const String aplusUrl = "https://www.aplus-tsukuba.net";
const String fcmServerUrl = "https://fcm.aplus-tsukuba.net";

class _WebViewAppState extends State<WebViewApp> {
  late final WebViewController controller;
  String currentUrl = "";
  bool showButton = false; // ボタンの表示状態を管理する2値の状態変数
  bool isSubscribed = false; // 通知の購読状態を管理する変数

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

  // 通知の購読状態に基づいて表示するアイコンを決定する関数
  IconData getNotificationIcon() {
    return isSubscribed ? Icons.notifications_off : Icons.notifications;
  }

  void handleNotificationTap(Map<String, dynamic> payload) {
    // payloadに含まれる値を取得
    final String threadId = payload['thread_id'] ?? '';
    if (threadId.isEmpty) {
      return;
    }

    // URLを生成
    final String targetUrl = '$aplusUrl/threads/$threadId/';

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
                backgroundColor: Color.fromRGBO(0, 123, 255, 1.0),
                onPressed: () async {
                  final fcmToken = await FirebaseMessaging.instance.getToken();
                  if (fcmToken == null) {
                    // fcmTokenはString?型なのでnullチェックが必要
                    print('FCM token is null');
                    return;
                  }

                  // 現在表示されているURLからスレッドIDを抽出
                  final threadIdPattern = RegExp(r'threads/(\d+)');
                  final match = threadIdPattern.firstMatch(currentUrl);
                  if (match == null || match.groupCount < 1) {
                    print('Thread ID not found in the current URL');
                    return;
                  }
                  final threadId = match.group(1);
                  if (threadId == null) {
                    print('Thread ID not found in the current URL');
                    return;
                  }
                  print('Thread ID: $threadId');

                  // 購読しているスレッド番号のリストを取得
                  // Key: X-HALFBLUE-FCM-TOKEN, Value: FCMトークン

                  const subscriptionUrl =
                      '$fcmServerUrl/api/device/subscription';
                  print('Subscription URL: $subscriptionUrl');
                  final subscriptionResponse = await http.get(
                    Uri.parse(subscriptionUrl),
                    headers: <String, String>{
                      'Content-Type': 'application/json; charset=UTF-8',
                      'X-HALFBLUE-FCM-TOKEN': fcmToken, // FCMトークンをヘッダーに含める
                    },
                  );
                  print('Subscription response: ${subscriptionResponse.body}');
                  // subscriptionResponse.bodyの例:  {"threads":[113,4000,4001,4002,4003,4677]}

                  final subscribedThreads = <int>{};
                  final subscriptionData =
                      jsonDecode(subscriptionResponse.body);
                  print('Subscription data: $subscriptionData');
                  if (subscriptionData is Map<String, dynamic>) {
                    final threads = subscriptionData['threads'];
                    if (threads is List<dynamic>) {
                      for (final thread in threads) {
                        if (thread is int) {
                          subscribedThreads.add(thread);
                        }
                      }
                    }
                  }

                  print('Subscribed threads: $subscribedThreads');
                  // subscribedThreadsの例: {113, 4000, 4001, 4002, 4003, 4677}

                  if (subscribedThreads.contains(int.parse(threadId))) {
                    // 購読解除処理
                    final unsubscribeUrl =
                        '$fcmServerUrl/api/thread/$threadId/unsubscribe';
                    final unsubscribeResponse = await http.delete(
                      Uri.parse(unsubscribeUrl),
                      headers: <String, String>{
                        'Content-Type': 'application/json; charset=UTF-8',
                        'X-HALFBLUE-FCM-TOKEN': fcmToken, // FCMトークンをヘッダーに含める
                      },
                    );
                    print(
                        'unsubscribeResponse.statusCode: ${unsubscribeResponse.statusCode}');
                    if (unsubscribeResponse.statusCode == 200) {
                      print(
                          'Unsubscribed successfully from thread ID $threadId');
                      Fluttertoast.showToast(
                        msg: 'このスレッドの通知をオフにしました。',
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 2,
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    } else {
                      print(
                          'Failed to unsubscribe from thread ID $threadId: ${unsubscribeResponse.body}');
                    }
                  } else {
                    // 購読追加処理
                    final subscribeUrl =
                        '$fcmServerUrl/api/thread/$threadId/subscribe';
                    final subscribeResponse = await http.post(
                      Uri.parse(subscribeUrl),
                      headers: <String, String>{
                        'Content-Type': 'application/json; charset=UTF-8',
                        'X-HALFBLUE-FCM-TOKEN': fcmToken, // FCMトークンをヘッダーに含める
                      },
                      body: jsonEncode(<String, String>{
                        'device_type': Platform.isIOS ? 'ios' : 'android',
                      }),
                    );
                    print(
                        'subscribeResponse.statusCode: ${subscribeResponse.statusCode}');
                    if (subscribeResponse.statusCode == 201) {
                      print('Subscribed successfully to thread ID $threadId');
                      Fluttertoast.showToast(
                        msg: 'このスレッドの通知をオンにしました。',
                        gravity: ToastGravity.BOTTOM,
                        timeInSecForIosWeb: 2,
                        backgroundColor: Colors.black,
                        textColor: Colors.white,
                        fontSize: 16.0,
                      );
                    } else {
                      print(
                          'Failed to subscribe to thread ID $threadId: ${subscribeResponse.body}');
                    }
                  }
                  // isSubscribedの値を更新
                  if (mounted) {
                    // 購読追加または解除の処理
                    setState(() {
                      isSubscribed = !isSubscribed; // 購読状態を反転
                    });
                  }
                }, // OnPressed
                child: ImageIcon(
                  AssetImage('assets/images/notification_icon.png'),
                  size: 48, // Iconのサイズを指定
                  color: Color.fromRGBO(255, 255, 255, 1.0),
                ),
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
