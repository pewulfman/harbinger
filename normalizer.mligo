(*********************************************************************)
(* A Normalizer contract normalizes incoming data by computing a     *)
(* volume weighted average price (VWAP) across a set number of data  *)
(* points.                                                           *)
(*                                                                   *)
(* Normalizers are configured to for one asset whose data is provided*)
(* from one oracle.                                                  *)
(*                                                                   *)
(* Updates sent to the normalizer must be pushed with monotonically  *)
(* increasing start times.                                           *)
(*                                                                   *)
(* The normalized value is represented as a natural number with six  *)
(* digits of precision. For instance $123.45 USD would be represented*)
(* as 123_450_000.                                                   *)
(*********************************************************************)

#import "./oracle.mligo" "Harbinger"
#import "./queue.mligo" "Queue"

type queue = Queue.t

module Storage = struct
    type asset = {
        prices : nat queue;
        volumes : nat queue;
        lastUpdateTime : timestamp;
        computedPrice : nat;
    }
    type t = {
        assetCode: string list;
        assetMap : (string, asset) big_map;
        oracleContract : address;
        numDataPoints : int;
    }

    let init oracleContratAddress numDataPoints= {
        assetCode = [];
        assetRecord = (Big_map.empty : (string, asset) big_map);
        oracleContract = oracleContratAddress;
        numDataPoints = numDataPoints;
    }
    (* Compute a VWAP with the given inputs *)
    let computeVWAP (high : nat) (low : nat) (close : nat) (volume : nat) =
    ((high + low + close) / 3n) * volume

    let add (a : nat) (b : nat) : nat = a + b

    let make_asset_record numDataPoints ({prices; volumes; lastUpdateTime ; computedPrice}: asset) ({
        start ; end_ = _ ; open = _ ; high  ; low   ; close ; volume; } : Harbinger.oracleData) : asset =
        if start <= lastUpdateTime
        then (* Update must have a monotonically increasing start time *)
            {prices; volumes; lastUpdateTime; computedPrice}
        else
        let price = computeVWAP high low close volume in
        let (prices,volumes) =
            let prices = Queue.push price prices in
            let volumes = Queue.push volume volumes in
            if Queue.len prices >= numDataPoints
            then  (Queue.rm prices, Queue.rm volumes)
            else (prices, volumes)
        in
        {
            prices = Queue.push price prices;
            volumes = Queue.push volume volumes;
            lastUpdateTime = start;
            computedPrice = (Queue.reduce 0n add prices) / (Queue.reduce 0n add volumes);
        }
end

(* Entry points *)
type update = (string, Harbinger.oracleData) map

let update (update_map : update) (s : Storage.t) : operation list * Storage.t =
    (* Ensure that caller is the oracle *)
    let () = assert_with_error (Tezos.get_sender () = s.oracleContract) "Sender is not the oracle contract" in
    (* Process update for one currency *)
    let process_one ((assetMap,assetCode),(key,update) : ((string,Storage.asset) big_map * string list) * (string * Harbinger.oracleData)) =
        let asset = Big_map.find_opt key assetMap in
        let asset_record, assetCode = match asset with
        (* If the asset is not in the map, create a new asset record *)
        | None -> (Storage.make_asset_record s.numDataPoints {prices = Queue.empty; volumes = Queue.empty; lastUpdateTime = (0 : timestamp); computedPrice = 0n} update, key :: assetCode)
        (* If the asset is in the map, update the asset record *)
        | Some asset -> (Storage.make_asset_record s.numDataPoints asset update, assetCode)
        in Big_map.add key asset_record assetMap, assetCode
    in
    let new_map, new_code = Map.fold process_one update_map (s.assetMap,s.assetCode) in
    [], {s with assetMap = new_map; assetCode = new_code}

type get = {
    assetCode : string;
    callback : (string * timestamp * nat) contract;
}
let get ({assetCode;callback} : get) (s : Storage.t) : operation list * Storage.t =
    let asset = Big_map.find_opt assetCode s.assetMap in
    match asset with
    | None -> failwith "Asset not found"
    | Some {prices=_; volumes=_; lastUpdateTime; computedPrice; } ->
    let op = Tezos.transaction (assetCode,lastUpdateTime, computedPrice) 0tez callback in
    [op], s

type parameter =
    | Update of update
    | Get of get

let main (param, s) : operation list * Storage.t =
    match param with
    | Update update_map -> update update_map s
    | Get p -> get p s

(* Parameter *)

(* Views *)
[@view]
let getPrice (assetCode : string) (s : Storage.t) : (timestamp * nat) =
    let asset = Big_map.find_opt assetCode s.assetMap in
    match asset with
    | None -> failwith "Asset not found"
    | Some {prices=_; volumes=_; lastUpdateTime; computedPrice; } -> (lastUpdateTime, computedPrice)
