(*********************************************************************)
(** This file is a standard implementation of a queue using 2 stack **)
(** - push on the first stack                                       **)
(** - pop from the second stack                                     **)
(**   if empty flip the first into the second                       **)
(*********************************************************************)

type 'a t =
	{ s1 : 'a list;
	  s2 : 'a list;
	  sum : int }


let empty (type a) : a t = { s1 = []; s2 = []; sum = 0 }

let len (type a) (q : a t) = q.sum

let push (type a) el (q : a t) = { q with s1 = el :: q.s1 }

let rec rev (type a) (acc : a list) (l : a list) : a list = match l with
	| [] -> acc
	| hd :: tl -> rev (hd :: acc) tl

let rev l = rev [] l

let rm (type a) ({s1; s2; sum}: a t) : a t = match s2 with
	| _ :: tl -> {s1; s2 = tl; sum = sum - 1}
	| [] ->
		let s2 = rev s1 in
		(match s2 with
		| _ :: tl -> {s1 = []; s2 = tl; sum = sum - 1}
		| [] -> empty)

let pop (type a) ({s1; s2; sum}: a t) = match s2 with
	| hd :: tl -> Some hd, {s1; s2 = tl; sum = sum - 1n}
	| [] ->
		let s2 = rev s1 in
		(match s2 with
		| hd :: tl -> Some hd, {s1 = []; s2 = tl; sum = sum - 1}
		| [] -> None, (empty : a t))



let head {s1; s2; sum = _} = match s2 with
	| hd :: _ -> Some hd
	| [] ->
		let s2 = rev s1 in
		(match s2 with
		| hd :: _ -> Some hd
		| [] -> None)

let reduce (type a) (zero : a) (f : a -> a -> a) (q : a t) =
	let hd, tl = pop q in
	match hd with
	| None -> zero
	| Some hd ->
		(let rec aux (type a) (acc : a) (q : a t) : a = match pop q with
			| Some hd, tl -> aux (f hd acc) tl
			| None, _ -> acc
		in aux hd tl
		)
