# Kizuna bot with Docker

## Requirement

* Docker
* (option) rbenv

## Usage

```sh
make init
```

で

* log ディレクトリの再作成
* default.env を .env としてコピー

がおこなわれる。（本番環境ではおこなわない方が良い）

```sh
make build
```

でコンテナ作成。

```sh
make run_dev
```

もしくは

```sh
make run_prod
```

で実行開始。


### Version up Ruby or gems

rbenv でローカルでやってもいいが、 `.ruby-version` を直接書き換えたのち、  
`make build && make login` でコンテナに入って `bundle update` で更新するという方法もある。
