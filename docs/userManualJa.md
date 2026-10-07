# 制御ステーション利用マニュアル

**状態：実装済み。シミュレーション、同一 PC 内の ROS、UDP は確認済みです。Motive の実配信と実機走行は未確認です。**

この文書は、利用者が何を設定し、どの順番で確認・実行するかを説明します。再構成前のプログラムは `legacy/controlStationV1/` に保存してあります。旧版を使う場合だけ [旧版の README](../legacy/controlStationV1/README.md) を参照してください。

## 1. このプログラムで行うこと

制御ステーションは、車両の位置や速度を受け取り、MATLAB で指令を計算して車両へ送ります。実機なしのシミュレーションにも対応します。位置情報を Motive から得る場合は、別に動かす「Motive ブリッジ」が NatNet のデータを ROS の位置メッセージへ変換します。

```text
Motive PC → NatNet → Motive ブリッジ → ROS の位置トピック
                                      ↓
車両の状態 ───────────────────→ 制御ステーション → 速度指令 → 車両
```

**Motive のデータ受信に成功しても、ブリッジから ROS へ届くことまでは確認できません。** 付属サンプルによる受信は成功しましたが、旧版ブリッジによる取り込みは成功していません。新版ブリッジは実配信で未検証です。接続を一段ずつ確認してから実機制御へ進みます。

## 2. 最初に覚える言葉

| 言葉 | 意味 |
| --- | --- |
| MATLAB コマンドウィンドウ | `>>` が表示され、コマンドを入力する場所 |
| Motive | カメラで剛体の位置・姿勢を計測するソフト |
| Rigid Body（剛体） | Motive が一つの物体として追跡する対象 |
| NatNet | Motive の計測結果を別のプログラムへ渡す通信方式 |
| ROS トピック | ROS 内でメッセージを送受信する名前付きの経路 |
| ブリッジ | NatNet の計測結果を ROS メッセージへ変換するプログラム |
| プロファイル | 車両そのものの名前と、利用できる通信先の定義 |
| 実験設定 | 今回使う車両、測位方法、初期位置、制御則などの指定 |

## 3. 設定ファイル

`vehicles.csv` は使いません。**車両の定義、今回の実験条件、制御用 PC の接続設定を別々に管理します。**

| ファイル | 利用者が決める内容 | 変更する場面 |
| --- | --- | --- |
| `+vehicleProfiles/pi1.m` など | 車両名、入力と指令先の候補、トピックやポート、Motive の剛体対応 | 車両の構成・通信先が変わったとき |
| `+shared/vehicleCatalog.m` | プロファイルの自動登録と名前・ROS グループ名の検査 | 通常は編集しない |
| `+shared/experimentConfig.m` | 今回使う車両、入力候補、初期位置、制御則 | 実験条件を変えるとき |
| `+shared/stationConfig.m` | ROS と Motive の接続先、制御周期、待ち時間、指令の上限 | 制御用 PC やネットワークの条件が変わったとき |

`+shared/resolveVehicleSettings.m` は、これらを読み合わせて実行前に一つの設定へ確定する内部ファイルです。利用者は通常編集しません。制御ステーションと Motive ブリッジはこの同じ処理で車両設定を確定します。内部処理は `+station/` と `+bridge/` に分かれています。2つの起動口 `runControlStation.m` と `runMotiveRosBridge.m` は最上位にあります。

関数と設定項目は `lowerCamelCase`、クラスは `UpperCamelCase` とします。MATLAB のクラス名とクラスファイル名は一致させます。ROS のトピック名、メッセージ型、NatNet の製品名など、外部が決める名前は変更しません。

### 3.1 車両を選ぶ

`+shared/experimentConfig.m` の `selectedVehicleNames` に **今回使う車両名**を並べます。現在の選択は `pi3` です。新しい車両は `+vehicleProfiles/` にプロファイルを追加すると自動登録されます。ファイル名、`profile.name`、ROS トピックの先頭グループ名を一致させてください。実験設定には、ファイル内のコメントアウトしたテンプレートを参考に、車両ごとの条件を全項目記入します。

