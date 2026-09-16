///|
/// How a data element obtains its encoded length.
pub(all) enum LengthKind {
  Fixed
  Llvar
  Lllvar
} derive(Eq, Debug)

///|
/// How a variable-length prefix is represented.
pub(all) enum LengthEncoding {
  AsciiLength
  BcdLength
} derive(Eq, Debug)

///|
/// How field content is represented on the wire.
pub(all) enum ContentEncoding {
  AsciiContent
  BcdContent
  BinaryContent
} derive(Eq, Debug)

///|
/// Validation class applied before a field is packed.
pub(all) enum DataKind {
  Numeric
  Alpha
  Alphanumeric
  AlphanumericSpecial
  Track2Data
  BinaryHex
  AnyText
} derive(Eq, Debug)

///|
/// Direction used when a fixed field needs padding.
pub(all) enum PadDirection {
  NoPadding
  PadLeft
  PadRight
} derive(Eq, Debug)

///|
/// One data-element definition in a packager profile.
pub(all) struct FieldSpec {
  number : Int
  name : String
  length_kind : LengthKind
  max_length : Int
  min_length : Int
  length_encoding : LengthEncoding
  content_encoding : ContentEncoding
  data_kind : DataKind
  pad_direction : PadDirection
  pad_char : UInt16
} derive(Eq, Debug)

///|
/// A field stored in a message. Values are unencoded canonical text.
pub(all) struct FieldEntry {
  number : Int
  value : String
} derive(Eq, Debug)

///|
/// Mutable message model used by pack and validation operations.
pub(all) struct IsoMessage {
  mut mti : String
  fields : Array[FieldEntry]
} derive(Debug)

///|
/// Ordered collection of field definitions.
pub(all) struct Packager {
  name : String
  specs : Array[FieldSpec]
} derive(Debug)

///|
/// A validation finding that can be rendered in stable logs.
pub(all) struct ValidationIssue {
  code : String
  field : Int
  message : String
  severity : String
} derive(Eq, Debug)

///|
/// Result of decoding with byte-consumption information.
pub(all) struct DecodeResult {
  message : IsoMessage
  consumed : Int
  bitmap_bytes : Int
} derive(Debug)

///|
/// Create a fixed ASCII field definition.
pub fn fixed_ascii(
  number : Int,
  name : String,
  length : Int,
  kind : DataKind,
) -> FieldSpec {
  {
    number,
    name,
    length_kind: Fixed,
    max_length: length,
    min_length: length,
    length_encoding: AsciiLength,
    content_encoding: AsciiContent,
    data_kind: kind,
    pad_direction: NoPadding,
    pad_char: ' ',
  }
}

///|
/// Create a fixed numeric field left padded with zeroes.
pub fn fixed_numeric(number : Int, name : String, length : Int) -> FieldSpec {
  {
    number,
    name,
    length_kind: Fixed,
    max_length: length,
    min_length: 1,
    length_encoding: AsciiLength,
    content_encoding: AsciiContent,
    data_kind: Numeric,
    pad_direction: PadLeft,
    pad_char: '0',
  }
}

///|
/// Create an ASCII LLVAR field.
pub fn llvar_ascii(
  number : Int,
  name : String,
  maximum : Int,
  kind : DataKind,
) -> FieldSpec {
  {
    number,
    name,
    length_kind: Llvar,
    max_length: maximum,
    min_length: 0,
    length_encoding: AsciiLength,
    content_encoding: AsciiContent,
    data_kind: kind,
    pad_direction: NoPadding,
    pad_char: ' ',
  }
}

///|
/// Create an ASCII LLLVAR field.
pub fn lllvar_ascii(
  number : Int,
  name : String,
  maximum : Int,
  kind : DataKind,
) -> FieldSpec {
  {
    number,
    name,
    length_kind: Lllvar,
    max_length: maximum,
    min_length: 0,
    length_encoding: AsciiLength,
    content_encoding: AsciiContent,
    data_kind: kind,
    pad_direction: NoPadding,
    pad_char: ' ',
  }
}

///|
/// Create a binary field represented as hexadecimal text in the API.
pub fn binary_hex(
  number : Int,
  name : String,
  maximum_bytes : Int,
  variable : Bool,
) -> FieldSpec {
  {
    number,
    name,
    length_kind: if variable {
      Lllvar
    } else {
      Fixed
    },
    max_length: maximum_bytes * 2,
    min_length: if variable {
      0
    } else {
      maximum_bytes * 2
    },
    length_encoding: AsciiLength,
    content_encoding: BinaryContent,
    data_kind: BinaryHex,
    pad_direction: NoPadding,
    pad_char: '0',
  }
}
