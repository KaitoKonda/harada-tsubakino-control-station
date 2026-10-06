# MATLABにOptiTrack Motive連携を導入する

参照日: 2026-09-22

MATLABでMotiveのリアルタイムデータを受け取るには、OptiTrack公式の
「MATLAB Plugin」を使用する。このプラグインはMATLABのアドオンマネージャーから
インストールする形式ではなく、配布ファイルを展開してMATLABパスへ追加する。

## 1. MATLAB Pluginを導入する

1. [OptiTrack公式ダウンロードページ](https://optitrack.com/support/downloads?cat=plugin)を開く。
2. `MATLAB Plugin`をダウンロードする。
3. ZIPファイルを任意の場所（例: `C:\OptiTrack\MATLABPlugin`）に展開する。
4. MATLABの［ホーム］→［パスの設定］→［サブフォルダーも含めて追加］から、
   展開したフォルダーを追加して保存する。

コマンドで追加する場合は、展開先に合わせて次を実行する。

```matlab
addpath(genpath('C:\OptiTrack\MATLABPlugin'));
savepath;
```

次のコマンドでプラグインが認識されていることを確認する。

```matlab
which natnet -all
properties('natnet')
```

プラグインには`natnet.m`と、名前が`OptiSample_`で始まるサンプルが含まれる。

## 2. Motiveのストリーミングを設定する

Motiveで設定画面を開き、［Streaming］のNatNet設定を次のようにする。

- `Enable`: オン
- `Local Interface`:
  - MotiveとMATLABが同じPCの場合: `127.0.0.1`
  - 別々のPCの場合: MATLAB側PCと通信できるMotive PCのLANアドレス
- `Transmission Type`: `Unicast`（このリポジトリの`motive_config.m`と一致させる）
- 取得したいデータを有効化:
  - 剛体: `Rigid Bodies`
  - マーカー: `Labeled Markers`または`Unlabeled Markers`
  - スケルトン: `Skeletons`
  - フォースプレートなど: `Devices`

NatNetの標準ポートは、コマンド用がUDP 1510、データ用がUDP 1511である。

## 3. MATLABで接続を確認する

最初は、用途に合う付属サンプルを開いて実行する。

- `OptiSample_RigidBodyPoseData.m`: 剛体の位置・姿勢
- `OptiSample_RigidBodyGraph.m`: 剛体データのグラフ
- `OptiSample_RigidBodyMarkerData.m`: 剛体を構成するマーカー
- `OptiSample_AllTypesPolling.m`: 各種データ

初回実行時にDLLを選択する画面が表示されたら、プラグインに同梱されている
64ビット版の`NatNetML.dll`を選択する。`NatNetLib.dll`も同じフォルダーに置く。
選択後、サンプルをもう一度実行する。

Motiveでライブ計測中、または記録済みTakeを再生中であれば、MATLAB側でデータを
受信できる。

## 接続できない場合

- MotiveのNatNetストリーミングが有効になっているか確認する。
- MATLABとMotiveで、IPアドレスとUnicast設定が一致しているか確認する。
- 別PCの場合は、両方のPCが同じネットワーク内にあることを確認する。
- カメラ専用ネットワークではなく、MATLAB PCと通信できるLAN側インターフェースを
  Motiveで選択する。
- Windowsファイアウォールで、Motive、MATLAB、UDP 1510・1511を許可する。
- MATLABとDLLがともに64ビットであることを確認する。
- DLLのプロパティに［ブロックの解除］が表示される場合は解除する。
- DLLの読み込みに失敗した後はMATLABを再起動する。

同じPCで試す場合は、まずMotiveとMATLABをともに`127.0.0.1`に設定し、
`OptiSample_RigidBodyPoseData.m`を実行する構成が最も簡単である。

## 参考資料

- [OptiTrack MATLAB Plugin](https://docs.optitrack.com/v3.2/plugins/optitrack-matlab-plugin)
- [Motive Streaming設定](https://docs.optitrack.com/motive-ui-panes/settings/settings-streaming)
- [NatNet SDK](https://docs.optitrack.com/developer-tools/natnet-sdk)