一度だけ選択を変える場合は `runControlStation("experiment", vehicleNames="pi1")` と指定します。どちらの方法でも、実行ログに**最終的に選ばれた車両と設定値**を保存します。

### 3.2 どこから位置を得るかを選ぶ

この選択は `+shared/experimentConfig.m` の各車両の `odometrySource` と `commandSink` に記録します。`pi1`〜`pi3` の入力候補は `motive`、`otos`、`wheelOdometry` です。`motive` はブリッジが配信する `nav_msgs/Odometry`、`otos` はローバが配信する `geometry_msgs/Pose2D`、`wheelOdometry` は車輪エンコーダ由来の速度を含む `nav_msgs/Odometry` を読みます。`katchaka` には `udpVelocity` があります。座標の扱いは入力候補から自動的に決まるため、別の設定項目はありません。Motive の剛体名と任意の Streaming ID は車両プロファイルに保持します。Motive を選んだ車両だけ、別の MATLAB セッションでブリッジを起動してください。

ROS トピックは車両名が `pi1` なら、Motive が `/pi1/odometry/motive`、OTOS が `/pi1/odometry/otos`、車輪が `/pi1/odometry/wheel` です。`pi2` と `pi3` では先頭の車両名を読み替えます。ローバ側と制御ステーション側の更新時期が違うと受信できないため、両方を新しい名前に揃えてください。

### 3.3 初期状態を決める

`initialState` は `[x, y, theta]` の順で、単位は m、m、rad です。OTOS では制御ステーションが最初に採用した測定の位置・向きをこの値に合わせます。車輪オドメトリと UDP の速度入力では、この値から位置を積分します。Motive の実機入力は共通座標の測定値をそのまま使うため、`initialState` は実機の位置合わせには使いません。シミュレーションでは入力方式にかかわらず、模擬車両の開始位置に使います。複数の車両を同じ座標軸で比較するときは、それぞれの座標設定が同じ場所と向きを表すようにしてください。

### 3.4 接続先を記録する

実機やブリッジを動かす前に、`+shared/stationConfig.m` の `ros.nodeHost`、`motive.serverIp`、`motive.clientIp` を現地の値と照合します。`ros.nodeHost` の現在値は環境に依存するため、そのまま使えるとは限りません。`katchaka` の UDP 指令先 IP は空欄です。実際の値が不明な場合は推測せず、設備担当者に確認します。

### 3.5 マウスで指令を試す

現在の `+shared/experimentConfig.m` ではマウス操作が有効です。停止制御則に戻す場合は、マウス操作用の三行をコメントアウトし、`config.controller = @station.stopController;` を有効にします。マウス操作の初期値は前進・後退が 0.05 m/s、旋回が 0.2 rad/s です。必要なら `station.MouseController(0.05, 0.2)` の数値を変更します。指令上限を超える値は送信前にエラーになります。

実験の Start を押すと別の「Manual drive」ウィンドウが開きます。車両名のボタンは複数同時に ON にできます。方向ボタンをマウスで押している間だけ、ON の車両すべてに同じ指令を送り、OFF の車両にはゼロを送ります。ボタンからカーソルが外れたときやマウスを離したときはゼロに戻ります。マウス解放を取り逃がした場合に備え、連続押下は標準で 10 秒までとし、その後は押し直します。車両選択を変えたときも方向指令は解除されるため、改めて方向ボタンを押します。中央の「停止」は方向指令だけを解除します。実験全体を終えるときは元の制御ステーション画面の Stop を押します。操作ウィンドウを閉じても指令はゼロになりますが、実験は終了しません。

### 3.6 二次元の位置表示を見る

