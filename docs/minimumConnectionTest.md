# Motive–ROS 最小接続試験

旧版の接続試験を、現在の `runMotiveRosBridge` と `+shared/` の設定に合わせて書き直した手順です。**現行ブリッジによる Motive の実配信はまだ未検証です。** この試験ではローバを動かさず、Motive → NatNet → MATLAB → ROS の各段階を確認します。

```text
Motive PC → 施設 LAN → 制御用 PC の NatNet クライアント
                         → runMotiveRosBridge → ROS の位置トピック
```

## 0. 準備する

- MATLAB、ROS Toolbox、[OptiTrack MATLAB Plugin](optitrackMatlab.md)を制御用 PC に用意する。
- MATLAB の現在のフォルダーを `runMotiveRosBridge.m` があるプロジェクト最上位へ合わせる。旧版の `legacy/controlStationV1/` を MATLAB パスへ同時に追加しない。
- Motive で少なくとも一つの Rigid Body を定義し、追跡中にする。作成方法は [剛体トラッキング](rigidBodyTrackingJa.md)、カメラの調整は[キャリブレーション](calibrationJa.md)を参照する。
- 現地の設備担当者と、Motive PC の施設 LAN 側 IP、制御用 PC の施設 LAN 側 IP、使用する Rigid Body の名前と Streaming ID を確認する。カメラ専用ネットワークの設定は変更しない。

| 記録する項目 | 現地で確認した値 |
| --- | --- |
| Motive PC の施設 LAN 側 IP |  |
| 制御用 PC の施設 LAN 側 IP |  |
| サブネットマスク |  |
| Rigid Body 名 |  |
| Streaming ID |  |
| Motive のバージョン |  |

Windows のコマンドプロンプトで `ipconfig` を実行すると、各 PC の IPv4 アドレスを確認できます。制御用 PC の Wi-Fi 側やカメラ専用 LAN 側のアドレスと取り違えないでください。

## 1. Motive の配信を確認する

