///|
/// One BER-TLV node as used by EMV data in ISO 8583 field 55.
pub(all) struct BerTlv {
  tag : String
  value : Bytes
  constructed : Bool
  children : Array[BerTlv]
} derive(Debug)

///|
/// Internal result returned after reading one BER tag.
priv struct BerTagResult {
  text : String
  constructed : Bool
  next : Int
}

///|
/// Internal result returned after reading a BER definite length.
priv struct BerLengthResult {
  length : Int
  next : Int
}

///|
/// Parse hexadecimal DE55 text into a BER-TLV tree.
pub fn parse_de55(value : String) -> Result[Array[BerTlv], IsoError] {
  let data = match hex_decode(value) {
    Ok(bytes) => bytes
    Err(_) =>
      return Err(InvalidTlv("DE55 must be even-length hexadecimal text"))
  }
  decode_ber_tlv(data)
}

///|
/// Decode a complete byte string containing one or more BER-TLV nodes.
pub fn decode_ber_tlv(data : Bytes) -> Result[Array[BerTlv], IsoError] {
  if data.length() == 0 {
    return Err(InvalidTlv("TLV sequence is empty"))
  }
  parse_tlv_range(data, 0, data.length(), 0)
}

///|
/// Parse all nodes in one exact byte range.
fn parse_tlv_range(
  data : Bytes,
  start : Int,
  end : Int,
  depth : Int,
) -> Result[Array[BerTlv], IsoError] {
  if depth > 16 {
    return Err(InvalidTlv("constructed TLV nesting exceeds 16 levels"))
  }
  let nodes : Array[BerTlv] = []
  let mut offset = start
  while offset < end {
    let tag = match parse_ber_tag(data, offset, end) {
      Ok(result) => result
      Err(error) => return Err(error)
    }
    let length = match parse_ber_length(data, tag.next, end) {
      Ok(result) => result
      Err(error) => return Err(error)
    }
    let value_end = length.next + length.length
    if value_end > end {
      return Err(
        InvalidTlv(
          "tag \{tag.text} declares \{length.length} bytes but only \{end - length.next} remain",
        ),
      )
    }
    let value = tlv_slice(data, length.next, value_end)
    let children = if tag.constructed {
      if value.length() == 0 {
        return Err(InvalidTlv("constructed tag \{tag.text} has an empty value"))
      }
      match parse_tlv_range(data, length.next, value_end, depth + 1) {
        Ok(result) => result
        Err(error) => return Err(error)
      }
    } else {
      []
    }
    nodes.push({ tag: tag.text, value, constructed: tag.constructed, children, })
    offset = value_end
  }
  if offset != end {
    return Err(InvalidTlv("TLV range was not consumed exactly"))
  }
  Ok(nodes)
}

///|
/// Read and canonicalize one BER tag.
fn parse_ber_tag(
  data : Bytes,
  start : Int,
  end : Int,
) -> Result[BerTagResult, IsoError] {
  if start >= end {
    return Err(InvalidTlv("missing tag byte"))
  }
  let first = data[start].to_int()
  if first == 0 || first == 255 {
    return Err(InvalidTlv("00 and FF padding bytes are not valid tags"))
  }
  let constructed = (first & 0x20) != 0
  let mut next = start + 1
  if (first & 0x1F) == 0x1F {
    if next >= end {
      return Err(InvalidTlv("truncated high-tag-number form"))
    }
    let first_continuation = data[next].to_int()
    if (first_continuation & 0x7F) == 0 {
      return Err(InvalidTlv("non-minimal high-tag-number form"))
    }
    let mut terminated = false
    let mut count = 1
    while next < end && count < 4 {
      let current = data[next].to_int()
      next += 1
      count += 1
      if (current & 0x80) == 0 {
        terminated = true
        break
      }
    }
    if !terminated {
      if next >= end {
        return Err(InvalidTlv("unterminated high-tag-number form"))
      }
      return Err(InvalidTlv("BER tag exceeds four bytes"))
    }
  }
  let bytes = tlv_slice(data, start, next)
  Ok({ text: hex_encode(bytes), constructed, next, })
}

