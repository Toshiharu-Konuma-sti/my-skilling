import requests

def main():
    print("=================================================")
    print("     Python (pip) Remote Repository Demo App     ")
    print("=================================================")
    
    # 外部API（GitHubの公開API）にリクエストを送信
    url = "https://api.github.com/zen"
    response = requests.get(url)
    
    if response.status_code == 200:
        print("GitHub Zen Message:", response.text)
    else:
        print(f"Failed to fetch. Status code: {response.status_code}")
        
    print("=================================================")

if __name__ == "__main__":
    main()
