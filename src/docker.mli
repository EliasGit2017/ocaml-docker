(** Interface to Docker Remote API <https://www.docker.com>. *)


val set_default_addr : Unix.sockaddr -> unit
(** Set the address the Docker daemon listens to.  This will be used
    by all funtions of this API unless the optioal parameter [~addr]
    is used. *)

exception Invalid_argument of string
(** [Invalid_argument msg] can be raised by any function
    when an argument is incorrect.  [msg] is the function raising
    the exception possibly followed by an explanation. *)

exception Server_error of string * string
(** [Server_error(fn_name, msg)] indicates that the server encountered
    an error or that the returned response is incorrect.  [fn_name] is
    the function raising the error and [msg] is a possible explanation
    for the error. *)

(** A stream returned by some Docker functions. *)
module Stream : sig
  type t

  type kind = Stdin | Stdout | Stderr

  exception Timeout

  val out : t -> out_channel
  (** [out stream] may be used to send data to the process running in
      the container.  Closing this channel is equivalent to calling
      {!close}. *)

  val shutdown : t -> unit
  (** [shutdown stream] transmit an end-of-file condition to the
      server reading on the other side of the connection meaning that
      you have finished sending data.  You can still read data from
      the string.  You must still close the string with {!close}. *)

  val read : ?timeout: float -> t -> kind * Bytes.t
  (** [read stream] reads the next payload from the stream.  The byte
    sequence will be empty if there is nothing to read at the time of
    the call (in particular, if everything has been read).

    @raise Timeout if the payload could not be read within the allowed
    timeout.  A negative timeout (the default) means unbounded wait. *)

  val close : t -> unit
  (** Close the stream. *)
end

module Container : sig
  type port = {
      priv: int;   (** Private port number. *)
      pub: int;    (** Public port number. *)
      typ: string; (** Type, e.g., "tcp". *)
    }

  type id = string

  type t = {
      id: id;    (** Identifier of the container. *)
      names: string list; (** Names given to the container. *)
      image: string; (** Name of the image used to create the container. *)
      command: string; (** Command passed to the container. *)
      created: float;  (** Unix time of creation. *)
      status: string;  (** Human readable status. *)
      ports: port list;
      size_rw: int;
      size_root_fs: int;
    }

  val list : ?addr: Unix.sockaddr ->
             ?all: bool -> ?limit: int -> ?since: id -> ?before: id ->
             ?size: bool ->
             unit -> t list
  (** [list ()] lists running containers (or all containers if [~all]
      is set to [true]).

      @param all Show all containers. Only running containers are
                 shown by default (i.e., this defaults to [false]).
   *)

  val create :
    ?addr: Unix.sockaddr ->
    ?hostname: string -> ?domainname: string -> ?user: string ->
    ?memory: int -> ?memory_swap: int ->
    ?attach_stdin: bool -> ?attach_stdout: bool -> ?attach_stderr: bool ->
    ?open_stdin: bool -> ?stdin_once: bool ->
    ?env: string list -> ?workingdir: string -> ?networking: bool ->
    ?binds: (string * string * [`RO|`RW]) list ->
    string -> string list -> id
  (** [create image cmd] create a container and returns its ID where
    [image] is the image name to use for the container and [cmd] the
    command to run.  [cmd] has the form [[prog; arg1;...; argN]].
    BEWARE that the output of [cmd] (on stdout and stderr) will be
    logged by the container (see {!logs}) so it will consume disk space.

    @param hostname the desired hostname to use for the container.
    @param domainname  the desired domain name to use for the container.
    @param user the user (or UID) to use inside the container.
    @param memory Memory limit in bytes.
    @param memory_swap Total memory usage (memory + swap);
                       set -1 to disable swap.
    @param attach_stdin Attaches to stdin (default [false]).
    @param attach_stdout Attaches to stdout (default [true]).
    @param attach_stdout Attaches to stderr (default [true]).
    @param open_stdin opens stdin (sic).
    @param stdin_once close stdin after the 1 attached client disconnects.
    @param env A list of environment variables n the form of ["VAR=value"].
    @param workingdir The working dir for commands to run in.
    @param networking Whether networking is enabled for the container.
                      Default: [false].
    @param binds A list of volume bindings for this container. Each volume
                 binding has the form [(host_path, container_path, access)].
   *)

  (* val inspect : ?addr: Unix.sockaddr -> id -> t *)

  (* val top : conn -> id -> *)

  (* val logs : conn -> id -> *)

  (* val changes : conn -> id -> *)
  (** [changes conn id] Inspect changes on container [id]'s filesystem. *)

  (* val export : ?addr: Unix.sockaddr -> id -> stream *)
  (** [export conn id] export the contents of container [id]. *)

  val start : ?addr: Unix.sockaddr ->
              ?binds: (string * string * [`RO|`RW]) list ->
              id -> unit
  (** [start id] starts the container [id].
    @raise Server_error when, for example, if the command given by
    {!create} does not exist in the container.

    @param binds directories shared between the host and the
    container.  Each has the form [(host_dir, container_dir, access)]. *)

  val stop : ?addr: Unix.sockaddr -> ?wait: int -> id -> unit
  (** [stop id] stops the container [id].
      @param wait number of seconds to wait before killing the container. *)

  (* val restart : ?addr: Unix.sockaddr -> ?time: float -> id -> unit *)

  (* val kill : ?addr: Unix.sockaddr -> ?signal: int -> id -> unit *)

  val attach : ?addr: Unix.sockaddr ->
               ?logs: bool -> ?stream: bool ->
               ?stdin: bool -> ?stdout: bool -> ?stderr: bool ->
               id -> Stream.t
  (** [attach id] view or interact with any running container [id]
    primary process (pid 1).

    @param logs Return logs.  Default [false].
    @param stream Return stream.  Default [false].
    @param stdin If [stream=true], attach to stdin.  Default [false].
    @param stdout If [logs=true], return stdout log,
                  if [stream=true], attach to stdout.  Default [false].
    @param stderr If [logs=true], return stderr log,
                  if [stream=true], attach to stderr.  Default [false]. *)

  (* val wait : ?addr: Unix.sockaddr -> id -> int *)

  val rm : ?addr: Unix.sockaddr -> ?volumes: bool -> ?force: bool ->
           id -> unit
  (** [rm id] remove the container [id] from the filesystem.
    @raise Docker.Invalid_argument if the container does not exist.

    @param volumes Remove the volumes associated to the container.
                   Default [false].
    @param force Kill then remove the container.  Default [false]. *)

  (* val copy_file : ?addr: Unix.sockaddr -> id -> string -> stream *)

  module Exec : sig
    type t

    val create : ?addr: Unix.sockaddr ->
                 ?stdin: bool -> ?stdout: bool -> ?stderr: bool ->
                 id -> string list -> t
    (** [exec id cmd] sets up an exec instance in the {i running}
      container [id] that executes [cmd].  [cmd] has the form [[prog;
      arg1;...; argN]].  The output of this command is not logged by
      the container.  If the command does not exist, an message will
      be printed on the stderr component of the stream returned by
      {!start}.

      @param stdin whether to attach stdin.  Default: [false].
      @param stdout whether to attach stdout.  Default: [true].
      @param stderr whether to attach stderr.  Default: [true]. *)

    val start : ?addr: Unix.sockaddr -> t -> Stream.t
    (** [start exec_id] starts a previously set up exec instance
      [exec_id].  Returns a stream that enable an interactive session
      with the command. *)
  end
end

module Images : sig
  type id = string

  type t = {
      id: id;
      created: float;
      size: int;
      virtual_size: int;
      tags: string list;
    }

  val list : ?addr: Unix.sockaddr -> ?all: bool -> unit -> t list

  (* val create : ?addr: Unix.sockaddr -> *)
  (*              ?from_image: string -> ?from_src: string -> ?repo: string -> *)
  (*              ?tag: string -> ?registry: string *)
  (*              -> stream *)

  (* val insert : ?addr: Unix.sockaddr -> name -> string -> stream *)

  (* val inspect : ?addr: Unix.sockaddr -> name -> t *)

  (* type history = { id: string;  created: float;  created_by: string } *)

  (* val history : ?addr: Unix.sockaddr -> name -> history list *)

  (* val push : ?addr: Unix.sockaddr -> name -> stream *)

  (* val tag : ?addr: Unix.sockaddr -> ?repo: string -> ?force:bool -> name -> unit *)

  (* val rm : ?addr: Unix.sockaddr -> name -> stream *)

  (* type search_result = { description: string; *)
  (*                        is_official: bool; *)
  (*                        is_trusted: bool; *)
  (*                        name: name; *)
  (*                        star_count: int } *)

  (* val search : ?addr: Unix.sockaddr -> string -> search_result list *)

  (* val build : ?addr: Unix.sockaddr -> unit -> stream *)

end

(* val auth : ?addr: Unix.sockaddr -> *)
(*            ?username:string -> ?password: string -> ?email: string -> *)
(*            ?serveraddress: string -> unit *)
(* (\** Get the default username and email. *\) *)

(* type info *)

(* val info : ?addr: Unix.sockaddr -> unit -> info *)

type version = { api_version: string;
                 version: string;
                 git_commit: string;
                 go_version: string }

val version : ?addr: Unix.sockaddr -> unit -> version

(* val ping : ?addr: Unix.sockaddr -> unit -> [`Ok | `Error] *)

(* val commit : ?addr: Unix.sockaddr -> unit -> Image.t *)

(* val monitor : ?addr: Unix.sockaddr -> unit -> event list *)

(* val get : ?addr: Unix.sockaddr -> name: string -> stream *)

(* val load : ?addr: Unix.sockaddr -> tarball: string -> unit *)
(* FIXME: More general than tarball in memory *)


;;
