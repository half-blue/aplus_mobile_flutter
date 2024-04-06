import 'dart:io';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
      debugShowCheckedModeBanner: false,
    );
  }
}

class QuizPage extends StatefulWidget {
  @override
  _QuizPageState createState() => _QuizPageState();
}

class _QuizPageState extends State<QuizPage> {
  final TextEditingController _controller =
      TextEditingController(); // 入力を管理するコントローラ
  // クイズの回答をチェックするメソッド
  void checkAnswer() async {
    if (_controller.text.toUpperCase() == 'ITF' ||
        _controller.text.toUpperCase() == 'ITF.') {
      // 正解の場合、その情報を保存
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(quizPassedKey, true);
      // ITFチェック通過時に新入生スレッドの通知をONにする
      //Androidの場合は通知許可を求める
      if (Platform.isAndroid) {
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>()
            ?.requestNotificationsPermission();
      }
      final fcmToken = await FirebaseMessaging.instance.getToken();
      if (fcmToken == null) {
        // fcmTokenはString?型なのでnullチェックが必要
        print('FCM token is null');
      } else {
        // 新入生スレッド購読追加処理
        final subscribeUrl = '$fcmServerUrl/api/thread/6304/subscribe';
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
        print('subscribeResponse.statusCode: ${subscribeResponse.statusCode}');
        if (subscribeResponse.statusCode == 201) {
          print('Subscribed successfully to thread ID 6304');
        } else {
          print(
              'Failed to subscribe to thread ID 6304: ${subscribeResponse.body}');
        }
      }
      // WebViewAppに遷移
      Navigator.of(context)
          .pushReplacement(MaterialPageRoute(builder: (_) => WebViewApp()));
    } else {
      // 不正解の場合、フィードバックを提供
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('不正解です'),
          content: const Text('正しい答えを入力してください。'),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('閉じる'),
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
      appBar: AppBar(title: const Text('筑波大生チェック')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "このサービスは筑波大生専用のサービスです。\n筑波大生は以下のクイズに解答して先に進んでくさい。\n\n筑波大学を表すアルファベット３文字を入力してください。\n（半角英文字で入力してください。）",
                textAlign: TextAlign.center,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: TextField(
                controller: _controller,
                decoration: const InputDecoration(
                  labelText: '答えを入力',
                  border: OutlineInputBorder(),
                ),
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: checkAnswer, // チェックボタンが押された時の処理
              child: const Text('答えを確認'),
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

// DO NOT end with '/'
const String aplusUrl = "https://5ca3-10";
const String fcmServerUrl = "https://5ca3-10";
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
              icon: "@drawable/aplus_tsukuba_kari_icon",
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
    final String postId = payload['post_id'] ?? '';

    print('Thread ID******: $threadId');
    print('Post ID******: $postId');

    // URLを生成 postIDをURLのパラメータとして追加
    String targetUrl = '$aplusUrl/threads/$threadId';
    if (postId.isNotEmpty) {
      targetUrl += '?post_id=$postId';
    }
    print('Target URL: $targetUrl');
    
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

                  // デバイスがactiveかどうかを確認し，inactiveの場合はactiveにする
                  const activeUrl = '$fcmServerUrl/api/device';
                  final activeResponse = await http.get(
                    Uri.parse(activeUrl),
                    headers: <String, String>{
                      'Content-Type': 'application/json; charset=UTF-8',
                      'X-HALFBLUE-FCM-TOKEN': fcmToken, // FCMトークンをヘッダーに含める
                    },
                  );
                  print(
                      'Active response: ${activeResponse.body}'); // 例: {"active":false,"device_type":"ios"}
                  // activeがtrueならば
                  if (activeResponse.body.contains('true')) {
                    // デバイスがactiveの場合は何もしない
                    print('Device is already active');
                  } else {
                    // デバイスがinactiveの場合はactiveにする
                    print('Device is inactive: $activeUrl/activate');
                    final activateResponseActivate = await http.patch(
                      Uri.parse('$activeUrl/activate'),
                      headers: <String, String>{
                        'Content-Type': 'application/json; charset=UTF-8',
                        'X-HALFBLUE-FCM-TOKEN': fcmToken, // FCMトークンをヘッダーに含める
                      },
                      // keyが文字列で，valueがbool型のJSONを送信
                      body: jsonEncode(<String, bool>{
                        'active': true,
                      }),
                    );
                    print(jsonEncode(<String, String>{
                      'active': true.toString(),
                    }));
                    print(
                        'Activate response: ${activateResponseActivate.body}');
                    // エラーメッセージを表示
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
