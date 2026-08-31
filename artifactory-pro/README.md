# Artifactory Pro インストール体験

[![GitHub License](https://img.shields.io/github/license/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/blob/main/LICENSE)
[![GitHub last commit](https://img.shields.io/github/last-commit/Toshiharu-Konuma-sti/my-skilling?style=flat-square)](https://github.com/Toshiharu-Konuma-sti/my-skilling/commits/main)
[![JFrog Artifactory](https://img.shields.io/badge/JFrog-Artifactory-41BF47?style=flat-square&logo=jfrog&logoColor=white)](https://jfrog.com/artifactory/)
[![JFrog Xray](https://img.shields.io/badge/JFrog-Xray-41BF47?style=flat-square&logo=jfrog&logoColor=white)](https://jfrog.com/xray/)
[![AWS EC2](https://img.shields.io/badge/AWS-EC2-FF9900?style=flat-square&logo=amazon-ec2&logoColor=white)](https://aws.amazon.com/ec2/)
[![Terraform](https://img.shields.io/badge/Terraform-1.9+-7B42BC?style=flat-square&logo=terraform&logoColor=white)](https://www.terraform.io/)
[![Ansible](https://img.shields.io/badge/Ansible-Automation-EE0000?style=flat-square&logo=ansible&logoColor=white)](https://www.ansible.com/)
[![Ubuntu](https://img.shields.io/badge/Ubuntu-Noble%2024.04-E95420?style=flat-square&logo=ubuntu&logoColor=white)](https://ubuntu.com/)

---

## 目次

1. [素材紹介](#1-素材紹介)
2. [本番導入時のTips](#2-本番導入時のtips)
3. [参考資料](#3-参考資料)

---

## 1. 素材紹介

- Case 1: [シェルスクリプトでローカルマシーンで構築](./shellscript-for-local-machine/)
- Case 2: [IaC で AWS の EC2 へ構築](./iac-for-aws-ec2/)

<table>
<tr><th width="50%">Case 1</th><th width="50%">Case 2</th></tr>
<tr>
<td width="50%" style="text-align: center"><img src="./image/my-skilling-artifactory-pro-overview-local.png"></td>
<td width="50%" style="text-align: center"><img src="./image/my-skilling-artifactory-pro-overview-ec2.png"></td></tr>
<tr><td>各コンポーネントはプロセス単位</td><td>各コンポーネントはEC2単位</td></tr>
</table>

## 2. 本番導入時の Tips

> このデモ環境では実施していないが、実際の本番導入時には対応の検討をお勧めします。

### Proxy（Load Balancer）の前面配置

Proxy（Load Balancer）は Artifactory の冗長化だけを目的とするものではなく、  
冗長化の要否に関わらず、以下の理由から Proxy を前面に配置することを推奨します。

- **SSL 終端** — エンタープライズ環境への導入では、実質的に SSL の終端を含む Proxy（Load Balancer）を必要とします。
- **IdP との SSO 連携** — Entra ID（旧 Azure AD）をはじめとするメジャーな IdP は、認可コードを返すリダイレクト URL に `https://` しか指定できないため、SSL を終端する Proxy を前面に置かないと SSO 連携ができません。
- **各種開発言語からのリモートリポジトリ利用** — 各種開発言語のパッケージマネージャーやビルドツールからリモートリポジトリとして利用する際、SSL（https）でないと利用しにくい、あるいは利用できないケースがあります。


## 3. 参考資料

- https://jfrog.com/help/r/jfrog-installation-setup-documentation/install-artifactory-on-debian
- https://jfrog.com/help/r/jfrog-installation-setup-documentation/create-the-artifactory-postgresql-database
- https://jfrog.com/help/r/jfrog-installation-setup-documentation/xray-single-node-manual-debian-installation
- https://jfrog.com/help/r/jfrog-installation-setup-documentation/create-the-xray-postgresql-database
