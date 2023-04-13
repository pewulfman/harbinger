(*************************************************************************************************)
(* An Oracle contract accepts signed updates for a list of assets.                               *)
(*                                                                                               *)
(* Oracles are configured with a list of assets whose updates they                               *)
(* track and a public key which will verify signatures on the asset                              *)
(* data.                                                                                         *)
(*                                                                                               *)
(* Anyone may update the Oracle with properly signed data. Signatures                            *)
(* for the oracle are provided by signing the packed bytes of the                                *)
(* following Michelson data:                                                                     *)
(* 'pair <asset code | string> (pair <start | timestamp> (pair <end | timestamp> (pair <nat | op *)
(*                                                                                               *)
(* Anyone can request the Oracle push its data to another contract. Pushed                       *)
(* data should generally be pushed to a Normalizer contract rather than                          *)
(* consumed directly.                                                                            *)
(*                                                                                               *)
(* Oracles can be revoked by calling the revoke entry point with the                             *)
(* signature for bytes representing an Option(Key) Michelson type with                           *)
(* value none. After revocation, the Oracle will refuse to process                               *)
(* further updates.                                                                              *)
(*                                                                                               *)
(* Updates to the Oracle must be monotonically increasing in start time.                         *)
(*                                                                                               *)
(* Values in the Oracle are represented as a natural numbers with six                            *)
(* digits of precision. For instance $123.45 USD would be represented                            *)
(* as 123_450_000.                                                                               *)
(*************************************************************************************************)

type oracleData = {
	start : timestamp;
	[@annot : end] end_  : timestamp;
	open  : nat;
	high  : nat;
	low   : nat;
	close : nat;
	volume: nat;
}
module Storage = struct
	type t = {
		publicKey : key option;
		oracleData : (string, oracleData) big_map;
	}

	let init key initialData () = {
		publicKey = Some key;
		oracleData = initialData;
	}
end

type update = (string, (signature * oracleData)) map

let update (s : Storage.t) (update_map : update) : operation list * Storage.t =
	let public_key = Option.unopt_with_error s.publicKey "Oracle is revoked" in
	let process_one (oracleData, (key, (sig,update))) =
		let () = if Crypto.check public_key sig (Bytes.pack (key, update)) then ()
		else failwith "bad sig" in
		match Big_map.find_opt key oracleData with
		| None -> Big_map.add key update oracleData
		| Some (old_data : oracleData) ->
			if old_data.start >= update.start then
				oracleData
			else
				Big_map.add key update oracleData
	in
	let oracleData = Map.fold process_one update_map s.oracleData in
	[], { s with oracleData = oracleData }

let revoke (s : Storage.t) (param) : operation list * Storage.t =
	let bytes = Bytes.pack (None : key option) in
		match s.publicKey with None -> [], s
		| Some public_key ->
			if Crypto.check public_key param bytes then
				[], { s with publicKey = None; oracleData = Big_map.empty }
			else failwith "bad sig"

let push (s : Storage.t) (contract : (string, oracleData) big_map contract) : operation list * Storage.t =
	let op = Tezos.transaction s.oracleData 0mutez contract in
	[op], s

type parameter = Update of update | Revoke of signature | Push of (string, oracleData) big_map contract

let main (p,s : parameter * Storage.t) =
	match p with
	| Update p -> update s p
	| Revoke p  -> revoke s p
	| Push   p -> push s p


[@view]
let getPrice (assetCode : string) (s : Storage.t) =
	Option.unopt_with_error (Big_map.find_opt assetCode s.oracleData) "Asset not found"
