# harada-tsubakino-control-station

MATLAB上で複数車両を登録し、ROSまたはUDPで状態を受信して指令を送る制御側リポジトリです。現在の車両一覧と通信設定は `vehiclesMyDesk.xlsx` にあり、`main.m` が接続待ち、較正、待機、制御ループを順に実行します。

## Motiveから位置姿勢を取り込む

`run_motive_ros_bridge.m` は、OptiTrack公式のNatNet MATLAB wrapperから剛体姿勢を取得し、制御コードが購読する `nav_msgs/Odometry` に変換します。標準の車両位置トピックは `/pi1/localization/odom`、`/pi2/localization/odom`、`/pi3/localization/odom` です。これはローバーに搭載したOTOSセンサーの生データとは別のトピックです。

MATLAB Pluginの導入とMotive側のストリーミング設定は、[MATLABにOptiTrack Motive連携を導入する](docs/optitrack-matlab.md)を参照してください。実機を一度に接続せず段階的に確認する場合は、[Motive–ROS最小接続試験](docs/minimum-connection-test.md)に従ってください。

Rigid Bodyのマーカー配置、作成、ピボット調整、Refineについては、[Rigid Bodyトラッキング日本語マニュアル](docs/rigid-body-tracking-ja.md)を参照してください（[英語原文](docs/rigid-body-tracking-en.md)）。

カメラシステムのMasking、Wanding、Ground Plane設定、キャリブレーション更新については、[キャリブレーション日本語マニュアル](docs/calibration-ja.md)を参照してください（[英語原文](docs/calibration-en.md)）。

ネットワークは次を想定しています。

- 有線LAN: 施設側Motiveネットワーク
- Wi-Fi: 可搬ルータとLightRoverのネットワーク
- ROS master: 制御ノートPC上

`motive_config.m` の次の3項目は、施設で確認するまで意図的に空欄です。

- `serverIP`: Motiveが動くPCのIPアドレス
- `clientIP`: 制御ノートPCの「有線LAN側」IPアドレス
- `motiveVersion`: 現地で確認したMotiveのバージョン（記録用。接続時のNatNetプロトコルは自動交渉）

`rosNodeHost` はROS通信に使う「Wi-Fi側」IPアドレスなので、`clientIP` と混同しないでください。Motive側では Data Streaming を有効にし、まずはUnicastを選びます。剛体名は初期値として `pi1`、`pi2`、`pi3` を置いてあり、Motive上の名前と異なる場合は `rigidBodies.name` を直します。名前の代わりにStreaming IDを固定したい場合は `rigidBodies.id` に数値を指定できます。

`main.m`も同じ`rosMasterURI`と`rosNodeHost`を使用します。制御を始める前に、`rosNodeHost`が可搬ルータへ接続したノートPCのIPアドレスになっていることを確認してください。既にMATLABでROSノードが起動している場合は既存設定が再利用されるため、IPを変更した後は一度`rosshutdown`してから`main`を実行します。

必要なOptiTrack MATLAB Plugin（`natnet.m`、`NatNetML.dll`、`NatNetLib.dll`）をMATLABパスに追加した後、別のMATLABセッションで次を実行します。

```matlab
run_motive_ros_bridge
```

その後、制御用MATLABセッションで `main` を実行します。ブリッジはMotiveのY-up座標をROSのZ-up座標へ `x=X, y=-Z, z=Y` として変換し、追跡されていない剛体は配信しません。制御側はタイムスタンプ付きオドメトリが0.25秒以上更新されない場合、全車両へ速度・角速度ゼロを送ります。

座標変換とNatNetフレーム形式の処理は、MotiveやROSに接続せず確認できます。

```matlab
results = runtests(["test_MotiveCoordinateTransform.m", "test_MotiveFrameAdapter.m"])
assert(all([results.Passed]), "A unit test failed")
```

## 参照資料

- [LightRover Raspberry Pi OS セットアップ](https://vstoneofficial.github.io/lightrover_webdoc/)
- [名古屋大学 飛行性能評価風洞・モーションキャプチャ設備](https://www.mae.nagoya-u.ac.jp/flight/facilities.html)
- [OptiTrack Prime X 41](https://www.motioncapture.jp/optitrack/products/camera/primex41.html)
- [OptiTrack NatNet MATLAB wrapper](https://docs.optitrack.com/v3.2/developer-tools/natnet-sdk/natnet-matlab-wrapper)
