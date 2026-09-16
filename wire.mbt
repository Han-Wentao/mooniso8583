///|
/// Bitmap representation selected by a wire profile.
pub(all) enum BitmapEncoding {
  BinaryBitmap
  AsciiHexBitmap
} derive(Eq, Debug)

///|
/// MTI representation selected by a wire profile.
pub(all) enum MtiEncoding {
  AsciiMti
  BcdMti
} derive(Eq, Debug)

///|
/// Complete message wire-format choices.
pub(all) struct WireProfile {
  name : String
  mti_encoding : MtiEncoding
  bitmap_encoding : BitmapEncoding
  reject_trailing : Bool
} derive(Eq, Debug)

///|
/// Common binary-bitmap ASCII-MTI profile.
pub fn ascii_binary_profile() -> WireProfile {
  {
    name: "ascii-mti-binary-bitmap",
    mti_encoding: AsciiMti,
    bitmap_encoding: BinaryBitmap,
    reject_trailing: true,
  }
}

///|
/// Common all-display profile using ASCII hexadecimal bitmap text.
pub fn ascii_hex_profile() -> WireProfile {
  {
    name: "ascii-mti-ascii-hex-bitmap",
    mti_encoding: AsciiMti,
    bitmap_encoding: AsciiHexBitmap,
    reject_trailing: true,
  }
}

///|
/// Compact profile with a two-byte BCD MTI.
pub fn bcd_binary_profile() -> WireProfile {
  {
    name: "bcd-mti-binary-bitmap",
    mti_encoding: BcdMti,
    bitmap_encoding: BinaryBitmap,
    reject_trailing: true,
  }
}

///|
/// Return a copy that allows bytes after one decoded message.
pub fn WireProfile::allow_trailing(self : WireProfile) -> WireProfile {
  {
    name: self.name,
    mti_encoding: self.mti_encoding,
    bitmap_encoding: self.bitmap_encoding,
    reject_trailing: false,
  }
}

///|
/// Encode the four-digit message type indicator.
fn encode_mti(profile : WireProfile, mti : String) -> Result[Bytes, IsoError] {
  if !valid_mti_text(mti) {
    return Err(InvalidMti(mti))
  }
  match profile.mti_encoding {
    AsciiMti => text_to_ascii(0, mti)
    BcdMti => bcd_pack_digits(0, mti, true, 0)
  }
}

///|
/// Decode an MTI at an offset and report consumed bytes.
fn decode_mti(
  profile : WireProfile,
  data : Bytes,
  start : Int,
) -> Result[(String, Int), IsoError] {
  let byte_length = match profile.mti_encoding {
    AsciiMti => 4
    BcdMti => 2
  }
  if start < 0 || start + byte_length > data.length() {
    return Err(
      Truncated("MTI", byte_length, Int::max(0, data.length() - start)),
    )
  }
  let raw = bytes_slice(data, start, start + byte_length)
  let text = match profile.mti_encoding {
    AsciiMti =>
      match ascii_to_text(0, raw) {
        Ok(text) => text
        Err(error) => return Err(error)
      }
    BcdMti =>
      match bcd_unpack_digits(0, raw, 4, true, 0) {
        Ok(text) => text
        Err(error) => return Err(error)
      }
  }
  if !valid_mti_text(text) {
    Err(InvalidMti(text))
  } else {
    Ok((text, byte_length))
  }
}

///|
/// Encode a bitmap according to the profile.
fn encode_bitmap(profile : WireProfile, bitmap : Bitmap) -> Bytes {
  match profile.bitmap_encoding {
    BinaryBitmap => bitmap.to_bytes()
    AsciiHexBitmap => bitmap.to_ascii_bytes()
  }
}

///|
/// Decode a bitmap according to the profile.
fn decode_bitmap(
  profile : WireProfile,
  data : Bytes,
  start : Int,
) -> Result[(Bitmap, Int), IsoError] {
  match profile.bitmap_encoding {
    BinaryBitmap => bitmap_decode_binary(data, start)
    AsciiHexBitmap => bitmap_decode_ascii(data, start)
  }
}

