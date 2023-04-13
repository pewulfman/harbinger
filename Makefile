.PHONY:

CC := ligo compile contract
INIT := ligo compile storage
TEZOS := octez-client --endpoint https://rpc.ghostnet.teztnets.xyz


build-oracle :
	$(CC) oracle.mligo > oracle.tz

build-normalizer :
	$(CC) normalizer.mligo > normalizer.tz

deploy-oracle :
	$(TEZOS) originate contract oracle transferring 0 from alice running oracle.tz --init $$($(INIT) oracle.mligo "Storage.init 'toto' {} ()") --burn-cap 0.1
