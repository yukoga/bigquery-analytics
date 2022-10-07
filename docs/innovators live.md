---
marp: true
---

# Innovators Live in Japan
# Google Analytics 4 と身近になった BigQuery
---

## Google Analytics 4 になって BigQuery export は何がかわったのか？
- 無料版 Google Analytics でも export できるようになった  
    - 1M events per day
- 細やかな export の設定が可能に
    - Stream を選んで export できるようになった  
    - Export 先 の reagion 指定ができる
- Schema がかわった
    - イベントごとに１行  
- 注意点
    - No backfill 


[アナリティクス ヘルプ [GA4] BigQuery export](https://support.google.com/analytics/answer/9358801) より

---

## なんのために GA4 のデータを export するの？  
- GA4 のレポート画面ではできない集計・分析ができる  
    - 自由なディメンション（表側）と指標（表頭）の組み合わせ
    - より専門的な分析 （例）統計解析、機械学習 ... etc.
- BigQuery のエコシステムが利用できる  
    - 豊富な連携先
        - Google Spreadsheet
        - データ ポータル
        - Looker
        - その他数多くのソリューション


---

フィールド名	データ型	説明
アプリ	 	 
app_info	RECORD	アプリについての情報を格納するレコード。
app_info.id	STRING	アプリのパッケージ名またはバンドル ID。
app_info.firebase_app_id	STRING	アプリに関連付けられている Firebase アプリ ID。
app_info.install_source	STRING	アプリをインストールしたストア。
app_info.version	STRING	アプリの versionName（Android の場合）または short bundle version。
デバイス	 	 
device	RECORD	デバイスの情報を格納するレコード。
device.category	STRING	デバイスのカテゴリ（モバイル、タブレット、PC）。
device.mobile_brand_name	STRING	デバイスのブランド名。
device.mobile_model_name	STRING	デバイスのモデル名。
device.mobile_marketing_name	STRING	デバイスのマーケティング名。
device.mobile_os_hardware_model	STRING	オペレーティング システムから直接取得したデバイスのモデル情報。
device.operating_system	STRING	デバイスのオペレーティング システム。
device.operating_system_version	STRING	OS のバージョン。
device.vendor_id	STRING	IDFV（IDFA を収集していない場合にのみ使用）。
device.advertising_id	STRING	広告 ID または IDFA。
device.language	STRING	OS の言語。
device.time_zone_offset_seconds	INTEGER	GMT との時差（秒単位）。
device.is_limited_ad_tracking	BOOLEAN	
デバイスの広告トラッキング制限の設定。

iOS14 以降では、IDFA がゼロ以外の場合、false が返されます。

device.web_info.browser	STRING	ユーザーがコンテンツを閲覧したブラウザ。
device.web_info.browser_version	STRING	ユーザーがコンテンツを閲覧したブラウザのバージョン。
device.web_info.hostname	STRING	ログに記録されたイベントに関連付けられたホスト名。
ストリームとプラットフォーム	 	 
stream_id	STRING	ストリームの数値 ID。
platform	STRING	アプリケーションが構築されているプラットフォーム。
ユーザー	 	 
user_first_touch_timestamp	INTEGER	ユーザーが初めてアプリを起動したか、サイトに訪れた時刻（マイクロ秒単位）。
user_id	STRING	setUserId API によって設定されるユーザー ID。
user_pseudo_id	STRING	ユーザーの仮の ID（アプリ インスタンス ID など）。
user_properties	RECORD	setUserProperty API によって設定される、ユーザー プロパティの繰り返しレコード。
user_properties.key	STRING	ユーザー プロパティの名前。
user_properties.value	RECORD	ユーザー プロパティの値を格納するレコード。
user_properties.value.string_value	STRING	ユーザー プロパティの文字列値。
user_properties.value.int_value	INTEGER	ユーザー プロパティの整数値。
user_properties.value.double_value	FLOAT	ユーザー プロパティの倍精度値。
user_properties.value.float_value	FLOAT	このフィールドは現在使用されていません。
user_properties.value.set_timestamp_micros	INTEGER	ユーザー プロパティが最後に設定された時刻（ミリ秒単位）。
user_ltv	RECORD	ユーザーのライフタイム バリューに関する情報を格納するレコード。このフィールドは当日表では使用されません。
user_ltv.revenue	FLOAT	ユーザーのライフタイム バリュー（収益）。このフィールドは当日表では使用されません。
user_ltv.currency	STRING	ユーザーのライフタイム バリュー（通貨）。このフィールドは当日表では使用されません。
キャンペーン	 	注: traffic_source のアトリビューションは、クロスチャネルのラストクリックに基づいています。traffic_source の値は、ユーザーがインストール後に次のキャンペーンを操作しても変更されません。
traffic_source	RECORD	ユーザーを最初に獲得したトラフィック ソースの名前。このフィールドは当日表では使用されません。
traffic_source.name	STRING	ユーザーを最初に獲得したマーケティング キャンペーンの名前。このフィールドは当日表では使用されません。
traffic_source.medium	STRING	ユーザーを最初に獲得したメディアの名前（有料検索、オーガニック検索、メールなど）。このフィールドは当日表では使用されません。
traffic_source.source	STRING	ユーザーを最初に獲得したネットワークの名前。このフィールドは当日表では使用されません。
地域	 	 
geo	RECORD	ユーザーの位置情報を格納するレコード。
geo.continent	STRING	イベントが報告された大陸（IP アドレスベース）。
geo.sub_continent	STRING	イベントが報告された亜大陸（IP アドレスベース）。
geo.country	STRING	イベントが報告された国（IP アドレスベース）。
geo.region	STRING	イベントが報告された地域（IP アドレスベース）。
geo.metro	STRING	イベントが報告された大都市圏（IP アドレスベース）。
geo.city	STRING	イベントが報告された都市（IP アドレスベース）。
イベント	 	 
event_date	STRING	イベントが記録された日付（アプリの登録タイムゾーンにおける日付を YYYYMMDD 形式で示したもの）。
event_timestamp	INTEGER	該当クライアントでイベントが記録された時刻（ミリ秒単位、UTC）。
event_previous_timestamp	INTEGER	該当クライアントで前回イベントが記録された時刻（ミリ秒単位、UTC）。
event_name	STRING	イベントの名前。
event_params	RECORD	このイベントに関連付けられたパラメータを格納する繰り返しレコード。
event_params.key	STRING	イベント パラメータのキー。
event_params.value	RECORD	イベント パラメータの値を格納するレコー