Motive の Streaming 設定で NatNet を有効にし、Rigid Body を配信対象にします。`Local Interface` には Motive PC の施設 LAN 側 IP、`Transmission Type` には双方で一致する方式を選びます。ここでは `Unicast` を使います。ライブ計測または Take 再生を開始し、対象の Rigid Body が追跡中であることを Motive の画面で確かめます。画面項目の位置はバージョンで変わるため、[OptiTrack の Streaming 設定](https://docs.optitrack.com/motive-ui-panes/settings/settings-streaming)も参照してください。

**合格条件：** 対象の Rigid Body 名と Streaming ID が Motive で確認でき、追跡が続いている。

## 2. NatNet だけを確認する

まず [Plugin の導入手順](optitrackMatlab.md)に従い、付属の `OptiSample_RigidBodyPoseData.m` で受信を確認します。サンプルは旧実験で成功した経路なので、失敗したらブリッジへ進む前に IP、配線、配信方式を調べます。

現在のプログラムが使う接続方式も切り分けたい場合は、MATLAB で次を実行します。先に `+shared/stationConfig.m` の `motive.serverIp` と `motive.clientIp` を現地の値へ記入してください。

```matlab
settings = shared.stationConfig();
client = natnet();
cleanup = onCleanup(@() client.disconnect());
connected = client.ConnectToNatNet( ...
    char(settings.motive.clientIp), ...
    char(settings.motive.serverIp), ...
    char(settings.motive.connectionType));
assert(connected == 1 && client.IsConnected == 1, 'NatNet 接続失敗');
model = client.getModelDescription();
for index = 1:double(model.RigidBodyCount)
    fprintf('%s: ID=%d\n', model.RigidBody(index).Name, model.RigidBody(index).ID);
end
pause(1);
frame = client.getFrame();
assert(~isempty(frame), 'フレームを受信できません');
fprintf('frame=%d\n', double(frame.iFrame));
pause(0.2);
nextFrame = client.getFrame();
assert(~isempty(nextFrame) && double(nextFrame.iFrame) > double(frame.iFrame), ...
    'フレーム番号が進んでいません');
clear cleanup client
```

途中でエラーが出たときは `clear cleanup client` を入力して接続を解放します。サンプルでは受信でき、上のコードでは受信できない場合は、接続引数やプラグインの版の違いを記録します。

**合格条件：** 剛体の名前と ID、増加するフレーム番号を取得できる。

## 3. 同じ PC 内で ROS を確認する

別の MATLAB セッションを開き、同じ PC 内だけで ROS の送受信を試します。必要なら既存の ROS 接続を `rosshutdown` で閉じてから実行してください。

```matlab
rosinit('http://localhost:11311', 'NodeHost', '127.0.0.1');
publisher = rospublisher('/connection_test', 'nav_msgs/Odometry');
subscriber = rossubscriber('/connection_test', 'nav_msgs/Odometry');
pause(1);
message = rosmessage(publisher);
message.Header.Stamp = rostime('now');
message.Pose.Pose.Orientation.W = 1;
send(publisher, message);
received = receive(subscriber, 5);
disp(received.MessageType)
delete(publisher);
delete(subscriber);
rosshutdown
```

**合格条件：** 5 秒以内に `nav_msgs/Odometry` を受信できる。これは同じ PC 内の確認であり、ローバとの通信確認ではありません。

## 4. 現行ブリッジを一台だけ動かす

MATLAB A と MATLAB B の二つのセッションを、どちらもプロジェクト最上位フォルダーで開きます。先に `+shared/stationConfig.m` の Motive 側 IP と、`+vehicleProfiles/pi1.m` の `profile.motive.name` を現地の値に合わせます。Streaming ID が確認できていれば `profile.motive.id` の `NaN` をその数値に置き換えられます。`+shared/experimentConfig.m` の pi1 の `odometrySource` は `"motive"` にします。MATLAB A に次を入力します。

```matlab
stationSettings = shared.stationConfig();
stationSettings.ros.masterUri = "http://localhost:11311";
stationSettings.ros.nodeHost = "127.0.0.1";
experiment = shared.experimentConfig();
runMotiveRosBridge(stationSettings, experiment, "pi1")
```

ブリッジは対象の剛体と ROS トピックを表示し、`frameNumber`、`receivedCount`、`matchedCount`、`trackedCount`、`publishedCount`、`invalidCount` の件数を約 1 秒ごとに表示します。MATLAB A の入力待ち記号 `>>` が戻らないのは、配信を続けているためです。

MATLAB B で同じ ROS マスターへ接続し、配信先の位置トピックを購読します。

```matlab
rosinit('http://localhost:11311', 'NodeHost', '127.0.0.1');
subscriber = rossubscriber('/pi1/odometry/motive', 'nav_msgs/Odometry');
message = receive(subscriber, 5);
disp(message.Pose.Pose)
```

剛体を少し動かし、MATLAB B でもう一度 `message = receive(subscriber, 5);` を実行します。位置と `message.Header.Stamp` が更新されることを確かめます。現在の軸変換は Motive の `[X,Y,Z]` を ROS の `[X,-Z,Y]` にします。追跡できない剛体は新しい位置として配信しません。

**合格条件：** MATLAB A で `publishedCount` が増え、MATLAB B で位置と時刻が更新される。A の表示だけで受信成功と判断しません。

## 5. 終了と記録

MATLAB A で Ctrl+C を押し、`>>` が戻るのを待ちます。MATLAB B で `delete(subscriber); rosshutdown` を実行します。MATLAB A でも必要に応じて `rosshutdown` を実行します。ブリッジの終了だけでは共有 ROS マスターを止めません。

| 項目 | 結果・値 |
| --- | --- |
| 実施日時と担当者 |  |
| Plugin 付属サンプル | 合格 / 不合格 |
| NatNet 単体 | 合格 / 不合格 |
| ROS 同一 PC 内 | 合格 / 不合格 |
| ブリッジの `publishedCount` |  |
| ROS 購読側の位置・時刻更新 | 合格 / 不合格 |
| 最後に成功した段階・エラー全文 |  |

失敗したら次の段階へ進まず、最後に成功した段階から調べます。NatNet が失敗した場合は Motive の配信、IP、通信方式と配線を確認します。`matchedCount=0` なら剛体名と ID、`trackedCount=0` なら追跡状態、`publishedCount>0` なのに MATLAB B で受け取れなければ ROS マスターとトピックを確認します。実配信でのフレーム型が想定と違う場合は、エラー全文とプラグインの版を記録してください。

この試験を通過した後の車両接続手順は[制御ステーション利用マニュアル](userManualJa.md)にあります。
