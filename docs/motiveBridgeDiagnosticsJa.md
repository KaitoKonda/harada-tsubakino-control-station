# Motive ブリッジの診断ログ

runMotiveRosBridge は、コマンドウィンドウと station.logDirectory 内の motiveBridge_日時_識別子.log に診断を出力します。ファイル名は起動時の [LOG] 行で確認できます。実機で確認する手順は [最小接続試験](minimumConnectionTest.md)を参照してください。

## 起動時

- [START]：NatNet の client/server IP・通信方式、ROS master URI・nodeHost。
- [REQUEST]：設定上の剛体名・ID・配信先。configuredID=NaN は名前で解決する指定です。
- [OK] NatNet connected、[MODEL]：取得したモデル内の剛体名と ID。
- [MAP]：モデルから解決した車両・剛体・ID・トピック・子フレームの対応。
- [READY]：接続と publisher 作成まで完了。最初の送信完了は別途 first publish completed と表示します。
- [ERROR]：失敗した段階、例外識別子、メッセージ、スタック。起動準備中のエラーも保存します。

## 区間集計

次は表示例です。各行の先頭には日時が付きます。

~~~text
[INTERVAL 1.020s] polls=61 newFrames=50 duplicates=10 empty=1 invalidBodies=0 lastFrame=12345 secondsSinceLastNewFrame=0.008
  pi3(ID=3): published=50 untracked=0 missing=0 invalid=0 suppressed=0 secondsSinceLastPublish=0.008 state=published
~~~

1 秒間隔は目標です。実際の集計時間は INTERVAL に示し、件数はその時間内の合計です。1 回だけの update 結果や、起動以来の累計ではありません。

| 項目 | 意味 |
| --- | --- |
| polls | getFrame を呼んだ回数 |
| newFrames | 直前と異なるフレーム番号を取得した回数。番号の巻き戻りも含む |
| duplicates | 同じ番号を再取得した回数。照合や車両別未配信数には加算しない |
| empty | getFrame が空を返した回数 |
| invalidBodies | 新規フレーム中で読み取り・値の検査に失敗した剛体の延べ数。対象外剛体も含む |
| lastFrame | 最後に取得した新規フレームの番号 |
| secondsSinceLastNewFrame | 最後の新規フレーム処理後からの経過秒数。未取得は never |
| published | 車両別の send() 完了数。購読側への到達を保証する値ではない |
| untracked | 対象 ID が存在するが Tracked=false だった新規フレーム数 |
| missing | 対象 ID を確認できなかった新規フレーム数 |
| invalid | ID を特定できた対象剛体が不正だった新規フレーム数 |
| suppressed | publisher が重複として配信を見送った回数。通常は上流で除外されるため 0 |
| secondsSinceLastPublish | 最後の送信完了を観測してからの経過秒数。未配信は never |
| state | 最後の新規フレームでの車両の処理結果。フレーム停止中も保持する |

経過時間は MATLAB の単調時計で計測し、newFrame と publish の時点は update 完了後に記録します。Motive の計測時刻からの通信遅延ではありません。state=published が残っていても、secondsSinceLastPublish が増えていれば新しい配信はありません。

ID 自体を読み取れない不正剛体は車両へ対応付けられません。その場合は invalidBodies と警告の配列位置・理由を確認します。対象車両側は missing になる場合があります。

## 状態変化と停止

追跡喪失、対象 ID 欠落、不正データを初めて検出した時と、状態・理由が変わった時に WARN を出します。同じ状態の各フレームで警告を繰り返しません。配信再開は publishing recovered と表示します。

新規フレームが閾値以上届かないと NatNet frame is not advancing と表示します。初回受信前は secondsSinceLastNewFrame=never と secondsSinceReady を併記し、復旧時に frame updates recovered と表示します。これは表示用の閾値であり、配信や制御の鮮度判定は変更しません。

Ctrl+C または例外による終了時には、残った区間の集計と [END]、車両ごとの [TOTAL] 配信数を保存してファイルを閉じます。MATLAB の強制終了・プロセスクラッシュでは終了処理を保証できません。ファイルを開けない／書けない場合は警告し、コンソール表示とブリッジ動作を継続します。

## 設定

+shared/stationConfig.m の motive 以下で設定します。既存の設定構造体で項目を省略した場合も次の既定値になります。

~~~matlab
config.motive.logIntervalSeconds = 1;
config.motive.staleWarningSeconds = 0.5;
config.motive.logPoseDetails = false;
config.motive.saveDiagnosticLog = true;
~~~

logPoseDetails=true では、各区間に車両別の最後の新規フレームの位置・姿勢を表示します。motive[m] は変換前、ros[m] は変換後で、クォータニオンはどちらも [qx qy qz qw] の無次元値です。frame と state を併記するため、古い値や未変換の値を識別できます。未取得・未変換の値は [] です。全フレームの生データは保存しません。

## 模擬フレームの回帰テスト

~~~matlab
results = runtests('tests/testBridgeDiagnostics.m');
assertSuccess(results);
~~~

NatNet 接続や ROS 通信なしで、重複を含む区間集計、追跡喪失・復旧、対象欠落、不正値、空フレーム、複数車両、例外とファイル保存を確認します。実機の配信と購読側への到達確認は、別途最小接続試験で行います。
