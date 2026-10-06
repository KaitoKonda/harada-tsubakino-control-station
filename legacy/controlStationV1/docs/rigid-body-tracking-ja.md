# Rigid Body（剛体）のトラッキング

この文書は、MotiveでRigid Body（剛体）を作成する詳しい手順と、Rigid Bodyアセットに関連する機能を説明する。[英語原文](rigid-body-tracking-en.md)

Motive上で見つけやすいよう、ボタン、ペイン、プロパティなどの画面項目名は原則として英語表記を残している。Motiveのバージョンによって配置や名称が多少異なる場合がある。

Motiveでは、変形しない物体を追跡するためにRigid Bodyアセットを使用する。追跡対象へ複数のマーカーを確実に固定し、その配置を使って物体を識別して、6自由度（6DoF）の位置・姿勢データを出力する。このため、動作中もマーカー間の距離が変わらないことが重要である。Rigid Bodyの定義と追跡には、パッシブ再帰反射マーカーまたはアクティブLEDマーカーを使用できる。

## Rigid Bodyのマーカー配置

MotiveのRigid Bodyは、変形しない物体に取り付けられた3個以上のマーカーを一つのまとまりとして扱う。より正確には、Motiveは取り付けたマーカー間の位置関係が変化しないと仮定する。マーカー間距離の変化が、該当するRigid BodyのPropertiesで指定された*Deflection*（たわみ）許容値を超えると、マーカーが[未ラベル](https://docs.optitrack.com/motive/data-recording)になることがある。

Rigid Body上の反射面は非反射材で覆い、カメラから見えやすい外側へマーカーを取り付ける。

> **ヒント:** Rigid Bodyの3次元姿勢（pitch、roll、yaw）をより正確に取得したい場合は、同じRigid Body内で可能な限りマーカー同士を離して配置する。マーカー間隔を広げると、小さな姿勢変化でも位置の変化として明確に現れる。

![左：クアッドコプターに取り付けた再帰反射マーカー。右：Motiveで定義した対応するRigid Body。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/2XRSavrpNyQdXZtmIiEn/Quadrocopter%20Live%20and%20MoCap.png)

### マーカーの個数

3次元空間でベクトル関係から平面を定義するには、最低3点の座標が必要である。同様に、MotiveでRigid Bodyを定義するには最低3個のマーカーが必要になる。可能であれば、4個以上のマーカーを使うことが望ましい。マーカーを増やすと位置・姿勢計算に利用できる3次元座標が増え、追跡が安定し、マーカーの遮蔽にも強くなる。一部のマーカーが隠れても、Motiveは見えている他のマーカーから欠けた情報を補い、Rigid Bodyの位置と姿勢を計算できる。

ただし、1個のRigid Bodyへ過剰に多くのマーカーを配置することは推奨されない。狭い範囲に多数のマーカーを置くと、カメラ画像上で重なり、個々の反射を分離できない場合がある。その結果、計測中にラベルが入れ替わる可能性が高くなる。Rigid Bodyの主要部分を十分に覆える数を、確実に固定する。通常は10個未満が目安になる。

> **注意:** Rigid Body 1個あたりの推奨マーカー数は**4～12個**である。過剰な数を使うと上限に達したり、そのアセットへRefineを実行した際にシステム性能上の問題が起きたりする場合がある。

### 非対称なマーカー配置

Rigid Body内のマーカーは非対称に配置する。非対称な配置にすると姿勢の向きを明確に区別できる。正方形、二等辺三角形、正三角形などの対称形は避ける。対称な配置ではアセットの識別が難しくなり、計測中にRigid Bodyの向きが反転することがある。

### Rigid Bodyごとに異なる配置

パッシブマーカーで複数の物体を追跡する場合は、Motive内で各Rigid Bodyを**固有の形状**にすることが望ましい。各物体で再帰反射マーカーを異なる配置にすると、Motiveが計測中に各Rigid Bodyのマーカーを明確に識別できる。互いに合同ではない固有配置が、複数アセットを区別する識別子として働く。

固有配置はRigid Bodyソルバーの処理負荷を下げ、追跡安定性も向上させる。特に大きさや形状が似た複数のアセットを追跡する場合、配置が同一だとラベル付けの誤りが起きやすい。

![](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/44J5GxH7LuHpVJgZaeZm/UniqueRBs.gif)

> **アクティブマーカーを使用する場合:** 複数のRigid Bodyを[OptiTrackアクティブマーカー](https://docs.optitrack.com/active-classic/active-marker-tracking)で追跡する場合、マーカー配置を物体ごとに変える必要はない。アクティブラベリングプロトコルでは各マーカーを個別にラベル付けでき、固有のマーカーラベルによって複数のRigid Bodyを区別できる。

#### Rigid Bodyを固有にする方法

重要なのは、Motive内の複数のRigid Body間で**幾何学的な合同を避ける**ことである。

- **固有のマーカー配置:** マーカーを結んだ形が他のRigid Bodyと合同にならないよう、各Rigid Bodyへ固有の配置を用いる。
- **固有のマーカー間距離:** 形状そのものを変えにくい場合は、マーカー間距離を変える。形が似ていても全体の大きさが異なるため、他のRigid Bodyと区別できる。
- **固有のマーカー数:** マーカーを追加して個数を変えることも有効である。Rigid Bodyを区別しやすくなるだけでなく、合同を避ける配置の選択肢も増える。

#### Rigid Bodyが固有でない場合

同じ配置のRigid Bodyが複数あると、誤ラベルが発生する可能性がある。ただしMotiveは過去の軌跡を参照し、フレーム間で対応するRigid Bodyを関連付けられるため、計測中に継続して追跡されている限り、固有でないRigid Bodyでも比較的良好に追跡できる。

それでも、各アセットを固有にすることを強く推奨する。合同なRigid Bodyは、遮蔽された場合やキャプチャボリューム外へ出た場合に追跡を失う可能性がある。また、同じ形のRigid Body同士が近接して重なると、マーカーラベルが入れ替わることがある。この場合、後処理で[ラベルを修正](https://docs.optitrack.com/motive/labeling)する必要が生じる。

#### 複数のRigid Bodyを追跡する場合

対象物によってはマーカーを置ける場所が限られ、固有配置のバリエーションを作りにくいことがある。次の方法を組み合わせる。

- **異なる2次元配置を作る:** 互いに合同でない特徴的な平面配置を基本形にする。
- **マーカーの高さを変える:** 高さの異なるベースや支柱を使って上下方向の違いを加える。
- **最大マーカー間距離を変える:** 配置全体の大きさを変える。
- **マーカーを2個以上追加する:** さらに違いが必要ならマーカーを追加する。遮蔽に備え、少なくとも2個追加することが推奨される。

## Rigid Bodyを作成する

Rigid Bodyを作成するときは、剛体へ取り付けたマーカーを一つのグループにし、Rigid Bodyとして自動ラベル付けする。一度作成した定義は複数のTakeで利用でき、同じアセットのマーカーを継続的に自動ラベル付けできる。Motiveはマーカー配置固有の位置関係を認識し、各マーカーを自動的にラベル付けしてRigid Bodyを追跡する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/I5MfSJveX05ySdJo9v7t/image.png" alt="" width="563"><figcaption><p>Builderペイン：Rigid Bodyの作成。</p></figcaption></figure>

### Rigid Bodyの作成手順

1. [3D Viewport](https://docs.optitrack.com/motive-ui-panes/viewport#perspective-view)で、Rigid Bodyに含めるマーカーをすべて選択する。
2. [Builderペイン](https://docs.optitrack.com/motive-ui-panes/builder-pane)を開き、選択したマーカーがRigid Bodyとして定義したい実物上のマーカーと一致していることを確認する。
3. *Create*をクリックし、選択したマーカーからRigid Bodyアセットを作成する。

マーカーを選択した状態で、次の方法でも作成できる。

- **Perspective View（3D Viewport）:** 選択範囲を右クリックしてコンテキストメニューを開き、*Markers*セクションの*Create Rigid Body*をクリックする。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/D5Wwo3Ibw3QudtnmN4eN/image.png" alt="" width="265"><figcaption><p>選択した8個のマーカーから、右クリックメニューを使ってRigid Bodyを作成する。</p></figcaption></figure>

- **Assetsペイン:** [Assetsペイン](https://docs.optitrack.com/motive-ui-panes/assets-pane)下部の追加ボタンをクリックする。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/RBuYL9YZyKWgNawhVv2y/image.png" alt="" width="308"><figcaption><p>AssetsペインからRigid Bodyを作成する。</p></figcaption></figure>

- **ホットキー:** マーカーを選択した状態で、Rigid Body作成ホットキーを押す。既定値はCtrl+Tである。

4. Rigid Bodyが作成されると、マーカーに色とラベルが付き、互いに線で結ばれる。新しいRigid BodyはAssetsペインに表示される。

> **補足:** MotiveはRigid Bodyと対応するIMUを検出し、組み合わせることができる。詳しくは[IMU Sensor Fusion](https://docs.optitrack.com/motive/imu-sensor-fusion)を参照する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/jGgzRf9frCxSpoCFomas/Rigid%20Body%20in%20the%20Viewport%20-%20nothing%20selected.png" alt=""><figcaption><p>3D Viewportに表示されたRigid Body。</p></figcaption></figure>

> **Editモードでアセットを定義する場合:** EditモードでRigid Bodyを作成した場合、対応するTakeを[自動ラベル付け](https://docs.optitrack.com/motive/data-recording/data-types)する必要がある。Rigid Bodyアセットを使ってマーカーがラベル付けされ、各フレームの位置と姿勢が計算される。記録済みデータを編集した後に3Dデータをラベル付けしていないと、アセットが追跡されない場合がある。

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/KMfnYqqAP4lcAznY7zZ6/Builder%20Pane%20-%20Create%20RB%20selected.png" alt="Rigid Bodyの作成" width="563">

### Rigid BodyのProperties

Rigid BodyのPropertiesでは、アセット固有の設定、追跡方法、Motive上での表示方法を定義する。各項目については[Properties: Rigid Body](https://docs.optitrack.com/motive-ui-panes/properties-pane/properties-pane-rigid-body)を参照する。

#### 既定のProperties

起動時または追跡継続時に必要な最小マーカー数、アセットのスケール、名前、色などの既定値は、新しく作成するすべてのアセットに適用される。既定値は[Application Settings](https://docs.optitrack.com/motive-ui-panes/settings/settings-assets)パネルのAssetsセクションで設定する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/hcazc0k3ROtOkQ1d6YFj/image.png" alt="" width="563"><figcaption><p>AssetとRigid Bodyの既定設定。</p></figcaption></figure>

#### Propertiesを変更する

既存のRigid BodyアセットのPropertiesは、[Propertiesペイン](https://docs.optitrack.com/motive-ui-panes/properties-pane)から変更できる。

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/sem5z1GjnU2twi8lVoBd/Properties%20-%20Rigid%20Body%20standard.png" alt="Propertiesペインに表示されたRigid BodyのProperties" width="563">

### マーカーを追加または削除する

Rigid Bodyのマーカーを追加・削除する方法は複数ある。

1. [Assetsペイン](https://docs.optitrack.com/motive-ui-panes/assets-pane)で、変更するRigid Bodyを選択する。
2. [3D Viewport](https://docs.optitrack.com/motive-ui-panes/viewport)で、追加または削除するマーカーを選択する。
3. 次のいずれかを実行する。
   - [Constraintsペイン](https://docs.optitrack.com/motive-ui-panes/constraints-pane)下部の追加または削除ボタンをクリックする。
   - [Builderペイン](https://docs.optitrack.com/motive-ui-panes/builder-pane)の*Modify*タブを選び、*Marker Constraints*セクションの追加または削除ボタンをクリックする。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/QPiaag9RIYd81LFxSbEc/Builder%20Pane%20-%20Modify%20RB%20Marker%20Restraints%20highlighted.png" alt="" width="247"><figcaption><p>Builderペインでマーカー制約を追加または削除する。</p></figcaption></figure>

## Rigid Bodyを追跡する

Rigid Bodyのピボット点（Bone）は、その位置と姿勢の基準になる。新しく作成したRigid Bodyでは、Boneの既定位置はマーカー配置の幾何中心で、姿勢軸はグローバル座標軸に一致する。3D Viewportでピボット点を表示するには、Rigid Bodyを選択し、[Propertiesペイン](https://docs.optitrack.com/motive-ui-panes/properties-pane/properties-pane-rigid-body)のVisualsセクションで*Bone*を有効にする。

<img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/eWzfBNrSlmbBzE7XsLTY/Info%20Pane%20-%20Rigid%20Body.png" alt="Infoペインに表示されたRigid Bodyのリアルタイム情報。位置はグローバル原点基準、姿勢はRigid Body作成時の初期姿勢基準。" width="375">

### リアルタイム情報

追跡中のRigid Bodyの位置と姿勢は[Infoペイン](https://docs.optitrack.com/motive-ui-panes/info-pane)でリアルタイムに確認できる。MotiveでRigid Bodyを選択し、ツールバーからInfoペインを開く。右上のメニューボタンをクリックして*Rigid Bodies*を選ぶと、選択したRigid Bodyのリアルタイム追跡データが表示される。

## Rigid Bodyのピボット点を調整する

ピボット点は、特定のマーカー位置へ割り当てるか、Rigid Bodyのx、y、z軸に沿って移動できる。高い精度でピボット位置を決めたい場合は、目的位置へマーカーを取り付け、そのマーカーへピボット点を設定してから、移動量を入力して微調整する。

### 後処理用Editモード

**Editモード**は、記録済みTakeの再生と後処理に使用する。Cameras Viewには記録された2Dデータが表示され、3D Viewportには次のモードに応じて記録済みまたはリアルタイム処理されたデータが表示される。

- **Edit:** 通常のEditモードでは、Takeに保存された処理済み3Dデータを再生・配信する。設定やアセットの変更は、Takeを[再処理](https://docs.optitrack.com/motive/reconstruction-and-2d-mode#applying-changes-to-3d-data)するまでViewportへ反映されない。
- **Edit 2D:** 3Dデータを再構築しながら再生し、設定やアセットの変更をリアルタイムに表示する。ただし、Takeを再処理して保存するまでは、変更は記録データへ保存されない。Editボタンをクリックし、*Edit 2D*を選択する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/xynX3M5XEiEPQqA9gWoX/Live%20or%20Edit%20mode%20-%20switch%20to%202D.png" alt="" width="200"><figcaption><p>EditボタンからEditモードを選択する。</p></figcaption></figure>

> **重要:** どちらのEditモードを使用した場合も、変更内容を基に新しい3Dデータを作成するにはTakeの再処理が必要である。

### 既定の姿勢

Rigid Bodyを作成した直後、その姿勢軸はグローバル軸に揃えられる。作成後は、[Builderペイン](https://docs.optitrack.com/motive-ui-panes/builder-pane)でRigid Bodyの姿勢を編集するか、Gizmoツールを使って調整できる。

BuilderペインにはRigid Bodyの位置合わせ用ツールが用意されている。Builderペインを開いて*Modify*タブをクリックし、3D ViewportでRigid Bodyを選択するとツールが表示される。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Xn2sR6TjsDWWAHpazyaO/Builder%20Pane%20-%20Modify%20RB%20unexpanded.png" alt="" width="305"><figcaption><p>BuilderペインのModifyタブとRigid Body変更項目。</p></figcaption></figure>

### Location：ピボット点を移動する

*Location*ツールにx、y、z方向の移動量をmm単位で入力し、*Apply*をクリックする。もう一度*Apply*をクリックすると、現在の位置へ同じ移動量が加算されるため、Bone位置の微調整に使用できる。

*Clear*は入力欄を0 mmへ戻す。*Reset*はマーカー位置から求めたRigid Bodyの幾何中心へピボット点を戻す。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/cqOBmCYDb3PwAawAII11/Builder%20Pane%20-%20Modify%20RB%20-%20Location%20settings.png" alt=""><figcaption><p>BuilderペインのModifyタブにあるRigid Body移動ツール。</p></figcaption></figure>

### Orientation：ピボット軸を回転する

選択したRigid Bodyのローカル座標系へ回転を適用する。姿勢をリセットし、Rigid Bodyの座標軸をグローバル軸へ揃え直すこともできる。姿勢をリセットするときは、対象のRigid Bodyがシーン内で追跡されている必要がある。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/IDJEdvJLB40wNFPh6sN2/Builder%20Pane%20-%20Modify%20RB%20Orientation%20expanded.png" alt=""><figcaption><p>BuilderペインのModifyタブにあるRigid Body回転ツール。</p></figcaption></figure>

### コンテキストメニューからピボット点をリセットする

BuilderペインのResetボタンに加え、選択したRigid Bodyを右クリックしてAsset(s)コンテキストメニューを開き、*Bones (#) → Reset Location*を選択して位置をリセットできる。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/T6mCAbdrVdLVuiKiDUVA/Rigid%20Body%20Context%20-%20Reset%20Bone%20Location.png" alt="" width="423"><figcaption><p>Rigid BodyのAsset(s)コンテキストメニュー：Bones → Reset Location。</p></figcaption></figure>

### Geometryへ位置合わせする

*Align to Geometry*は、Rigid BodyのピボットをGeometryのオフセットへ揃える機能である。Motiveに含まれる標準形状だけでなく、外部アプリケーションで作成した独自モデルも使用できる。MotiveとUnreal Engine、Unityなどの外部レンダリングソフトウェアとの整合を取りやすくなる。

AssetsペインでRigid Bodyを選択する。Propertiesペインのメニューから、まだ有効でなければ*Show Advanced*を選ぶ。アセットのPropertiesにある*Visuals*セクションまでスクロールし、*Geometry*でオブジェクト形式を選択する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/N18dMP96AYChhHZyvAGq/Rigid%20Body%20Align%20to%20Geometry.png" alt="" width="249"><figcaption><p>Rigid BodyのAdvanced PropertiesにあるGeometry設定。</p></figcaption></figure>

独自モデルを読み込むには、*Custom Model*を選択する。表示される*Attached Geometry*欄でフォルダーアイコンをクリックし、`.obj`、`.fbx`、または`.stl`ファイルを選ぶ。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Lmdpv3AAGlyxJYSko06c/Asset%20Properties%20-%20Attach%20custom%20geometry.png" alt="" width="287"><figcaption><p>独自Geometryモデルの選択。</p></figcaption></figure>

### Cameraへ位置合わせする

アセットを特定のカメラへ揃えるには、3D Viewportでアセットとカメラを両方選択する。Modifyタブの*Align to...*欄で*Camera*をクリックする。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/FStEWWqAoHJgXBVEBwAv/Builder%20Pane%20-%20Modify%20RB%20Align%20to%20Object.png" alt="" width="302"><figcaption></figcaption></figure>

### 別のRigid Bodyへ位置合わせする

既存のRigid Bodyへアセットを揃える場合は、2D Editモードにする。画面左下のEditボタンをクリックし、メニューから*EDIT 2D*を選択する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/GRDWUeFeDMgOUYI2rtQj/Live%20or%20Edit%20mode%20-%20switch%20to%202D.png" alt="" width="200"><figcaption><p>3Dから2D Editモードへ切り替える。</p></figcaption></figure>

### 球面に合わせてBoneを配置する

ボールなどの球形物体を追跡するときに使用する。Motiveは、選択したRigid Bodyのすべてのマーカーが球の表面に配置されていると仮定し、ピボット点を計算して球の中心へ移動する。MotiveでRigid Bodyを選択し、BuilderペインでRigid Body定義を編集して*Apply*をクリックする。

### Refine

Rigid Body refinementツールは、MotiveにおけるRigid Body計算の精度を向上させる。Rigid Bodyを最初に作成した時点では、Motiveは1フレームだけを参照して定義を作る。Refineを実行すると複数のサンプルを収集し、期待されるマーカー位置、Rigid Body自体の位置と姿勢をより正確に計算できる。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/A7TiKvSAqaTeYSDg0jaR/Builder%20Pane%20-%20Refine%20RB.png" alt=""><figcaption><p>BuilderペインのModifyタブからRigid BodyをRefineする。</p></figcaption></figure>

#### Refineの手順

1. [Viewメニュー](https://docs.optitrack.com/motive-ui-panes/toolbar-command-bar#view)から[Builderペイン](https://docs.optitrack.com/motive-ui-panes/builder-pane)を開くか、ツールバーのBuilderペインボタンをクリックする。
2. *Modify*タブをクリックする。
3. AssetsペインでRefineするRigid Bodyを選択する。
4. [Liveモード](https://docs.optitrack.com/motive-ui-panes/control-deck#live-and-edit-mode)でRefineする場合は、できるだけ多くのカメラがマーカーを明瞭に撮影できるよう、Rigid Bodyをキャプチャボリューム中央で保持する。
   1. BuilderペインのModifyタブにある**Refine**セクションで*Start...*をクリックする。
   2. さまざまな姿勢のサンプルを取得するため、進捗バーが満杯になるまでRigid Bodyをゆっくり回転させる。
5. EditモードでもRefineできる。この場合、Motiveは現在のTakeを自動再生してRefine処理を完了する。

<div><figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/xxhlntQFkUnWPhTEbTMK/Refine%20RB%20-%20in%20progress.png" alt=""><figcaption><p>Rigid BodyのRefine実行中。</p></figcaption></figure> <figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/EBC77VzAuI2OJ4qTSCrV/Refine%20RB%20-%20results.png" alt=""><figcaption><p>Rigid BodyのRefine結果。</p></figcaption></figure></div>

### Gizmoツール

3D ViewportのPerspective Viewにあるマウスオプション内の[Gizmoツール](https://docs.optitrack.com/motive/assets/gizmo-tool-translate-rotate-and-scale)でも、Rigid Bodyのピボット位置と姿勢を簡単に変更できる。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/9VM9JB4YC3t7Dd4z7fo5/image.png" alt=""><figcaption><p>Perspective ViewportのGizmoツールメニュー。</p></figcaption></figure>

- **Select Tool（Q）:** 既定の選択ツール。Viewport内の物体を選択する。Gizmo操作が終わったらこのモードへ戻す。
- **Translate Tool（W）:** Rigid Bodyのピボット点を移動する。
- **Rotate Tool（E）:** Rigid Bodyの座標軸の向きを変更する。
- **Scale Tool（R）:** Rigid Bodyのピボット表示を拡大・縮小する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/Ln2FTwPQvn0zVrXvHy55/image.png" alt=""><figcaption><p>3D ViewportのGizmo Translate Tool。</p></figcaption></figure>

## Rigid Bodyトラッキングデータの出力

Rigid Bodyのトラッキングデータは、ファイルへ出力するか、クライアントアプリケーションへリアルタイム配信できる。

- 記録した6DoF Rigid BodyデータはCSVまたはFBXファイルへ出力できる。詳しくは[Data Export](https://docs.optitrack.com/motive/data-export)を参照する。
- ストリーミングプラグインまたはNatNetクライアントを使い、リアルタイムでトラッキングデータを受信できる。詳しくは[NatNet SDK](https://docs.optitrack.com/developer-tools/natnet-sdk/natnet-4.5)を参照する。

## その他の機能

### 無効なアセットのマーカーを隠す

ラベル付けと編集が完了したアセットを無効化し、関連マーカーを非表示にすると、未編集のアセットへ集中しやすくなる。

アセットを無効にするには、Assetsペインでアセット名左側のチェックを外す。マーカーを隠すには、3D ViewportのVisual Optionsボタンをクリックし、*Markers → Hide for Disabled Assets*を選択する。

<figure><img src="https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/B8ah8TmXNVsplgxemwyx/Visual%20Options%20-%20Rigid%20Body%20menu.png" alt=""><figcaption><p>3D ViewportのVisualsメニューにあるマーカー表示設定。</p></figcaption></figure>

### アセット定義を書き出す

アセット定義は、後で再インポートできるようMotiveユーザープロファイル（`.MOTIVE`）へ書き出せる。[ユーザープロファイル](https://docs.optitrack.com/motive/pages/KhJrv0dZJx3yYwdrmwCW#motive-user-profile-.motive)は、アセット定義を含むMotiveの各種設定を保存するテキスト形式のファイルである。

アセット定義をユーザープロファイルへ書き出すと、Motiveはそのアセットに対して校正されたマーカーの配置を保存する。別のTakeへインポートしたとき、Rigid Bodyを最初から作り直さずに利用できる。

プロファイルには各マーカーの空間的な位置関係が保存される。インポート後に認識・定義されるのは、保存時と同一のマーカー配置だけである。

Liveまたは現在のTakeに含まれるすべてのアセットを書き出すには、*File → Export Assets*を選択する。アセット以外のソフトウェア設定も含めて書き出すには、*File → Export Profile*を選択する。

![アセットをユーザープロファイルへ書き出す。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/tNiMFEJRqv4BUI7tGCxK/image.png) ![アセットを含むユーザープロファイルを書き出す。Export Profile As画面。](https://content.gitbook.com/content/WkNF2QVM5V7MzRdzoXmL/blobs/LhoMbHPC2gJQJcEhb9OA/image%20\(453\).png)
