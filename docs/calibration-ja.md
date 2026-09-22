# キャリブレーション

この文書は、Motiveでカメラシステムをキャリブレーションする手順と、Calibrationペインの機能を説明する。[英語原文](calibration-en.md)

Motive上で照合しやすいよう、ボタン、ペイン、設定項目の名称は原則として英語表記を残している。バージョンによって配置や名称が多少異なる場合がある。

## 概要

[Quick Start Guide - Calibration（動画）](https://youtu.be/HyrHhaRVOaM?si=VFYfwq7IKoBEWWDq&t=136)

高品質な光学式モーションキャプチャにはキャリブレーションが不可欠である。キャリブレーション中、複数の同期カメラが観測した既知のマーカーの2次元像を三角測量で対応付け、各カメラの位置・姿勢と画像の歪みを計算して、Motive内に3次元キャプチャボリュームを構築する。

カメラの配置や設定を変更した場合は再キャリブレーションが必要である。温度変化などの環境要因でも精度は徐々に低下するため、定期的な再キャリブレーションを推奨する。

### キャリブレーション全体の流れ

1. キャプチャボリュームとカメラ配置を準備・最適化する。
2. カメラに映る不要な反射へMaskを適用する。
3. Wandを振り、キャリブレーション用サンプルを集める。
4. Wanding結果を確認し、キャリブレーションを適用する。
5. Ground Planeと原点を設定する。

Motiveは通常、必要なペインをまとめたCalibrationレイアウトを表示する。右上のCalibrationレイアウトボタンまたはCtrl+1でも開ける。

### キャリブレーションの種類

- **Full:** 以前のカメラ位置やレンズ歪み情報を破棄し、対象カメラを最初から計算する。最も時間がかかる。
- **Refine:** 前回の結果を基に小さなずれだけを補正するため、Fullより速い。前回のキャリブレーション後にカメラが大きく動いていない場合だけ使用する。取付部の熱膨張などによる小さな位置・姿勢変化を補正できる。

> **注意:** 選択したカメラでFull Calibrationを一度も完了していない場合、Refineは実行できない。

## 新しいキャリブレーションを開始する

[Calibrationペイン](https://docs.optitrack.com/motive-ui-panes/calibration-pane)が手順を案内する。ツールバーのCalibrationアイコンまたは右上のCalibrationレイアウトから開き、新規の場合は*New Calibration*をクリックする。

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/zBhvVxHbaWq1fcixBkYt/Calibration%20Pane%20-%20New%20Calibration.png" alt="新しいキャリブレーションを開始する" width="204">

### 準備とセットアップの最適化

- キャプチャボリューム全体を覆うようカメラを適切に配置・設定する。
- 計測中に動かないよう、各カメラを確実に固定する。
- キャリブレーション時のCamera、Gain、Filter Switcherなど、データ取得へ影響する設定は計測中も維持する。大きく変更した場合は再キャリブレーションする。
- 3D Viewportの既定グリッドは6平方メートルである。必要なら*Settings → Views / 3D*でGrid WidthとGrid Lengthをキャプチャボリュームに合わせる。
- 詳細設定は*Settings → General*の[Calibration settings](https://docs.optitrack.com/motive-ui-panes/settings/settings-general#calibration-settings-advanced)にある。

## Masking

キャリブレーション前に、不要な反射物や不要なマーカーを撤去または覆い、カメラに映らないようにする。撤去できない反射はMotiveの*Mask*で無視させる。

反射を検出したカメラには警告が表示され、PrimeシリーズではLEDリングも白く点灯する。Calibrationペインの*Mask*をクリックすると、2D Camera Viewで検出した反射部分へ赤いMaskが設定され、その領域の画素はデータから完全に除外される。Maskは追加方式なので、作り直す場合は既存のMaskを先に消す。

> **Active Wanding:** パッシブマーカーのWandを使う場合にMaskが必要である。Active Wandは全カメラのLEDを消灯してキャリブレーションするため、撤去できない反射物が多い環境に適している。

![不要な反射へMaskを適用する。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/CtCnA4rasH5P8drpTbeF/image.png)

### Maskを適用する手順

1. Calibrationペインで、反射やノイズを検出したカメラの警告を確認する。
2. 該当するCamera Viewを見て原因を特定し、可能なら反射物を撤去または覆う。
3. 残った反射に対してCalibrationペインの*Mask*をクリックする。他のカメラ自体の反射など、撤去できないものが対象になる。

![Camera 1/3の反射へMaskを適用する。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/gLhps0WOEqcX9isYYdKH/473px-Calibration_Masking2_30.gif)

Cameras Viewportから手動で追加・消去することもできる。歯車アイコンから[Masking options](https://docs.optitrack.com/motive-ui-panes/viewport#camera-masking-settings)を開き、マウス操作モードを切り替える。

![Camera ViewportのMaskingメニュー。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/0meqllstcO9y3AK53c7q/Viewport%20-%20mask%20cameras%20button%20and%20menu.png)

> **重要:** Mask領域の画素は[2Dデータ](https://docs.optitrack.com/motive/data-recording/data-types)から完全に除外され、3D計算にも使用されない。過剰なMaskはデータ欠損や頻繁なマーカー遮蔽を引き起こす。

## Wanding

Wandingはキャリブレーションサンプルを収集する中心的な工程である。既知の配置を持つCalibration Wandをボリューム全体で繰り返し振り、各カメラが観測したサンプルから3次元空間内の位置と姿勢を計算する。

### Wandサンプルの条件

- 少なくとも2台のカメラが、Wand上の3個すべてのマーカーを同時に見る必要がある。
- カメラにはCalibration Markerだけが映ることが望ましい。別の反射やノイズがあるとサンプルが採用されず、結果も悪化する。作業者は反射する服や装飾品を着用しない。
- Wandのマーカー表面を良好な状態に保つ。傷や擦れがあるとサンプルを収集しにくい。

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/vzP81qSqq0bioxkYkGj5/Calibration%20Pane%20-%20Start%20Wanding.png" alt="Wanding開始時のCalibrationペイン" width="203">

### Wandの種類

用途に応じた複数のWandがある。いずれもMotiveが非対称なマーカー配置をWandとして認識し、開始時に選択したWand寸法を計算へ使用する。指定がない限り、所定の間隔で一直線に並べた再帰反射マーカーを使う。マーカーを動かしたり変形させたりしない。

- **CW-500:** Configuration Aで幅500 mm。マーカー間隔が広く、遠距離でも分離しやすいため大規模ボリューム向け。
- **CW-500 Active:** CW-500と同寸法。カメラLEDを消した状態で使えるため、撤去できない反射物が多い環境向け。
- **CW-250:** 幅250 mm。狭いボリュームでも3マーカーを同一フレームに収めやすく、小～中規模向け。CW-500をConfiguration Bにして代用することもできる。
- **CWM-125 / CWM-250:** 校正されたWand幅の精度と信頼性が高く、小規模かつ高精度な用途向け。

### Wandingの手順

開始位置までWandマーカーの1個を覆って運び、その場で露出させるとよい。2台以上のカメラが3マーカーすべてを検出し、他の反射がなければMotiveがWandを認識して収集を始める。

1. Maskingが完了し、不要な反射が残っていないことを確認する。
2. Full Calibrationでは、前工程で選択したカメラをすべて選択解除する。
3. 新しいボリュームならCalibration Typeを*Full*にする。
4. 使用するWand Typeを正しく選択する。誤るとスケールが不正になる。
5. 設定を再確認して*Start Wanding*をクリックする。
6. Wandをボリュームへ入れ、空間全体を覆うようゆっくり動かす。向きを変えながら8の字を繰り返し描き、高さや位置の異なるサンプルを集める。
7. Cameras Viewportの各2D Viewに色付きの軌跡が表示される。大きな空白がある領域を重点的に振る。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Gc8w8N0fPHnntBw1XMgO/image.png" alt=""><figcaption><p>2D Camera Viewportに表示されたWandingサンプル。</p></figcaption></figure>

8. Calibrationペインの表で各カメラの進捗を確認し、低い位置から高い位置まで均等に覆う。
9. 各カメラの四角が濃い緑（不足）から明るい緑（十分）になるまで続ける。すべて明るい緑になると*Start Calculating*が有効になる。
10. *Start Calculating*をクリックする。通常は1カメラあたり1,000～4,000サンプルで十分であり、過剰なサンプルは精度を悪化させることがある。

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/VY151BDFDTGFCSz63nro/CalibrationPane_Wanding.png" alt="十分なサンプルを得たカメラは明るい緑になる" width="563">

**Wandingのコツ**

- 速く振りすぎない。悪いサンプルの原因になる。
- 反射する服や装飾品を避ける。
- 10,000サンプルを超えないようにする。
- 各カメラの画面内で異なる領域を覆う。PrimeカメラではLEDリングで範囲を確認できる。
- ボリューム全体を覆いつつ、特に追跡精度が必要な領域では多めにサンプルを集める。

> **Marker Labeling Mode:** Wanding中は*Application Settings → Live-Reconstruction → Marker Labeling Mode*を既定の*Passive Markers Only*にする。一部のActive Markerモードには既知の問題があり、パッシブWandとIR LED Wandの両方に影響する。

### PrimeXシリーズのLED Indicator Ring

<div><figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/V8fhGY6Kg2rx19YQV6KV/image.png" alt=""></figure> <figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/tsZE08s5hkixilmnbASG/Calibrating%20PrimeX.png" alt=""></figure> <figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/mWI3NycQKDNISbcKVfuS/Calibrated%20PrimeX.png" alt=""></figure></div>

- Wanding開始時、LEDリングは暗くなる。
- 3個のWandマーカーを検出すると一部が青く光り、サンプル収集中であることとCamera View内のWand位置を示す。
- 十分なサンプルが集まるにつれてリング全体が緑になる。
- 他のカメラが最低閾値へ達しても不足しているカメラは白く光る。2D Viewで不足領域を確認する。
- 全カメラが明るい緑になると*Start Calculating*が有効になる。

## キャリブレーション結果

*Start Calculating*を押す。計算時間はカメラ数とサンプル数に依存する。計算中は青いWanding軌跡が表示され、Calibrationペインへカメラごとの結果が表示される。*Show List*で各カメラの誤差を確認できる。

TakeをDataペインで選ぶと、対応する結果をPropertiesペインで確認できる。この情報はMotive 1.10以降で記録したTakeに限られる。

### 結果レポート

- 計算完了後、Calibrationペインに結果が表示される。
- 平均誤差によりPoor、Fair、Good、Great、Excellent、Exceptionalの順で評価される。
- 許容できる場合は*Continue*で適用し、できない場合は*Cancel*してWandingをやり直す。
- 一般にExcellent未満なら、Camera設定やWanding方法を見直して再実行することを推奨する。

![キャリブレーション結果。Wanding軌跡とレンズ歪みも表示される。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/IgiNb88LFyoB9mpJLqP3/image.png)

#### Mean Ray Error

各カメラからの追跡Rayが一つの3D点へどの程度近く収束したかを示す平均誤差で、Wanding中に計算した3D点の精密さを表す。許容値はボリュームの大きさやカメラ数によって異なる。

#### Mean Wand Error

Wanding全体で、検出されたWand長と想定Wand長との差を示す平均誤差である。

## Ground Planeと原点

最後にCalibration Squareを使い、Motive座標系のGround Planeと原点を設定する。

1. 原点にしたい位置、かつGround Planeを水平にしたい場所へCalibration Squareを置く。
2. 標準OptiTrack Calibration SquareならMotiveが自動認識し、Calibrationペインへ表示する。
3. 希望する軸方向に合わせる。長い脚が+z、短い脚が+x、右手座標系で上方向が+yになる。
4. 水準器で水平を確認し、必要ならマーカー下のノブを回して調整する。
5. 正しく配置・検出されたら*Set Ground Plane*をクリックする。自動検出できない場合はマーカーを手動選択する。
6. Ground Planeは後から調整できる。

![MotiveでGround Planeを設定する。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/srK1zvWiLd0NSTmMZOJu/image.png)

### 独自のCalibration Square

直角を作る3個のマーカーを用い、一方の腕を他方より長くすれば独自Squareを作れる。ドロップダウンで*Custom*を選び、正しいVertical Offsetを入力し、3D Viewportで3マーカーを選択してGround Planeを設定する。

#### Vertical Offset

Vertical Offsetは[Calibration Square](https://docs.optitrack.com/motive/calibration/calibration-squares)のマーカー中心から実際の床面までの距離であり、グローバル原点設定に必要である。標準SquareではMotiveがOffsetを考慮し、マーカー中心ではなくSquare底部の角を原点にする。

<div><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/u6LOEdMry0uxmTGdfYap/Ground%20plane%20offset.png" alt="CS-400のVertical Offset"> <figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/CG5msnEIAmL0gQ0flqUM/Calibration%20marker%20vs%20global%20origin.png" alt=""><figcaption><p>Ground Planeマーカーとグローバル原点のOffset。</p></figcaption></figure></div>

独自Squareでは、頂点にあるマーカー中心からSquare最下端までの距離を測り、Calibrationペインの*Vertical Offset*へ入力する。正の値では平面がマーカーより下、負の値では上に設定される。

![独自Calibration SquareでGround Planeを設定する。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/YwW6skwyc8QAoFGzxti3/image.png)

### Rigid Bodyを使って原点を設定する

マーカー位置そのものを原点にするなど、原点位置を細かく制御したい場合はRigid Bodyのピボットを利用する。

1. Rigid Bodyを作成する。
2. ピボットを原点にしたい位置へ合わせる。特定マーカーへ合わせる場合は、Shiftを押しながらマーカーとピボットを選択し、*Builder → Modify → Align to... Marker*を選ぶ。
3. AssetsペインでRigid Bodyを選択する。
4. CalibrationペインのGround Planeで*Rigid Body*を選ぶ。選択したピボットが原点になる。

## Ground Plane変更オプション

Calibrationペインの*Change Ground Plane...*をクリックし、下部のページ切替で各ツールを開く。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/4iMEsi21Fahumbu3Nn6s/Change%20Ground%20Plane%20-%203%20pages.png" alt=""><figcaption><p>左からRefine Ground Plane、Translate/Rotate、Scale Volume。</p></figcaption></figure>

### Ground Plane Refinement

大きなボリュームなど、床面が完全に均一でない場合の水平精度を改善する。半径が既知の複数マーカーを床へ置き、Vertical Offsetをその半径に設定する。Motiveでマーカーを選び*Refine Ground Plane*を押すと、各マーカー位置から平面を補正する。

### Ground Planeの移動・回転

計測後にグローバル原点の位置や姿勢を調整するには、Capture VolumeのTranslate/Rotateツールを使う。変更を記録済みTakeへ反映するには、記録済み2Dデータから3Dデータを再構築する。

### Volumeのスケール変更

既知の距離だけ離した2個のマーカーを置き、その距離を入力する。3D Viewportで2個を選択し、*Scale Volume*をクリックする。

## キャリブレーションファイル

結果は`.cal`、XML形式の`.mcal`、または`.json`として書き出せる。`.cal`と`.mcal`はMotiveへインポートできる。毎回の起動時にやり直す必要がなく、既定では最後に作成されたファイルが読み込まれる。保存先や読込設定はApplication Settingsで変更できる。一般に各計測セッション前の書き出しを推奨する。

> **重要:** カメラを動かすなどシステム構成を変更すると、以前のファイルは有効でなくなるため再キャリブレーションが必要である。

## キャリブレーションを改善・更新する

### Continuous Calibration

カメラの状態を継続監視し、小さなずれを自動補正する。振動、取付部の熱膨張、カメラの小さな変位などであれば、再度Wandingせずに調整できる。初回キャリブレーション後、Calibrationペインで有効化する。同ペインには最終更新時刻と状態も表示される。

![Calibrationペイン下部のContinuous Calibration情報。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/y1mGG2QdvoVeV58NDDDW/image.png)

### Offline Calibration

一日を通した計測では温度変化で精度が低下する場合がある。大規模システムで毎回Full Calibrationを繰り返す代わりに、WandingとCalibration Squareを置いたGround PlaneのTakeを時刻ごとに記録し、必要になったとき後処理で再キャリブレーションできる。

#### Offline Calibrationの手順

異なる時刻に、通常のWandingと同様のWanding Takeと、対応するGround Plane Takeを記録しておく。通常のキャリブレーション時にもMotiveはWandingとGround Planeの2個のCalibration Take（`.tak`）を自動保存する。

1. 再キャリブレーション対象のTakeを開く。
2. Calibrationペインで*Load Calibration...*をクリックする。
3. 対象Takeと近い時刻に記録したWanding Takeを選ぶ。
4. *New Calibration*をクリックする。
5. Editモードで*Start Wanding*をクリックし、読み込まれた結果を確認する。
6. *Start Calculating*をクリックする。
7. 必要なら*File → Export Camera Calibration*で`.mcal`を書き出す。
8. *Apply Results*をクリックする。
9. Ground Planeが別Takeなら*Done*を押して次へ進む。同じTake内なら手順13へ進む。
10. *Load Calibration...*をクリックする。
11. 対応するGround Plane Takeを選ぶ。
12. *Change Ground Plane*をクリックする。
13. Ground Plane Typeを*Custom*にし、Vertical Offsetを入力して3マーカーを選び、*Change Ground Plane*をクリックする。
14. 3Dデータの再構築と自動ラベル付けが必要という警告で*Continue*を押す。

### Partial Calibration

![選択したカメラだけをPartial Calibrationする。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/x8LCOoT9Xi61nZpDh2PO/image.png)

選択したカメラの位置を、既に良好にキャリブレーションされた他のカメラに対して更新する。カメラ数が多く一部だけ調整したい場合、Ground Planeを維持したい場合、既存ボリュームへ新しいカメラを追加する場合に使う。Continuous Calibrationが無効な状態でカメラへ衝撃が加わった場合にも有効である。

#### Partial Calibrationの手順

1. Cameras Viewportで再キャリブレーションするカメラだけを選択する。
2. Calibrationペインで*New Calibration*を選ぶ。
3. Typeを選ぶ。新規カメラ追加や複数台調整では通常*Full*、わずかなずれなら*Refine*も使用できる。
4. Wand Typeを指定する。
5. *Start Wanding*をクリックし、選択カメラだけを対象にする警告で*Continue*を押す。
6. 選択カメラと、少なくとも1台の未選択カメラの前でWandを振る。これによりシステム全体との位置関係を計算できる。
7. 十分なサンプルが集まったら*Calculate*を押す。
8. 結果がExcellentまたはExceptionalになるまで必要に応じて繰り返す。
9. *Apply*をクリックする。

未選択カメラが良好な状態であることが前提である。未選択側がずれていると結果も悪くなる。Partial Calibrationは未選択カメラ自体を更新しないが、レポートにはサンプルを受けた選択・未選択の全カメラが含まれる。

### Camera Gizmo

*Settings → General → Calibration → Editable in 3D View*を有効にすると、Gizmoでカメラを修正できる。誤操作防止のため、既定では有効になっていない。

1. 修正するカメラを選び、そのカメラ視点へ切り替える（3キー）。
2. TranslateまたはRotate Gizmoを選ぶ（WまたはEキー）。
3. 赤いひし形を使い、未ラベルRayを対応するマーカーへ大まかに合わせる。
4. 右クリックして*Correct Camera Position/Orientation*を選ぶ。
5. Continuous Calibrationを有効にし、正しい位置への最終調整を完了させる。

![Gizmo Rotateでカメラ位置を調整する。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/avTEJWd1pGjQm1tgCecT/image.png) ![](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Q2lUMkZUN03ykXMbL2Y6/image.png)

## Active LED Calibration

OptiTrackは再帰反射マーカー向けに設計されているが、適切なカスタマイズによりActive LED Markerも追跡できる。Active LEDを使う場合は、Active LED Wandによるキャリブレーションが望ましい。詳細はOptiTrackへ問い合わせる。

## Q&A

### トラブルシューティング

<details><summary><strong>Q：実際は1 mなのに2 mと表示されるなど、距離のスケールが正しくありません。</strong></summary>

Wanding時に誤ったWand Typeを選択したか、Scale Volumeで誤ったスケールを設定した可能性がある。
</details>

<details><summary><strong>Q：Wanding中にCalibration Wandが検出されません。</strong></summary>

選択したWand Typeで想定される位置にマーカーがないか、表面に傷や損傷がある可能性がある。損傷している場合は[OptiTrackサポート](http://optitrack.com/support/#contact-support)へ交換を相談する。
</details>

<details><summary><strong>Q：キャリブレーション結果が悪くなります。</strong></summary>

- Wandを速く振りすぎない。高速移動するとマーカー重心の品質が低下する。
- 正しいWand Typeを選ぶ。
- Wanding中だけ現れる反射も除去する。反射する服や装飾品も含め、撤去できないものはMaskする。
- サンプルを過剰に集めない。必要数はシステム構成によって異なる。
</details>

### 一般的な質問

<details><summary><strong>Q：別のCamera Calibrationファイルを使って3Dデータを再構築できますか。</strong></summary>

可能だが、カメラ構成が変わっていない場合に限ることを推奨する。

1. 過去のTakeまたは新しいキャリブレーションから`.cal`ファイルを書き出す。
2. 更新したい古いCalibrationを含むTakeを開く。
3. 手順1の新しいファイルを読み込む。
4. ReconstructとAuto-labelを実行する。新しいCalibrationを反映した3Dデータが得られる。
</details>

<details><summary><strong>Q：どの大きさのCalibration Wandを選べばよいですか。</strong></summary>

一般に、小さいボリュームには小さいWand、大きいボリュームには大きいWandが適している。
</details>
