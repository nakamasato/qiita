---
title: sudoerでないときに、pythonのライブラリをインストールする（または、新規ユーザをSudoerにはしたくないけど、好きにPythonLibraryを入れてもらうのは構わない時の方法）
tags: Python pyenv Linux
author: nakamasato
slide: false
---
#解決方法

開発に入った時など、よくあるのが、sudoerには入れてもらえないが、開発でライブラリが必要。

そんなときは、pyenvで管理する

```bash
pip install <package名> --user
```

これで大丈夫


# pyenvを初めて使う

注意：もしもpyenvが入ってないと、これを入れる作業には、sudo権限が必要になってしまうので、管理者にやってもらうしかない。（はず）

## installを参考にする
https://github.com/yyuu/pyenv#installation

###mac

1. brewでインストールする
```bash
brew install pyenv-virtualenv
```
2. ~/.zshrcにいかを追加する(zshを使っている場合)

```
if which pyenv > /dev/null; then eval "$(pyenv init -)"; fi
if which pyenv-virtualenv-init > /dev/null; then eval "$(pyenv virtualenv-init -)"; fi
```
3 読みなおす

```bash
source ~/.zshrc
```

###ubuntu

pipをインストール（Sudo権限が必要）

```
sudo aptitude install python-pip
```

pyenvをインストール

```
pip install pyenv --egg
```

.zshrcにいかを記入

```
export PATH="$HOME/.pyenv/bin:$PATH"
eval "$(pyenv init -)"
eval "$(pyenv virtualenv-init -)"
```

.zshrcを再読み込み

```
source ~/.zshrc
```


##基本コマンド

### Pythonの特定のVersionをインストール

```bash
pyenv install <version>
```

例えば、

```bash
pyenv install 3.5.1
```


### globalで使うPythonのVersionを指定

```bash
pyenv global <version>
```

