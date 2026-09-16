///|
/// PAN validation and Track 2 payment data helpers.
pub(all) struct PanInfo {
  digits : String
  length : Int
  issuer_prefix : String
  masked : String
} derive(Eq, Debug)

///|
/// Parsed Track 2 data.
pub(all) struct Track2 {
  pan : String
  expiration : String
  service_code : String
  discretionary : String
  separator : UInt16
} derive(Eq, Debug)

///|
/// Validate a PAN with length and Luhn constraints.
pub fn parse_pan(value : String) -> Result[PanInfo, IsoError] {
  if value.length() < 12 || value.length() > 19 {
    return Err(InvalidPan(value))
  }
  match validate_numeric_text(2, value) {
    Err(_) => return Err(InvalidPan(value))
    Ok(_) => ()
  }
  if !pan_luhn_valid(value) {
    return Err(InvalidPan(value))
  }
  let prefix_length = if value.length() >= 6 { 6 } else { value.length() }
  Ok({
    digits: value,
    length: value.length(),
    issuer_prefix: value[0:prefix_length].to_owned(),
    masked: mask_pan(value),
  })
}

///|
/// Check the Luhn checksum of a numeric PAN.
pub fn pan_luhn_valid(value : String) -> Bool {
  if value.length() == 0 {
    return false
  }
  let mut sum = 0
  let mut double_digit = false
  let mut i = value.length() - 1
  while i >= 0 {
    let digit = value[i].to_int() - 48
    if digit < 0 || digit > 9 {
      return false
    }
    let adjusted = if double_digit {
      let doubled = digit * 2
      if doubled > 9 {
        doubled - 9
      } else {
        doubled
      }
    } else {
      digit
    }
    sum += adjusted
    double_digit = !double_digit
    i -= 1
  }
  sum % 10 == 0
}

///|
/// Produce a log-safe PAN mask while preserving the first six and last four digits.
pub fn mask_pan(value : String) -> String {
  if value.length() <= 10 {
    let out = StringBuilder()
    for _ in 0..<value.length() {
      out.write_char('*')
    }
    return out.to_string()
  }
  let out = StringBuilder()
  out.write_string(value[0:6].to_owned())
  for _ in 0..<(value.length() - 10) {
    out.write_char('*')
  }
  out.write_string(value[value.length() - 4:].to_owned())
  out.to_string()
}

///|
/// Find the Track 2 separator position.
fn track2_separator(value : String) -> Int? {
  for i = 0; i < value.length(); i = i + 1 {
    if value[i] == '=' || value[i] == 'D' {
      return Some(i)
    }
  }
  None
}

///|
/// Parse PAN, expiry, service code and discretionary data from Track 2.
pub fn parse_track2(value : String) -> Result[Track2, IsoError] {
  let separator_position = match track2_separator(value) {
    Some(position) => position
    None => return Err(InvalidTrack2("missing separator"))
  }
  if separator_position < 12 || separator_position > 19 {
    return Err(InvalidTrack2("PAN length is outside 12..19"))
  }
  for i = 0; i < value.length(); i = i + 1 {
    let c = value[i]
    if i == separator_position {
      continue
    }
    if !ascii_digit(c) {
      return Err(InvalidTrack2("non-decimal Track 2 character"))
    }
  }
  let tail_length = value.length() - separator_position - 1
  if tail_length < 7 {
    return Err(InvalidTrack2("expiry and service code are incomplete"))
  }
  let pan = value[0:separator_position].to_owned()
  let tail = value[separator_position + 1:].to_owned()
  match parse_pan(pan) {
    Err(_) => return Err(InvalidTrack2("PAN checksum failed"))
    Ok(_) => ()
  }
  Ok({
    pan,
    expiration: tail[0:4].to_owned(),
    service_code: tail[4:7].to_owned(),
    discretionary: tail[7:].to_owned(),
    separator: value[separator_position],
  })
}

///|
/// Render Track 2 with a canonical '=' separator.
pub fn Track2::to_string(self : Track2) -> String {
  self.pan + "=" + self.expiration + self.service_code + self.discretionary
}

///|
/// Render a masked Track 2 value for diagnostics.
pub fn Track2::masked(self : Track2) -> String {
  mask_pan(self.pan) +
  "=" +
  self.expiration +
  self.service_code +
  self.discretionary
}

///|
/// Replace the separator and preserve the other Track 2 components.
pub fn Track2::with_separator(
  self : Track2,
  separator : UInt16,
) -> Result[Track2, IsoError] {
  if separator != '=' && separator != 'D' {
    return Err(InvalidTrack2("separator must be '=' or 'D'"))
  }
  Ok({
    pan: self.pan,
    expiration: self.expiration,
    service_code: self.service_code,
    discretionary: self.discretionary,
    separator,
  })
}

///|
/// Pack Track 2 into BCD nibbles using D as separator and F as pad.
pub fn track2_to_bcd(value : Track2) -> Result[Bytes, IsoError] {
  let text = value.to_string()
  let separator_position = match track2_separator(text) {
    Some(position) => position
    None => return Err(InvalidTrack2("missing separator"))
  }
  let nibbles : Array[Int] = []
  for i = 0; i < text.length(); i = i + 1 {
    if i == separator_position {
      nibbles.push(13)
    } else {
      nibbles.push(text[i].to_int() - 48)
    }
  }
  if nibbles.length() % 2 == 1 {
    nibbles.push(15)
  }
  let bytes : Array[Byte] = []
  let mut i = 0
  while i < nibbles.length() {
    bytes.push(((nibbles[i] << 4) | nibbles[i + 1]).to_byte())
    i += 2
  }
  Ok(Bytes::from_array(bytes))
}

///|
/// Decode Track 2 BCD nibbles, accepting either D or '=' in the API.
pub fn track2_from_bcd(data : Bytes) -> Result[Track2, IsoError] {
  if data.length() == 0 {
    return Err(InvalidTrack2("empty BCD data"))
  }
  let out = StringBuilder()
  let mut separator_count = 0
  for i = 0; i < data.length(); i = i + 1 {
    let value = data[i].to_int()
    let high = (value >> 4) & 15
    let low = value & 15
    for nibble_index = 0; nibble_index < 2; nibble_index = nibble_index + 1 {
      let nibble = if nibble_index == 0 { high } else { low }
      if nibble == 13 {
        out.write_char('=')
        separator_count += 1
      } else if nibble == 15 && i == data.length() - 1 && nibble_index == 1 {
        ()
      } else if nibble <= 9 {
        out.write_char((48 + nibble).unsafe_to_char())
      } else {
        return Err(InvalidTrack2("invalid BCD nibble"))
      }
    }
  }
  if separator_count != 1 {
    return Err(InvalidTrack2("expected one BCD separator"))
  }
  parse_track2(out.to_string())
}

///|
/// Extract the issuer identification number prefix from a valid PAN.
pub fn pan_issuer_prefix(value : String) -> Result[String, IsoError] {
  match parse_pan(value) {
    Ok(info) => Ok(info.issuer_prefix)
    Err(error) => Err(error)
  }
}

///|
/// Compare two PANs without exposing their digits to callers.
pub fn pan_equal(left : String, right : String) -> Bool {
  bytes_equal(text_to_ascii(2, left).unwrap(), text_to_ascii(2, right).unwrap())
}
