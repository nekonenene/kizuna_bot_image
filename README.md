# Kizuna bot with Docker

## Requirement

* Docker
* (option) rbenv

## Usage

```sh
make init
```

で

* log ディレクトリの作成
* default.env を .env としてコピー

がおこなわれる。

```sh
make build
```

でコンテナ作成。

```sh
make fluentd
```

で fluentd を立ち上げておいたあと、

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
