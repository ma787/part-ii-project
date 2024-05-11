open Lwt.Infix
open Logs_syslog_lwt

let install_logger () =
  unix_reporter () >|= function
    | Ok r -> Logs.set_reporter r
    | Error e -> print_endline e

let _ = Lwt_main.run (install_logger ())
let log_src = Lwt_main.run (Lwt.return (Logs.Src.create "sysloggingtest" ~doc:"my syslog testing code"))
module Log = (val Logs.src_log log_src : Logs.LOG)

let _ = Lwt_main.run (Printf.printf "testing log"; Log.app (fun m -> m "testing log"); Lwt.return_unit)