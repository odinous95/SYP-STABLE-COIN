-include .env

.PHONY: all test test-zk clean deploy fund help install snapshot format anvil install deploy deploy-zk deploy-zk-sepolia deploy-sepolia verify

DEFAULT_ANVIL_KEY := 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
DEFAULT_ZKSYNC_LOCAL_KEY := 0x7726827caac94a7f9e1b160f7ea819f172f7b6f9d2a97f992c38edeab82d4110

all: clean remove install update build

test-zk :; foundryup-zksync && forge test --zksync && foundryup

anvil :; anvil -m 'test test test test test test test test test test test junk' --steps-tracing --block-time 1

deploy:
	@forge script script/DeployLira.s.sol:DeployLira --rpc-url http://localhost:8545 --private-key $(DEFAULT_ANVIL_KEY) --broadcast

deploy-sepolia:
	@forge script script/DeployLira.s.sol:DeployLira --rpc-url $(SEPOLIA_RPC_URL) --account $(ACCOUNT) --sender $(SENDER) --etherscan-api-key $(ETHERSCAN_API_KEY) --broadcast --verify

deploy-zk:
	@forge script script/DeployLira.s.sol --rpc-url http://127.0.0.1:8011 --private-key $(DEFAULT_ZKSYNC_LOCAL_KEY) --legacy --zksync

deploy-zk-sepolia:
	@forge script script/DeployLira.s.sol --rpc-url $(ZKSYNC_SEPOLIA_RPC_URL) --account $(ACCOUNT) --legacy --zksync

deploy-zk-bad:
	@forge script script/DeployLira.s.sol --rpc-url https://sepolia.era.zksync.dev --private-key $(PRIVATE_KEY) --legacy --zksync

verify:
	@forge verify-contract --chain-id 11155111 --num-of-optimizations 200 --watch --constructor-args 0x00000000000000000000000000000000000000000000d3c21bcecceda1000000 --etherscan-api-key $(ETHERSCAN_API_KEY) --compiler-version v0.8.19+commit.7dd6d404 0x089dc24123e0a27d44282a1ccc2fd815989e3300 src/OurToken.sol:OurToken