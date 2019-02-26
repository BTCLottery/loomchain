PKG = github.com/loomnetwork/loomchain

PROTOC = protoc --plugin=./protoc-gen-gogo -Ivendor -I$(GOPATH)/src -I/usr/local/include

PLUGIN_DIR = $(GOPATH)/src/github.com/loomnetwork/go-loom
GOLANG_PROTOBUF_DIR = $(GOPATH)/src/github.com/golang/protobuf
GOGO_PROTOBUF_DIR = $(GOPATH)/src/github.com/gogo/protobuf
GO_ETHEREUM_DIR = $(GOPATH)/src/github.com/ethereum/go-ethereum
SSHA3_DIR = $(GOPATH)/src/github.com/miguelmota/go-solidity-sha3
HASHICORP_DIR = $(GOPATH)/src/github.com/hashicorp/go-plugin
LEVIGO_DIR = $(GOPATH)/src/github.com/jmhodges/levigo

# NOTE: To build on Jenkins using a custom go-loom branch update the `deps` target below to checkout
#       that branch, you only need to update GO_LOOM_GIT_REV if you wish to lock the build to a
#       specific commit.
GO_LOOM_GIT_REV = HEAD
# Make trie.Database.Commit() write out preimages in deterministic order 
ETHEREUM_GIT_REV = f9c06695672d0be294447272e822db164739da67
# use go-plugin we get 'timeout waiting for connection info' error
HASHICORP_GIT_REV = f4c3476bd38585f9ec669d10ed1686abd52b9961
LEVIGO_GIT_REV = c42d9e0ca023e2198120196f842701bb4c55d7b9
SSHA3_GIT_REV = d2f351954c0ff0a64030123a2b3a7c6b890238af

GIT_SHA = `git rev-parse --verify HEAD`
GO_LOOM_GIT_SHA = `cd ${PLUGIN_DIR} && git rev-parse --verify ${GO_LOOM_GIT_REV}`
ETHEREUM_GIT_SHA = `cd ${GO_ETHEREUM_DIR} && git rev-parse --verify ${ETHEREUM_GIT_REV}`
HASHICORP_GIT_SHA = `cd ${HASHICORP_DIR} && git rev-parse --verify ${HASHICORP_GIT_REV}`

GOFLAGS_BASE = -X $(PKG).Build=$(BUILD_NUMBER) -X $(PKG).GitSHA=$(GIT_SHA) -X $(PKG).GoLoomGitSHA=$(GO_LOOM_GIT_SHA) -X $(PKG).EthGitSHA=$(ETHEREUM_GIT_SHA) -X $(PKG).HashicorpGitSHA=$(HASHICORP_GIT_SHA)
GOFLAGS = -tags "evm" -ldflags "$(GOFLAGS_BASE)"
GOFLAGS_GAMECHAIN = -tags "evm gamechain" -ldflags "$(GOFLAGS_BASE)"
GOFLAGS_PLASMACHAIN = -tags "evm plasmachain" -ldflags "$(GOFLAGS_BASE) -X $(PKG).BuildVariant=plasmachain"
GOFLAGS_PLASMACHAIN_CLEVELDB = -tags "evm plasmachain gcc" -ldflags "$(GOFLAGS_BASE) -X $(PKG).BuildVariant=plasmachain"
GOFLAGS_CLEVELDB = -tags "evm gcc" -ldflags "$(GOFLAGS_BASE)"
GOFLAGS_GAMECHAIN_CLEVELDB = -tags "evm gamechain gcc" -ldflags "$(GOFLAGS_BASE)"
GOFLAGS_NOEVM = -ldflags "$(GOFLAGS_BASE)"

WINDOWS_BUILD_VARS = CC=x86_64-w64-mingw32-gcc CGO_ENABLED=1 GOOS=windows GOARCH=amd64 BIN_EXTENSION=.exe

.PHONY: all clean test install deps proto builtin oracles tgoracle loomcoin_tgoracle pcoracle dposv2_oracle plasmachain-cleveldb loom-cleveldb

all: loom builtin

oracles: tgoracle pcoracle

builtin: contracts/coin.so.1.0.0 contracts/dpos.so.1.0.0 contracts/dpos.so.2.0.0 contracts/dpos.so.3.0.0 contracts/plasmacash.so.1.0.0

contracts/coin.so.1.0.0:
	go build -buildmode=plugin -o $@ $(PKG)/builtin/plugins/coin/plugin

contracts/dpos.so.1.0.0:
	go build -buildmode=plugin -o $@ $(PKG)/builtin/plugins/dpos/plugin

contracts/dpos.so.2.0.0:
	go build -buildmode=plugin -o $@ $(PKG)/builtin/plugins/dposv2/plugin

contracts/dpos.so.3.0.0:
	go build -buildmode=plugin -o $@ $(PKG)/builtin/plugins/dposv3/plugin

contracts/plasmacash.so.1.0.0:
	go build -buildmode=plugin -o $@ $(PKG)/builtin/plugins/plasma_cash/plugin

tgoracle:
	go build $(GOFLAGS) -o $@ $(PKG)/cmd/$@

loomcoin_tgoracle:
	go build $(GOFLAGS) -o $@ $(PKG)/cmd/$@

pcoracle:
	go build $(GOFLAGS) -o $@ $(PKG)/cmd/$@

dposv2_oracle:
	go build $(GOFLAGS) -o $@ $(PKG)/cmd/$@

loom: proto
	go build $(GOFLAGS) $(PKG)/cmd/$@

