(* The package sedlex is released under the terms of an MIT-like license. *)
(* See the attached LICENSE file.                                         *)
(* Copyright 2005, 2013 by Alain Frisch and LexiFi.                       *)

(** Runtime support for lexers generated by [sedlex]. *)

(** This module is roughly equivalent to the module Lexing from the
    OCaml standard library, except that its lexbuffers handle Unicode
    code points (OCaml type: [int] in the range [0..0x10ffff]) instead
    of bytes (OCaml type: [char]).

    It is possible to have sedlex-generated lexers work on a custom
    implementation for lex buffers. To do this, define a module [L]
    which implements the [start], [next], [mark] and [backtrack]
    functions (See the Internal Interface section below for a
    specification).  They need not work on a type named [lexbuf]: you
    can use the type name you want. Then, just do in your
    sedlex-processed source, bind this module to the name [Sedlexing]
    (for instance, with a local module definition: [let module Sedlexing
    = L in ...].

    Of course, you'll probably want to define functions like [lexeme] to
    be used in the lexers semantic actions.  *)

type lexbuf
      (** The type of lexer buffers. A lexer buffer is the argument passed
          to the scanning functions defined by the generated lexers.
          The lexer buffer holds the internal information for the
          scanners, including the code points of the token currently scanned,
          its position from the beginning of the input stream,
          and the current position of the lexer. *)

exception InvalidCodepoint of int
    (** Raised by some functions to signal that some code point is not
        compatible with a specified encoding. *)

exception MalFormed
    (** Raised by functions in the [Utf8] and [Utf16] modules to report
        strings which do not comply to the encoding. *)

(** {6 Creating generic lexbufs} *)

val create: (int array -> int -> int -> int) -> lexbuf
    (** Create a generic lexer buffer.  When the lexer needs more
        characters, it will call the given function, giving it an array of
        integers [a], a position [pos] and a code point count [n].  The
        function should put [n] code points or less in [a], starting at
        position [pos], and return the number of characters provided. A
        return value of 0 means end of input. *)

val from_gen: int Gen.t -> lexbuf
    (** Create a lexbuf from a stream of Unicode code points. *)

val from_stream: int Stream.t -> lexbuf
    (** Create a lexbuf from a stream of Unicode code points. *)
    [@@ocaml.deprecated "Use [Sedlexing.from_gen] instead."]

val from_int_array: int array -> lexbuf
    (** Create a lexbuf from an array of Unicode code points. *)

(** {6 Interface for lexers semantic actions} *)

(** The following functions can be called from the semantic actions of
    lexer definitions.  They give access to the character string matched
    by the regular expression associated with the semantic action. *)

val lexeme_start: lexbuf -> int
    (** [Sedlexing.lexeme_start lexbuf] returns the offset in the
        input stream of the first code point of the matched string.
        The first code point of the stream has offset 0. *)

val lexeme_end: lexbuf -> int
    (** [Sedlexing.lexeme_end lexbuf] returns the offset in the input
        stream of the character following the last code point of the
        matched string. The first character of the stream has offset
        0. *)

val loc: lexbuf -> int * int
    (** [Sedlexing.loc lexbuf] returns the pair
        [(Sedlexing.lexeme_start lexbuf,Sedlexing.lexeme_end
        lexbuf)]. *)

val lexeme_length: lexbuf -> int
    (** [Sedlexing.loc lexbuf] returns the difference
        [(Sedlexing.lexeme_end lexbuf) - (Sedlexing.lexeme_start
        lexbuf)], that is, the length (in code points) of the matched
        string. *)

val lexeme: lexbuf -> int array
    (** [Sedlexing.lexeme lexbuf] returns the string matched by the
        regular expression as an array of Unicode code point. *)

val lexeme_char: lexbuf -> int -> int
    (** [Sedlexing.lexeme_char lexbuf pos] returns code point number [pos] in
        the matched string. *)

val sub_lexeme: lexbuf -> int -> int -> int array
(** [Sedlexing.lexeme lexbuf pos len] returns a substring of the string
    matched by the regular expression as an array of Unicode code point. *)


val rollback: lexbuf -> unit
(** [Sedlexing.rollback lexbuf] puts [lexbuf] back in its configuration before
    the last lexeme was matched. It is then possible to use another
    lexer to parse the same characters again. The other functions
    above in this section should not be used in the semantic action
    after a call to [Sedlexing.rollback]. *)

(** {6 Internal interface} *)

(** These functions are used internally by the lexers. They could be used
    to write lexers by hand, or with a lexer generator different from
    [sedlex]. The lexer buffers have a unique internal slot that can store
    an integer. They also store a "backtrack" position.
 *)

val start: lexbuf -> unit
(** [start t] informs the lexer buffer that any
    code points until the current position can be discarded.
    The current position become the "start" position as returned
    by [Sedlexing.lexeme_start]. Moreover, the internal slot is set to
    [-1] and the backtrack position is set to the current position.
 *)

val next: lexbuf -> int
(** [next lexbuf] extracts the next code point from the
    lexer buffer and increments to current position. If the input stream
    is exhausted, the function returns [-1]. *)

val mark: lexbuf -> int -> unit
(** [mark lexbuf i] stores the integer [i] in the internal
    slot. The backtrack position is set to the current position. *)

val backtrack: lexbuf -> int
(** [backtrack lexbuf] returns the value stored in the
    internal slot of the buffer, and performs backtracking
    (the current position is set to the value of the backtrack position). *)


(** {6 Support for common encodings} *)

module Latin1: sig
  val from_gen: char Gen.t -> lexbuf
      (** Create a lexbuf from a Latin1 encoded stream (ie a stream
          of Unicode code points in the range [0..255]) *)

  val from_stream: char Stream.t -> lexbuf
      (** Create a lexbuf from a Latin1 encoded stream (ie a stream
          of Unicode code points in the range [0..255]) *)
      [@@ocaml.deprecated "Use [Sedlexing.Latin1.from_gen] instead."]

  val from_channel: in_channel -> lexbuf
      (** Create a lexbuf from a Latin1 encoded input channel.
          The client is responsible for closing the channel. *)

  val from_string: string -> lexbuf
      (** Create a lexbuf from a Latin1 encoded string. *)


  val lexeme: lexbuf -> string
      (** As [Sedlexing.lexeme] with a result encoded in Latin1.  This
          function throws an exception [InvalidCodepoint] if it is not
          possible to encode the result in Latin1. *)

  val sub_lexeme: lexbuf -> int -> int -> string
      (** As [Sedlexing.sub_lexeme] with a result encoded in Latin1.
          This function throws an exception [InvalidCodepoint] if it
          is not possible to encode the result in Latin1. *)

  val lexeme_char: lexbuf -> int -> char
      (** As [Sedlexing.lexeme_char] with a result encoded in Latin1.
          This function throws an exception [InvalidCodepoint] if it
          is not possible to encode the result in Latin1. *)
end


module Utf8: sig
  val from_gen: char Gen.t -> lexbuf
      (** Create a lexbuf from a UTF-8 encoded stream. *)

  val from_stream: char Stream.t -> lexbuf
      (** Create a lexbuf from a UTF-8 encoded stream. *)
      [@@ocaml.deprecated "Use [Sedlexing.Utf8.from_gen] instead."]

  val from_channel: in_channel -> lexbuf
      (** Create a lexbuf from a UTF-8 encoded input channel. *)

  val from_string: string -> lexbuf
      (** Create a lexbuf from a UTF-8 encoded string. *)

  val lexeme: lexbuf -> string
   (** As [Sedlexing.lexeme] with a result encoded in UTF-8. *)

  val sub_lexeme: lexbuf -> int -> int -> string
      (** As [Sedlexing.sub_lexeme] with a result encoded in UTF-8. *)
end


module Utf16: sig
  type byte_order = Little_endian | Big_endian

  val from_gen: char Gen.t -> byte_order option -> lexbuf
      (** [Utf16.from_gen s opt_bo] creates a lexbuf from an UTF-16
          encoded stream. If [opt_bo] matches with [None] the function
          expects a BOM (Byte Order Mark), and takes the byte order as
          [Utf16.Big_endian] if it cannot find one. When [opt_bo]
          matches with [Some bo], [bo] is taken as byte order. In this
          case a leading BOM is kept in the stream - the lexer has to
          ignore it and a `wrong' BOM ([0xfffe]) will raise
          Utf16.InvalidCodepoint.  *)

  val from_stream: char Stream.t -> byte_order option -> lexbuf
      (** Works as [Utf16.from_gen] with a [stream]. *)
      [@@ocaml.deprecated "Use [Sedlexing.Utf16.from_gen] instead."]

  val from_channel: in_channel -> byte_order option-> lexbuf
      (** Works as [Utf16.from_gen] with an [in_channel]. *)

  val from_string: string -> byte_order option -> lexbuf
      (** Works as [Utf16.from_gen] with a [string]. *)

  val lexeme: lexbuf -> byte_order -> bool -> string
      (** [utf16_lexeme lb bo bom] as [Sedlexing.lexeme] with a result
          encoded in UTF-16 in byte_order [bo] and starting with a BOM
          if [bom = true].  *)

  val sub_lexeme: lexbuf -> int -> int -> byte_order -> bool -> string
      (** [sub_lexeme lb pos len bo bom] as
          [Sedlexing.sub_lexeme] with a result encoded in UTF-16 with
          byte order [bo] and starting with a BOM if [bom=true] *)
end