///|
/// Read a BER short or long definite length.
fn parse_ber_length(
  data : Bytes,
  start : Int,
  end : Int,
) -> Result[BerLengthResult, IsoError] {
  if start >= end {
    return Err(InvalidTlv("missing length byte"))
  }
  let first = data[start].to_int()
  if first < 128 {
    return Ok({ length: first, next: start + 1, })
  }
  if first == 128 {
    return Err(InvalidTlv("indefinite length is not supported"))
  }
  let count = first & 0x7F
  if count == 0 || count > 4 {
    return Err(InvalidTlv("long-form length must use one to four bytes"))
  }
  if start + 1 + count > end {
    return Err(InvalidTlv("truncated long-form length"))
  }
  if data[start + 1].to_int() == 0 {
    return Err(InvalidTlv("long-form length has a leading zero"))
  }
  let mut length = 0
  for i = 0; i < count; i = i + 1 {
    let byte = data[start + 1 + i].to_int()
    if length > 0x7FFFFF {
      return Err(InvalidTlv("declared length exceeds supported range"))
    }
    length = (length << 8) | byte
  }
  if length < 128 {
    return Err(InvalidTlv("long-form length is not minimally encoded"))
  }
  Ok({ length, next: start + 1 + count, })
}

///|
/// Construct a primitive TLV after validating the tag form.
pub fn primitive_tlv(tag : String, value : Bytes) -> Result[BerTlv, IsoError] {
  let tag_bytes = match hex_decode(tag) {
    Ok(bytes) => bytes
    Err(_) => return Err(InvalidTlv("tag must be hexadecimal"))
  }
  let parsed = match parse_ber_tag(tag_bytes, 0, tag_bytes.length()) {
    Ok(result) => result
    Err(error) => return Err(error)
  }
  if parsed.next != tag_bytes.length() {
    return Err(InvalidTlv("tag text contains more than one tag"))
  }
  if parsed.constructed {
    return Err(InvalidTlv("constructed tag requires child TLVs"))
  }
  Ok({ tag: parsed.text, value, constructed: false, children: [], })
}

///|
/// Construct a primitive TLV from hexadecimal value text.
pub fn primitive_tlv_hex(
  tag : String,
  value : String,
) -> Result[BerTlv, IsoError] {
  let bytes = match hex_decode(value) {
    Ok(result) => result
    Err(_) => return Err(InvalidTlv("TLV value must be hexadecimal"))
  }
  primitive_tlv(tag, bytes)
}

///|
/// Construct a BER constructed node and derive its encoded value.
pub fn constructed_tlv(
  tag : String,
  children : Array[BerTlv],
) -> Result[BerTlv, IsoError] {
  if children.length() == 0 {
    return Err(InvalidTlv("constructed TLV needs at least one child"))
  }
  let tag_bytes = match hex_decode(tag) {
    Ok(bytes) => bytes
    Err(_) => return Err(InvalidTlv("tag must be hexadecimal"))
  }
  let parsed = match parse_ber_tag(tag_bytes, 0, tag_bytes.length()) {
    Ok(result) => result
    Err(error) => return Err(error)
  }
  if parsed.next != tag_bytes.length() {
    return Err(InvalidTlv("tag text contains more than one tag"))
  }
  if !parsed.constructed {
    return Err(InvalidTlv("primitive tag cannot contain child TLVs"))
  }
  let value = match encode_ber_tlv(children) {
    Ok(result) => result
    Err(error) => return Err(error)
  }
  Ok({ tag: parsed.text, value, constructed: true, children, })
}

///|
/// Encode a complete BER-TLV sequence.
pub fn encode_ber_tlv(nodes : Array[BerTlv]) -> Result[Bytes, IsoError] {
  if nodes.length() == 0 {
    return Err(InvalidTlv("TLV sequence is empty"))
  }
  let output : Array[Byte] = []
  for node in nodes {
    match encode_tlv_node(node, output, 0) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
  }
  Ok(Bytes::from_array(output))
}

