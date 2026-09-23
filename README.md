# harada-tsubakino-control-station

ローバなどの状態を受け取り、MATLABで制御指令を計算して送り返す、制御用PC側のプログラムです。Motiveは位置を得る方法の一つです。**実機なしのシミュレーション、ROS車両、UDP車両を同じ `main` から扱います。**

## 最初に試す：実機を使わず10秒動かす

1. MATLABを開きます。
2. 上部の「現在のフォルダー」で、このREADMEと `main.m` があるフォルダーを選びます。
3. コマンドウィンドウ（`>>` がある欄）へ次を貼り付け、Enterを押します。

```matlab
result = main("simulation", Duration=10);
```

車両一覧で有効な3台をPC内に作り、10秒で終了します。途中で止めるには、表示された **Stop** を押すか小窓を閉じます。ROS、Motive、ローバ、追加のMATLAB起動は不要です。現在の制御関数はゼロ指令なので、初期位置から動かないのが正常です。シミュレーションではネットワークへ指令を送信しません。

終わると `Run log: ...` に結果の保存先が表示されます。MATLABで次を入力して確認できます。

```matlab
result.status        % "completed" なら指定時間の実行を完了
result.vehicleNames  % 使用した車両名
result.states(end,:,:) % 最後の位置・方位・速度・角速度
```

## 全体の流れ

```text
station_config.m ── ROS接続先、制御周期、制御関数、制限値
vehicles.csv ────── 車両一覧、状態の受信方法、指令の送信先、座標の扱い
        ↓
main ── 設定検証 → 接続 → 座標初期化 → 開始待ち → 状態更新・制御・送信 → 停止・保存
        ↑
実機: ROS / UDPで受信・送信
模擬: PC内の車両モデルから受信・送信

Motiveを使う場合だけ:
motive_config.m → run_motive_ros_bridge → vehicles.csvで指定したROS位置トピック
```

| ファイル | 役割 |
| --- | --- |
| `station_config.m` | 制御用PCの共通設定。まずここを確認する |
| `vehicles.csv` | 実機・シミュレーション・Motiveブリッジで共通の車両一覧 |
| `main.m` | 実行の入口。台数や制御内容を引数で選べる |
| `ControllerStop.m` | 全車両にゼロ指令を返す標準の制御関数 |
| `ControllerOneLine.m` | 隊列制御の実装用雛形。現在はゼロ指令 |
| `Vehicle.m` | 状態と通信を管理。状態受信と指令送信を個別に選択する |
| `motive_config.m` | Motive / NatNet専用の設定 |
| `run_motive_ros_bridge.m` | Motiveの位置姿勢をROSへ配信する |
| `logs/` | 設定・状態・指令・終了理由を保存する。Git管理対象外 |

## 実行方法を選ぶ

```matlab
% 引数なしでもシミュレーション。標準は250秒。
result = main();

% 1台だけ、または指定した複数台
result = main("simulation", Vehicles="pi1", Duration=10);
result = main("simulation", Vehicles=["pi1","pi3"], Duration=10);

% 画面を出さず、実時間を待たずに計算する（シミュレーション専用）
result = main("simulation", Duration=10, ShowUI=false, RealTime=false);
```

`Vehicles` を省略するとCSVの `enabled=1` の行を使います。名前を指定すると、その車両を `enabled=0` でも明示的に選べます。存在しない名前や重複名は起動前にエラーになります。

`simulation` は指令に応じて動く平面車両モデルです。ROS・UDPの通信そのもの、滑り、センサーノイズ、実機の性能は再現しません。ROS / UDPの実通信は後述の単体試験で確認します。

## 実機で使う前の準備

必要なものは接続方法で異なります。

- 全構成：MATLAB。自動テストはR2026aで確認しています。
- ROSを受信または送信する構成：ROS Toolbox。Pythonなどの準備は、使用するMATLAB版のROS Toolboxの案内に従います。
- UDPを受信または送信する構成：`udpport` が使える環境（Instrument Control Toolbox）。
- Motiveを使う構成：OptiTrack MATLAB Pluginと施設ネットワークの設定。

