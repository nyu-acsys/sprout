(** Error messages and exceptions *)

type error_kind =
  | Generic
  | Lexical
  | Syntax
  | Internal

let error_kind_to_lsp_string = function
  | Generic -> "Generic"
  | Lexical -> "Lexical"
  | Syntax -> "Syntax"
  | Internal -> "Internal"

let error_kind_to_string = function
  | Generic -> "Error"
  | Lexical -> "Lexical Error"
  | Syntax -> "Syntax Error"
  | Internal -> "Internal Error"

type t = error_kind * Loc.t * string

exception Msg of t list
exception Generic_Error of string

let fail ?(lbl = Generic) loc msg = raise (Msg [ (lbl, loc, msg) ])
let fail_with errors = raise (Msg errors)

let to_string (kind, (loc : Loc.t), msg) =
  let label =
    kind |> error_kind_to_string 
  in
  if Loc.(loc = Loc.dummy) then Printf.sprintf !"[%s] %s" label msg
  else
    (*if !Config.flycheck_mode
          then Printf.sprintf "%s:%s" (flycheck_string_of_src_pos pos) msg*)
    Printf.sprintf !"%{Loc}: [%s] %s." loc label msg

let to_lsp_string ppf (kind, (loc : Loc.t), msg) =
  let r = Str.regexp "\n" in
  let split_msg = Str.split r msg in
  let pr_string ppf s = Stdlib.Format.fprintf ppf "%s" s in
  Stdlib.Format.fprintf ppf !"@\n{ \"file\": \"%s\", \"start_line\": %d, \"start_col\": %d, \"end_line\": %d, \"end_col\": %d, \"kind\": \"%s\", \"message\": [\"%a\"] }"
    (Loc.file_name loc) (Loc.start_line loc) (Loc.start_col loc) (Loc.end_line loc) (Loc.end_col loc) (error_kind_to_lsp_string kind) (Print.pr_list_sep "\", \"" pr_string) split_msg

let errors_to_lsp_string errs =
  let print_list ppf errs = Stdlib.Format.fprintf ppf "[@[<2>%a@]]" (Print.pr_list_comma to_lsp_string) errs in
  Print.string_of_format print_list errs

(** Predefined error messags *)

let error loc msg = fail loc ~lbl:Generic msg
let error_simple msg = fail Loc.dummy msg
let lexical_error loc msg = fail loc ~lbl:Lexical msg
let syntax_error loc msg = fail loc ~lbl:Syntax msg

