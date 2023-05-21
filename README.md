# dbt-tutorial

[dbt 入門](https://zenn.dev/foursue/books/31456a86de5bb4)を参照

## （事前）postgresコンテナ作成・起動
* postgres用docker-compose.yml作成

```yml:docker-compose.yml
version: '3'
# ローカルでpostgresを起動する時のみ
services:
  postgres:
    image: postgres:latest
    restart: always
    ports:
      - 5432:5432
    environment:
      POSTGRES_USER: admin
      POSTGRES_PASSWORD: admin
    volumes:
      - ./postgres:/var/lib/postgresql/data

```

* postgresコンテナ起動、確認、停止（後続でdbtを追記するために停止する）

```bash
$ docker-compose up -d
$ docker-compose ps
$ docker-compose stop
```

## dbtコンテナ作成・起動
* postgres接続用profiles.yml作成

```yml:profiles.yml
dbt_training_dw:
  target: dev
  outputs:
    dev:
      type: postgres
      host: localhost
      user: admin
      password: admin
      port: 5432
      dbname: postgres
      schema: public
      threads: 1
      keepalives_idle: 0
      connect_timeout: 10
```

* dbtファイル格納用ディレクトリ作成（コンテナからマウントする）

```bash
$ mkdir dbt_projects
```

* dbt用Dockerfile, docker-compose.yml作成

```docker:Dockerfile
FROM python:3.9.12-slim-bullseye

# System setup
RUN apt-get update \
  && apt-get dist-upgrade -y \
  && apt-get install -y --no-install-recommends \
    git \
    ssh-client \
    software-properties-common \
    make \
    build-essential \
    ca-certificates \
    libpq-dev \
    vim \
  && apt-get clean \
  && rm -rf \
    /var/lib/apt/lists/* \
    /tmp/* \
    /var/tmp/*

# Env vars
ENV PYTHONIOENCODING=utf-8
ENV LANG=C.UTF-8

# Update python
RUN python -m pip install --upgrade pip setuptools wheel --no-cache-dir

# dbt
RUN python -m pip install dbt-postgres --no-cache-dir

COPY profiles.yml /root/.dbt/profiles.yml

WORKDIR /usr/app/dbt/
VOLUME /usr/app
ENTRYPOINT tail -f /dev/null
```

```docker:docker-compose.yml（postgresに追記）
  dbt:
    container_name: dbt
    build: .
    volumes:
      - ./dbt_projects:/usr/app/dbt
    ports:
      - 8080:8080
```

* dbtコンテナ起動、ログイン

```bash
$ docker-compose up -d
$ docker exec -it dbt /bin/bash
```

## dbtプロジェクト設定

```bash
$ mkdir dbt_projects/dbt_training
```

* dbt がどのディレクトリを参照するのかや、どのディレクトリへコンパイルした SQL ファイルをアウトプットするのか

```yml:dbt_training/dbt_project.yml
name: 'dbt_training'
config-version: 2
version: '1.0.0'

profile: 'dbt_training_dw'

model-paths: ["models"]
analysis-paths: ["analysis"]
test-paths: ["tests"]
seed-paths: ["seeds"]
macro-paths: ["macros"]
snapshot-paths: ["snapshots"]

target-path: "target"
clean-targets: [target, dbt_packages]

models:
  dbt_training:
    example:
```

```
$ cd dbt_training
$ mkdir models analysis tests seeds macros snapshots target
```

* 現時点のディレクトリ構成

```
.
├── Dockerfile
├── dbt_projects
│   └── dbt_training
│       ├── analysis
│       ├── dbt_project.yml
│       ├── macros
│       ├── models
│       ├── seeds
│       ├── snapshots
│       ├── target
│       └── tests
├── docker-compose.yml
└── profiles.yml
```

* 接続確認
    * DBに接続しているわけではない
```
$ root@container:/usr/app/dbt/dbt_training# dbt run
```

## モデル作成
* （事前）データ準備

```sql
# psql -U admin

-- DB作成
CREATE DATABASE dbt_training;
-- DB一覧確認
\l

-- DB接続
\connect dbt_training
-- スキーマ作成
CREATE SCHEMA raw;
-- スキーマ一覧確認
\dn
-- 現在のスキーマ確認
select current_schema;
-- スキーマ内のテーブル一覧
\dt raw.*

-- テーブル作成
--   従業員テーブル
CREATE TABLE dbt_training.raw.employees (
	"employee_id" varchar(256),
	"first_name" varchar(256),
	"last_name" varchar(256),
	"email" varchar(256),
	"job_id" varchar(256),
	"loaded_at" timestamp
);

--   お仕事テーブル
CREATE TABLE dbt_training.raw.jobs (
	"job_id" varchar(256),
	"job_title" varchar(256),
	"min_salary" INTEGER,
	"max_salary" INTEGER,
	"loaded_at" timestamp
);

-- データをINSERT
-- 従業員テーブルへデータをINSERT
INSERT INTO dbt_training.raw.employees VALUES
	('101','taro','yamada','yamada@example.com','11','2022-03-16'),
	('102','ziro','sato','satou@example.com','11','2022-03-16')
;

-- 仕事テーブルへデータをINSERT
INSERT INTO dbt_training.raw.jobs VALUES
	('11','datascientist',6000000,12000000,'2022-03-16'),
	('12','dataengineer',5000000,10000000,'2022-03-16')
;
```

* profilesのdbnameをdbt_trainingに修正する
* モデル作成
    * employeesテーブルを元に、employee_namesビューを作成する

```sql:models/employee_names.sql
select
	"employee_id",
	concat("first_name", ' ', "last_name") as full_name
from
	dbt_training.raw.employees
```

```
$ dbt run
```

* 確認

```sql
SELECT table_name FROM INFORMATION_SCHEMA.views  WHERE table_schema = ANY (current_schemas(false));
```

## 参考
* [dbt-core](https://github.com/dbt-labs/dbt-core)
* [dbt 入門](https://zenn.dev/foursue/books/31456a86de5bb4)
* [dbt (CLI) × BigQuery 〜Docker 環境構築から GitHub Pages 公開まで〜](https://qiita.com/mida12251141/items/47b4ade9cbbb82290d43)