///|
/// Pack a complete ISO 8583 message.
pub fn pack_message(
  packager : Packager,
  profile : WireProfile,
  message : IsoMessage,
) -> Result[Bytes, IsoError] {
  match parse_mti(message.mti) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let issues = validate_message_fields(message, packager)
  if issues.length() > 0 {
    return Err(TemplateViolation(issues[0].message))
  }
  let mti = match encode_mti(profile, message.mti) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  let bitmap = match message.bitmap() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let bitmap_bytes = encode_bitmap(profile, bitmap)
  let fields = match encode_selected_fields(packager, message) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  let output : Array[Byte] = []
  append_bytes(output, mti)
  append_bytes(output, bitmap_bytes)
  append_bytes(output, fields)
  Ok(Bytes::from_array(output))
}

///|
/// Decode a complete message and retain consumption metadata.
pub fn unpack_message_with_result(
  packager : Packager,
  profile : WireProfile,
  data : Bytes,
) -> Result[DecodeResult, IsoError] {
  let (mti, mti_bytes) = match decode_mti(profile, data, 0) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let (bitmap, bitmap_bytes) = match decode_bitmap(profile, data, mti_bytes) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let fields_start = mti_bytes + bitmap_bytes
  let (fields, field_bytes) = match
    decode_selected_fields(packager, bitmap, data, fields_start) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let consumed = fields_start + field_bytes
  if profile.reject_trailing && consumed != data.length() {
    return Err(TrailingBytes(data.length() - consumed))
  }
  let message = { mti, fields, }
  Ok({ message, consumed, bitmap_bytes, })
}

///|
/// Decode exactly one complete message.
pub fn unpack_message(
  packager : Packager,
  profile : WireProfile,
  data : Bytes,
) -> Result[IsoMessage, IsoError] {
  match unpack_message_with_result(packager, profile, data) {
    Ok(result) => Ok(result.message)
    Err(error) => Err(error)
  }
}

///|
/// Pack directly to a hexadecimal diagnostic fixture.
pub fn pack_message_hex(
  packager : Packager,
  profile : WireProfile,
  message : IsoMessage,
) -> Result[String, IsoError] {
  match pack_message(packager, profile, message) {
    Ok(bytes) => Ok(hex_encode(bytes))
    Err(error) => Err(error)
  }
}

///|
/// Unpack a hexadecimal diagnostic fixture.
pub fn unpack_message_hex(
  packager : Packager,
  profile : WireProfile,
  fixture : String,
) -> Result[IsoMessage, IsoError] {
  let bytes = match hex_decode(fixture) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  unpack_message(packager, profile, bytes)
}

///|
/// Explain byte-level layout without exposing sensitive values.
pub fn message_layout(
  packager : Packager,
  profile : WireProfile,
  message : IsoMessage,
) -> Result[Array[String], IsoError] {
  let lines : Array[String] = []
  let mti_bytes = match encode_mti(profile, message.mti) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  let bitmap = match message.bitmap() {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let bitmap_bytes = encode_bitmap(profile, bitmap)
  lines.push("MTI offset=0 bytes=\{mti_bytes.length()} value=\{message.mti}")
  lines.push(
    "bitmap offset=\{mti_bytes.length()} bytes=\{bitmap_bytes.length()} fields=\{bitmap.field_count()}",
  )
  let mut offset = mti_bytes.length() + bitmap_bytes.length()
  for entry in message.fields {
    let spec = match packager.spec(entry.number) {
      Some(value) => value
      None => return Err(UnknownField(entry.number))
    }
    let encoded = match encode_field(spec, entry.value) {
      Ok(value) => value
      Err(error) => return Err(error)
    }
    lines.push(
      "DE\{entry.number} offset=\{offset} bytes=\{encoded.bytes.length()} logical=\{encoded.logical_length} name=\{spec.name}",
    )
    offset += encoded.bytes.length()
  }
  lines.push("total bytes=\{offset}")
  Ok(lines)
}
