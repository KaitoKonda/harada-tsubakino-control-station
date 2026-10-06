# Motive–ROS最小接続試験

参照日: 2026-09-23

## 目的と試験範囲

最初からローバ、可搬ルータ、制御ループをすべて接続せず、次の経路だけを確認する。

```text
Motive PC → 施設側有線LAN → 制御ノートPCのNatNetクライアント
          → MotiveRosBridge → ノートPC内のROS master → /pi1/localization/odom
```

この試験にはローバ、Wi-Fi、可搬ルータ、`main.m`は不要である。ROSまで確認できた後に、ローバを含む試験へ進む。

## この文書の使い方

上から順番に実施し、各節の「合格条件」を満たしてから次へ進む。途中で失敗した場合は、それより後の試験を行わない。こうすることで、Motive、ネットワーク、NatNet、ROSのどこに問題があるかを一つずつ切り分けられる。

操作するコンピューターは2台である。

- **Motive PC**: 施設に固定され、カメラとMotiveが接続されているPC
- **制御ノートPC**: MATLABとこのリポジトリを実行するPC

この文書で「MATLABコマンドウィンドウ」と書かれている場所では、MATLABを起動し、画面中央または下部の`>>`が表示される欄へコードを貼り付けてEnterを押す。複数行のコードは、コードブロック全体をまとめてコピーしてよい。

途中で分からなくなった場合は、値を推測して入力しない。特にMotiveのカメラ用ネットワーク設定は変更せず、施設担当者に確認する。

## 前提

- ノートPCにMATLABとROS Toolboxが導入されている。
- ROS ToolboxでPython 3.10が設定済みである。
- OptiTrack MATLAB PluginがMATLABパスに追加されている。
- Motive上に少なくとも1個のRigid Bodyが定義され、Tracked状態になる。未登録の場合は[Rigid Bodyトラッキング日本語マニュアル](rigid-body-tracking-ja.md)に従って作成する。
- Motiveのカメラシステムがキャリブレーション済みである。再設定が必要な場合は[キャリブレーション日本語マニュアル](calibration-ja.md)に従う。
- Motive PCとノートPCの有線LANが同一サブネットにある。

試験を始める前に、次を手元に用意する。

- 制御ノートPCとその電源
- ノートPCを施設LANへ接続するLANケーブルまたは指定された有線接続手段
- Motiveを操作できる状態または施設担当者の立ち会い
- メモ用紙、またはこの文書の表へ値を記録する手段

この時点ではローバの電源を入れなくてよい。ノートPCを可搬ルータのWi-Fiへ接続する必要もない。

MATLABでプラグインを確認する。

1. 制御ノートPCでMATLABを起動する。
2. MATLABコマンドウィンドウへ次の4行を貼り付ける。
3. Enterを押し、エラーが出ないことを確認する。

```matlab
which natnet -all
n = natnet();
disp(class(n))
delete(n)
```

`C:\Optitrack\...\natnet.m`のようなファイル位置と、クラス名`natnet`が表示されれば合格である。赤いエラーが表示された場合は、先に[MATLABにOptiTrack Motive連携を導入する](optitrack-matlab.md)を実施する。

## 1. 現地情報を記録する

試験前に次を確認する。

| 項目 | 値 |
|---|---|
| Motive PCの施設LAN側IP | `________________` |
| ノートPCの有線LAN側IP | `________________` |
| サブネットマスク | `________________` |
| Rigid Body名 | `________________` |
| Streaming ID | `________________` |
| Motiveバージョン | `________________` |

`serverIP`はMotive PC、`clientIP`はノートPCの有線LAN側IPである。ローバ用Wi-FiのIPを`clientIP`に指定しない。

### WindowsでIPアドレスを調べる

Motive PCと制御ノートPCの両方で、次の操作を行う。

