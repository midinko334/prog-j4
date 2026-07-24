## 仮想環境で動かすのに必要なアプリ
gcc, nasm, ld, QEMU

## Ubuntuの場合以下のコマンドでインストール可能
- sudo apt update
- sudo apt install build-essential nasm qemu-system-x86


## 実行する場合
- コンパイル : make
- 起動 : make run
- 環境をきれいにするコマンド : make clean
