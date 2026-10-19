# システム
水平面（$x$-$y$ 平面）内を移動する $N$ 台の移動体を考える．
移動体は水平面内に姿勢角を持ち，回転運動および姿勢角方向への並進運動が可能である．
各移動体のキネマティクスは次のとおりである．

$$
\begin{aligned}
	\begin{bmatrix}
		\dot{x}_i\\
		\dot{y}_i\\
		\dot{\theta}_i
	\end{bmatrix}
	&=
	\begin{bmatrix}
		\cos{\theta_i} & 0\\
		\sin{\theta_i} & 0\\
		0 & 1
	\end{bmatrix}
	\begin{bmatrix}
		v_i\\
		\omega_i
	\end{bmatrix}
	&
	& \left( i = 1,2,\dots,N \right)
\end{aligned}
$$

ここで $(x_i, y_i)$ が移動体の位置，$\theta_i$ が移動体の姿勢角であり，
$v_i$ は移動体の並進速さ，$\omega_i$ は移動体の回転角速度である．

以下，移動体のダイナミクスは十分速いとして無視し，並進速さ $v_i$ および回転角速度 $\omega_i$ を直接指令できるものとする．

# 質点モデル
制御則設計のために，移動体の姿勢角を排除した質点モデルを考える．
質点モデルは次のとおりである．

$$
\begin{aligned}
	\begin{bmatrix}
		\dot{x}_i\\
		\dot{y}_i
	\end{bmatrix}
	&=
	\begin{bmatrix}
		u_{x,i}\\
		u_{y,i}
	\end{bmatrix}
	&
	& \left( i = 1,2,\dots,N \right)
\end{aligned}
$$

ここで $u_{x,i}, u_{y,i}$ はそれぞれ移動体の並進速度となる．

以下では，まず質点モデルにおいて階層化最適制御に基づいて実現したい並進速度 $(u_{x,i}, u_{y,i})$ を生成したのちに，その並進速度をバックステッピングに基づいて並進速さ $v_i$ と回転角速度 $\omega_i$ へ変換する．

# 階層化最適制御

階層化最適制御に基づいて理想的な並進速度を生成する．
はじめに制御問題を定める．

参照点 $(x_{\mathrm{ref}}, y_{\mathrm{ref}})$ を定める．
参照点は時間に伴って連続的に変化する．
例えば次のように定められる．

$$
\begin{aligned}
	x_{\mathrm{ref}} &= v_{x,\mathrm{ref}} t\\
	y_{\mathrm{ref}} &= v_{y,\mathrm{ref}} t
\end{aligned}
$$

このとき $(v_{x,\mathrm{ref}}, v_{y,\mathrm{ref}})$ は参照点の並進速度である．
また，各移動体の目標位置を，参照点との相対位置の形で $(l_{x,i}, l_{y,i})$ と定める．
さらに，各移動体の位置と目標位置との偏差を $(\tilde{x}_i, \tilde{y}_i)$ と書く．
すなわち次のとおりである．

$$
\begin{aligned}
	\tilde{x}_i &= x_i - x_{\mathrm{ref}} - l_{x,i}\\
	\tilde{y}_i &= y_i - y_{\mathrm{ref}} - l_{y,i}
\end{aligned}
$$


質点モデルを偏差系として書き換える．
次のとおりである．

$$
\begin{aligned}
	\begin{bmatrix}
		\dot{\tilde{x}}_i\\
		\dot{\tilde{y}}_i
	\end{bmatrix}
	&=
	\begin{bmatrix}
		\tilde{u}_{x,i}\\
		\tilde{u}_{y,i}
	\end{bmatrix}
	&
	& \left( i = 1,2,\dots,N \right)
\end{aligned}
$$

ここで $(\tilde{u}_{x,i}, \tilde{u}_{y,i})$ は参照点に伴って移動する座標系（参照座標系）から見た移動体の並進速度となり，次のように表せる．

$$
\begin{aligned}
	\tilde{u}_{x,i}
	&= u_{x,i} - \dot{x}_{\mathrm{ref}}\\
	\tilde{u}_{y,i}
	&= u_{y,i} - \dot{y}_{\mathrm{ref}}
\end{aligned}
$$


便利のために，総括した変数 $\tilde{X}, \tilde{U}$を次のように定める．

$$
\begin{aligned}
	\tilde{X} &= \left[\ \tilde{x}_{1}\ \tilde{y}_1\ \tilde{x}_2\ \tilde{y}_2\ \cdots\ \tilde{x}_N\ \tilde{y}_N \right]^\top\\
	\tilde{U} &= \left[\ \tilde{u}_{x,1}\ \tilde{u}_{y,1}\ \tilde{u}_{x,2}\ \tilde{u}_{y,2}\ \cdots\ \tilde{u}_{x,N}\ \tilde{u}_{y,N} \right]^\top