1. Windowsキーを押す。
2. `cmd`と入力し、「コマンド プロンプト」を開く。
3. `ipconfig`と入力してEnterを押す。
4. `イーサネット アダプター`の中から施設LANに接続されているものを探す。
5. `IPv4 アドレス`と`サブネット マスク`を上の表へ記入する。

Wi-Fi、Bluetooth、カメラ専用NICの値は使わない。`169.254`で始まるアドレスは、通常は正しいネットワーク設定を受け取れていない状態なので、そのまま試験を進めない。

例えば、Motive PCが`192.168.10.20`、ノートPCが`192.168.10.30`、両方のサブネットマスクが`255.255.255.0`なら、通常は同じサブネットにいる。両PCへ同じIPを設定してはいけない。

ノートPCのコマンドプロンプトで次を実行し、基本的な到達性を確認する。`<Motive PCのIP>`は、例えば`192.168.10.20`のような実際の値へ置き換える。山括弧は入力しない。

```text
ping <Motive PCのIP>
```

「応答」が返れば次へ進む。「要求がタイムアウトしました」と表示されても、Motive PCがpingを禁止している可能性があるため、それだけで故障とは断定しない。ただしIPと配線は再確認する。

## 2. Motiveを設定する

この操作はMotive PCで行う。Motiveのバージョンによって画面名が多少異なるが、`Data Streaming`または`Streaming`と書かれた設定画面を開く。

1. MotiveのSettingsまたはData Streamingペインを開く。
2. NatNetの`Enable`または`Broadcast Frame Data`をオンにする。
3. `Local Interface`に、手順1で記録したMotive PCの施設LAN側IPを選ぶ。
4. `Transmission Type`を`Unicast`にする。
5. Rigid Bodyデータを配信対象にする。
6. DataペインやRigid BodyのPropertiesで、試験に使うRigid Bodyの正確な名前とStreaming IDを調べ、手順1の表へ記入する。
7. Live計測を開始するか、記録済みTakeを再生する。

画面上でRigid Bodyが認識されていることも確認する。マーカーが隠れてRigid Bodyが消えている、灰色になっている、または未追跡を示す表示になっている場合は、追跡できる位置へ移動してから進む。

Windowsファイアウォールの確認を求められた場合は、施設LANでMotiveとMATLABの通信を許可する。NatNetの標準ポートはコマンド用UDP 1510、データ用UDP 1511である。

カメラが接続されているネットワークインターフェースを`Local Interface`に選ばない。判断できない場合は変更せず施設担当者へ確認する。

## 3. NatNetだけを確認する

ROSを起動せず、MotiveからMATLABまでを先に確認する。IPアドレスを現地の値に置き換えて実行する。

1. 制御ノートPCでMATLABを1つだけ開く。
2. MATLAB上部のアドレス欄で、このリポジトリのフォルダーを開く。
3. 下のコードの`192.168.x.x`を、手順1で記録した実際のIPへ書き換える。
4. コード全体をMATLABコマンドウィンドウへ貼り付け、Enterを押す。

`clientIP`と`serverIP`は間違えやすい。`clientIP`が手元のノートPC、`serverIP`がMotive PCである。

```matlab
clientIP = "192.168.x.x"; % ノートPCの有線LAN側IP
serverIP = "192.168.x.x"; % Motive PCのIP

n = natnet();
n.IsReporting = true;
n.ClientIP = char(clientIP);
n.HostIP = char(serverIP);
n.ConnectionType = 'Unicast';
n.connect();
assert(n.IsConnected == 1, "NatNet connection failed")

model = n.getModelDescription();
for k = 1:model.RigidBodyCount
    fprintf("%d: %s (Streaming ID=%d)\n", ...
        k, model.RigidBody(k).Name, model.RigidBody(k).ID);
end

pause(1)
frame = n.getFrame();
[frameNumber, rigidBodies] = MotiveFrameAdapter.unpack(frame);
assert(~isempty(rigidBodies), "No rigid-body frame received")
fprintf("NatNet frame %d received.\n", frameNumber)

delete(n)
```

