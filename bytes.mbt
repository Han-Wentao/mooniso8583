///|
/// True for an ASCII decimal character.
pub fn ascii_digit(c : UInt16) -> Bool {
  c >= '0' && c <= '9'
}

///|
/// True for an ASCII alphabetic character.
pub fn ascii_alpha(c : UInt16) -> Bool {
  (c >= 'A' && c <= 'Z') || (c >= 'a' && c <= 'z')
}

///|
/// True for an ASCII alphanumeric character.
pub fn ascii_alnum(c : UInt16) -> Bool {
  ascii_digit(c) || ascii_alpha(c)
}

///|
/// Convert a hexadecimal character to its nibble value.
fn hex_nibble(c : UInt16) -> Int? {
  if c >= '0' && c <= '9' {
    Some(c.to_int() - 48)
  } else if c >= 'A' && c <= 'F' {
    Some(c.to_int() - 55)
  } else if c >= 'a' && c <= 'f' {
    Some(c.to_int() - 87)
  } else {
    None
  }
}

///|
/// Convert one nibble to uppercase hexadecimal.
fn nibble_char(value : Int) -> Char {
  if value < 10 {
    (48 + value).unsafe_to_char()
  } else {
    (55 + value).unsafe_to_char()
  }
}

///|
/// Copy a byte range without exposing mutable backing storage.
fn bytes_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  Bytes::makei(end - start, i => data[start + i])
}

///|
/// Append immutable bytes into a mutable byte array.
fn append_bytes(target : Array[Byte], source : Bytes) -> Unit {
  for byte in source {
    target.push(byte)
  }
}

///|
/// Concatenate two byte sequences.
pub fn concat_bytes(left : Bytes, right : Bytes) -> Bytes {
  let out : Array[Byte] = []
  append_bytes(out, left)
  append_bytes(out, right)
  Bytes::from_array(out)
}

///|
/// Convert ASCII text into bytes, rejecting non-ASCII characters.
pub fn text_to_ascii(field : Int, text : String) -> Result[Bytes, IsoError] {
  let out : Array[Byte] = []
  for i = 0; i < text.length(); i = i + 1 {
    let value = text[i].to_int()
    if value < 0 || value > 127 {
      return Err(InvalidCharacter(field, i, "non-ASCII"))
    }
    out.push(value.to_byte())
  }
  Ok(Bytes::from_array(out))
}

///|
/// Convert bytes to an ASCII string, rejecting bytes above 0x7f.
pub fn ascii_to_text(field : Int, data : Bytes) -> Result[String, IsoError] {
  let out = StringBuilder()
  for i = 0; i < data.length(); i = i + 1 {
    let value = data[i].to_int()
    if value > 127 {
      return Err(InvalidCharacter(field, i, "non-ASCII byte"))
    }
    out.write_char(value.unsafe_to_char())
  }
  Ok(out.to_string())
}

///|
/// Encode bytes as uppercase hexadecimal.
pub fn hex_encode(data : Bytes) -> String {
  let out = StringBuilder()
  for byte in data {
    let value = byte.to_int()
    out.write_char(nibble_char((value >> 4) & 15))
    out.write_char(nibble_char(value & 15))
  }
  out.to_string()
}

///|
/// Decode even-length hexadecimal text.
pub fn hex_decode(text : String) -> Result[Bytes, IsoError] {
  if text.length() % 2 != 0 {
    return Err(InvalidHex(text))
  }
  let out : Array[Byte] = []
  let mut i = 0
  while i < text.length() {
    match (hex_nibble(text[i]), hex_nibble(text[i + 1])) {
      (Some(high), Some(low)) => out.push(((high << 4) | low).to_byte())
      _ => return Err(InvalidHex(text))
    }
    i += 2
  }
  Ok(Bytes::from_array(out))
}

///|
/// Render a non-negative integer as zero-padded decimal text.
pub fn decimal_width(value : Int, width : Int) -> Result[String, IsoError] {
  if value < 0 {
    return Err(LengthPrefixOverflow(width, value))
  }
  let text = value.to_string()
  if text.length() > width {
    return Err(LengthPrefixOverflow(width, value))
  }
  let out = StringBuilder()
  for _ in 0..<(width - text.length()) {
    out.write_char('0')
  }
  out.write_string(text)
  Ok(out.to_string())
}

///|
/// Parse a decimal ASCII range without allocating an intermediate slice.
pub fn parse_decimal_bytes(
  data : Bytes,
  start : Int,
  width : Int,
) -> Result[Int, IsoError] {
  if start < 0 || width < 0 || start + width > data.length() {
    return Err(
      Truncated(
        "decimal length prefix",
        width,
        Int::max(0, data.length() - start),
      ),
    )
  }
  let mut value = 0
  for i = start; i < start + width; i = i + 1 {
    let digit = data[i].to_int() - 48
    if digit < 0 || digit > 9 {
      return Err(
        InvalidNumeric(0, hex_encode(bytes_slice(data, start, start + width))),
      )
    }
    value = value * 10 + digit
  }
  Ok(value)
}

///|
/// Left pad text to a fixed width.
pub fn left_pad(text : String, width : Int, fill : UInt16) -> String {
  if text.length() >= width {
    return text
  }
  let out = StringBuilder()
  for _ in 0..<(width - text.length()) {
    out.write_char(fill.to_int().unsafe_to_char())
  }
  out.write_string(text)
  out.to_string()
}

///|
/// Right pad text to a fixed width.
pub fn right_pad(text : String, width : Int, fill : UInt16) -> String {
  if text.length() >= width {
    return text
  }
  let out = StringBuilder()
  out.write_string(text)
  for _ in 0..<(width - text.length()) {
    out.write_char(fill.to_int().unsafe_to_char())
  }
  out.to_string()
}

///|
/// Remove leading padding down to a minimum of one character.
pub fn trim_left_char(text : String, fill : UInt16) -> String {
  let mut i = 0
  while i + 1 < text.length() && text[i] == fill {
    i += 1
  }
  text[i:].to_owned()
}

///|
/// Remove trailing padding.
pub fn trim_right_char(text : String, fill : UInt16) -> String {
  let mut end = text.length()
  while end > 0 && text[end - 1] == fill {
    end -= 1
  }
  text[0:end].to_owned()
}

///|
/// Constant-time-ish equality for byte strings of equal public length.
pub fn bytes_equal(left : Bytes, right : Bytes) -> Bool {
  if left.length() != right.length() {
    return false
  }
  let mut diff = 0
  for i = 0; i < left.length(); i = i + 1 {
    diff = diff | (left[i].to_int() ^ right[i].to_int())
  }
  diff == 0
}
