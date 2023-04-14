.PHONY:

CC := ligo compile contract
INIT := ligo compile storage
TEZOS := octez-client --endpoint https://rpc.ghostnet.teztnets.xyz


build-oracle :
	$(CC) oracle.mligo > oracle.tz

build-normalizer :
	$(CC) normalizer.mligo > normalizer.tz

deploy-oracle :
	$(TEZOS) originate contract oracle transferring 0 from alice running oracle.tz --init "$$($(INIT) oracle.mligo 'Storage.init ("edpkvWrdF1bWv2YSPpo1ZUCbweZ9coSx3ocRv4ABthwSA8reZSmKze" : key ) Big_map.empty ()')" --burn-cap 1


update-oracle-data :
	$(TEZOS) transfer 0 from alice to oracle --arg "$$(./gen_oracle_update_param.sh oracleData.csv)" --burn-cap 1
