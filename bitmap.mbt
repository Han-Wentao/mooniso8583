///|
/// ISO 8583 primary or primary+secondary bitmap.
pub(all) struct Bitmap {
  bytes : Bytes
} derive(Eq, Debug)

///|
/// Create an empty primary bitmap.
pub fn bitmap_empty() -> Bitmap {
  { bytes: Bytes::make(8, (0).to_byte()), }
}

///|
/// Create a bitmap from validated raw bytes.
pub fn bitmap_from_bytes(data : Bytes) -> Result[Bitmap, IsoError] {
  if data.length() != 8 && data.length() != 16 {
    return Err(InvalidBitmapLength(data.length()))
  }
  let copy = bytes_slice(data, 0, data.length())
  if copy.length() == 8 && (copy[0].to_int() & 128) != 0 {
    return Err(InvalidBitmapLength(8))
  }
  if copy.length() == 16 && (copy[0].to_int() & 128) == 0 {
    return Err(InvalidBitmapLength(16))
  }
  Ok({ bytes: copy, })
}

///|
/// Build a bitmap from data-element numbers.
pub fn bitmap_from_fields(fields : Array[Int]) -> Result[Bitmap, IsoError] {
  let mut secondary = false
  for field in fields {
    if field == 1 {
      return Err(BitmapFieldOneReserved)
    }
    if field < 2 || field > 128 {
      return Err(InvalidFieldNumber(field))
    }
    if field > 64 {
      secondary = true
    }
  }
  let size = if secondary { 16 } else { 8 }
  let raw : Array[Byte] = []
  for _ in 0..<size {
    raw.push((0).to_byte())
  }
  if secondary {
    raw[0] = (128).to_byte()
  }
  for field in fields {
    let offset = field - 1
    let byte_index = offset / 8
    let bit_index = offset % 8
    raw[byte_index] = (raw[byte_index].to_int() | (128 >> bit_index)).to_byte()
  }
  Ok({ bytes: Bytes::from_array(raw), })
}

///|
/// Build the wire bitmap for a message.
pub fn IsoMessage::bitmap(self : IsoMessage) -> Result[Bitmap, IsoError] {
  bitmap_from_fields(self.field_numbers())
}

///|
/// Raw bitmap bytes suitable for binary bitmap profiles.
pub fn Bitmap::to_bytes(self : Bitmap) -> Bytes {
  bytes_slice(self.bytes, 0, self.bytes.length())
}

///|
/// Uppercase hexadecimal bitmap text.
pub fn Bitmap::to_hex(self : Bitmap) -> String {
  hex_encode(self.bytes)
}

///|
/// Parse a hexadecimal primary or extended bitmap.
pub fn bitmap_from_hex(text : String) -> Result[Bitmap, IsoError] {
  if text.length() != 16 && text.length() != 32 {
    return Err(InvalidBitmapLength(text.length() / 2))
  }
  match hex_decode(text) {
    Err(error) => Err(error)
    Ok(data) => bitmap_from_bytes(data)
  }
}

///|
/// True when the data element is present.
pub fn Bitmap::has(self : Bitmap, field : Int) -> Bool {
  if field < 1 || field > self.bytes.length() * 8 {
    return false
  }
  let offset = field - 1
  let byte_index = offset / 8
  let bit_index = offset % 8
  (self.bytes[byte_index].to_int() & (128 >> bit_index)) != 0
}

///|
/// Whether a secondary bitmap follows the primary bitmap.
pub fn Bitmap::has_secondary(self : Bitmap) -> Bool {
  self.bytes.length() == 16 && self.has(1)
}

///|
/// Number of bytes occupied by this bitmap.
pub fn Bitmap::byte_length(self : Bitmap) -> Int {
  self.bytes.length()
}

///|
/// Return populated data-element numbers, excluding bit 1.
pub fn Bitmap::fields(self : Bitmap) -> Array[Int] {
  let result : Array[Int] = []
  for field = 2; field <= self.bytes.length() * 8; field = field + 1 {
    if self.has(field) {
      result.push(field)
    }
  }
  result
}

///|
/// Return the number of populated data elements.
pub fn Bitmap::field_count(self : Bitmap) -> Int {
  let mut count = 0
  for byte_index = 0
      byte_index < self.bytes.length()
      byte_index = byte_index + 1 {
    let mut value = self.bytes[byte_index].to_int()
    if byte_index == 0 {
      value = value & 127
    }
    while value != 0 {
      count += value & 1
      value = value >> 1
    }
  }
  count
}

///|
/// Read a binary bitmap at an offset and report consumed bytes.
pub fn bitmap_decode_binary(
  data : Bytes,
  start : Int,
) -> Result[(Bitmap, Int), IsoError] {
  if start < 0 || start + 8 > data.length() {
    return Err(
      Truncated("primary bitmap", 8, Int::max(0, data.length() - start)),
    )
  }
  let extended = (data[start].to_int() & 128) != 0
  let length = if extended { 16 } else { 8 }
  if start + length > data.length() {
    return Err(
      Truncated("secondary bitmap", length, Int::max(0, data.length() - start)),
    )
  }
  let raw = bytes_slice(data, start, start + length)
  match bitmap_from_bytes(raw) {
    Ok(bitmap) => Ok((bitmap, length))
    Err(error) => Err(error)
  }
}

///|
/// Read an ASCII-hex bitmap at an offset and report consumed bytes.
pub fn bitmap_decode_ascii(
  data : Bytes,
  start : Int,
) -> Result[(Bitmap, Int), IsoError] {
  if start < 0 || start + 16 > data.length() {
    return Err(
      Truncated("ASCII primary bitmap", 16, Int::max(0, data.length() - start)),
    )
  }
  let primary_text = match
    ascii_to_text(1, bytes_slice(data, start, start + 16)) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  let primary = match hex_decode(primary_text) {
    Ok(bytes) => bytes
    Err(error) => return Err(error)
  }
  let extended = (primary[0].to_int() & 128) != 0
  let chars = if extended { 32 } else { 16 }
  if start + chars > data.length() {
    return Err(
      Truncated(
        "ASCII secondary bitmap",
        chars,
        Int::max(0, data.length() - start),
      ),
    )
  }
  let text = match ascii_to_text(1, bytes_slice(data, start, start + chars)) {
    Ok(text) => text
    Err(error) => return Err(error)
  }
  match bitmap_from_hex(text) {
    Ok(bitmap) => Ok((bitmap, chars))
    Err(error) => Err(error)
  }
}

///|
/// Encode a bitmap as uppercase ASCII hexadecimal bytes.
pub fn Bitmap::to_ascii_bytes(self : Bitmap) -> Bytes {
  text_to_ascii(1, self.to_hex()).unwrap()
}

///|
/// Compare a bitmap against the fields stored in a message.
pub fn Bitmap::matches_message(self : Bitmap, message : IsoMessage) -> Bool {
  let expected = match message.bitmap() {
    Ok(bitmap) => bitmap
    Err(_) => return false
  }
  bytes_equal(self.bytes, expected.bytes)
}
