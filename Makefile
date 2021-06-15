# Tool versoins
PROTOC_VERSION = 3.17.3
PROTOC_GEN_DOC_VERSION = 1.4.1
PROTOC_GEN_GO_VERSION = 1.26.0
PROTOC_GEN_GO_GRPC_VERSION = 1.1.0

MODULE := $(shell awk '/^module / {print $$2}' go.mod)
PWD := $(shell pwd)
PROTOC = $(PWD)/bin/protoc
PROTOC_GEN_DOC = $(PWD)/bin/protoc-gen-doc
PROTOC_GEN_GO = $(PWD)/bin/protoc-gen-go
PROTOC_GEN_GO_GRPC = $(PWD)/bin/protoc-gen-go-grpc
RUN_PROTOC = PATH=$(PWD)/bin:$$PATH $(PROTOC) -I$(PWD)/include -I.

# generate markdown specification
deepthought.md: deepthought.proto $(PROTOC) $(PROTOC_GEN_DOC)
	$(RUN_PROTOC) --doc_out=. --doc_opt=markdown,$@ $<

go/deepthought/deepthought.pb.go: deepthought.proto $(PROTOC) $(PROTOC_GEN_GO)
	$(RUN_PROTOC) --go_out=module=$(MODULE):. $<

go/deepthought/deepthought_grpc.pb.go: deepthought.proto $(PROTOC) $(PROTOC_GEN_GO_GRPC)
	$(RUN_PROTOC) --go-grpc_out=module=$(MODULE):. $<

server: go/deepthought/deepthought_grpc.pb.go go/deepthought/deepthought.pb.go $(wildcard go/server/*.go)
	go build -o $@ ./go/server

client: go/deepthought/deepthought_grpc.pb.go go/deepthought/deepthought.pb.go $(wildcard go/client/*.go)
	go build -o $@ ./go/client

.PHONY: clean
clean:
	rm -f deepthought.md server client

.PHONY: fullclean
fullclean: clean
	rm -rf bin include go/deepthought

$(PROTOC):
	curl -fsL -o /tmp/protoc.zip https://github.com/protocolbuffers/protobuf/releases/download/v$(PROTOC_VERSION)/protoc-$(PROTOC_VERSION)-linux-x86_64.zip
	unzip /tmp/protoc.zip 'bin/*' 'include/*'
	rm -f /tmp/protoc.zip

$(PROTOC_GEN_DOC):
	mkdir -p bin
	curl -fsL https://github.com/pseudomuto/protoc-gen-doc/releases/download/v$(PROTOC_GEN_DOC_VERSION)/protoc-gen-doc-$(PROTOC_GEN_DOC_VERSION).linux-amd64.go1.15.2.tar.gz | \
	tar -C bin -x -z -f - --strip-components=1

$(PROTOC_GEN_GO):
	mkdir -p bin
	GOBIN=$(PWD)/bin go install google.golang.org/protobuf/cmd/protoc-gen-go@v$(PROTOC_GEN_GO_VERSION)

$(PROTOC_GEN_GO_GRPC):
	mkdir -p bin
	GOBIN=$(PWD)/bin go install google.golang.org/grpc/cmd/protoc-gen-go-grpc@v$(PROTOC_GEN_GO_GRPC_VERSION)