成功すると、Rigid Bodyの名前とStreaming IDに続いて、例えば`NatNet frame 12345 received.`と表示される。フレーム番号は例と同じでなくてよい。

合格条件は次の3点である。

- `NatNet connection failed`という赤いエラーが出ない。
- 手順1で記録したRigid Body名とStreaming IDが一覧に表示される。
- `NatNet frame ... received.`が表示される。

ここで失敗する場合はROS側へ進まない。Motive設定、IP、配線、ファイアウォールの順に確認する。

## 4. ROSのPC内ループバックを確認する

この試験では外部機器へROS通信を出さないため、`NodeHost`に`127.0.0.1`を使用する。

1. 手順3で使用したMATLABをそのまま使う。
2. 下のコード全体をMATLABコマンドウィンドウへ貼り付ける。
3. 初回だけROS coreの起動に数秒かかるので、完了まで操作せず待つ。

```matlab
try
    rosshutdown
catch
end

rosinit('http://localhost:11311', 'NodeHost', '127.0.0.1')
publisher = rospublisher('/connection_test', 'nav_msgs/Odometry');
subscriber = rossubscriber('/connection_test', 'nav_msgs/Odometry');
pause(1)

message = rosmessage(publisher);
message.Header.Stamp = rostime('now');
message.Pose.Pose.Orientation.W = 1;
send(publisher, message)
received = receive(subscriber, 5);
disp(received.MessageType)

rosshutdown
```

成功すると最後に`nav_msgs/Odometry`と表示される。合格条件は、赤いエラーが出ず、5秒以内にこの文字列が表示されることである。

`rosshutdown`まで実行されるため、この試験が終わった時点でROSは停止している。次の手順でブリッジが改めてROSを起動する。

## 5. MotiveRosBridgeを剛体1個で確認する

ここだけはMATLABを2つ同時に開く。区別しやすいように、先に開く方を「MATLAB A」、後から開く方を「MATLAB B」と呼ぶ。

### 5-1. MATLAB Aでブリッジを起動する

1. MATLAB Aを開き、このリポジトリのフォルダーを表示する。
2. 下のコードで、2つのIP、Rigid Body名、Streaming IDを実際の値へ置き換える。
3. コード全体を貼り付けてEnterを押す。

最小試験では設定を1剛体だけに縮める。`config.rigidBodies.id = 1`の`1`は例であり、必ずMotiveに表示された実際のStreaming IDへ変更する。

```matlab
config = motive_config();
config.serverIP = "192.168.x.x"; % Motive PC
config.clientIP = "192.168.x.x"; % ノートPCの有線LAN側
station = station_config();
station.ros.nodeHost = "127.0.0.1";

config.rigidBodies = MotiveMappings(LoadVehicleSettings(station.vehicleFile, "pi1"));
config.rigidBodies.name = "Motive上のRigid Body名";
config.rigidBodies.id = 1; % 実際のStreaming ID

run_motive_ros_bridge(config, station)
```

成功すると`Motive bridge connected: ...`と`Press Ctrl+C to stop.`が表示される。この状態では処理が継続しているため、MATLAB Aの`>>`は戻ってこない。それが正常である。MATLAB Aは閉じず、そのままにする。

### 5-2. MATLAB Bで配信結果を受信する

1. Windowsのスタートメニューなどから、MATLABをもう1つ起動する。
2. これをMATLAB Bとして使用する。
3. MATLAB Bでも、このリポジトリのフォルダーを表示する。
4. 下のコードを貼り付けてEnterを押す。

```matlab
rosinit('http://localhost:11311', 'NodeHost', '127.0.0.1')
subscriber = rossubscriber('/pi1/localization/odom', 'nav_msgs/Odometry');
message = receive(subscriber, 5);
disp(message.Pose.Pose)
```

位置と姿勢の数値が表示されたら、MotiveからROSまでの1回目の受信は成功である。次にMotive上のRigid Bodyを少し動かし、MATLAB Bで次を数回実行する。