ローバ側は[ローバ側README](https://github.com/KaitoKonda/harada-tsubakino-rover-agent)のセットアップを終えます。制御用PCと車両を同じルータなどで相互通信できるように接続します。最初は車輪を浮かせるなど、ゼロ指令で接続を確認できる状態にしてください。

### 1. 共通設定を確認する

MATLABのファイル一覧で `station_config.m` をダブルクリックして開きます。

| 設定 | 意味 |
| --- | --- |
| `ros.masterURI` | ROSマスターの場所。制御用PCで起動するなら `http://localhost:11311` |
| `ros.nodeHost` | 制御用PCの、ローバ側から到達できるIP。初期値 `192.168.11.53` を現在の値へ変更する |
| `vehicleFile` | 共通の車両一覧。標準はこのフォルダーの `vehicles.csv` |
| `rateHz` | 制御の目標周期。標準は20 Hz |
| `durationSeconds` | 制御開始後の実行時間。標準は250秒 |
| `connectionTimeoutSeconds` | 初期接続の待ち時間。標準は5秒 |
| `odometryTimeoutSeconds` | 状態を新しいと認める時間。標準は0.25秒 |
| `controller` | 使用する制御関数。標準は `@ControllerStop` |
| `maxSpeed` / `maxAngularVelocity` | 指令の絶対値の上限。標準は0.2 m/s、0.5 rad/s。機体の保証値ではないため実機に合わせて決める |
| `logDirectory` | ログの保存先。標準は `logs/` |

Windowsではコマンドプロンプトで `ipconfig` を実行し、ローバと同じルータにつながるWi-FiなどのIPv4アドレスを確認します。Motive専用の有線LAN側IPと混同しないでください。ローバ側の `ROS_MASTER_URI` は `http://制御用PCのIP:11311` にします。

一時的な変更はファイルを編集せずにも指定できます。

```matlab
config = station_config();
config.ros.nodeHost = "実際の制御用PCのIP";
config.rateHz = 20;
% このconfigを使う場合は、以降のmainにも Config=config を渡します。
```

### 2. 車両一覧を確認する

`vehicles.csv` をExcelまたはテキストエディターで開きます。**1行目は列名、2行目以降は1行につき1台**です。Excelで編集した場合も、列名を変えずCSV形式で保存してください。

初期状態では `pi1`、`pi2`、`pi3` が有効です。`katchaka` は無効で、UDPのIPはPC内試験用の `127.0.0.1` です。実機に使う場合は実際の接続先へ変更します。

| 列名 | 内容 |
| --- | --- |
| `name` | 重複しない車両名。例：`pi1` |
| `enabled` | 通常使うなら `1`、通常使わないなら `0` |
| `odometryProtocol` | 状態の受信方式。`ROS` または `UDP` |
| `commandProtocol` | 指令の送信方式。`ROS` または `UDP`。受信方式と違ってもよい |
| `odometryType` | `position&orientation`（位置・方位）または `speed&angularVelocity`（前進速度・角速度） |
| `coordinateMode` | `global` または `initial`。下記を参照 |
| `x0`, `y0`, `theta0` | 初期位置・方位。単位はm、m、rad |
| `odometryTopic` | ROS受信時の完全なトピック名。例：`/pi1/localization/odom` |
| `odometryMessageType` | ROS受信メッセージ型。位置なら `nav_msgs/Odometry`。速度ならこれか `geometry_msgs/Twist` |
| `commandTopic` | ROS送信時の完全なトピック名。例：`/pi1/rover_drive` |
| `odometryPort` | UDPの状態を受ける制御用PCのポート |
| `commandLocalPort` | UDP指令の送信元となる制御用PCのポート |
| `commandTargetPort` | UDP指令を受ける車両側のポート |
| `vehicleIP` | UDP指令を送る車両のIP |
| `motiveName` / `motiveId` | Motive上の剛体名 / Streaming ID。IDを空欄にすると名前で検索する。Motiveを使わない行では両方を空欄にする |

通信方式に関係しない欄は空欄で構いません。例えばROSだけの車両ではUDPの欄は使いません。空行・重複名・無効な数値・選択車両のローカルUDPポート重複などは、通信を始める前に検出します。`TCP` は未対応です。

**座標の扱い：**

- `global`：受信した位置・方位をそのまま使います。Motiveで複数車両を同じ座標系で測る場合の標準です。実機では `x0,y0,theta0` に合わせ直しません。
- `initial`：較正時の位置・方位を `x0,y0,theta0` に合わせます。位置入力では回転と平行移動をまとめて適用します。速度入力ではこの初期値から積分します。
- シミュレーションの車両は、どちらのモードでも `x0,y0,theta0` の位置から配置されます。

**Motiveを使わない入力例：** 車輪エンコーダの `/pi1/odom` から速度を使うなら、`odometryTopic=/pi1/odom`、`odometryType=speed&angularVelocity`、`odometryMessageType=nav_msgs/Odometry`、`coordinateMode=initial` とし、Motiveの2列を空欄にします。速度の積分には誤差が蓄積します。

搭載OTOSの `/pi1/otos_pose` は `geometry_msgs/Pose2D` です。現状は直接受信できないため、位置入力として使う場合は対応する変換処理が必要です。`/pi1/odom`、`/pi1/otos_pose`、`/pi1/localization/odom` を混同しないでください。

### 3. 車両側と状態配信を起動する

ROSを使う場合、制御用MATLABで次を実行します。

```matlab
config = station_config();
StartStationROS(config.ros);
```

続けて[ローバ側の起動手順](https://github.com/KaitoKonda/harada-tsubakino-rover-agent/blob/main/docs/usage.md)に従って車両を起動します。Motiveを使う場合は後述のブリッジも別MATLABで起動します。UDPだけならROSの起動は不要で、車両側のUDP送受信プログラムを起動します。

ROS状態の受信例です。トピック名と型をCSVの値に合わせます。

```matlab
rostopic list
sub = rossubscriber('/pi1/localization/odom', 'nav_msgs/Odometry');
msg = receive(sub, 5)
```

5秒以内に受信でき、配信が継続していることを確認します。`StartStationROS` は同じ設定の接続を再利用します。IPを変えた場合や、手動の `rosinit` で作った接続が残っている場合は、実験停止後に `rosshutdown` を実行してからやり直します。

### 4. 制御を開始・停止する

まず1台から確認します。

```matlab
result = main("experiment", Vehicles="pi1");
```

`Config=config` を渡すと、前の手順で作った一時設定を使います。省略すると `station_config.m` を読み直します。

1. 指定車両から状態が届くまで待ち、座標を初期化します。
2. **Start / Stop** の小窓を表示します。待機中はゼロ指令を送り続けます。
3. 準備ができたら **Start** を押します。ここから制御時間を数えます。
4. **Stop**、小窓の閉じる操作、またはMATLABの `Ctrl+C` で終了します。待機中に閉じた場合は制御を開始しません。
5. 設定時間に達した場合も終了します。

状態の配信が途絶えた場合や無効な指令が出た場合は、全車両にゼロ指令を試みて実行を終了します。通信が復旧しても自動的には再開しません。終了処理では1台の送信失敗があっても残りの車両の停止を試みます。ただしPCの停止や通信断で指令そのものが届かない場合に備え、車両側の停止手段も用意してください。

実験後は車両側のノードとMotiveブリッジを停止し、最後に各MATLABで `rosshutdown` を実行します。`main` とブリッジの終了だけでは共有ROSマスターを停止しません。

## 制御関数を作る・切り替える

標準の `ControllerStop` は登録台数に関係なくゼロ指令を返します。`ControllerOneLine` も現在は同じ動作で、隊列制御則は未実装です。車両名の固定参照はありません。

自分の制御関数は、次の形で `MyController.m` に保存します。

```matlab
function commands = MyController(vehicles)
    commands = ControllerStop(vehicles);
    names = fieldnames(vehicles);
    for i = 1:numel(names)
        vehicle = vehicles.(names{i});
        % vehicle.position: [x; y] [m]
        % vehicle.orientation: 方位 [rad]
        % vehicle.speed / angularVelocity: [m/s], [rad/s]
        % ここで状態から指令を計算する
        commands.(names{i}) = [0, 0]; % [前進速度, 角速度]
    end
end
```

まずシミュレーションで選択します。

```matlab
result = main("simulation", Controller=@MyController, Duration=10);
```

全車両の指令がそろっていること、2要素の有限実数であること、上限以内であることを確認してから送信します。NaN・欠落・上限超過はエラーとして停止し、勝手に値を切り詰めません。

## Motiveを使う場合だけ

1. [OptiTrack MATLAB Plugin導入](docs/optitrack-matlab.md)と[Motive–ROS最小接続試験](docs/minimum-connection-test.md)を済ませます。
2. `motive_config.m` の `serverIP` にMotive PCのIP、`clientIP` に制御用PCの**施設側有線LANのIP**を入れます。`motiveVersion` は確認したバージョンの記録用です。
3. `station_config.m` のROS設定、CSVの `motiveName / motiveId / odometryTopic` を確認します。通常、Motiveから受ける行は `coordinateMode=global` にします。
4. 別のMATLABを開き、このフォルダーで次を実行します。

```matlab
run_motive_ros_bridge
```

ブリッジはCSVで有効なMotive対象車両の位置を配信します。制御用MATLABで状態を確認し、`main("experiment", Vehicles="pi1")` などを実行します。ブリッジは `Ctrl+C` で停止します。

通常は `motive_config.m` の `rigidBodies=[]` を保ち、対応表をCSVから自動作成します。最小接続試験だけ、構造体を指定して1剛体に絞れます。

MotiveのY-up座標は `x=X, y=-Z, z=Y` としてROSのZ-up座標に変換します。追跡できない剛体は配信しません。剛体の作成は[Rigid Bodyマニュアル](docs/rigid-body-tracking-ja.md)、カメラの較正は[キャリブレーションマニュアル](docs/calibration-ja.md)を参照してください。

## 実行ログを見る

通常は `logs/` に実行ごとのMATファイルが残ります。使った設定と車両一覧、制御関数名、開始・終了時刻、状態、指令、終了理由を保存します。設定が不正で起動前に拒否された場合はログを作りません。

```matlab
saved = load('logs/実際のファイル名.mat');
result = saved.result;
result.status
result.error
result.shutdownErrors
plot(result.time, result.states(:,1,1));
xlabel('Time [s]'); ylabel('First vehicle x [m]');
```

- `states(時点, 項目, 車両)`：項目は `x, y, yaw, speed, angularVelocity`。
- `commands(時点, 項目, 車両)`：項目は前進速度と角速度。
- `fresh(時点, 車両)`：その回で状態を使えたか。
- `sent(時点, 車両)`：その回の送信呼び出しが成功したか。車両の受領確認ではありません。
- `shutdownErrors`：終了時のゼロ指令送信で発生したエラー。

`completed` は時間到達、`stopped` は操作による停止、`cancelled` は開始前の中止、`odometry_lost` は状態途絶、`error` は実行エラー、`interrupted` は中断です。

## 通信の仕様と試験

ROS指令は `geometry_msgs/Twist` の `Linear.X`（m/s）と `Angular.Z`（rad/s）です。UDPはビッグエンディアンの64ビット `double` を使い、1回のデータを1データグラムで送ります。

| UDPの用途 | 数値の並び | サイズ |
| --- | --- | --- |
| 指令 | `[前進速度, 角速度]` | 16バイト |
| 位置入力 | `[x, y, theta]` | 24バイト |
| 速度入力 | `[連番, 前進速度, 角速度]` | 24バイト。受信側は先頭値を位置推定に使わない |

ROS入力は実際の受信時刻で配信停止を検出します。時刻付きメッセージは同じ時刻の繰り返しも新しい測定として扱いません。UDPは不正な長さや非有限値のデータで期限を延長しません。

`dummy_ros_vehicle.m`、`dummy_udp_vehicle.m`、`dummy_udp_vehicle.py` はROS / UDPそのものを調べる単体試験用です。指令に追従し、初期状態と指令途絶時は速度ゼロになります。`main("simulation")` には起動不要です。ローカルで使い、実機と同じトピックへ同時配信しないでください。

自動テストは次で実行できます。UDPはPC内だけを使用します。開始・中止の画面も非表示で検査します。

```matlab
run_station_tests
```

ROS ToolboxのPython設定が済んでいる環境では、追加で次を実行できます。通常の11311番とは別の11539番に試験用マスターを作り、PC内の試験トピックだけでROS送受信とROS入力・UDP出力の組み合わせを検査します。

```matlab
results = runtests("test_StationROS.m");
assert(all([results.Passed]));
```

2026年9月24日、MATLAB R2026aでROS結合テスト3件すべての成功を確認しました。確認した内容は次のとおりです。

- 時刻ヘッダーのないROS速度メッセージの受信、速度・角速度の指令送信、受信途絶の検出。
- ROS位置メッセージの受信とUDP指令送信の組み合わせ。
- 同じROS接続設定の再利用と、異なる設定での再利用の拒否。

この検証は同一PC内で実施しました。別PCとのネットワーク接続、Motiveの実配信、実機の走行・停止は別途確認が必要です。

Pythonの単体ダミーの試験はコマンドプロンプトなどで実行します。

```text
python -m unittest test_dummy_udp_vehicle
```

## 困ったとき・以前の版からの変更

| 症状・以前の操作 | 対応 |
| --- | --- |
| 動かない | 標準はゼロ指令。制御則を実装して `Controller` で選択する |
| 状態が届かず終了する | エラーに出た車両の起動、入力トピック、メッセージ型、UDPポートを確認する |
| ROS設定が不明・不一致と表示される | 実験を停止し `rosshutdown` 後、`StartStationROS` から接続する |
| Motive以外の受信方法へ変えた | CSVのMotive用2列も空欄にする |
| Excelを編集したのに反映されない | 有効な設定は `vehicles.csv`。旧Excelは [docs/legacy](docs/legacy/README.md) に移行前の参考として保存している |
| `launch_dummy_vehicles(IP,...)` を使っていた | 新しい入口は `main("simulation")`。補助関数も現在はこのシミュレーションを起動する |
| `motive_config` のROS設定を変えていた | ROS設定は `station_config.m` の `ros.masterURI / ros.nodeHost` へ移動した |
| 待機窓を閉じて開始していた | 今後はStartを押す。閉じる操作は中止・停止 |
| 無引数の `main` で実機を使っていた | 無引数はシミュレーション。実機は `main("experiment")` と明示する |

設定ファイルへの標準パスはプログラムの配置場所から決まります。別フォルダーから使う場合は、このリポジトリをMATLABのパスへ追加してください。

## 参照資料

- [LightRover Raspberry Pi OS セットアップ](https://vstoneofficial.github.io/lightrover_webdoc/)
- [名古屋大学 飛行性能評価風洞・モーションキャプチャ設備](https://www.mae.nagoya-u.ac.jp/flight/facilities.html)
- [OptiTrack NatNet MATLAB wrapper](https://docs.optitrack.com/v3.2/developer-tools/natnet-sdk/natnet-matlab-wrapper)
