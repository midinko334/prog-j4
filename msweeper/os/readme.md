## 仮想環境で動かすのに必要なアプリ
gcc, nasm, ld, QEMU

## Ubuntuの場合以下のコマンドでインストール可能
- sudo apt update
- sudo apt install build-essential nasm qemu-system-x86


## 実行する場合
- コンパイル : make
- 起動 : make run
- 環境をきれいにするコマンド : make clean

## 時分割テスト

- `Alt` + `←` で左側の時計、`Alt` + `→` で右側のゲームへ入力先を切り替えます。
- 左側の時計を選択中に任意のキーを押すと、時計の行に `still working!` を3秒間表示してから時計表示へ戻ります。
- 右側のゲームを選択中は、従来どおり `W` / `A` / `S` / `D` と Space を使えます。

キーボードはIRQ1でカーネルが一度だけ読み、選択中タスクのメールボックスへ渡します。
PITのIRQ0（約100Hz）では各タスクのレジスタとスタックを保存・復元するため、
タスクは `ret` せず長時間処理や無限ループを行えます。
