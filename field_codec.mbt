///|
/// Encoded data element with length accounting.
pub(all) struct EncodedField {
  bytes : Bytes
  logical_length : Int
  prefix_length : Int
  content_length : Int
} derive(Eq, Debug)

///|
/// Decoded data element with byte-consumption accounting.
pub(all) struct DecodedField {
  value : String
  consumed : Int
  logical_length : Int
  prefix_length : Int
} derive(Eq, Debug)

///|
/// Number of decimal digits used by a variable-length prefix.
fn length_prefix_digits(kind : LengthKind) -> Int {
  match kind {
    Fixed => 0
    Llvar => 2
    Lllvar => 3
  }
}

///|
/// Encode a logical length according to the field definition.
fn encode_length_prefix(
  spec : FieldSpec,
  length : Int,
) -> Result[Bytes, IsoError] {
  let digits = length_prefix_digits(spec.length_kind)
  if digits == 0 {
    return Ok(Bytes::make(0, (0).to_byte()))
  }
  match spec.length_encoding {
    AsciiLength => {
      let text = match decimal_width(length, digits) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      text_to_ascii(spec.number, text)
    }
    BcdLength => bcd_pack_length(length, digits)
  }
}

///|
/// Decode a logical length and report prefix bytes consumed.
fn decode_length_prefix(
  spec : FieldSpec,
  data : Bytes,
  start : Int,
) -> Result[(Int, Int), IsoError] {
  let digits = length_prefix_digits(spec.length_kind)
  if digits == 0 {
    return Ok((field_max_logical_length(spec), 0))
  }
  match spec.length_encoding {
    AsciiLength => {
      let value = match parse_decimal_bytes(data, start, digits) {
        Ok(value) => value
        Err(error) => return Err(error)
      }
      Ok((value, digits))
    }
    BcdLength => bcd_unpack_length(data, start, digits)
  }
}

///|
/// Compute bytes occupied by content of the given logical length.
pub fn encoded_content_length(spec : FieldSpec, logical_length : Int) -> Int {
  match spec.content_encoding {
    AsciiContent => logical_length
    BinaryContent => logical_length
    BcdContent => (logical_length + 1) / 2
  }
}

///|
/// Encode canonical field content without a length prefix.
fn encode_field_content(
  spec : FieldSpec,
  value : String,
) -> Result[Bytes, IsoError] {
  match spec.content_encoding {
    AsciiContent => text_to_ascii(spec.number, value)
    BinaryContent => hex_decode(value)
    BcdContent => bcd_pack_digits(spec.number, value, true, 0)
  }
}

///|
/// Decode field content bytes into canonical API text.
fn decode_field_content(
  spec : FieldSpec,
  content : Bytes,
  logical_length : Int,
) -> Result[String, IsoError] {
  match spec.content_encoding {
    AsciiContent => ascii_to_text(spec.number, content)
    BinaryContent => Ok(hex_encode(content))
    BcdContent =>
      bcd_unpack_digits(spec.number, content, logical_length, true, 0)
  }
}

///|
/// Encode one data element including its optional length prefix.
pub fn encode_field(
  spec : FieldSpec,
  value : String,
) -> Result[EncodedField, IsoError] {
  let canonical = match canonical_field_value(spec, value) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let logical_length = field_logical_length(spec, canonical)
  let prefix = match encode_length_prefix(spec, logical_length) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  let content = match encode_field_content(spec, canonical) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  let combined = concat_bytes(prefix, content)
  Ok({
    bytes: combined,
    logical_length,
    prefix_length: prefix.length(),
    content_length: content.length(),
  })
}

