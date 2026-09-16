///|
test "ASCII fixed and LLVAR fields encode with exact prefixes" {
  let amount = fixed_numeric(4, "Amount", 12)
  let encoded_amount = encode_field(amount, "1234").unwrap()
  assert_eq(ascii_to_text(4, encoded_amount.bytes).unwrap(), "000000001234")
  let pan = llvar_ascii(2, "PAN", 19, Numeric)
  let encoded_pan = encode_field(pan, "6222021234567890").unwrap()
  assert_eq(ascii_to_text(2, encoded_pan.bytes).unwrap(), "166222021234567890")
  assert_eq(
    decode_field(pan, encoded_pan.bytes, 0).unwrap().value,
    "6222021234567890",
  )
}

///|
test "BCD fields preserve odd digit counts" {
  let pan = llvar_bcd_numeric(2, "PAN", 19)
  let encoded = encode_field(pan, "123456789012345").unwrap()
  assert_eq(hex_encode(encoded.bytes), "150123456789012345")
  let decoded = decode_field(pan, encoded.bytes, 0).unwrap()
  assert_eq(decoded.value, "123456789012345")
  assert_eq(decoded.consumed, encoded.bytes.length())
}

///|
test "binary LLLVAR length counts bytes not hex characters" {
  let icc = lllvar_bcd_binary(55, "ICC data", 255)
  let encoded = encode_field(icc, "9F0206000000000100").unwrap()
  assert_eq(hex_encode(encoded.bytes), "00099F0206000000000100")
  let decoded = decode_field(icc, encoded.bytes, 0).unwrap()
  assert_eq(decoded.logical_length, 9)
  assert_eq(decoded.value, "9F0206000000000100")
}

///|
test "decoder rejects advertised length beyond available data" {
  let pan = llvar_ascii(2, "PAN", 19, Numeric)
  let data = text_to_ascii(2, "191234").unwrap()
  match decode_field(pan, data, 0) {
    Err(Truncated(_, 19, 4)) => ()
    _ => fail("expected truncated field")
  }
}
