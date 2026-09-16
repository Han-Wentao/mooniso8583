///|
test "DE55 parses primitive EMV tags and round trips" {
  let value = "9F260811223344556677889F2701809F100706010A03A00000"
  let nodes = parse_de55(value).unwrap()
  assert_eq(nodes.length(), 3)
  assert_eq(nodes[0].tag, "9F26")
  assert_eq(hex_encode(nodes[0].value), "1122334455667788")
  assert_eq(find_tlv(nodes, "9f27").unwrap().tag, "9F27")
  assert_eq(format_de55(nodes), Ok(value))
}

///|
test "BER-TLV supports constructed tags and recursive lookup" {
  let nodes = parse_de55("E10A5A081234567890123456").unwrap()
  assert_eq(nodes.length(), 1)
  assert_true(nodes[0].constructed)
  assert_eq(nodes[0].children.length(), 1)
  assert_eq(
    find_tlv(nodes, "5A").map(fn(node) { hex_encode(node.value) }),
    Some("1234567890123456"),
  )
  assert_eq(count_tlv_nodes(nodes), 2)
  assert_eq(format_de55(nodes), Ok("E10A5A081234567890123456"))
}

///|
test "BER-TLV encodes long definite lengths canonically" {
  let value = Bytes::make(130, 0xAB)
  let node = primitive_tlv("9F10", value).unwrap()
  let encoded = encode_ber_tlv([node]).unwrap()
  assert_eq(hex_encode(Bytes::makei(5, fn(i) { encoded[i] })), "9F108182AB")
  assert_eq(decode_ber_tlv(encoded).unwrap()[0].value.length(), 130)
}

///|
test "BER-TLV constructors enforce primitive and constructed tag bits" {
  let pan = primitive_tlv_hex("5A", "1234567890123456").unwrap()
  let outer = constructed_tlv("E1", [pan]).unwrap()
  assert_eq(format_de55([outer]), Ok("E10A5A081234567890123456"))
  match primitive_tlv_hex("E1", "00") {
    Err(InvalidTlv(_)) => ()
    _ => fail("constructed tag should be rejected by primitive constructor")
  }
}

///|
test "BER-TLV rejects indefinite non-minimal and truncated encodings" {
  let invalid = [
    "5A8012340000",
    "5A817F" + "00".repeat(127),
    "9F80010100",
    "9F26081122",
    "00",
  ]
  for value in invalid {
    match parse_de55(value) {
      Err(InvalidTlv(_)) => ()
      _ => fail("expected strict BER-TLV rejection for \{value}")
    }
  }
}

///|
test "BER-TLV flatten preserves primitive wire order" {
  let nodes = parse_de55("E10A5A0812345678901234569F270180").unwrap()
  let flat = flatten_primitive_tlv(nodes)
  assert_eq(flat, [("5A", "1234567890123456"), ("9F27", "80")])
  assert_eq(find_all_tlv(parse_de55("5A01015A0102").unwrap(), "5A").length(), 2)
}
