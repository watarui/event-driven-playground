defmodule ClientServiceWeb.Plugs.GraphiQLAuthPlug do
  @moduledoc """
  GraphiQL に postMessage で送信された認証トークンを処理するプラグ
  """
  import Plug.Conn

  def init(opts), do: opts

  def call(conn, _opts) do
    case conn.method do
      "GET" ->
        # GraphiQL のインターフェースにカスタムスクリプトを注入
        register_before_send(conn, &inject_auth_script/1)

      "POST" ->
        # POST リクエストの場合は、Firebase 認証を適用
        conn
        |> ClientService.Auth.FirebasePlug.call([])
        |> ClientServiceWeb.Plugs.DataloaderPlug.call([])

      _ ->
        conn
    end
  end

  defp inject_auth_script(conn) do
    case get_resp_header(conn, "content-type") do
      ["text/html" <> _] ->
        body = conn.resp_body

        # postMessage でトークンを受け取るスクリプトを注入
        auth_script = """
        <script>
          (function() {
            let authToken = null;
            let userRole = null;
            
            // 元の fetch を保存
            const originalFetch = window.fetch;
            
            // GraphiQL が使用する fetcher を直接オーバーライド
            function customFetcher(graphQLParams) {
              return fetch('/graphql', {
                method: 'post',
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                  ...(authToken ? { 'Authorization': 'Bearer ' + authToken } : {})
                },
                body: JSON.stringify(graphQLParams),
                credentials: 'same-origin',
              }).then(function (response) {
                return response.text();
              }).then(function (responseBody) {
                try {
                  return JSON.parse(responseBody);
                } catch (error) {
                  return responseBody;
                }
              });
            }
            
            // fetch をオーバーライドして認証ヘッダーを追加
            window.fetch = function(url, options = {}) {
              // GraphQL エンドポイントへのリクエストの場合
              if (url.includes('/graphql') || url.includes('/graphiql')) {
                // URL を /graphql に修正
                if (url.includes('/graphiql') && options.method === 'POST') {
                  url = url.replace('/graphiql', '/graphql');
                }
                
                // 認証ヘッダーを追加
                if (authToken) {
                  options.headers = options.headers || {};
                  options.headers['Authorization'] = 'Bearer ' + authToken;
                }
              }
              
              return originalFetch.call(this, url, options);
            };
            
            // GraphiQL の設定をオーバーライド
            if (window.GraphiQL) {
              window.graphQLFetcher = customFetcher;
            }
            
            // GraphiQL が後で読み込まれる場合のために定期的にチェック
            const checkInterval = setInterval(function() {
              if (window.GraphiQL && !window.graphQLFetcher) {
                window.graphQLFetcher = customFetcher;
                clearInterval(checkInterval);
              }
            }, 100);
            
            // 親ウィンドウからのメッセージを受信
            window.addEventListener('message', function(event) {
              // セキュリティチェック（本番環境では適切なオリジンを設定）
              if (event.origin !== 'http://localhost:4001' && event.origin !== window.location.origin) {
                return;
              }
              
              if (event.data && event.data.type === 'AUTH_TOKEN') {
                authToken = event.data.token;
                userRole = event.data.role;
                
                // ユーザー情報を右上に小さく表示
                setTimeout(() => {
                  // 既存の情報バッジを削除
                  const existingBadge = document.getElementById('auth-info-badge');
                  if (existingBadge) existingBadge.remove();
                  
                  // 右上に小さなバッジを追加
                  const infoBadge = document.createElement('div');
                  infoBadge.id = 'auth-info-badge';
                  infoBadge.style.cssText = 'position: fixed; top: 10px; right: 10px; background: ' + 
                    (userRole === 'admin' ? '#10b981' : '#f59e0b') + 
                    '; color: white; padding: 4px 8px; font-size: 11px; border-radius: 4px; z-index: 1000; opacity: 0.9;';
                  infoBadge.textContent = userRole.toUpperCase();
                  infoBadge.title = 'Authenticated as ' + userRole + ' via Dashboard';
                  
                  document.body.appendChild(infoBadge);
                }, 500);
              }
            });
            
            // 初期化完了を親ウィンドウに通知
            if (window.parent !== window) {
              window.parent.postMessage({ type: 'GRAPHIQL_READY' }, '*');
            }
          })();
        </script>
        """

        # </body> タグの直前にスクリプトを挿入
        new_body = String.replace(body, "</body>", auth_script <> "</body>")

        conn
        |> put_resp_header("content-length", to_string(byte_size(new_body)))
        |> resp(conn.status, new_body)

      _ ->
        conn
    end
  end
end
