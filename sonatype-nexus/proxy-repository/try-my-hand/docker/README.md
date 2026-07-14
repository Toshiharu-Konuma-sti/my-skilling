# Docker リモートリポジトリ体験手順

対象: Sonatype Nexus の `docker-hub-proxy` リポジトリ

## 前提条件

- Nexus が起動していること (`http://nexus.local:8081`)
- `docker-hub-proxy` リポジトリが作成されていること (port: `8085`)
- `/etc/docker/daemon.json` に `insecure-registries` が設定済みであること
  - → `setup/step01_SETUP_PRIVILEGED_ENV.sh` を実行済みであること

---

## 1. Nexus レジストリへログイン

```sh
docker login nexus.local:8085 -u admin -p password
```

---

## 2. Nexus の docker-hub-proxy 経由でイメージを取得する

```sh
# Alpine Linux (軽量イメージ)
docker pull nexus.local:8085/alpine:latest

# Ubuntu
docker pull nexus.local:8085/ubuntu:24.04

# Hello World (動作確認用)
docker pull nexus.local:8085/hello-world:latest
```

---

## 3. 取得したイメージを実行する

```sh
docker run --rm nexus.local:8085/alpine:latest echo "Hello from Nexus proxy!"

docker run --rm nexus.local:8085/hello-world:latest
```

---

## 4. Nexus にキャッシュされたことを確認する

ブラウザでアクセス:

```
http://nexus.local:8081 → Browse → docker-hub-proxy → v2/
```

---

## 5. ローカルキャッシュを削除して Nexus 経由を確認する

```sh
# ローカルから削除
docker rmi nexus.local:8085/alpine:latest

# 再取得 (Nexus のキャッシュから配信される)
docker pull nexus.local:8085/alpine:latest
```

---

## 6. ログアウト

```sh
docker logout nexus.local:8085
```