```matlab
message = receive(subscriber, 5);
fprintf("stamp=%d.%09d  x=%.3f  y=%.3f  z=%.3f\n", ...
    message.Header.Stamp.Sec, message.Header.Stamp.Nsec, ...
    message.Pose.Pose.Position.X, ...
    message.Pose.Pose.Position.Y, ...
    message.Pose.Pose.Position.Z)
```

次を確認する。

- 5秒以内にメッセージを受信する。
- `Header.Stamp`が更新される。
- 位置がRigid Bodyの移動に応じて変わる。
- MotiveからROSへの軸変換が`x=X, y=-Z, z=Y`になっている。
- MotiveでRigid Bodyを見失うと、新しいメッセージが配信されなくなる。

### 5-3. 安全に終了する

1. MATLAB Aをクリックして操作対象にする。
2. キーボードのCtrl+Cを押す。
3. `>>`が再び表示されるまで待つ。
4. MATLAB Bで`rosshutdown`を実行する。
5. MATLAB Aでも`rosshutdown`を実行する。

NatNet接続はブリッジの終了処理で閉じられる。ROS masterは他の処理と共用するため、ブリッジ停止だけでは閉じない。両MATLABで上記の終了操作を行う。

## 失敗時の切り分け

### NatNetに接続できない

- `serverIP`と`clientIP`を逆にしていないか確認する。
- 両PCの有線LANが同一サブネットか確認する。
- Motiveの`Local Interface`がカメラ専用ネットワークになっていないか確認する。
- MotiveとMATLABの両方が`Unicast`になっているか確認する。
- WindowsファイアウォールとUDP 1510・1511を確認する。

### Rigid Bodyが表示されない

- MotiveがLiveまたはTake再生状態か確認する。
- Rigid BodyがTracked状態か確認する。
- Rigid Body配信が有効か確認する。
- Motive上のStreaming IDを再確認する。

### ROSを起動できない

- MATLABのROS Toolbox設定でPython 3.10の実行ファイルが選択されているか確認する。
- 設定変更後にMATLABを再起動する。
- 既存のROS global nodeが残っている場合は`rosshutdown`してから再試行する。

### ブリッジは起動するがトピックを受信できない

- ブリッジ側と購読側でROS master URIが`http://localhost:11311`になっているか確認する。
- 両方の`NodeHost`が`127.0.0.1`になっているか確認する。
- `config.rigidBodies`を1要素に減らしたか確認する。
- トピック名が`/pi1/localization/odom`になっているか確認する。

## 次段階へ進む条件

次の全項目にチェックできれば最小接続試験は合格である。

- [ ] NatNetプラグインをエラーなく読み込めた。
- [ ] Motive PCとノートPCのIPを記録した。
- [ ] MotiveでUnicastストリーミングを有効にした。
- [ ] NatNet単体試験でRigid Body一覧とフレーム番号を取得した。
- [ ] ROSループバックで`nav_msgs/Odometry`を受信した。
- [ ] `/pi1/localization/odom`でRigid Bodyの位置姿勢を受信した。
- [ ] Rigid Bodyを動かすと位置とタイムスタンプが更新された。
- [ ] Ctrl+Cと`rosshutdown`で正常終了した。

すべて合格してから、ノートPCを可搬ルータへWi-Fi接続し、`station_config.m` の `ros.nodeHost` をWi-Fi側IPへ変更する。その後、READMEの `main("experiment", Vehicles="pi1")` から、複数ローバ、Kachakaの順に接続範囲を広げる。

## 試験結果メモ

| 項目 | 記録 |
|---|---|
| 実施日時 |  |
| 実施者 |  |
| NatNet単体 | 合格 / 不合格 |
| ROSループバック | 合格 / 不合格 |
| MotiveRosBridge | 合格 / 不合格 |
| 確認したROSトピック |  |
| エラー表示 |  |
| 備考 |  |
