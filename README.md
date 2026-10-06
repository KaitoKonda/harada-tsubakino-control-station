# harada-tsubakino-control-station

このフォルダーには、コメントの疑似コードを残したまま実装した制御ステーションがあります。シミュレーション、同一 PC 内の ROS、UDP は確認済みです。Motive の実配信と実機走行は未確認です。

- [文書一覧](docs/README.md)：利用マニュアル、接続試験、Motive 操作資料と移行前の車両設定表
- [利用マニュアル](docs/userManualJa.md)：設定と操作手順
- [Motive 接続の段階別試験](docs/minimumConnectionTest.md)：NatNet から ROS までの確認
- [OptiTrack MATLAB Plugin の導入](docs/optitrackMatlab.md)：プラグインと Motive 配信設定
- [剛体トラッキング](docs/rigidBodyTrackingJa.md)・[キャリブレーション](docs/calibrationJa.md)：Motive の操作参考資料（英語版も `docs/` に収録）
- [旧版の README](legacy/controlStationV1/README.md)：退避した実行可能な旧版の説明
- `legacy/controlStationV1/`：旧版のプログラム、設定、テスト、関連文書

旧版を確認・実行する場合は、MATLAB の「現在のフォルダー」を `legacy/controlStationV1/` に合わせて、そちらの README を読んでください。新旧のファイルを同じ MATLAB パスに同時に追加しないでください。

## 最初に試す

MATLAB の「現在のフォルダー」をこの README があるフォルダーに合わせ、コマンドウィンドウで実行します。

```matlab
result = runControlStation("simulation", durationSeconds=10);
result.status
```

現在の実験設定ではマウス制御が有効です。別の「Manual drive」画面で車両と方向を選ぶと指令が出ます。操作しなければゼロ指令のままです。Stop を押すと途中終了します。実験設定は `+shared/experimentConfig.m`、車両の通信候補は `+vehicleProfiles/` にあり、`vehicles.csv` は使いません。

最上位の起動口は `runControlStation.m`（制御）と `runMotiveRosBridge.m`（Motive から ROS への配信）です。後者は別の MATLAB セッションで起動します。内部ファイルは `+station/`、`+bridge/`、`+shared/` に分けています。最上位フォルダーを MATLAB の現在のフォルダーまたは検索パスに置いて呼び出します。

自動テストは実機を使わずに次で実行します。ROS の試験は PC 内に試験用 ROS マスターを起動します。

```matlab
results = runtests("tests");
assert(all([results.Passed]));
```
