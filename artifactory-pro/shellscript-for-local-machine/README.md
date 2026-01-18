# Artifactory Pro 構築体験: シェルスクリプトでローカルマシーン

## 体験手順

### インストール

1. リポジトリを取得します。

    ```
    $ git clone https://github.com/Toshiharu-Konuma-sti/my-skilling.git
	$ cd my-skilling/artifactory-pro/shellscript-for-local-machine/
    ```


1. まずはインストールスクリプトの処理概要を理解します。
    - [INSTALL-Artifactory.sh](./INSTALL-Artifactory.sh)

1. 実行権限が掛けられているはずですが、念のために掛けます。

    ```
    $ chmod +x INSTALL-Artifactory.sh
    ```

1. インストールスクリプトを実行します。スクリプト内で sudo コマンドを使うため、パスワードを求められたら入力します。

    ```
	$ ./INSTALL-Artifactory.sh

	############################################################
	# START SCRIPT
	############################################################

	### START: Install PostgreSQL #######################################
	[sudo] hoge のパスワード: **********
	  :

    ```

1. 構築した環境で動作を確認します。

    - ログ確認:
	    ```
		# Artifactory
		$ sudo tail -f /var/opt/jfrog/artifactory/log/artifactory-service.log
		# Xray
		$ sudo tail -f /var/opt/jfrog/xray/log/xray-server-service.log
		```
	- ブラウザアクセス:
        - http://localhost:8082/
		    - user: admin
			- password: password

1. 動作確認が終わったら、不要なリソース消費を防ぐため、次に説明するアンインストール手順で環境を破棄します。

### アンインストール

1. 実行権限が掛けられているはずですが、念のために掛けます。

    ```
    $ chmod +x UNINSTALL-Artifactory.sh
    ```

1. アンインストールスクリプトを実行します。スクリプト内で sudo コマンドを使うため、パスワードを求められたら入力します。

    ```
    $ ./UNINSTALL-Artifactory.sh
	############################################################
	# START SCRIPT
	############################################################
	
	### START: Stopping Services ########################################
	[sudo] hoge のパスワード: **********
	  :
    ```