Start / Stop 画面と同時に「Vehicle position map」ウィンドウが開きます。実機の Start は準備中には無効です。画面生成・状態受信・校正・初回位置描画を終え、描画後の新しい測定を確認すると有効になります。準備中も Stop または操作画面を閉じると中止できます。横軸は x、縦軸は y で、単位は m です。色付きの点が車両の現在位置、矢印が車両の向き、文字が車両名を表します。実機では Start 前の待機中から位置を更新します。車両が表示範囲の端に近づくと座標軸が広がります。地図のウィンドウを閉じても運転は続くため、運転を止めるときは Start / Stop 画面の Stop を押してください。

表示する値は状態入力に応じて決まる推定位置です。複数の車両を同じ画面で比較する場合は、それぞれの設定が同じ座標系を表すようにしてください。車輪オドメトリの位置は車輪速度の積分値なので、滑りなどによるずれが蓄積しえます。

## 4. 初回の準備

1. 制御用 PC に MATLAB を用意します。実機で ROS を使う場合は ROS Toolbox、UDP を使う場合は対応する MATLAB の通信機能、Motive を使う場合は OptiTrack MATLAB Plugin が必要です。詳しい導入手順は [OptiTrack MATLAB Plugin の導入](optitrackMatlab.md)を参照してください。
2. MATLAB の「現在のフォルダー」を、この文書がある `docs/` の一つ上、`runControlStation.m` があるフォルダーに合わせます。旧版と新版を同時に MATLAB パスへ追加しないでください。
3. 実機を使う前に、[Motive–ROS 最小接続試験](minimumConnectionTest.md)に従い、NatNet、ROS、ブリッジを一段ずつ確認します。Motive の Rigid Body が未登録なら[剛体トラッキング](rigidBodyTrackingJa.md)、カメラの調整が必要なら[キャリブレーション](calibrationJa.md)を参照してください。
4. 車両側の起動方法は [ローバ側の利用手順](https://github.com/KaitoKonda/harada-tsubakino-rover-agent/blob/main/docs/usage.md)で確認します。最初の接続確認は、車輪が接地していないなど、意図せず走行しない状態で行います。

## 5. 実験前から終了までの手順

### 手順 A：実機なしで確認する

1. MATLAB でこのプロジェクトを開きます。
2. コマンドウィンドウで `result = runControlStation("simulation", durationSeconds=10);` を実行します。
3. 表示された Stop を押すか、10 秒後に終了するのを待ちます。
4. `result.status` が `"completed"` なら、指定した時間を終えています。マウス画面で車両を選んで方向を押さなければ、指令はゼロです。シミュレーションは実際の ROS・UDP 通信を検証しません。

### 手順 B：Motive と ROS だけを確認する

1. Motive PC で計測または記録済みデータの再生を始めます。剛体が追跡できていることを画面で確認します。
2. 制御用 PC で、OptiTrack 付属サンプルがフレームと剛体 ID を読めることを確認します。
3. MATLAB で ROS の試験用トピックを送受信できることを確認します。
4. `+shared/stationConfig.m` の `ros.nodeHost`、`motive.serverIp`、`motive.clientIp` と、`+vehicleProfiles/pi1.m` の剛体名・IDを現地の値に合わせます。`+shared/experimentConfig.m` で pi1 の `odometrySource` が `"motive"` であることを確認します。ブリッジ用の MATLAB A で、まず一台だけを指定して実行します。

   ```matlab
   runMotiveRosBridge([], [], "pi1")
   ```

   表示される車両名、剛体名・ID、トピックを照合します。処理中は MATLAB A の `>>` が戻らないのが正常です。
5. 別の MATLAB B で同じプロジェクトを開き、対象トピックを購読します。

   ```matlab
   config = shared.stationConfig();
   rosinit(char(config.ros.masterUri), 'NodeHost', char(config.ros.nodeHost));
   subscriber = rossubscriber('/pi1/odometry/motive', 'nav_msgs/Odometry');
   message = receive(subscriber, 5);
   disp(message.Pose.Pose.Position)
   ```

   剛体を少し動かして再度 `message = receive(subscriber, 5);` を実行し、位置と時刻が更新されることを確認します。ブリッジの `publishedCount` が増えても、購読側で受け取るまでは合格としません。
6. ここで失敗した場合は実機制御へ進まず、最後に成功した段階を記録します。終了時は MATLAB A で Ctrl+C を押し、両方の MATLAB で必要に応じて `rosshutdown` を実行します。NatNet 単体・ROS 単体の操作例は [Motive–ROS 最小接続試験](minimumConnectionTest.md)を参照してください。

### 手順 C：実機を接続する

1. `+shared/experimentConfig.m` で今回の車両と状態入力を選び、`+shared/stationConfig.m` で IP アドレスと指令上限を確認します。
2. `result = runControlStation("experiment", vehicleNames="pi1");` のように、まず 1 台だけで実行します。ROS を使う場合はマスターへの接続後、MATLAB が Enter キーの入力を待ちます。この段階では位置情報の接続待ち時間は始まりません。
3. 対象車両を起動します。Motive を選んだ場合は別の MATLAB セッションでブリッジも起動します。必要なら対象の状態トピックが更新されることを確認します。
4. 起動を確認してから、`runControlStation` を実行している MATLAB のコマンドウィンドウで Enter キーを押します。ここから位置情報の受信を待ち、期限内に届かなければ車両名付きのエラーを表示します。
5. 受信状態、進行方向、停止手段を確認してから、表示された画面の Start を押します。Start 前はゼロ指令を送ります。
6. 終了するときは Stop を押します。緊急時は車両側の停止手段も使ってください。通信が切れた場合、指令が車両へ届いたとは限りません。
7. 終了後に `result.status` と実行ログを確認します。必要に応じて MATLAB の ROS 接続を `rosshutdown` で閉じます。

### 起動時だけ設定を変える

`runControlStation` の名前付き引数には `vehicleNames`、`durationSeconds`、`controller`、`showUi`、`waitForNextCycle`、`saveRunLog`、`stationConfig`、`experimentConfig` を使います。例えば `runControlStation("simulation", vehicleNames="pi3", durationSeconds=10, saveRunLog=false)` は一回だけ車両と時間を指定し、ファイルへのログ保存を止めます。実機では `showUi` と `waitForNextCycle` を無効にできません。接続待ち時間と状態の有効期限は `stationConfig` の `connectionTimeoutSeconds` と `odometryTimeoutSeconds` で設定します。制御周期は `controlRateHz`、前進速度の上限は `maxLinearVelocity` です。

戻り値 `result` は保存を無効にしても作られます。`result.elapsedSeconds` は運転開始からの秒数、`result.states` と `result.commands` は車両ごとの状態と指令です。各列の順番は `stateComponents` と `commandComponents`、車両の順番は `vehicleNames` で確認できます。`odometryFresh` はその周期に状態が有効だったか、`commandSent` は指令の送信呼び出しが成功したかを示します。`commandSent` は車両が指令を受領した証明ではありません。実行条件は `stationConfig`、`experimentConfig`、`vehicleSettings`、終了時の理由は `status` と `errorText`、保存先は `logFilePath` に入ります。

## 6. 失敗したときの見分け方

| 最後に成功したこと | 次に確認すること |
| --- | --- |
| MATLAB が `natnet` を認識した | DLL、Motive の配信、両 PC の IP、通信方式 |
| NatNet サンプルが剛体を読めた | ブリッジの接続設定、フレーム解釈、剛体 ID の対応 |
| ブリッジが剛体を選べた | ROS 接続先、配信トピック、ROS メッセージの送信結果 |
| ROS の位置トピックを受信できた | 実験設定のトピック名、状態の鮮度、制御ステーションの接続待ち |
| 制御ステーションが状態を読めた | 車両への指令経路、車両側の受信状態、安全停止 |

エラー画面だけで「Motive が故障した」と判断しないでください。ブリッジはフレーム番号、受信・照合・追跡・配信の件数を表示します。調査時は、実行日時、実行したコマンド、表示されたエラー全文、最後に成功した段階を残してください。

## 7. ファイルの役割を知りたいとき

普段の操作では次の内部ファイルを編集しません。担当を分けることで、問題が起きた段階を探しやすくします。

| ファイル | 受け持つ処理 |
| --- | --- |
| `+station/StationRunner.m` | 接続待ち、開始待ち、制御の繰り返し、安全停止 |
| `+station/StationWindow.m` | Start / Stop の画面 |
| `+station/PositionMap.m` | 車両位置と向きの二次元表示 |
| `+station/RunLogger.m` | 実行条件、状態、指令、終了理由の保存 |
| `+station/Vehicle.m`, `+station/StateEstimator.m` | 車両状態の保持、座標初期化、状態の計算 |
| `+station/RosOdometrySource.m`, `+station/UdpOdometrySource.m` | ROS / UDP の状態受信 |
| `+station/RosCommandSink.m`, `+station/UdpCommandSink.m` | ROS / UDP の指令送信 |
| `+station/SimulatedVehicleIo.m` | 実機なしの車両モデル |
| `+bridge/MotiveRosBridge.m`, `+bridge/NatNetFrameSource.m`, `+bridge/decodeNatNetFrame.m` | Motive 接続、フレーム取得・解釈、ROS 配信の進行 |
| `+bridge/resolveRigidBodyMappings.m`, `+bridge/MotiveCoordinateTransform.m`, `+bridge/RosOdometryPublisher.m` | 剛体の対応付け、座標変換、ROS メッセージ送信 |

## 8. 現在の動作と確認範囲

- 制御ステーションとブリッジは、同じ確定済み車両設定を使用する。
- 車両名、トピック、ポート、剛体 ID の重複や欠落を、通信開始前に検出する。
- 受信できない剛体や追跡されていない剛体を、正常な位置として配信しない。
- 実験中に新しい状態が届かなくなったら、全車両へのゼロ指令を試みて終了する。自動再開しない。
- ログには、選択した車両と実際に使用した設定、時刻、状態、指令、終了理由を残す。
- MATLAB R2026a でシミュレーション、UDP の PC 内送受信、ROS の PC 内送受信を確認した。Motive の実フレーム受信、別 PC 間の通信、実機走行と停止は現地で別途確認する。

### 起動・待機中の受信エラーを調べる

ログの `result.diagnostics` は運転開始前も記録します。`phase` は `uiInitialized`（画面生成と初回描画）、`connecting`（最初の受信確認）、`initialMapDrawn`（校正後の初回位置描画）、`ready`（描画後の新測定待ち）、`standby`、`running` です。`ready` の途中の記録は準備完了を意味しません。

`durationSeconds` は描画イベントでは描画所要時間、受信待ちではその待ち開始からの経過時間、standby/running では周期の時間差です。`diagnostics.elapsedSeconds` はログ作成からの実時間で、Enter 入力待ちも含みます。既存の `result.elapsedSeconds`（運転開始からの時間）とは別の系列です。

例えばエラーで保存されたログを確認します。

```matlab
saved = load("logs/対象のログ.mat", "result");
d = saved.result.diagnostics;
d([d.phase] == "uiInitialized")
d([d.phase] == "initialMapDrawn")
k = find([d.phase] == "standby", 1, "last");
if ~isempty(k)
    d(k).vehicles.pi3
end
```

車両ごとの `ageSeconds` は採用した最終測定からの時間、`timeoutSeconds` は有効期限、`sampleNumber` は測定番号、`fresh` はその周期での鮮度判定です。未受信時の age は Inf になります。`checkedAtSeconds` と `receivedAtSeconds` は各 Vehicle の作成時を基準にした時計です。

ROS の場合はさらに `vehicles.pi3.ros` にコールバック実行数（`receivedCount`）、有効測定の採用数（`acceptedCount`）、ヘッダー時刻と値による棄却数（`rejectedStampCount`、`rejectedValueCount`）を残します。コールバック実行数はネットワーク上の受信パケット数ではありません。数が止まった場合は配信停止・通信・MATLAB の処理遅延を別途確認し、棄却数だけが増える場合は配信値や Header.Stamp を確認します。
