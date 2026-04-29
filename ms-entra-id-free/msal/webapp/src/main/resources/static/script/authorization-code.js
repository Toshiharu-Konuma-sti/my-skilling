function decodeJwt() {
    const token = document.getElementById('jwtInput').value.trim();
    const resultArea = document.getElementById('decodedResult');
    
    if (!token) {
        resultArea.value = "トークンを入力してください。";
        return;
    }

    try {
        const parts = token.split('.');
        if (parts.length !== 3) {
            throw new Error("JWTの形式が正しくありません（ヘッダー.ペイロード.署名の3層構造が必要です）");
        }

        // Base64UrlをBase64に変換してデコード
        const base64UrlDecode = (str) => {
            const base64 = str.replace(/-/g, '+').replace(/_/g, '/');
            return decodeURIComponent(atob(base64).split('').map(function(c) {
                return '%' + ('00' + c.charCodeAt(0).toString(16)).slice(-2);
            }).join(''));
        };

        const header = JSON.parse(base64UrlDecode(parts[0]));
        const payload = JSON.parse(base64UrlDecode(parts[1]));

        resultArea.value = `[Header]\n${JSON.stringify(header, null, 2)}\n\n[Payload]\n${JSON.stringify(payload, null, 2)}`;
        
    } catch (e) {
        resultArea.value = "デコードに失敗しました: " + e.message;
    }
}

function clearDecoder() {
    document.getElementById('jwtInput').value = "";
    document.getElementById('decodedResult').value = "";
}