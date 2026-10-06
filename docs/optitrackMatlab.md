# OptiTrack MATLAB Plugin の導入

この文書は旧版の導入メモを現行の制御ステーション用に更新したものです。Motive の画面名はバージョンにより異なります。接続設定は現地で確認した値を使ってください。

## 1. プラグインを MATLAB から見えるようにする

1. [OptiTrack の配布ページ](https://optitrack.com/support/downloads?cat=plugin)から MATLAB Plugin を入手し、展開します。既に配布済みのフォルダーがある場合は、それを使います。
2. 展開先に `Matlab/natnet.m`、サンプルの `OptiSample_*.m`、`NatNetML.dll`、`NatNetLib.dll` があることを確認します。手元の Plugin 1.1.0 では `natnet.m` は `Matlab/`、DLL はその一つ上にあります。
3. MATLAB の［ホーム］→［パスの設定］で `natnet.m` がある `Matlab/` フォルダーを追加します。制御ステーションの最上位フォルダーも MATLAB の現在のフォルダーまたは検索パスに置きます。旧版の `legacy/controlStationV1/` は同時に追加しません。

MATLAB のコマンドウィンドウで次を入力し、`natnet.m` の実際の場所が表示されることを確かめます。

```matlab
which natnet -all
properties('natnet')
```

初回に DLL の選択を求められたら、展開先の `NatNetML.dll` を指定します。`NatNetLib.dll` も同じ場所に保持します。OptiTrack のプラグイン説明も、初回に `NatNetML.dll` を指定する手順を案内しています。[OptiTrack MATLAB Plugin](https://docs.optitrack.com/v3.2/plugins/optitrack-matlab-plugin)

## 2. Motive の配信を設定する

Motive の Streaming 設定で、NatNet の配信を有効にし、Rigid Body を配信対象にします。`Local Interface` には、制御用 PC から到達できる Motive PC のインターフェースを選びます。同じ PC だけで試す場合は `127.0.0.1` を使えます。`Transmission Type` は現行の `+shared/stationConfig.m` の `motive.connectionType` と一致させます。初期設定は `Unicast` です。設定項目と標準ポート（コマンド UDP 1510、データ UDP 1511）は [Motive の Streaming 設定](https://docs.optitrack.com/motive-ui-panes/settings/settings-streaming)を参照してください。

制御ステーション側では `+shared/stationConfig.m` の次の値を記入します。

| 項目 | 入れる値 |
| --- | --- |
| `motive.serverIp` | Motive PC の施設 LAN 側 IP |
| `motive.clientIp` | 制御用 PC の同じ LAN 側 IP |
| `motive.connectionType` | Motive 側と同じ `Unicast` または `Multicast` |

これらの IP を推測で埋めず、実際のネットワークで確認します。Motive のカメラ専用ネットワークを変更する必要がある場合は、施設担当者に確認します。

## 3. まず付属サンプルで受信する

`OptiSample_RigidBodyPoseData.m` は剛体の位置と姿勢を確認するための付属サンプルです。サンプルの接続 IP と通信方式を現地の条件へ合わせ、Motive でライブ計測または Take 再生を開始して実行します。**サンプルで受信できたという結果は、現行ブリッジから ROS まで届いたことを意味しません。** 次は [Motive–ROS 最小接続試験](minimumConnectionTest.md)で段階ごとに確認します。

## 4. 受信できない場合

- `which natnet -all` でプラグインを認識しているか確認する。
- DLL の選択先、MATLAB と DLL の実行環境、必要なら MATLAB の再起動を確認する。
- Motive の配信が有効か、Rigid Body が追跡中かを確認する。
- `serverIp` と `clientIp`、Motive の `Local Interface`、通信方式が対応しているか確認する。
- 別 PC の場合は配線と Windows ファイアウォール、UDP 1510・1511 の設定を確認する。

参考：[NatNet MATLAB Wrapper](https://docs.optitrack.com/v3.2/developer-tools/natnet-sdk/natnet-matlab-wrapper)、[制御ステーション利用マニュアル](userManualJa.md)。