\end{aligned}
$$


## パターン 1: 1 階層の階層化最適制御

制御目標を次のように定める．

$$
\begin{aligned}
	&\lim_{t \to \infty} \left( \tilde{x}_1 - \tilde{x}_j \right) &
	& \left( j \ne 1 \right)\\
	&\lim_{t \to \infty} \left( \tilde{y}_1 - \tilde{y}_j \right) &
	& \left( j \ne 1 \right)
\end{aligned}
$$

これに対応して，評価出力 $Z$ を次のように定める．

$$
\begin{aligned}
	Z &= \left( C_{\mathrm{diff}} \otimes I_2 \right) \tilde{X}
	&
	& \left( C_{\mathrm{diff}} =
	\begin{bmatrix}
		1      & -1 &    &        & O\\
		1      &    & -1 &        &  \\
		\vdots &    &    & \ddots &  \\
		1      &  O &    &        & -1
	\end{bmatrix}
	\in \mathbb{R}^{(N-1) \times N}
	\right)
\end{aligned}
$$

また評価関数は次のように定める．

$$
\begin{aligned}
	\int_{0}^{\infty} \left( Z^\top \left( I_{(N-1)} \otimes Q_0 \right) Z + r \tilde{U}^\top \tilde{U} \right)\,dt
\end{aligned}
$$

ここで $Q_0$ は $2 \times 2$ の正定行列，$r$ は正の実数である．
この評価関数は，行列

$$
\begin{aligned}
	Q \coloneq \left( C_{\mathrm{diff}}^\top C_{\mathrm{diff}} \right) \otimes Q_0
\end{aligned}
$$

を定めることで次のように書き換えられる．

$$
\begin{aligned}
	\int_{0}^{\infty} \left( \tilde{X}^\top Q \tilde{X} + r \tilde{U}^\top \tilde{U} \right)\,dt
\end{aligned}
$$


この評価関数を最小化する最適制御入力は，代数 Riccati 方程式

$$
\begin{aligned}
	-\frac{1}{r} P^2 + Q = O
\end{aligned}
$$

の準正定解 $P = \sqrt{r} Q^{1/2}$ を用いて次のように決定される．

$$
\begin{aligned}
	\tilde{U} = -\frac{1}{r} P \tilde{X}
\end{aligned}
$$


## パターン 2: 2 階層の階層化最適制御

移動体数 $N$ が適当な正の整数 $N_1, N_2$ に関して $N = N_1 N_2$ と書けると仮定する．
移動体群を，$N_1$ 台ずつの $N_2$ グループに分ける．

移動体の通し番号 $i = 1,2,\dots,N$ を，グループの番号 $i_2 = 1,2,\dots,N_2$ およびグループ内での通し番号 $i_1 = 1,2,\dots,N_1$ の組と一対一に対応付ける．
例えば次のように定められる．

$$
\begin{aligned}
	i = \left( N_2 - 1 \right) i_2 + i_1
\end{aligned}
$$

また対応付けに基づいて添え字の $i$ と $i_2,i_1$ を互いに読み換える．

グループ間の制御目標を次のように定める．

$$
\begin{aligned}
	&\lim_{t \to \infty} \left( \tilde{x}_{1,1} - \tilde{x}_{j_2,1} \right) = 0 &
	& \left( j_2 \ne 1 \right)
	\\
	&\lim_{t \to \infty} \left( \tilde{y}_{1,1} - \tilde{y}_{j_2,1} \right) = 0 &
	& \left( j_2 \ne 1 \right)
\end{aligned}
$$

また各グループ内の制御目標を次のように定める．

$$
\begin{aligned}
	&\lim_{t \to \infty} \left( \tilde{x}_{i_2,1} - \tilde{x}_{i_2,j_1} \right) = 0 &
	& \left( j_1 \ne 1 \right)
	\\
	&\lim_{t \to \infty} \left( \tilde{y}_{i_2,1} - \tilde{y}_{i_2,j_1} \right) = 0 &
	& \left( j_1 \ne 1 \right)
\end{aligned}
$$

ただし $i_2 = 1,2,\dots,N_2$ は各グループの番号である．
これに対応して，評価出力 $Z_2, Z_1$ を次のように定める．