///|
/// Encode one node recursively into a caller-owned output buffer.
fn encode_tlv_node(
  node : BerTlv,
  output : Array[Byte],
  depth : Int,
) -> Result[Unit, IsoError] {
  if depth > 16 {
    return Err(InvalidTlv("constructed TLV nesting exceeds 16 levels"))
  }
  let tag = match hex_decode(node.tag) {
    Ok(bytes) => bytes
    Err(_) => return Err(InvalidTlv("node tag must be hexadecimal"))
  }
  let parsed = match parse_ber_tag(tag, 0, tag.length()) {
    Ok(result) => result
    Err(error) => return Err(error)
  }
  if parsed.next != tag.length() {
    return Err(InvalidTlv("node tag contains trailing bytes"))
  }
  if parsed.constructed != node.constructed {
    return Err(InvalidTlv("tag constructed bit disagrees with node type"))
  }
  let value = if node.constructed {
    if node.children.length() == 0 {
      return Err(InvalidTlv("constructed node has no children"))
    }
    let nested : Array[Byte] = []
    for child in node.children {
      match encode_tlv_node(child, nested, depth + 1) {
        Err(error) => return Err(error)
        Ok(_) => ()
      }
    }
    Bytes::from_array(nested)
  } else {
    if node.children.length() != 0 {
      return Err(InvalidTlv("primitive node cannot have children"))
    }
    node.value
  }
  append_tlv_bytes(output, tag)
  match append_ber_length(output, value.length()) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  append_tlv_bytes(output, value)
  Ok(())
}

///|
/// Append a canonical BER definite length.
fn append_ber_length(
  output : Array[Byte],
  length : Int,
) -> Result[Unit, IsoError] {
  if length < 0 {
    return Err(InvalidTlv("negative length"))
  }
  if length < 128 {
    output.push(length.to_byte())
    return Ok(())
  }
  let encoded : Array[Byte] = []
  let mut remaining = length
  while remaining > 0 {
    encoded.push((remaining & 255).to_byte())
    remaining = remaining >> 8
  }
  if encoded.length() > 4 {
    return Err(InvalidTlv("value exceeds four-byte BER length range"))
  }
  output.push((128 | encoded.length()).to_byte())
  let mut i = encoded.length()
  while i > 0 {
    i -= 1
    output.push(encoded[i])
  }
  Ok(())
}

///|
/// Encode a TLV tree as uppercase DE55 hexadecimal text.
pub fn format_de55(nodes : Array[BerTlv]) -> Result[String, IsoError] {
  match encode_ber_tlv(nodes) {
    Ok(bytes) => Ok(hex_encode(bytes))
    Err(error) => Err(error)
  }
}

///|
/// Return the first node with a canonical hexadecimal tag, depth-first.
pub fn find_tlv(nodes : Array[BerTlv], tag : String) -> BerTlv? {
  let wanted = tag.to_upper()
  for node in nodes {
    if node.tag == wanted {
      return Some(node)
    }
    if node.constructed {
      match find_tlv(node.children, wanted) {
        Some(found) => return Some(found)
        None => ()
      }
    }
  }
  None
}

///|
/// Return every matching node in depth-first wire order.
pub fn find_all_tlv(nodes : Array[BerTlv], tag : String) -> Array[BerTlv] {
  let output : Array[BerTlv] = []
  collect_tlv(nodes, tag.to_upper(), output)
  output
}

///|
fn collect_tlv(
  nodes : Array[BerTlv],
  tag : String,
  output : Array[BerTlv],
) -> Unit {
  for node in nodes {
    if node.tag == tag {
      output.push(node)
    }
    if node.constructed {
      collect_tlv(node.children, tag, output)
    }
  }
}

///|
/// Count all primitive and constructed nodes recursively.
pub fn count_tlv_nodes(nodes : Array[BerTlv]) -> Int {
  let mut count = 0
  for node in nodes {
    count += 1
    if node.constructed {
      count += count_tlv_nodes(node.children)
    }
  }
  count
}

///|
/// Return hexadecimal values for all primitive nodes in wire order.
pub fn flatten_primitive_tlv(nodes : Array[BerTlv]) -> Array[(String, String)] {
  let output : Array[(String, String)] = []
  flatten_tlv_into(nodes, output)
  output
}

///|
fn flatten_tlv_into(
  nodes : Array[BerTlv],
  output : Array[(String, String)],
) -> Unit {
  for node in nodes {
    if node.constructed {
      flatten_tlv_into(node.children, output)
    } else {
      output.push((node.tag, hex_encode(node.value)))
    }
  }
}

///|
/// Copy a byte range for TLV values and tag parsing.
fn tlv_slice(data : Bytes, start : Int, end : Int) -> Bytes {
  Bytes::makei(end - start, fn(i) { data[start + i] })
}

///|
/// Append immutable bytes to a mutable byte buffer.
fn append_tlv_bytes(target : Array[Byte], source : Bytes) -> Unit {
  for byte in source {
    target.push(byte)
  }
}
