///|
test "primary bitmap derives field bits" {
  let bitmap = bitmap_from_fields([2, 3, 4, 11, 41, 49]).unwrap()
  assert_eq(bitmap.byte_length(), 8)
  assert_true(bitmap.has(2))
  assert_true(bitmap.has(41))
  assert_false(bitmap.has(1))
  assert_eq(bitmap.fields(), [2, 3, 4, 11, 41, 49])
  assert_eq(bitmap.field_count(), 6)
}

///|
test "secondary bitmap sets bit one automatically" {
  let bitmap = bitmap_from_fields([3, 70, 90, 128]).unwrap()
  assert_eq(bitmap.byte_length(), 16)
  assert_true(bitmap.has_secondary())
  assert_true(bitmap.has(70))
  assert_true(bitmap.has(128))
  assert_eq(bitmap.fields(), [3, 70, 90, 128])
}

///|
test "binary and ASCII bitmap decoders consume exact bytes" {
  let bitmap = bitmap_from_fields([2, 3, 11, 70]).unwrap()
  let binary = bitmap.to_bytes()
  let decoded_binary = bitmap_decode_binary(binary, 0).unwrap()
  assert_eq(decoded_binary.0, bitmap)
  assert_eq(decoded_binary.1, 16)
  let ascii = bitmap.to_ascii_bytes()
  let decoded_ascii = bitmap_decode_ascii(ascii, 0).unwrap()
  assert_eq(decoded_ascii.0, bitmap)
  assert_eq(decoded_ascii.1, 32)
}

///|
test "bitmap validates extension indicator" {
  match bitmap_from_bytes(hex_decode("8000000000000000").unwrap()) {
    Err(InvalidBitmapLength(8)) => ()
    _ => fail("expected missing secondary bitmap error")
  }
}