///|
/// Decode one data element from an offset.
pub fn decode_field(
  spec : FieldSpec,
  data : Bytes,
  start : Int,
) -> Result[DecodedField, IsoError] {
  if start < 0 || start > data.length() {
    return Err(Truncated("field \{spec.number}", 0, 0))
  }
  let (logical_length, prefix_length) = match
    decode_length_prefix(spec, data, start) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let minimum = field_min_logical_length(spec)
  let maximum = field_max_logical_length(spec)
  if logical_length < minimum {
    return Err(FieldTooShort(spec.number, minimum, logical_length))
  }
  if logical_length > maximum {
    return Err(FieldTooLong(spec.number, maximum, logical_length))
  }
  let content_length = encoded_content_length(spec, logical_length)
  let content_start = start + prefix_length
  if content_start + content_length > data.length() {
    return Err(
      Truncated(
        "field \{spec.number} content",
        content_length,
        Int::max(0, data.length() - content_start),
      ),
    )
  }
  let content = bytes_slice(data, content_start, content_start + content_length)
  let value = match decode_field_content(spec, content, logical_length) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match validate_data_kind(spec.number, spec.data_kind, value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  Ok({
    value,
    consumed: prefix_length + content_length,
    logical_length,
    prefix_length,
  })
}

///|
/// Encode a field directly to uppercase hexadecimal for fixtures.
pub fn encode_field_hex(
  spec : FieldSpec,
  value : String,
) -> Result[String, IsoError] {
  match encode_field(spec, value) {
    Ok(encoded) => Ok(hex_encode(encoded.bytes))
    Err(error) => Err(error)
  }
}

///|
/// Decode a field from hexadecimal fixture text.
pub fn decode_field_hex(
  spec : FieldSpec,
  wire : String,
) -> Result[DecodedField, IsoError] {
  let data = match hex_decode(wire) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  decode_field(spec, data, 0)
}

///|
/// Construct a fixed BCD numeric field definition.
pub fn fixed_bcd_numeric(
  number : Int,
  name : String,
  digits : Int,
) -> FieldSpec {
  {
    number,
    name,
    length_kind: Fixed,
    max_length: digits,
    min_length: digits,
    length_encoding: BcdLength,
    content_encoding: BcdContent,
    data_kind: Numeric,
    pad_direction: PadLeft,
    pad_char: '0',
  }
}

///|
/// Construct a BCD-content LLVAR numeric field.
pub fn llvar_bcd_numeric(
  number : Int,
  name : String,
  digits : Int,
) -> FieldSpec {
  {
    number,
    name,
    length_kind: Llvar,
    max_length: digits,
    min_length: 0,
    length_encoding: BcdLength,
    content_encoding: BcdContent,
    data_kind: Numeric,
    pad_direction: NoPadding,
    pad_char: '0',
  }
}

///|
/// Construct a binary LLLVAR field with BCD length prefix.
pub fn lllvar_bcd_binary(
  number : Int,
  name : String,
  maximum_bytes : Int,
) -> FieldSpec {
  {
    number,
    name,
    length_kind: Lllvar,
    max_length: maximum_bytes * 2,
    min_length: 0,
    length_encoding: BcdLength,
    content_encoding: BinaryContent,
    data_kind: BinaryHex,
    pad_direction: NoPadding,
    pad_char: '0',
  }
}

///|
/// Decode a sequence of fields selected by a bitmap.
pub fn decode_selected_fields(
  packager : Packager,
  bitmap : Bitmap,
  data : Bytes,
  start : Int,
) -> Result[(Array[FieldEntry], Int), IsoError] {
  let fields : Array[FieldEntry] = []
  let mut offset = start
  for number in bitmap.fields() {
    let spec = match packager.spec(number) {
      Some(spec) => spec
      None => return Err(UnknownField(number))
    }
    let decoded = match decode_field(spec, data, offset) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    fields.push({ number, value: decoded.value, })
    offset += decoded.consumed
  }
  Ok((fields, offset - start))
}

///|
/// Encode message fields in ascending data-element order.
pub fn encode_selected_fields(
  packager : Packager,
  message : IsoMessage,
) -> Result[Bytes, IsoError] {
  let output : Array[Byte] = []
  for entry in message.fields {
    let spec = match packager.spec(entry.number) {
      Some(spec) => spec
      None => return Err(UnknownField(entry.number))
    }
    let encoded = match encode_field(spec, entry.value) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    append_bytes(output, encoded.bytes)
  }
  Ok(Bytes::from_array(output))
}
