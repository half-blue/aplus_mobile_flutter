# aplus_mobile_flutter
「A＋つくば」のネイティブアプリ開発ブランチ

WebViewでA+つくばを表示＋更新をプッシュ通知する。

## アプリの入手
以下のストアからインストールできる。

<a href="https://apps.apple.com/jp/app/a-%E3%81%A4%E3%81%8F%E3%81%B0/id6478435435?itsct=apps_box_badge&amp;itscg=30200" style="display: inline-block; overflow: hidden; border-radius: 13px; width: 250px; height: 83px;"><img src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/ja-jp?size=250x83&amp;releaseDate=1708819200" alt="Download on the App Store" style="border-radius: 13px; width: 250px; height: 83px;"></a>
<a href='https://play.google.com/store/apps/details?id=com.aplus.tsukuba2023&pcampaignid=pcampaignidMKT-Other-global-all-co-prtnr-py-PartBadge-Mar2515-1'><img alt='Google Play で手に入れよう' src='https://play.google.com/intl/en_us/badges/static/images/badges/ja_badge_web_generic.png' style="border-radius: 13px; height: 83px;"/></a>

## 関連リポジトリ
- [A+つくば本体](https://github.com/half-blue/A_plus_Tsukuba) ... WebViewで表示するWebサイト。ネイティブアプリのUAは`A+Tsukuba-flutter-App`になる。
- [FCMサーバ](https://github.com/half-blue/aplus_mobile_fcm_server) ... 通知スレッドの購読情報等を管理し、Firebase Cloud Messagingに通知送信を命じる
