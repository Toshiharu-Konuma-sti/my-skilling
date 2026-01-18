# Artifactory Pro 構築体験: IaC で AWS の EC2

## 事前準備

### AWS CLI 向け AWS アクセスキーとシークレット発行

1. [AWS コンソール](https://console.aws.amazon.com/console/home/) にアクセスします。
1. コンソール右上のアカウント名をクリックすると表示するメニューから「セキュリティ認証情報」を選択します。
1. 自分の認証情報画面で少し下方にスクロールするとアクセスキー枠が存在します。
1. 枠内の「アクセスキーを作成」ボタンをクリックしてから以下を入力して発行します。
    - 「コマンドラインインターフェース (CLI)」を選択します。
    - 「上記のレコメンデーションを理解し、アクセスキーを作成します。」をチェックします。
    - 「次へ」ボタンで進みます。
    - 「説明タグ値」は空欄でよいので「アクセスキーを作成」をクリックします。
    - 次の画面で「アクセスキー」と「シークレットアクセスキー」が表示されるので記録します。特にシークレットアクセスキーは、この画面を逃すと二度と見れないので必ず記録します。

### AWS CLI インストール

1. AWS CLI コマンドをインストールする。

    ```
    $ curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
    $ sudo apt install -y unzip
    $ unzip ./awscliv2.zip
    $ sudo ./aws/install
    ```
    ```
    $ aws --version

      aws-cli/2.32.32 Python/3.13.11 Linux/6.6.87.2-microsoft-standard-WSL2 exe/x86_64.ubuntu.24
    ```

1. AWS CLI コマンドへ AWS アクセスキーとシークレットを登録します。

    ```
    $ aws configure

      AWS Access Key ID : {AWS's Access Key}
      AWS Secret Access Key : {AWS's Secret Access Key}
      Default region name : ap-northeast-1
      Default output format : json
    ```

### EC2 操作向け SSH キーペア発行

1. [AWS コンソール](https://console.aws.amazon.com/console/home/) にアクセスします。
1. 検索欄で「ec2」で検索して EC2 へ遷移します。
1. 左ペインのメニューから「ネットワーク & セキュリティ > キーペア」を選択します。
1. 「キーペアを作成」をクリックして以下を入力して発行します。
    - 名前: 先頭にアカウント名（例：hoge）を含め「hoge-ec2-key-pair」の様に分かりやすい名前を入力します。
    - キーペアのタイプ: 「RSA」を選択します。
    - プライベートキーファイル形式: 「.pem」を選択します。
    - 「キーペアを作成」ボタンのクリックと同時に秘密鍵がダウンロードされるので保管します。
1. 取得した秘密鍵をローカル環境の「~/.ssh/」ディレクトリで管理します。

    ```
    $ mv hoge-ec2-key-pair.pem ~/.ssh/
    $ chmod 400 ~/.ssh/hoge-ec2-key-pair.pem
    ```

### Terraform インストール

```
$ wget -O- https://apt.releases.hashicorp.com/gpg | sudo gpg --dearmor -o /usr/share/keyrings/hashicorp-archive-keyring.gpg
$ echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $(lsb_release -cs) main" \
 | sudo tee /etc/apt/sources.list.d/hashicorp.list
$ sudo apt update && sudo apt install terraform
```
```
$ terraform --version

  Terraform v1.14.3
  on linux_amd64
```

### Ansible インストール

```
$ sudo apt update
$ sudo apt install -y ansible
```
```
$ ansible --version

  ansible [core 2.16.3]
    config file = None
	 :
```

## 体験手順

### インストール

1. リポジトリを取得します。

    ```
    $ git clone https://github.com/Toshiharu-Konuma-sti/my-skilling.git
    $ cd my-skilling/artifactory-pro/iac-for-aws-ec2/
    ```

1. Terraform で AWS へインフラ構築から開始するため、Terraform のアセットが格納されているディレクトリへ遷移します。

    ```
    $ cd terraform/
    ```

1. Terraform コマンド実行前に必ず「[terraform.tfvars](./terraform/terraform.tfvars)」の値を調整します。

    | 項目 | 説明 |
    | ---- | ---- |
    | project_prefix | AWS で VPC や EC2 などの各種リソースの名前に付く接頭辞のため、アカウント名など誰が見ても構築者が分かる識別子を指定します。 |
    | ec2_ssh_key_name | 「EC2 操作向け SSH キーペア発行」章で発行した秘密鍵の拡張子（.pem）を除いたファイル名を指定します。 |
    | allowed_cidr |  SSH や Web UI へアクセスを許可する IP アドレスを「xxx.xxx.xxx.xxx/32」の書式で指定します。<br>```$ curl inet-ip.info``` コマンドで自身の IP を取得して指定します。 |
    | artifactory_node_count | Artifactory を構築するノード数を指定します。 |


1. Terraform コマンドで VPC や EC2 などインフラを構築します。

    ```
    $ terraform init
    $ terraform plan
    ```
    ```
    $ terraform apply

       :
      Enter a value: yes
       :
    ```

1. Terraform apply コマンド実行後に表示される、各 EC2 のパブリック IP アドレスは、動作確認する際に必要となるのでメモしておきます。
    ```
       :
      artifactory_ip = [
        "52.194.226.xxx",
      ]
      db_ip = "13.113.214.xxx"
      haproxy_ip = "18.183.109.xxx"
      nfs_ip = "13.231.59.xxx"
      xray_ip = "13.230.96.xxx"
    ```

1. Ansible で EC2 へアプリケーションをインストールするため、Ansible のアセットが格納されているディレクトリへ遷移します。

    ```
    $ cd ../ansible/
    ```

1. Ansible コマンドで EC2 へ SSH 接続できるか疎通確認します。

    ```
    $ ansible -i inventory.ini all -m ping
    ```

1. Ansible コマンドで EC2 へアプリケーション環境を構築します。

    ```
    $ ansible-playbook -i inventory.ini setup_db.yml -v
    $ ansible-playbook -i inventory.ini setup_nfs.yml -v
    $ ansible-playbook -i inventory.ini setup_art.yml -v
    $ ansible-playbook -i inventory.ini setup_lb.yml -v
    $ ansible-playbook -i inventory.ini setup_xray.yml -v
    ```

1. 構築した環境で動作を確認します。

    - ログ確認:
	    ```
      # Artifactory
      $ ssh -i ~/.ssh/hoge-ec2-key-pair.pem ubuntu@{ip of artifactory}
      $ sudo tail -f /var/opt/jfrog/artifactory/log/artifactory-service.log

      # Xray
      $ ssh -i ~/.ssh/hoge-ec2-key-pair.pem ubuntu@{ip of xray}
      $ sudo tail -f /var/opt/jfrog/xray/log/xray-server-service.log
      ```

	- ブラウザアクセス:
      - 管理画面: http://{ip of haproxy}:8404/stats
        - user: admin
        - password: password
      - Artifactory: http://{ip of haproxy}
        - user: admin
        - password: password

1. 動作確認が終わったら、不要なリソース消費を防ぐため、次に説明するアンインストール手順で環境を破棄します。


### アンインストール

1. アンインストールでは Ansible は使わずに、Terraform で AWS の VPC や EC2 を始めとする各種リソースを削除して元通りに戻します。

    ```
    $ cd terraform/
    $ terraform destroy
    
       :
      Enter a value: yes
       :
    ```
