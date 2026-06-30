# llama.cpp CUDA + JupyterLab + MCP Tools for RunPod

CUDA-enabled `llama.cpp` server for RunPod with:

- the standard `llama.cpp` WebUI
- OpenAI-compatible API
- JupyterLab
- MCP tools for filesystem access, web fetch, and Brave Search
- preconfigured MCP server entries in the WebUI

This template is intended for local/private AI workflows such as writing, research, reference reading, and file-assisted model use.

## Ports

Configure these RunPod HTTP ports:

| Port | Label | Purpose |
| --- | --- | --- |
| `8080` | `llama-webui` | `llama.cpp` WebUI and OpenAI-compatible API |
| `8888` | `jupyterlab` | JupyterLab |
| `8082` | `spare` | Reserved / optional |

Do not expose MCP ports `8091`, `8092`, or `8093`.

The MCP servers are intended to run inside the pod and be accessed by the WebUI through localhost.

## RunPod Template Settings

Container image:

```text
ghcr.io/stinger722/runpod-llamacpp-jupyter:latest
```

Persistent storage mount path:

```text
/workspace
```

Recommended disk sizes:

```text
Container Disk: 80 GB
Volume Disk:    200 GB
```

Smaller disks may work depending on the model size.

## Environment Variables

Example:

```env
MODEL_REPO=your-huggingface-org/your-gguf-repo
MODEL_FILE=your-model-Q4_K_M.gguf
MODEL_DIR=/workspace/models/your-model

PROJECTOR_REPO=
PROJECTOR_FILE=
PROJECTOR_DIR=/workspace/projectors/your-model

CTX_SIZE=131072
GPU_LAYERS=auto
PARALLEL=1
HOST=0.0.0.0
PORT=8080

ENABLE_MCP_FILESYSTEM=1
ENABLE_MCP_FETCH=1
ENABLE_MCP_BRAVE=0
BRAVE_API_KEY=PUT_YOUR_BRAVE_SEARCH_API_KEY_HERE

LLAMA_API_KEY=CHANGE_ME_TO_A_LONG_RANDOM_SECRET
JUPYTER_TOKEN=CHANGE_ME_TO_A_LONG_RANDOM_SECRET_TOO
```

Set `PROJECTOR_REPO` and `PROJECTOR_FILE` only when using a multimodal model that requires an `mmproj` file.

## MCP Tools

### filesystem

The filesystem MCP server is restricted to these directories only:

```text
/workspace/ai-readable/input
/workspace/ai-readable/output
```

Use `input` for files the AI should read.
Use `output` for files the AI should create.

Subdirectories under `input` and `output` are not created automatically. Organize them as needed.

Recommended instruction for file work:

```text
Treat /workspace/ai-readable/input as read-only reference material.
Write new files only under /workspace/ai-readable/output.
Do not overwrite or delete existing files unless explicitly requested.
```

### fetch

The fetch MCP server can retrieve web pages for research.

The package default response limit is `5000` characters. For longer pages, ask the model to pass `max_length` and `start_index` to the fetch tool, or configure a larger default when customizing the image.

Example prompt:

```text
Use fetch_markdown to read https://example.com.
Set max_length to 20000.
```

### brave-search

Brave Search is optional.

To enable it:

```env
ENABLE_MCP_BRAVE=1
BRAVE_API_KEY=your_brave_search_api_key
```

If `BRAVE_API_KEY` is not set, the pod can still run, but Brave Search will not work.

## WebUI MCP Setup

At startup, the WebUI config is generated with these MCP server entries:

```text
filesystem
fetch
brave-search
```

The endpoints are internal to the pod:

```text
filesystem:   http://127.0.0.1:8091/mcp
fetch:        http://127.0.0.1:8092/mcp
brave-search: http://127.0.0.1:8093/mcp
```

If needed, open the MCP settings in the `llama.cpp` WebUI and enable the servers for the current chat.

## API Usage

The server exposes an OpenAI-compatible API on port `8080`.

Base URL:

```text
https://YOUR-RUNPOD-8080-URL/v1
```

