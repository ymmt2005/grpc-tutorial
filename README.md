# gRPC チュートリアル

> 本資料は 2021 年にサイボウズ社内の研修用に作成したものです。

[解説動画](https://youtu.be/YXSTcLi38UE)があるのでこちらを視ながら学んでください。

- [内容について](#内容について)
- [参考文献](#参考文献)
- [gRPC とは](#grpc-とは)
	- [RPC 概説](#rpc-概説)
	- [gRPC の特徴](#grpc-の特徴)
	- [他のプロトコルとの比較](#他のプロトコルとの比較)
- [はじめての gRPC 実装](#はじめての-grpc-実装)
	- [Protocol Buffers で API を定義してみよう](#protocol-buffers-で-api-を定義してみよう)
	- [proto ファイルをコンパイルしてみよう](#proto-ファイルをコンパイルしてみよう)
	- [サーバーを実装してみよう](#サーバーを実装してみよう)
	- [クライアントを実装してみよう](#クライアントを実装してみよう)
	- [（発展）他の人の実装と通信してみよう](#発展他の人の実装と通信してみよう)
	- [プロトコルを拡張してみよう](#プロトコルを拡張してみよう)
	- [Well-known types](#well-known-types)
- [実用的な gRPC 実装](#実用的な-grpc-実装)
	- [Keep-alive](#keep-alive)
	- [テスト](#テスト)
	- [ログ](#ログ)
	- [メトリクス](#メトリクス)
	- [セキュリティ](#セキュリティ)
	- [認証](#認証)
	- [ヘルスチェック](#ヘルスチェック)
	- [冗長化と負荷分散](#冗長化と負荷分散)
- [発展的な話題](#発展的な話題)
	- [拡張エラー](#拡張エラー)
	- [大容量データ](#大容量データ)
	- [UNIX ドメインソケットでの通信](#unix-ドメインソケットでの通信)
	- [ブラウザからの利用](#ブラウザからの利用)
	- [FAQ](#faq)

## 内容について

本文書は gRPC について丁寧に全て解説するものではありません。

gRPC とその周辺の技術については様々な文書や本が既にあります。
それらを紹介しつつ、受講者が実際に gRPC でプログラミングできるよう具体例と課題を提供するのが目的です。

受講者は以下について必要な知識を持っているものとします。

- gRPC が[サポートしている言語](https://grpc.io/docs/languages/)のいずれか

    ただし PHP など一部の言語はサーバーを実装するのには向いていません。
    また各所にあるサンプル実装の多くは Go か Java です。

- TCP および HTTP に関する知識

    通信は隠蔽されるので深い知識は必要ありませんが、一定の知識は gRPC の動作・仕様の理解に役立ちます。

## 参考文献

以下に上げる書籍および Web サイトは gRPC とその関連技術である Protocol Buffers の公式ないし良いチュートリアルです。
以降の説明で適宜参照します。

- 公式資料
    - [grpc.io][]: gRPC の公式サイトです。仕様だけでなく、各言語のチュートリアルもあります。
    - [grpc.github.io][]: 詳細なドキュメント群です。
    - [gRPC over HTTP2][http2]: 上記サイトの一ドキュメントです。HTTP/2 をどう利用しているかの仕様書です。
    - [developers.google.com/protocol-buffers][]: Protocol Buffers の公式サイトです。
- チュートリアル・本
    - [The complete gRPC course][course]: ステップバイステップ形式で進むチュートリアルです。非常に良い。
    - [gRPC: Up and Running][book]: gRPC と Protocol Buffers の本です。ぶっちゃけこれを読めば十分だったりします。 
    - [Securing your gRPCApplication][secure]: KubeCon 2019 NA のセッションの一つで、gRPC の認証・認可の実装方法を詳しく解説しています。

## gRPC とは

gRPC は Google で開発された多言語間の Remote Procedure Call (RPC) を実現するプロトコルです。
IDL としては Protocol Buffers が使われ、通信には HTTP/2 の枠組みが利用されています。

多くの言語をサポートしているため、マイクロサービス間の通信プロトコルとして gRPC を採用する例が多くあります。

### RPC 概説

Remote Procedure Call, RPC はその名の通り外部のプログラムが提供する Procedure を呼び出す仕組みです。
各言語の普通の関数（stub 関数）を呼び出すとライブラリがネットワーク通信して外部で動作しているサーバーにリクエストを投げ、結果を受け取って関数の戻り値として返すのが普通です。

このような仕組みであるため、RPC の利用者視点ではネットワークや他の言語の知識を必要とすることなく、ただの関数として利用できます。

異なる言語間で RPC として呼び出せる関数を定義する場合、特定の言語に依らない独立の定義方法が必要になります。
一般に、RPC の関数やその引数を定義する言語を [Interface Description Language (IDL)][IDL] と言います。

IDL にはコンパイラが付属し、サポートしている言語用に関数呼び出しのためのコードを自動生成します。
例えばクライアントが Python でサーバーが Go の場合、Python の文字列リストをネットワークで送れるようバイト列に serialize し、Go では受け取ったバイト列を deserialize して Go の文字列スライスにしないといけません。
IDL コンパイラはこのような serialize / deserialize コードを生成してくれます。

### gRPC の特徴

詳しい仕組みは gRPC 公式ドキュメントや[本][book]を読んでください。ここでは簡単に。

gRPC は RPC の実装の一つで、以下の特徴があります。

- IDL として仕様が小さく拡張性の高い Protocol Buffers を採用

    つまり学習コストが低いということです。

- 通信プロトコルとして HTTP/2 を採用

    HTTP/2 のフレームを使って独自のプロトコルを構築しているため、HTTP/1 とは互換性がありません。
    そのため、例えば HTTP/2 を受け付けるリバースプロキシが、バックエンドには HTTP/1 でしか接続できない場合、gRPC のリバースプロキシはできません。
    詳しいことは [gRPC over HTTP2][http2] を読んでください。

- 単純な関数呼び出しに加え、ストリーム処理を提供

    ストリームとは、不定長の連続したデータです。
    gRPC では単純なリクエスト・レスポンス形式（[Unary RPC](https://grpc.io/docs/what-is-grpc/core-concepts/#unary-rpc)）以外に、サーバーから不定長のメッセージを受け取るモード、クライアントから不定長のメッセージを受け取るモード、そして双方向にメッセージを送り続けるモードがあります。

- リクエストチェーン全体に渡るタイムアウトやキャンセルをプロトコルレベルでサポート

    タイムアウトやキャンセルが gRPC のプロトコルとしてサポートされているため、各言語の実装で簡単に実装できるようになっています。
    これは、複数のマイクロサービスを跨いでいるリクエストを制御するのにとても強力な仕組みです。

### 他のプロトコルとの比較

Web サービスやマイクロサービスで使われるプロトコルの代表格は HTTP と、それを利用した REST API です。
HTTP は非常に柔軟ですが、渡すデータのスキーマが標準化されていないため、異なる言語間の RPC を実装するのは面倒です。
[OpenAPI][] という REST API 用の IDL もありますが、Protocol Buffers と比較すると記述量が多いです。

cf. [OpenAPI examples](https://github.com/OAI/OpenAPI-Specification/tree/main/examples/v3.0)

また、OpenAPI スキーマからコードを生成するツールが公式には提供されておらず、言語毎に完成度がまちまちな点が困ります。

[GraphQL][] は Facebook が開発したプロトコルで、HTTP 上で処理されますが REST API とは異なり GET/POST などのメソッドやステータスコードに意味を持たせていません。
特徴はスキーマはデータ構造を定義するもので、標準化されたクエリにより任意のデータを取得可能な仕組みになっていることです。

以下の表で特徴をまとめます。必要な機能に合わせて選択してください。

| 機能                           | gRPC                         | REST           | GraphQL                    |
| ------------------------------ | ---------------------------- | -------------- | -------------------------- |
| スキーマ言語                   | Protocol Buffers             | OpenAPI        | GraphQL                    |
| クエリ言語                     | なし                         | なし           | あり                       |
| IDL コンパイラ                 | 公式が多数提供               | 公式提供なし   | 公式提供なし               |
| ストリーム処理                 | 双方向可能                   | サーバーサイド | [ドラフト][graphql-stream] |
| クライアント指定のタイムアウト | あり                         | なし           | なし                       |
| クライアントからのキャンセル   | あり                         | なし           | なし                       |
| バイナリデータ                 | 扱える                       | 扱える         | [実装次第][graphql-binary] |
| 最大メッセージサイズ           | デフォルト 4 MiB, 最大 4 GiB | 仕様上はなし   | 仕様上はなし               |

## はじめての gRPC 実装

### Protocol Buffers で API を定義してみよう

とても賢いスーパーコンピューター Deep Thought を gRPC で API として利用できるようにしてみましょう。

以下のように `deepthought.proto` ファイルを作成してください。
なお、本ファイルのあるリポジトリに[作成済み](./deepthought.proto)なのでそれを利用しても構いません。

Protocol Buffers を書くときは以下の資料を参照してください。

- [Language Guide (proto3)](https://developers.google.com/protocol-buffers/docs/proto3)
- [Style Guide](https://developers.google.com/protocol-buffers/docs/style)
- [Protocol Buffers Version 3 Language Specification][proto3]

```proto
// Protocol Buffers のバージョン。2 と 3 があるが、今からやるなら `proto3` 一択
syntax = "proto3";

// package 指定は必須。HTTP/2 の :path 疑似ヘッダの一部として使われる。
package deepthought;

// option 指定は文字通りオプションで無くても構いません。
// 以下の例は Go のコードを生成する際のパッケージ名を指定しています。
option go_package = "github.com/ymmt2005/grpc-tutorial/go/deepthought";

// 以下の例は Java のコードを(以下同
option java_package = "io.github.ymmt2005.grpc_tutorial.deepthought";

/**
 * BootRequest は Boot RPC のリクエストのメッセージです。
 * 現状空ですが、拡張可能にするため定義しておきます。
 */
message BootRequest {}

/**
 * BootResponse は Boot RPC のレスポンスのメッセージです。
 */
message BootResponse {
  string message = 1;  // フィールドには 1 以上の整数の識別子が必要です
}

/**
 * InferRequest は Infer RPC のリクエストのメッセージです。
 */
message InferRequest {
  string query = 1;
}

/**
 * InferResponse は Infer RPC のレスポンスのメッセージです。
 */
message InferResponse {
  sint64 answer = 1;  // sint は符号付きの整数で、負の数を効率よくエンコードしてくれます
  repeated string description = 2; // repeated を付けると配列を渡せます
}

/** 
 * Compute は gRPC のサービスです。二つ RPC を定義しています。
 */
service Compute {
  // Compute は Boot した瞬間に思考を始めるのでキャンセルするまでレスポンスを stream し続けます。
  // リクエスト・レスポンスのメッセージは省略できません。
  // `stream` がレスポンスについているので、この RPC はサーバーサイドストリーミングになります。
  rpc Boot(BootRequest) returns (stream BootResponse);

  // Infer は任意の質問に解答してくれます。
  // 質問が Life, Universe, Everything に関する場合 750 万年、もとい 750 ミリ秒の計算を必要とします。
  // この RPC はメッセージに `stream` がついていないので、Unary RPC です。
  rpc Infer(InferRequest) returns (InferResponse);
}
```

### proto ファイルをコンパイルしてみよう

Protocol Buffers のファイルから `protoc` というコンパイラで各言語のクライアントないしサーバー実装を生成できます。
`protoc` はプラッガブルな構造になっており、`protoc-gen-xxx` という別のコマンドをフィルタとして呼び出すことで、任意の言語やファイルを生成するように拡張できます。

さて、ここからは残念なお知らせです。
実際にコードを生成する方式は Java, Go, Python といった言語毎に激しく異なります。

- Go: `protoc` に `protoc-gen-go`, `protoc-gen-go-grpc` というプラグインを組み合わせてコンパイル
- Java: Maven や Gradle に gRPC 用プラグインを組み込んで間接的にコンパイル
- Python: PIP でモジュールをインストールしてモジュール経由でコンパイル
- PHP: `grpc_php_plugin` をビルドして `protoc` でコンパイル
- Node: 事前コンパイル方式ではなく、proto ファイルから動的にサーバー・クライアント実装を生成

とはいえ `protoc` とプラグインでコンパイルする仕組みが基本ではあるので、ここでは proto ファイルから仕様書を生成してみましょう。

まずは `protoc` をインストールします。
以下の URL にアクセスして、`protoc-3.xx.yy-*.zip` というZIP ファイルをダウンロードしてください。

https://github.com/protocolbuffers/protobuf/releases

展開すると `bin/protoc` と `include` ディレクトリができるので、`bin` ディレクトリの絶対パスを PATH 環境変数に追加します。

```console
$ curl -fsL -o /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v3.17.3/protoc-3.17.3-linux-x86_64.zip
$ unzip /tmp/protoc.zip 'bin/*' 'include/*'
$ rm -f /tmp/protoc.zip
$ export PATH=$(pwd)/bin:$PATH
```

次に [protoc-gen-doc][] というプラグインを同じ `bin/` ディレクトリにインストールします。

```console
$ curl -fsL https://github.com/pseudomuto/protoc-gen-doc/releases/download/v1.4.1/protoc-gen-doc-1.4.1.linux-amd64.go1.15.2.tar.gz | tar -x -z -f - -C bin --strip-components=1
```

これで準備は整いました。以下のように HTML や Markdown の仕様書を生成してみましょう。

```console
$ protoc -I. -Iinclude --doc_out=. deepthought.proto                                    # index.html を作成
$ protoc -I. -Iinclude --doc_out=. --doc_opt=markdown,deepthought.md deepthought.proto  # Markdown の仕様書を作成
```

[Makefile](./Makefile) にこれらの処理を自動化する実装例があります。

### サーバーを実装してみよう

さて、それでは Deep Thought を gRPC のサーバーとして実装してみましょう。

サンプルは Go で実装しています。
Java や C++, Node でも実装できますが、やり方はまったく異なるので自分の得意な言語でチャレンジする場合は以下の URL を参照してください。

- [Supported languages](https://grpc.io/docs/languages/): 各言語のチュートリアル
- [github.com/avinassh/grpc-errors](https://github.com/avinassh/grpc-errors): 各言語でのエラー処理方法

Java の人には [Introduction to gRPC](https://www.baeldung.com/grpc-introduction) や [Config Gradle to generate Java code from Protobuf](https://dev.to/techschoolguru/config-gradle-to-generate-java-code-from-protobuf-1cla) も役立つでしょう。

まず Go の `protoc` プラグインをセットアップします。
Go は 1.16 を使ってください。

```console
$ GOBIN=$(pwd)/bin go install google.golang.org/protobuf/cmd/protoc-gen-go@v1.26.0
$ GOBIN=$(pwd)/bin go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v1.1.0
```

次に `protoc` コマンドで gRPC のサーバーとクライアント用コードを生成します。

```console
$ go mod init github.com/ymmt2005/grpc-tutorial
$ protoc -I. -Iinclude --go_out=module=github.com/ymmt2005/grpc-tutorial:. deepthought.proto
$ protoc -I. -Iinclude --go-grpc_out=module=github.com/ymmt2005/grpc-tutorial:. deepthought.proto
$ go mod tidy
```

gRPC 用のコードは [`go/deepthought/deepthought_grpc.go`](https://github.com/ymmt2005/grpc-tutorial/blob/answer/go/deepthought/deepthought_grpc.pb.go) として生成されます。
このファイルは編集せずそのまま利用します。
サーバーが実装するインタフェースは `ComputeServer` としてこのファイルに定義されています。

```go
type ComputeServer interface {
	Boot(*BootRequest, Compute_BootServer) error
	Infer(context.Context, *InferRequest) (*InferResponse, error)
	mustEmbedUnimplementedComputeServer()
}
```

まず、このインタフェースを実装する必要があります。
`go/server` ディレクトリに `server.go` を以下のように作りましょう。

```go
package main

import (
	"context"
	"time"

	// protoc で自動生成されたパッケージ
	"github.com/ymmt2005/grpc-tutorial/go/deepthought"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

// ComputeServer を実装する型
type Server struct {
	// 将来 proto ファイルに RPC が追加されてインタフェースが拡張された際、
	// ビルドエラーになるのを防止する仕組み。
	deepthought.UnimplementedComputeServer
}

// インタフェースが実装できていることをコンパイル時に確認するおまじない
var _ deepthought.ComputeServer = &Server{}

// Boot RPC の型。実装は後で。
func (s *Server) Boot(req *deepthought.BootRequest, stream deepthought.Compute_BootServer) error {
	panic("not implemented") // TODO: Implement
}

// Infer RPC の型。実装は後で。
func (s *Server) Infer(ctx context.Context, req *deepthought.InferRequest) (*deepthought.InferResponse, error) {
	panic("not implemented") // TODO: Implement
}
```

では `Boot` メソッドを実装してみましょう。ストリームでデータを送るには `stream.Send` を使います。
Deep Thought はクライアントからキャンセルしてくるまで、延々とデータを投げ続けることにします。

```go
func (s *Server) Boot(req *deepthought.BootRequest, stream deepthought.Compute_BootServer) error {
	for {
		select {
		// クライアントがリクエストをキャンセルしたら終わり
		case <-stream.Context().Done():
			return nil
		// そうでなければ 1 秒待機してデータを送信
		case <-time.After(1 * time.Second):
		}

		if err := stream.Send(&deepthought.BootResponse{
			Message: "I THINK THEREFORE I AM.",
		}); err != nil {
			return err
		}
	}
}
```

次に `Infer` メソッドを実装しましょう。

"Life", "Universe", "Everything" に関しては 750 ミリ秒考えて答えを返すことにします。
もしクライアントがそれよりも短いデッドラインを指定している場合、エラーを返します。

```go
func (s *Server) Infer(ctx context.Context, req *deepthought.InferRequest) (*deepthought.InferResponse, error) {
	switch req.Query {
	case "Life", "Universe", "Everything":
	default:
		// gRPC は共通で使われるエラーコードを定めているので、基本は定義済みのコードを使う
		// https://grpc.github.io/grpc/core/md_doc_statuscodes.html
		return nil, status.Error(codes.InvalidArgument, "Contemplate your query")
	}

	// クライアントがタイムアウトを指定しているかチェック
	deadline, ok := ctx.Deadline()

	// 指定されていない、もしくは十分な時間があれば回答
	if !ok || time.Until(deadline) > 750*time.Millisecond {
		time.Sleep(750 * time.Millisecond)
		return &deepthought.InferResponse{
			Answer:      42,
			Description: []string{"I checked it"},
		}, nil
	}

	// 時間が足りなければ DEADLINE_EXCEEDED (code 4) エラーを返す
	// https://grpc.github.io/grpc/core/md_doc_statuscodes.html
	return nil, status.Error(codes.DeadlineExceeded, "It would take longer")
}
```

さて、これで実装できました。メソッドの内容は好みに応じて変更しても大丈夫です。

実際にサーバーとして動作させるには `go/server` ディレクトリに `main.go` を以下の内容で作ります。

```go
package main

import (
	"fmt"
	"net"
	"os"

	// protoc で自動生成されたパッケージ
	"github.com/ymmt2005/grpc-tutorial/go/deepthought"
	"google.golang.org/grpc"
)

const portNumber = 13333

func main() {
	serv := grpc.NewServer()

	// 実装した Server を登録
	deepthought.RegisterComputeServer(serv, &Server{})

	// 待ち受けソケットを作成
	l, err := net.Listen("tcp", fmt.Sprintf(":%d", portNumber))
	if err != nil {
		fmt.Println("failed to listen:", err)
		os.Exit(1)
	}

	// gRPC サーバーでリクエストの受付を開始
	// l は Close されてから戻るので、main 関数での Close は不要
	serv.Serve(l)
}
```

以下の手順でビルドして動かしてみましょう。

```console
$ go build -o server ./go/server
$ ./server
```

### クライアントを実装してみよう

次に Deep Thought に問い合わせるクライアントを実装してみましょう。
問い合わせコードは自動生成されるため、実際に書かなくてはいけないのはネットワークに接続する部分のみです。

サーバーを実装したときに、すでにクライアントの問い合わせコードも生成されています。
あとは接続して実際に RPC を呼び出せば OK です。

`go/client` ディレクトリに `main.go` を以下の内容で作りましょう。
好みに応じて内容は変更しても構いません。

```go
package main

import (
	"context"
	"errors"
	"fmt"
	"os"
	"time"

	"github.com/ymmt2005/grpc-tutorial/go/deepthought"
	"google.golang.org/grpc"
	"google.golang.org/grpc/codes"
	"google.golang.org/grpc/status"
)

func main() {
	err := subMain()
	if err != nil {
		fmt.Fprintln(os.Stderr, err)
		os.Exit(1)
	}
}

func subMain() error {
	if len(os.Args) != 2 {
		return errors.New("usage: client HOST:PORT")
	}
	// コマンドライン引数で渡されたアドレスに接続
	addr := os.Args[1]

	// grpc.WithInsecure() を指定することで、TLS ではなく平文で接続
	// 通信内容が保護できないし、不正なサーバーに接続しても検出できないので本当はダメ
	conn, err := grpc.Dial(addr, grpc.WithInsecure())
	if err != nil {
		return err
	}
	// 使い終わったら Close しないとコネクションがリークします
	defer conn.Close()

	// 自動生成された RPC クライアントを conn から作成
	// gRPC は HTTP/2 の stream を用いるため、複数のクライアントが同一の conn を使えます。
	// また RPC クライアントのメソッドも複数同時に呼び出し可能です。
	// see https://github.com/grpc/grpc-go/blob/master/Documentation/concurrency.md
	cc := deepthought.NewComputeClient(conn)

	// Boot を 2.5 秒後にクライアントからキャンセルするコード
	ctx, cancel := context.WithCancel(context.Background())
	go func(cancel func()) {
		time.Sleep(2500 * time.Millisecond)
		cancel()
	}(cancel)

	// 自動生成された Boot RPC 呼び出しコードを実行
	stream, err := cc.Boot(ctx, &deepthought.BootRequest{})
	if err != nil {
		return err
	}

	// ストリームから読み続ける
	for {
		resp, err := stream.Recv()
		if err != nil {
			// io.EOF は stream の正常終了を示す値
			if err == io.EOF {
				break
			}
			// status パッケージは error と gRPC status の相互変換を提供
			// `status.Code` は gRPC のステータスコードを取り出す
			// see https://pkg.go.dev/google.golang.org/grpc/status
			if status.Code(err) == codes.Canceled {
				// キャンセル終了ならループを脱出
				break
			}
			return fmt.Errorf("receiving boot response: %w", err)
		}
		fmt.Printf("Boot: %s\n", resp.Message)
	}

	return nil
}
```

ビルドして動かしてみましょう。
サーバーも動作していれば、以下のように表示されるはずです。

```console
$ go build -o client ./go/client
$ ./client 127.0.0.1:13333
Boot: I THINK THEREFORE I AM.
Boot: I THINK THEREFORE I AM.

$ echo $?
0
```

`Infer` メソッドを呼び出すのは皆さんの課題にしておきます。
[`context.WithTimeout`](https://golang.org/pkg/context/#WithTimeout) でデッドラインを指定してサーバーの挙動が変わるのを確認してみてください。

デッドラインの指定の仕方は以下の記事にまとまっています。

- [gRPC and Deadlines](https://grpc.io/blog/deadlines/)

### （発展）他の人の実装と通信してみよう

自分が作ったサーバーもしくはクライアントと、他の人が作ったサーバーもしくはクライアントで通信してみましょう。

講師が作成したサーバー・クライアントは以下の手順でビルドして動作させられます。

```console
$ git clone https://github.com/ymmt2005/grpc-tutorial
$ cd grpc-tutorial
$ git checkout answer
$ go build -o server ./go/server
$ go build -o client ./go/client

# Run server
$ ./server

# Run client
$ ./client 127.0.0.1:13333
```

### プロトコルを拡張してみよう

gRPC がマイクロサービスに向いているもう一つの大きな理由が、プロトコルに前方および後方互換性を保つ仕組みがあることです。

仕組みは単純で、メッセージのすべてのフィールドがオプショナル、つまり指定してもしなくても良いということになっているのです。
そのため追加されたフィールドがあっても古いサーバーは無視しますし、削除されたフィールドについてはゼロ値（数値なら 0, 文字列なら空文字列, bool なら `false`）で渡るようになっています。

もちろん、サーバー実装で必須としているフィールドの値がなければエラーを返すことにはなります。

詳しいことは [Updating A Message Type](https://developers.google.com/protocol-buffers/docs/proto3#updating) を読んでください。

注意点は、削除したフィールドの ID は他のフィールドに使いまわさないことです。
使いまわしを防止するため、Protocol Buffers には [Reserved Fields](https://developers.google.com/protocol-buffers/docs/proto3#reserved) という仕組みがあります。

試しに、以下のように `BootRequest` と `InferResponse` メッセージを変更してみましょう。

```proto
// フィールドがなかったところに、silent を追加
// silent true なら Boot RPC はデータをストリームせずさっさと完了する
message BootRequest {
  bool silent = 1;
}

message InferResponse {
  sint64 answer = 1;
  // repeated string description = 2;
  // description フィールドは廃止して reserved に
  reserved 2;
  reserved "description";
}
```

新しい `deepthought.proto` から `protoc` でコードを再生成して、新しいクライアント・サーバーを実装してみましょう。
新しいクライアントが古いサーバーと通信がうまくできるか、あるいは古いクライアントが新しいサーバーと通信できるか試してみてください。

### Well-known types

`protoc` をダウンロードした際、`bin` ディレクトリと合わせて `include` ディレクトリもインストールしました。
中身は以下のようになっています。

```console
$ tree include
include
└── google
    └── protobuf
        ├── any.proto
        ├── api.proto
        ├── compiler
        │   └── plugin.proto
        ├── descriptor.proto
        ├── duration.proto
        ├── empty.proto
        ├── field_mask.proto
        ├── source_context.proto
        ├── struct.proto
        ├── timestamp.proto
        ├── type.proto
        └── wrappers.proto
```

これらは [Well-known types][well-known] と呼ばれ、タイムスタンプや Empty メッセージを定義しています。
以下のように import して使います。

```proto
syntax = "proto3";
package = sample;

import "google/protobuf/empty.proto";
import "google/protobuf/timestamp.proto";

message Foo {
  google.protobuf.Timestamp ts = 1;
}

service S {
  rpc P(google.protobuf.Empty) returns (Foo);
}
```

また、各言語の型と Protocol Buffers の型で相互変換するライブラリが用意されています。

- Go の例 [google.golang.org/protobuf/types/known/timestamppb](https://pkg.go.dev/google.golang.org/protobuf@v1.26.0/types/known/timestamppb)
- Java の例 [com.google.protobuf.util.Timestamps](https://developers.google.com/protocol-buffers/docs/reference/java/com/google/protobuf/util/Timestamps.html)

課題として、`BootResponse` にタイムスタンプフィールドを追加してみましょう。

## 実用的な gRPC 実装

ここまでで、gRPC のサーバー・クライアント実装に必要な基礎知識は整えることができました。
しかし上記サンプルコードは中身の無さはさておいても、実運用にはとても耐えられません。

- 自動テストされていない
- ログがでない
- 通信内容がまる見え
- 認証の仕組みがない
- ...

実運用に耐えるために必要な知識をさらに学びましょう。

### Keep-alive

まず最初に憶えておきたいのは、TCP 接続の場合は Keep-alive を有効にすることです。

TCP の場合、接続先のサーバーが落ちると場合によっては長時間そのことに気付けない問題があります。
詳しくは [TCP とタイムアウトと私](https://blog.cybozu.io/entry/2015/11/26/170019)を読んでみてください。

この問題に対応するため、gRPC は HTTP/2 の PING フレームを送信することで接続先がまだ存在していることを確認できます。
しかし PING フレームによる死活確認機能がデフォルトでは有効になっていない実装が多いようです。

Go の場合、以下のようにクライアントのコードを変更して Keep-alive 機能を有効にしましょう。

```go
	// see https://pkg.go.dev/google.golang.org/grpc/keepalive#ClientParameters
	kp := keepalive.ClientParameters{
		Time: 1 * time.Minute,
	}
	conn, err := grpc.Dial(addr, grpc.WithInsecure(), grpc.WithKeepaliveParams(kp))
```

Java の場合 [`ManagedChannelBuilder.keepAliveTime`](https://grpc.github.io/grpc-java/javadoc/io/grpc/ManagedChannelBuilder.html#keepAliveTime-long-java.util.concurrent.TimeUnit-) で指定します。

Node の場合[こちらのブログ記事](https://kiririmode.hatenablog.jp/entry/20190512/1557619277)が詳しいです。

さて、このまま動かすと RPC に時間がかかるときにクライアントのリクエストが以下のように失敗してしまいます。

> failed to clone data: failed to clone data from 10.x.y.z: rpc error: code = Unknown desc = closing transport due to: connection error: desc = "error reading from server: EOF", received prior goaway: code: ENHANCE_YOUR_CALM, debug data: too_many_pings

設定された閾値（デフォルトは 5 分）より短い間隔で何度も PING フレームを送るとこのエラーが発生してしまいます。
たとえば上記のクライアントは 1 分毎に PING を送るためにエラーになったわけです。

この閾値を調整するには、サーバーを以下のように修正します。

```go
func main() {
	kep := keepalive.EnforcementPolicy{
		MinTime: 10 * time.Second,
	}
	serv := grpc.NewServer(grpc.KeepaliveEnforcementPolicy(kep))
...
```

ref. https://github.com/grpc/grpc-go/blob/master/Documentation/keepalive.md

### テスト

gRPC のサーバー・クライアントを両方用意して結合試験することはもちろん可能です。
しかし、どちらかしか用意できない場合やテストの粒度を細かくしてテストしたいことは良くあります。

クライアントのテストでは、RPC 関数呼び出しをモックすることで簡単に単体テストできます。
例えば Go では以下のように RPC がインタフェースとして定義されているので、モックで実装すれば良いわけです。

```go
// ComputeClient is the client API for Compute service.
//
// For semantics around ctx use and closing/ending streaming RPCs, please refer to https://pkg.go.dev/google.golang.org/grpc/?tab=doc#ClientConn.NewStream.
type ComputeClient interface {
	Boot(ctx context.Context, in *BootRequest, opts ...grpc.CallOption) (Compute_BootClient, error)
	Infer(ctx context.Context, in *InferRequest, opts ...grpc.CallOption) (*InferResponse, error)
}
```

サーバーのハンドラは先に実装した通り普通のメソッドなので、パラメーターを人工的に作ってテストすれば OK です。

### ログ

gRPC は各言語でインターセプターと呼ばれるリクエスト処理の前後に任意の処理を追加する仕組みを提供しています。
インターセプタを使えば、アクセスログや後述するメトリクスなど様々な機能を付け加えることが可能です。

インターセプタは既存の便利なものがたくさんあります。
Go では [github.com/grpc-ecosystem/go-grpc-middleware](https://github.com/grpc-ecosystem/go-grpc-middleware) にログやメトリクス、接続レート制限など各種インターセプタが揃っています。

ログの実装例は以下のブログ記事を参照してください。

- [Use go-grpc-middleware with kubebuilder](https://ymmt2005.hatenablog.com/entry/2020/08/31/Use_go-grpc-middleware_with_kubebuilder#Introducing-go-grpc-middleware)

Java では [github.com/yidongnan/grpc-spring-boot-starter](https://github.com/yidongnan/grpc-spring-boot-starter) を使うのが便利そうです。

- [実装例](https://github.com/yidongnan/grpc-spring-boot-starter/blob/master/examples/local-grpc-server/src/main/java/net/devh/boot/grpc/examples/local/server/LogGrpcInterceptor.java)

### メトリクス

メトリクスはログと同様インターセプタとして実装するのが便利です。

ログの節で紹介した Go と Java のライブラリはメトリクスの実装も含んでいます。

### セキュリティ

gRPC の通信を TCP で行うと、そのままではデータは平文のまま送受信されるため、パスワードなど重要な情報が漏洩する可能性があります。
また、適切なサーバーないしクライアントであるかを認証することもできません。

そこで、gRPC では通信を [Transport Layer Security (TLS)][TLS] で通常は保護することにしています。
TLS にはクライアント認証機能もあるため、サーバー・クライアントの相互認証(mTLS)も実装できます。

詳しい実装方法はここでは解説しません。
Go の場合 [advancedtls](https://pkg.go.dev/google.golang.org/grpc/security/advancedtls) や [pemfile](https://pkg.go.dev/google.golang.org/grpc@v1.38.0/credentials/tls/certprovider/pemfile) というパッケージを使うと証明書が更新された際の自動再読み込みや mTLS を比較的簡単に実装できます。

- [サーバー実装例](https://github.com/grpc/grpc-go/blob/95e48a892d6c/security/advancedtls/examples/credential_reloading_from_files/server/main.go)
- [クライアント実装例](https://github.com/grpc/grpc-go/blob/95e48a892d6c/security/advancedtls/examples/credential_reloading_from_files/client/main.go)

Java の mTLS 実装例は[こちら](https://github.com/grpc/grpc-java/tree/master/examples/example-tls)にあります。

[MOCO](https://github.com/cybozu-go/moco) では mTLS 用の証明書を [cert-manager](https://cert-manager.io/) で生成しています。
詳しくはこの辺りを参照してください。

- https://github.com/cybozu-go/moco/blob/main/docs/security.md#grpc-api
- https://github.com/cybozu-go/moco/blob/main/docs/reconcile.md#clustering-related-resources

### 認証

TLS クライアント認証よりも柔軟な認証が必要な場合に備え、gRPC には OAuth トークンや JSON Web Token (JWT) を全ての RPC で自動的に送信する機能があります。
トークンを保護するため、前述の TLS は前提となります（Go の場合 TLS 有効でないとエラーになります）。

実装については以下の資料を参照してください。

- [Use gRPC interceptor for authorization with JWT](https://dev.to/techschoolguru/use-grpc-interceptor-for-authorization-with-jwt-1c5h)
- [Securing your gRPC Application][secure] - RPC 単位の認可の実装まで丁寧に解説
- [gRPC-Java の JWT 認証例](https://github.com/grpc/grpc-java/tree/master/examples/example-jwt-auth)

上記の例で JWT は対称鍵で署名されていますが、公開鍵で署名することもできます。
詳しくは [JSON Web Tokens with Public Key Signatures](https://blog.miguelgrinberg.com/post/json-web-tokens-with-public-key-signatures) などを参照してください。

**Tips**

認証情報のようにメッセージ本文とは関係がない付属データを送るため、gRPC には「メタデータ」という仕組みがあります。
メタデータは HTTP/2 のフレームに付属するカスタムヘッダとして実装されています。
 
- [google.golang.org/grpc/metadata](https://pkg.go.dev/google.golang.org/grpc@v1.38.0/metadata): Go ではメタデータは Context 経由で受け渡し
- [PerRPCCredentials.GetRequestMetadata](https://pkg.go.dev/google.golang.org/grpc@v1.38.0/credentials#PerRPCCredentials): 認証情報をメタデータに変換

### ヘルスチェック

gRPC サーバーが正常に稼働しているかを確認する手段が必要な場合があります。
例えば Kubernetes のコンテナとして動作させる場合、readinessProbe や livenessProbe に応答させると自動的に負荷分散対象から外したり再起動させたりできます。

gRPC には[標準的なヘルスチェックのプロトコル][health]が定義されています。

```proto
syntax = "proto3";
 
package grpc.health.v1;
 
message HealthCheckRequest {
  string service = 1;
}
 
message HealthCheckResponse {
  enum ServingStatus {
    UNKNOWN = 0;
    SERVING = 1;
    NOT_SERVING = 2;
    SERVICE_UNKNOWN = 3;  // Used only by the Watch method.
  }
  ServingStatus status = 1;
}
 
service Health {
  rpc Check(HealthCheckRequest) returns (HealthCheckResponse);
 
  rpc Watch(HealthCheckRequest) returns (stream HealthCheckResponse);
}
```

`HealthCheckRequest` の `service` はオプションで、ここには `<package>.<service>` 形式の名前を指定できるとされています。

Go の場合、上記プロトコルの実装が [google.golang.org/grpc/health](https://pkg.go.dev/google.golang.org/grpc/health) パッケージとしてすでに提供されています。
この `Server` を登録して、`Resume` や `SetServingStatus` 等を呼び出せば良いわけです。

```go
import (
	"google.golang.org/grpc/health"
	healthgrpc "google.golang.org/grpc/health/grpc_health_v1"
)

func main() {
	s := grpc.NewServer()
	hs := health.NewServer()
	healthgrpc.RegisterHealthServer(s, hs)
	hs.Resume()
	...
}
```

Java では [`io.grpc.protobuf.services.HealthStatusManager`](https://grpc.github.io/grpc-java/javadoc/io/grpc/protobuf/services/HealthStatusManager.html) クラスで実装されています。

```java
hm = new HealthStatusManager();
serverBuilder.addService(hm.getHealthService());
hm.setStatus()
```

実際に Kubernetes の probe でこのヘルスチェックサービスを使う場合、[`grpc_health_probe`][grpc-health-probe] という実行ファイルをコンテナに同梱しておき、`exec` タイプの probe を設定します。

```yaml
spec:
  containers:
  - name: server
    image: quay.io/cybozu/foobar
    ports:
    - containerPort: 5000
    readinessProbe:
      exec:
        command: ["grpc_health_probe", "-addr=:5000"]
      initialDelaySeconds: 5
    livenessProbe:
      exec:
        command: ["grpc_health_probe", "-addr=:5000"]
      initialDelaySeconds: 10
```

### 冗長化と負荷分散

gRPC の Go 実装には、クライアントサイドで複数のサーバーに負荷分散する実装が含まれています。
しかしながら Kubernetes を利用する場合この機能は使わず、標準の Deployment と Service で冗長化・負荷分散するのが良いでしょう。

Service による負荷分散は TCP レベルの負荷分散で、複雑なことはできません。
クライアントに応じて別々の Service に振り分けるとか、リクエスト種別に応じて gRPC と REST 用 Service に振り分けるといった高度な処理をするには、gRPC の負荷分散に対応した L7 ロードバランサーを使う必要があります。

NGINX Ingress や Neco が採用している [Contour][] は gRPC の負荷分散に対応しているので、上記のような高度な負荷分散を実現できます。
この際注意しなければいけないのは、クライアントとロードバランサ間の通信が gRPC であることは無論、ロードバランサと Service (のバックエンド Pod)間の通信も gRPC で行わないといけない点です。

Contour の場合、HTTPProxy の [`routes.services.protocol`](https://projectcontour.io/docs/main/config/api/#projectcontour.io/v1.Service) で指定します。

```yaml
apiVersion: projectcontour.io/v1
kind: HTTPProxy
metadata:
  name: foo
  namespace: default
spec:
  virtualhost:
    fqdn: foo.example.com
  routes:
  - services:
    - name: app
      port: 80
      protocol: h2c   # TLS なしの平文 HTTP/2
    conditions:
      - prefix: /
```

このようにすれば、ロードバランサで TLS を terminate してくれるので gRPC サービスのデプロイが楽になります。

gRPC と REST を同一の URL で受け取り、それぞれに対応する Service に振り分けるには Content-Type ヘッダを使います。
gRPC のリクエストには `application/grpc` から始まる Content-Type が必ず付きます。

```
Content-Type → "content-type" "application/grpc" [("+proto" / "+json" / {custom})]
```

複数の gRPC サービスを同一の URL で受け取って Service に振り分けるには :path 疑似ヘッダの値を使います。
:path 疑似ヘッダの値は `/<package>.<service>/<RPC名>` となります。

e.g. `/deepthought.Compute/Boot`

## 発展的な話題

### 拡張エラー

gRPC の標準のエラーは[ステータスコード](https://grpc.github.io/grpc/core/md_doc_statuscodes.html)と文字列メッセージだけのシンプルな内容です。

これでは使いにくいということで、[Richer error model](https://grpc.io/docs/guides/error/#richer-error-model) という拡張が用意されています。
簡単にいえばステータスコード、文字列メッセージに加え、任意個の `google.protobuf.Any` がフィールドとして追加できます。

追加するエラーはまず Protocol Buffers の message として定義します。
例えば Coil v2 では CNI のエラーを埋め込むため、以下のような message を定義して拡張エラーで返しています。

```proto
message CNIError {
  ErrorCode code = 1;
  string msg = 2;
  string details = 3;
}
```

各言語でおおむね使えるようになっていて、例えば Go では以下のようにします。

```go
import "google.golang.org/grpc/status"

func makeError() error {
	st := status.New(codes.InvalidArgument, "message")
	st, err := st.WithDetails(&pb.CNIError{...})  // protocol buffers で定義したメッセージ
	if err != nil {
		panic(err)
	}
	return st.Err()
}
```

Java では以下の記事が参考になります。

- https://stackoverflow.com/a/67763163/1493661

### 大容量データ

多くの場合受け取りメッセージサイズは最大 4 MiB までに制限されています。
最大 4 GiB まで拡張可能ですが、メッセージがメモリに載ることを考えると拡張するよりもストリームで分割して送受信するほうが安全で効率的です。

gRPC ではサーバーサイドだけでなくクライアントサイドからもストリーム送信が可能であるため、少々のコーディングで送受信ともに大容量のデータを扱えると言えます。

### UNIX ドメインソケットでの通信

gRPC のトランスポート層は TCP に限りません。UNIX ドメインソケットも使えます。

UNIX ドメインソケットとは、ある一台の OS の中でプロセス間通信を可能にする仕組みです。
UNIX ドメインソケットはファイルシステム上の特殊なファイルとして作られます。

TCP と違って、通信相手のプロセスが落ちたら即エラーになるため keep-alive をしなくても大丈夫です。
また、外部のネットワークに通信内容が漏れないため TLS で保護する必要もありません。

Go でサーバーを書く場合は以下のようになります。

```go
	socketName := "/tmp/foo.sock"
	err = os.Remove(socketName)
	if err != nil && !os.IsNotExist(err) {
		return err
	}

	lis, err := net.Listen("unix", socketName)
	if err != nil {
		return err
	}

	serv := grpc.NewServer()
	serv.Serve(lis)
```

クライアントは以下のようになります。

```go
	dialer := &net.Dialer{}
	dialFunc := func(ctx context.Context, a string) (net.Conn, error) {
		return dialer.DialContext(ctx, "unix", a)
	}
	conn, err := grpc.Dial("/tmp/foo.sock", grpc.WithInsecure(), grpc.WithContextDialer(dialFunc))
	if err != nil {
		return err
	}
	defer conn.Close()
```

### ブラウザからの利用

gRPC は便利ですが、ブラウザ内の JavaScript から利用することはできません。
HTTP/2 のフレームを直接扱う手段がないためです。

この問題を解決するため、以下二つの方法があります。

- [gRPC Web](https://github.com/grpc/grpc-web): Envoy のような対応プロキシを介して gRPC を呼び出す仕組み
- [gRPC Gateway](https://grpc-ecosystem.github.io/grpc-gateway/): REST API にマッピングする仕組み

gRPC Web のほうが後発の仕組みで、クライアントストリーミング以外ほぼ gRPC そのままの使い勝手になります。
Neco が採用しているロードバランサー [Contour でも利用可能](https://github.com/projectcontour/contour/pull/319)です。

gRPC Web はクライアントを JavaScript コードとして生成するので、JavaScript 専用です。
gRPC Gateway は REST API にマッピングするので、任意の言語からアクセスできます。

### FAQ

研修中にいただいた質問について、[FAQ.md](FAQ.md) に回答をまとめています。
こちらも読んでいただくとさらに理解が深まります。

[grpc.io]: https://grpc.io/
[grpc.github.io]: https://grpc.github.io/grpc/core/pages.html
[http2]: https://grpc.github.io/grpc/core/md_doc__p_r_o_t_o_c_o_l-_h_t_t_p2.html
[health]: https://grpc.github.io/grpc/core/md_doc_health-checking.html
[course]: https://dev.to/techschoolguru/the-complete-grpc-course-protobuf-go-java-2af6
[developers.google.com/protocol-buffers]: https://developers.google.com/protocol-buffers/
[book]: https://www.amazon.co.jp/dp/B0845YMM37
[secure]: https://static.sched.com/hosted_files/kccncna19/f9/luis-pabon-securing-your-gRPC-service.pdf
[IDL]: https://en.wikipedia.org/wiki/Interface_description_language
[OpenAPI]: https://en.wikipedia.org/wiki/OpenAPI_Specification
[GraphQL]: https://graphql.org/
[graphql-stream]: https://graphql.org/blog/2020-12-08-improving-latency-with-defer-and-stream-directives
[graphql-binary]: https://github.com/graphql/graphql-spec/issues/432
[proto3]: https://developers.google.com/protocol-buffers/docs/reference/proto3-spec
[protoc-gen-doc]: https://github.com/pseudomuto/protoc-gen-doc
[TLS]: https://en.wikipedia.org/wiki/Transport_Layer_Security
[grpc-health-probe]: https://github.com/grpc-ecosystem/grpc-health-probe
[well-known]: https://developers.google.com/protocol-buffers/docs/reference/google.protobuf
[Contour]: https://projectcontour.io/
