///|
/// Validate a string containing decimal digits only.
pub fn validate_digits(field : Int, text : String) -> Result[Unit, IsoError] {
  for i = 0; i < text.length(); i = i + 1 {
    if !ascii_digit(text[i]) {
      return Err(InvalidCharacter(field, i, "decimal"))
    }
  }
  Ok(())
}

///|
/// Pack decimal digits into BCD. Odd values are padded on the requested side.
pub fn bcd_pack_digits(
  field : Int,
  digits : String,
  pad_left : Bool,
  pad_nibble : Int,
) -> Result[Bytes, IsoError] {
  match validate_digits(field, digits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if pad_nibble < 0 || pad_nibble > 15 {
    return Err(InvalidBcd(0, pad_nibble))
  }
  let odd = digits.length() % 2 == 1
  let byte_count = (digits.length() + 1) / 2
  let output : Array[Byte] = []
  for byte_index = 0; byte_index < byte_count; byte_index = byte_index + 1 {
    let digit_index = byte_index * 2
    let high = if odd && pad_left && byte_index == 0 {
      pad_nibble
    } else {
      let index = if odd && pad_left { digit_index - 1 } else { digit_index }
      digits[index].to_int() - 48
    }
    let low = if odd && !pad_left && byte_index == byte_count - 1 {
      pad_nibble
    } else {
      let index = if odd && pad_left { digit_index } else { digit_index + 1 }
      digits[index].to_int() - 48
    }
    output.push(((high << 4) | low).to_byte())
  }
  Ok(Bytes::from_array(output))
}

///|
/// Unpack BCD bytes into decimal digits.
pub fn bcd_unpack_digits(
  field : Int,
  data : Bytes,
  digit_count : Int,
  pad_left : Bool,
  pad_nibble : Int,
) -> Result[String, IsoError] {
  if digit_count < 0 || data.length() != (digit_count + 1) / 2 {
    return Err(InvalidLength(field, (digit_count + 1) / 2, data.length()))
  }
  let odd = digit_count % 2 == 1
  let out = StringBuilder()
  for i = 0; i < data.length(); i = i + 1 {
    let value = data[i].to_int()
    let high = (value >> 4) & 15
    let low = value & 15
    if odd && pad_left && i == 0 {
      if high != pad_nibble {
        return Err(InvalidBcd(i * 2, high))
      }
    } else {
      if high > 9 {
        return Err(InvalidBcd(i * 2, high))
      }
      out.write_char((48 + high).unsafe_to_char())
    }
    if odd && !pad_left && i == data.length() - 1 {
      if low != pad_nibble {
        return Err(InvalidBcd(i * 2 + 1, low))
      }
    } else {
      if low > 9 {
        return Err(InvalidBcd(i * 2 + 1, low))
      }
      out.write_char((48 + low).unsafe_to_char())
    }
  }
  Ok(out.to_string())
}

///|
/// Pack an LLVAR or LLLVAR length into BCD bytes.
pub fn bcd_pack_length(value : Int, digits : Int) -> Result[Bytes, IsoError] {
  if digits != 2 && digits != 3 {
    return Err(LengthPrefixOverflow(digits, value))
  }
  let text = match decimal_width(value, digits) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  bcd_pack_digits(0, text, true, 0)
}

///|
/// Decode a BCD length prefix and return value plus consumed bytes.
pub fn bcd_unpack_length(
  data : Bytes,
  start : Int,
  digits : Int,
) -> Result[(Int, Int), IsoError] {
  if digits != 2 && digits != 3 {
    return Err(LengthPrefixOverflow(digits, 0))
  }
  let bytes_needed = (digits + 1) / 2
  if start < 0 || start + bytes_needed > data.length() {
    return Err(
      Truncated(
        "BCD length prefix",
        bytes_needed,
        Int::max(0, data.length() - start),
      ),
    )
  }
  let raw = bytes_slice(data, start, start + bytes_needed)
  let text = match bcd_unpack_digits(0, raw, digits, true, 0) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let mut value = 0
  for i = 0; i < text.length(); i = i + 1 {
    value = value * 10 + text[i].to_int() - 48
  }
  Ok((value, bytes_needed))
}

///|
/// Pack signed decimal text using a trailing C/D sign nibble.
pub fn bcd_pack_signed(field : Int, text : String) -> Result[Bytes, IsoError] {
  if text.length() < 2 {
    return Err(InvalidNumeric(field, text))
  }
  let negative = text[0] == '-'
  let positive = text[0] == '+'
  if !negative && !positive {
    return Err(InvalidNumeric(field, text))
  }
  let digits = text[1:].to_owned()
  match validate_digits(field, digits) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let nibbles : Array[Int] = []
  if digits.length() % 2 == 0 {
    nibbles.push(0)
  }
  for i = 0; i < digits.length(); i = i + 1 {
    nibbles.push(digits[i].to_int() - 48)
  }
  nibbles.push(if negative { 13 } else { 12 })
  let out : Array[Byte] = []
  let mut index = 0
  while index < nibbles.length() {
    out.push(((nibbles[index] << 4) | nibbles[index + 1]).to_byte())
    index += 2
  }
  Ok(Bytes::from_array(out))
}

///|
/// Decode signed BCD text using a trailing C/D sign nibble.
pub fn bcd_unpack_signed(
  field : Int,
  data : Bytes,
  digits : Int,
) -> Result[String, IsoError] {
  let expected = (digits + 2) / 2
  if digits <= 0 || data.length() != expected {
    return Err(InvalidLength(field, expected, data.length()))
  }
  let nibbles : Array[Int] = []
  for byte in data {
    nibbles.push((byte.to_int() >> 4) & 15)
    nibbles.push(byte.to_int() & 15)
  }
  let digit_start = if digits % 2 == 0 { 1 } else { 0 }
  if digit_start == 1 && nibbles[0] != 0 {
    return Err(InvalidBcd(0, nibbles[0]))
  }
  let sign = nibbles[nibbles.length() - 1]
  let out = StringBuilder()
  if sign == 13 {
    out.write_char('-')
  } else if sign == 12 || sign == 15 {
    out.write_char('+')
  } else {
    return Err(InvalidBcd(nibbles.length() - 1, sign))
  }
  for i = digit_start; i < nibbles.length() - 1; i = i + 1 {
    let nibble = nibbles[i]
    if nibble > 9 {
      return Err(InvalidBcd(i, nibble))
    }
    out.write_char((48 + nibble).unsafe_to_char())
  }
  Ok(out.to_string())
}