Use the value of `LLAMA_API_KEY` as the bearer token.

Example:

```bash
curl https://YOUR-RUNPOD-8080-URL/v1/chat/completions \
  -H "Authorization: Bearer YOUR_LLAMA_API_KEY" \
  -H "Content-Type: application/json" \
  -d '{
    "model": "local-model",
    "messages": [
      {"role": "user", "content": "Hello"}
    ]
  }'
```

## Security Notes

- Always replace `LLAMA_API_KEY` with a long random secret.
- Always replace `JUPYTER_TOKEN` with a long random secret.
- Do not put real API keys or RunPod URLs in GitHub.
- Do not expose MCP ports `8091`, `8092`, or `8093`.
- Do not give filesystem MCP access to `/`, `/root`, `/etc`, or all of `/workspace`.
- Treat `/workspace/ai-readable/input` as reference material.
- Ask the AI to write generated files under `/workspace/ai-readable/output`.

## Changing Models

This template downloads GGUF models from Hugging Face using:

```env
MODEL_REPO=
MODEL_FILE=
MODEL_DIR=
```

For multimodal models, also set:

```env
PROJECTOR_REPO=
PROJECTOR_FILE=
PROJECTOR_DIR=
```

The exact model license and acceptable use rules depend on the model you choose. Review the model card before publishing a template or demo.

## Japanese Guide

## 概要

このRunPodテンプレートは、CUDA対応の `llama.cpp` サーバー、標準WebUI、OpenAI互換API、JupyterLab、MCPツールをまとめたものです。

主な用途:

- 小説・文章制作
- 資料調査
- 長文資料の参照
- ファイルを使ったAI作業
- OpenAI互換APIによる外部アプリ連携

## ポート

RunPodのHTTP Portsには以下だけを設定してください。

| ポート | ラベル | 用途 |
| --- | --- | --- |
| `8080` | `llama-webui` | `llama.cpp` WebUI / OpenAI互換API |
| `8888` | `jupyterlab` | JupyterLab |
| `8082` | `spare` | 予備 |

MCP用の `8091`, `8092`, `8093` は公開しないでください。

## ファイル操作

filesystem MCPがアクセスできるのは以下だけです。

```text
/workspace/ai-readable/input
/workspace/ai-readable/output
```

使い分け:

- `input`: AIに読ませたい資料
- `output`: AIに作成させるファイル

推奨指示:

```text
/workspace/ai-readable/input は参照専用として扱ってください。
新しいファイルは /workspace/ai-readable/output 以下にだけ作成してください。
明示的に依頼されない限り、既存ファイルの上書きや削除はしないでください。
```

## Brave Search

Brave Searchを使う場合は以下を設定します。

```env
ENABLE_MCP_BRAVE=1
BRAVE_API_KEY=あなたのBrave Search APIキー
```

使わない場合は以下で問題ありません。

```env
ENABLE_MCP_BRAVE=0
BRAVE_API_KEY=PUT_YOUR_BRAVE_SEARCH_API_KEY_HERE
```

## セキュリティ注意

- `LLAMA_API_KEY` は必ず長いランダム文字列に変更してください。
- `JUPYTER_TOKEN` も必ず長いランダム文字列に変更してください。
- GitHubや公開テンプレート説明に実際のAPIキーを書かないでください。
- RunPodのHTTP Service URLを不用意に公開しないでください。
- MCPポート `8091`, `8092`, `8093` は公開しないでください。
- filesystem MCPに `/`, `/root`, `/etc`, `/workspace` 全体を許可しないでください。

## モデルの変更

モデルは以下の環境変数で差し替えできます。

```env
MODEL_REPO=
MODEL_FILE=
MODEL_DIR=
```

マルチモーダルモデルを使う場合は、必要に応じて以下も設定します。

```env
PROJECTOR_REPO=
PROJECTOR_FILE=
PROJECTOR_DIR=
```

モデルごとにライセンスや利用条件が異なります。公開テンプレートやデモに使う前に、必ずモデルカードを確認してください。
