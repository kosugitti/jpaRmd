
<!-- README.md is generated from README.Rmd. Please edit that file -->

# jpaRmd

<!-- badges: start -->

<!-- badges: end -->

jpaRmdは，日本心理学会の「心理学研究」への投稿論文をRmarkdownで作成するためのパッケージです。

以下の日本心理学会の「執筆・投稿の手びき(2015年版)」に基づいています。

<https://psych.or.jp/manual/>

まだ全く完成していません・・・使用

## インストール

以下のコマンドをRコンソールに打ち込んで，Github経由でインストールしてください。

    # install.packages("devtools")
    devtools::install_github("ykunisato/jpaRmd")

## 使用法

  - RStudioで，「File」 -\> 「New File」 -\> 「R Markdown…」
    をクリックする。以下の画面がでてきたら，「From
    Template」から「… {jpaRmd}」を選んで，OKをクリックする。開かれた.RmdファイルをKnitください。

  - Research
    Compendiumの関数も用意していて，以下のようにset\_rc\_jpa()関数を使って，引数にプロジェクト名をいれると（なおスペースは避けてください），『心理学研究』用のRmdや解析，データを配置するフォルダなども準備されます。

<!-- end list -->

    library(jpaRmd)
    set_rc_jpa("rmarkdown_for_reproducibility")