loom-windows:
	$(WINDOWS_BUILD_VARS) make loom

gamechain: proto
	go build $(GOFLAGS_GAMECHAIN) -o gamechain$(BIN_EXTENSION) $(PKG)/cmd/loom

gamechain-cleveldb: proto  c-leveldb
	go build $(GOFLAGS_GAMECHAIN_CLEVELDB) -o gamechain$(BIN_EXTENSION) $(PKG)/cmd/loom

gamechain-windows: proto
	$(WINDOWS_BUILD_VARS) make gamechain

loom-cleveldb: proto c-leveldb
	go build $(GOFLAGS_CLEVELDB) -o $@ $(PKG)/cmd/loom

plasmachain: proto
	go build $(GOFLAGS_PLASMACHAIN) -o $@ $(PKG)/cmd/loom

plasmachain-cleveldb: proto c-leveldb
	go build $(GOFLAGS_PLASMACHAIN_CLEVELDB) -o $@ $(PKG)/cmd/loom

plasmachain-windows:
	$(WINDOWS_BUILD_VARS) make plasmachain

loom-race: proto
	go build -race $(GOFLAGS) -o loom-race $(PKG)/cmd/loom

install: proto
	go install $(GOFLAGS) $(PKG)/cmd/loom

protoc-gen-gogo:
	go build github.com/gogo/protobuf/protoc-gen-gogo

%.pb.go: %.proto protoc-gen-gogo
	if [ -e "protoc-gen-gogo.exe" ]; then mv protoc-gen-gogo.exe protoc-gen-gogo; fi
	$(PROTOC) --gogo_out=$(GOPATH)/src $(PKG)/$<

proto: registry/registry.pb.go

c-leveldb:
	go get github.com/jmhodges/levigo
	cd $(LEVIGO_DIR) && git checkout master && git pull && git checkout $(LEVIGO_GIT_REV)

$(PLUGIN_DIR):
	git clone -q git@github.com:loomnetwork/go-loom.git $@

$(GO_ETHEREUM_DIR):
	git clone -q git@github.com:loomnetwork/go-ethereum.git $@

$(SSHA3_DIR):
	git clone -q git@github.com:loomnetwork/go-solidity-sha3.git $@
	cd $(SSHA3_DIR) && git checkout master && git pull && git checkout $(SSHA3_GIT_REV)

validators-tool:
	go build -o e2e/validators-tool $(PKG)/e2e/cmd

deps: $(PLUGIN_DIR) $(GO_ETHEREUM_DIR) $(SSHA3_DIR)
	go get \
		golang.org/x/crypto/ed25519 \
		google.golang.org/grpc \
		github.com/gogo/protobuf/gogoproto \
		github.com/gogo/protobuf/proto \
		github.com/hashicorp/go-plugin \
		github.com/spf13/cobra \
		github.com/spf13/pflag \
		github.com/go-kit/kit/log \
		github.com/grpc-ecosystem/go-grpc-prometheus \
		github.com/prometheus/client_golang/prometheus \
		github.com/go-kit/kit/log \
		github.com/BurntSushi/toml \
		github.com/ulule/limiter \
		github.com/loomnetwork/mamamerkle \
		golang.org/x/sys/cpu \
		github.com/loomnetwork/yubihsm-go \
		github.com/gorilla/websocket \
		github.com/phonkee/go-pubsub \
		github.com/inconshreveable/mousetrap
	# for when you want to reference a different branch of go-loom
	# cd $(PLUGIN_DIR) && git checkout time && git pull origin time
	cd $(GOLANG_PROTOBUF_DIR) && git checkout v1.1.0
	cd $(GOGO_PROTOBUF_DIR) && git checkout v1.1.1
	cd $(GO_ETHEREUM_DIR) && git checkout master && git pull && git checkout $(ETHEREUM_GIT_REV)
	cd $(HASHICORP_DIR) && git checkout $(HASHICORP_GIT_REV)
	# fetch vendored packages
	dep ensure -vendor-only

#TODO we should turn back vet on, it broke when we upgraded go versions
test: proto
	go test  -failfast -timeout 20m -v -vet=off $(GOFLAGS) $(PKG)/...

test-race: proto
	go test -race -failfast -timeout 20m -v -vet=off $(GOFLAGS) $(PKG)/...

test-no-evm: proto
	go test -failfast -timeout 20m -v -vet=off $(GOFLAGS_NOEVM) $(PKG)/...

# Only builds the tests with the EVM disabled, but doesn't actually run them.
no-evm-tests: proto
	go test -failfast -v -vet=off $(GOFLAGS_NOEVM) -run nothing $(PKG)/...

test-e2e:
	go test -failfast -timeout 20m -v -vet=off $(PKG)/e2e

test-e2e-race:
	go test -race -failfast -timeout 20m -v -vet=off $(PKG)/e2e

test-app-store-race:
	go test -race -timeout 2m -failfast -v $(GOFLAGS) $(PKG)/store -run TestMultiReaderIAVLStore
	#go test -race -timeout 2m -failfast -v $(GOFLAGS) $(PKG)/store -run TestIAVLStoreTestSuite

vet:
	go vet ./...

vet-evm:
	go vet -tags evm ./...

clean:
	go clean
	rm -f \
		loom \
		protoc-gen-gogo \
		contracts/coin.so.1.0.0 \
		contracts/dpos.so.1.0.0 \
		contracts/dpos.so.2.0.0 \
		contracts/dpos.so.3.0.0 \
		contracts/plasmacash.so.1.0.0 \
		pcoracle
