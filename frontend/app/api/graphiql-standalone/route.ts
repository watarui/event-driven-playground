import { type NextRequest, NextResponse } from "next/server"
import { cookies } from "next/headers"

export async function GET(request: NextRequest) {
  // Cookie から認証トークンを取得
  const cookieStore = await cookies()
  const authToken = cookieStore.get("auth-token")?.value || ""

  // GraphiQL の HTML を生成
  const html = `
<!DOCTYPE html>
<html lang="ja">
<head>
  <meta charset="utf-8">
  <title>GraphQL Explorer</title>
  <meta name="viewport" content="width=device-width, initial-scale=1">
  
  <!-- GraphiQL CSS -->
  <link rel="stylesheet" href="https://unpkg.com/graphiql@3/graphiql.min.css" />
  
  <style>
    body {
      height: 100vh;
      margin: 0;
      overflow: hidden;
    }
    #graphiql {
      height: 100vh;
    }
    
    /* ダークモード対応 */
    @media (prefers-color-scheme: dark) {
      .graphiql-container {
        background-color: #1f2937;
        color: #f3f4f6;
      }
      .graphiql-editor {
        background-color: #111827;
      }
      .CodeMirror {
        background-color: #111827 !important;
        color: #f3f4f6 !important;
      }
      .CodeMirror-gutters {
        background-color: #1f2937 !important;
        border-right-color: #374151 !important;
      }
      .graphiql-doc-explorer-content {
        background-color: #111827;
        color: #f3f4f6;
      }
      .graphiql-doc-explorer-header {
        background-color: #1f2937;
      }
    }
  </style>
</head>
<body>
  <div id="graphiql">Loading...</div>
  
  <!-- React and GraphiQL from CDN -->
  <script crossorigin src="https://unpkg.com/react@18/umd/react.production.min.js"></script>
  <script crossorigin src="https://unpkg.com/react-dom@18/umd/react-dom.production.min.js"></script>
  <script src="https://unpkg.com/graphiql@3/graphiql.min.js"></script>
  
  <script>
    // 認証付き fetcher
    function createGraphQLFetcher() {
      return function graphQLFetcher(graphQLParams) {
        return fetch('/api/graphql', {
          method: 'post',
          headers: {
            'Accept': 'application/json',
            'Content-Type': 'application/json',
            ${authToken ? `'Authorization': 'Bearer ${authToken}',` : ""}
          },
          body: JSON.stringify(graphQLParams),
          credentials: 'same-origin',
        }).then(function (response) {
          return response.json();
        }).catch(function (error) {
          return {
            errors: [{
              message: 'GraphQL request failed: ' + error.message
            }]
          };
        });
      };
    }

    // トークンリフレッシュ機能
    async function refreshToken() {
      try {
        // Firebase Auth から新しいトークンを取得するため、親ウィンドウにメッセージを送信
        if (window.parent !== window) {
          window.parent.postMessage({ type: 'REFRESH_TOKEN_REQUEST' }, '*');
        }
      } catch (error) {
        console.error('Failed to refresh token:', error);
      }
    }

    // GraphiQL をレンダリング
    const root = ReactDOM.createRoot(document.getElementById('graphiql'));
    root.render(
      React.createElement(GraphiQL, {
        fetcher: createGraphQLFetcher(),
        defaultQuery: \`# Event Driven Playground GraphQL Explorer
# 
# ショートカット:
#   Ctrl/Cmd + Enter: クエリを実行
#   Ctrl/Cmd + Space: オートコンプリート
#   Ctrl/Cmd + /: 選択行をコメント化
#
# 例: カテゴリ一覧を取得
query GetCategories {
  categories {
    id
    name
    products {
      id
      name
      price
    }
  }
}\`,
        headerEditorEnabled: true,
        shouldPersistHeaders: true,
      })
    );

    // 親ウィンドウからのメッセージを受信（トークン更新用）
    window.addEventListener('message', function(event) {
      if (event.data && event.data.type === 'AUTH_TOKEN_UPDATED') {
        // ページをリロードして新しいトークンを反映
        window.location.reload();
      }
    });
  </script>
</body>
</html>
  `.trim()

  return new NextResponse(html, {
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-cache, no-store, must-revalidate",
    },
  })
}