$$
\begin{aligned}
	Z_2 &= \left( C_{\mathrm{diff},2} \otimes C_{\mathrm{lead},1} \otimes I_2 \right) \tilde{X}
	\\
	Z_1 &= \left( I_{N_2} \otimes C_{\mathrm{diff},1} \otimes I_2 \right) \tilde{X}
	\\
	&\left(
	\begin{aligned}
		C_{\mathrm{diff},2} &=
		\begin{bmatrix}
			1      & -1 &    &        & O\\
			1      &    & -1 &        &  \\
			\vdots &    &    & \ddots &  \\
			1      &  O &    &        & -1
		\end{bmatrix}
		\in \mathbb{R}^{(N_2-1) \times N_2}
		\\
		C_{\mathrm{diff},1} &=
		\begin{bmatrix}
			1      & -1 &    &        & O\\
			1      &    & -1 &        &  \\
			\vdots &    &    & \ddots &  \\
			1      &  O &    &        & -1
		\end{bmatrix}
		\in \mathbb{R}^{(N_1-1) \times N_1}
		\\
		C_{\mathrm{lead},1} &=
		\begin{bmatrix}
			1 & 0 & \cdots & 0
		\end{bmatrix}
		\in \mathbb{R}^{1 \times N_1}
	\end{aligned}
	\right)
\end{aligned}
$$

また評価関数は次のように定める．

$$
\begin{aligned}
	\int_{0}^{\infty} \left(
		Z_2^\top \left( I_{(N_2 - 1)} \otimes I_1 \otimes Q_{0,2} \right) Z_2
		+ Z_1^\top \left( I_{N_2} \otimes I_{(N_1 - 1)} \otimes Q_{0,1} \right) Z_1
		+ r \tilde{U}^\top \tilde{U}
	\right)\,dt
\end{aligned}
$$

ここで $Q_{0,2}, Q_{0,1}$ は $2 \times 2$ の正定行列，$r$ は正の実数である．
この評価関数は，行列

$$
\begin{aligned}
	Q
	\coloneq \left( C_{\mathrm{diff},2}^\top C_{\mathrm{diff},2} \right) \otimes \left( C_{\mathrm{lead},1}^\top C_{\mathrm{lead},1} \right) \otimes Q_{0,2}
	+ I_{N_2} \otimes \left( C_{\mathrm{diff},1}^\top C_{\mathrm{diff},1} \right) \otimes Q_{0,1}
\end{aligned}
$$

を定めることで次のように書き換えられる．

$$
\begin{aligned}
	\int_{0}^{\infty} \left( \tilde{X}^\top Q \tilde{X} + r \tilde{U}^\top \tilde{U} \right)\,dt
\end{aligned}
$$


以降はパターン 1 と同様である．


最適制御入力 $\tilde{U}$ が，参照座標系で見た移動体の理想的な並進速度である．
慣性座標系で見た移動体の理想的な並進速度 $U$ は

$$
\begin{aligned}
	U = \tilde{U} + \mathbf{1}_N \otimes
	\begin{bmatrix}
		\dot{x}_{\mathrm{ref}}\\
		\dot{y}_{\mathrm{ref}}
	\end{bmatrix}
\end{aligned}
$$

である．

便利のために

$$
\begin{aligned}
	U = \left[\ u_{x,1}\ u_{y,1}\ u_{x,2}\ u_{y,2}\ \cdots\ u_{x,N}\ u_{y,N} \right]^\top
\end{aligned}
$$

と書く．

次に，理想的な並進速度を変換し，指令する並進速さと回転角速度を決定する．

# バックステッピング
並進速さには，理想的な並進速度を実現するために必要な並進速さ

$$
\begin{aligned}
	v_i = \sqrt{u_{x,i}^2 + u_{y,i}^2}
\end{aligned}
$$

を指令する．

また理想的な並進速度を実現するために必要な姿勢角 $\theta_i^{\mathrm{d}}$ は

$$
\begin{aligned}
	\theta_i^{\mathrm{d}} = \mathrm{atan2}\,(u_{y,i}, u_{x,i})
\end{aligned}
$$

である．これを実現するために，角速度には次を指令する．

$$
\begin{aligned}
	\omega_i = k_{\theta,i} \sin(\theta_i^{\mathrm{d}} - \theta_i) + \dot{\theta}_i^{\mathrm{d}}
\end{aligned}
$$

ここで $k_{\theta,i}$ は正の比例ゲインである．

なお，制御則中のフィードフォワード項にあたる $\dot{\theta}_i^{\mathrm{d}}$ は計算がやや面倒であるため，実装ではこの項を省略する．
すなわち実装する制御則は次のとおりである．

$$
\begin{aligned}
	\omega_i = k_{\theta,i} \sin(\theta_i^{\mathrm{d}} - \theta_i)
\end{aligned}
$$
