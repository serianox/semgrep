(* Yoann Padioleau
 *
 * Copyright (C) 2019-2021 r2c
 *
 * This program is free software; you can redistribute it and/or
 * modify it under the terms of the GNU General Public License (GPL)
 * version 2 as published by the Free Software Foundation.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * file license.txt for more details.
*)
open Common

module R = Rule

module E = Parse_mini_rule
module H = Parse_mini_rule

(*****************************************************************************)
(* Helpers *)
(*****************************************************************************)

(* less: could use a hash to accelerate things *)
let rec find_fields_and_sort flds xs =
  match flds with
  | [] -> [], xs
  | fld::flds ->
      let fld_match = List.assoc_opt fld xs in
      let xs = List.remove_assoc fld xs in
      let (matches, rest) = find_fields_and_sort flds xs in
      (fld, fld_match)::matches, rest

(*****************************************************************************)
(* Formula *)
(*****************************************************************************)
let rec parse_formula env (x: string * Yaml.value) =
  match x with
  | "pattern", `String pattern_string ->
      let (id, lang) = env in
      let pattern = H.parse_pattern ~id ~lang pattern_string in
      R.Pat pattern
  | "pattern-not", `String pattern_string ->
      let (id, lang) = env in
      let pattern = H.parse_pattern ~id ~lang pattern_string in
      R.PatNot pattern

  | "pattern-inside", `String pattern_string ->
      let (id, lang) = env in
      let pattern = H.parse_pattern ~id ~lang pattern_string in
      R.PatInside pattern
  | "pattern-not-inside", `String pattern_string ->
      let (id, lang) = env in
      let pattern = H.parse_pattern ~id ~lang pattern_string in
      R.PatNotInside pattern

  | "pattern-either", `A xs ->
      R.PatEither (List.map (fun x ->
        match x with
        | `O [x] -> parse_formula env x
        | x ->
            pr2_gen x;
            raise (E.InvalidYamlException "wrong rule fields")
      ) xs)
  | "patterns", `A xs ->
      R.Patterns (List.map (fun x ->
        match x with
        | `O [x] -> parse_formula env x
        | x ->
            pr2_gen x;
            raise (E.InvalidYamlException "wrong rule fields")
      ) xs)
  | x ->
      pr2_gen x;
      raise (E.InvalidYamlException "wrong rule fields")


(*****************************************************************************)
(* Main entry point *)
(*****************************************************************************)

let parse file =
  let str = Common.read_file file in
  let yaml_res = Yaml.of_string str in
  match yaml_res with
  | Result.Ok v ->
      (match v with
       | `O ["rules", `A xs] ->
           xs |> List.map (fun v ->
             match v with
             | `O xs ->
                 let flds = ["id";
                             "languages";
                             "message";
                             "severity";
                             "metadata"]
                 in
                 (match find_fields_and_sort flds xs with
                  | [
                    "id", Some (`String id);
                    "languages", Some (`A langs);
                    "message", Some (`String message);
                    "severity", Some (`String sev);
                    "metadata", _metadata_opt;
                  ], rest ->
                      let languages, lang = H.parse_languages ~id langs in
                      let severity = H.parse_severity ~id sev in
                      let formula =
                        match rest with
                        | [x] ->
                            parse_formula (id, lang) x
                        | x ->
                            pr2_gen x;
                            raise (E.InvalidYamlException "wrong rule fields")
                      in
                      let metadata = [] in
                      { R. id; formula; message; languages; severity; metadata}
                  | x ->
                      pr2_gen x;
                      raise (E.InvalidYamlException "wrong rule fields")
                 )
             | x ->
                 pr2_gen x;
                 raise (E.InvalidYamlException "wrong rule fields")
           )
       | _ -> raise (E.InvalidYamlException "missing rules entry as top-level key")
      )
  | Result.Error (`Msg s) ->
      raise (E.UnparsableYamlException s)