///|
test "BCD packs even and odd digit counts" {
  assert_eq(hex_encode(bcd_pack_digits(2, "1234", true, 0).unwrap()), "1234")
  assert_eq(hex_encode(bcd_pack_digits(2, "123", true, 0).unwrap()), "0123")
  assert_eq(hex_encode(bcd_pack_digits(2, "123", false, 15).unwrap()), "123F")
  assert_eq(
    bcd_unpack_digits(2, hex_decode("0123").unwrap(), 3, true, 0).unwrap(),
    "123",
  )
  assert_eq(
    bcd_unpack_digits(2, hex_decode("123F").unwrap(), 3, false, 15).unwrap(),
    "123",
  )
}

///|
test "BCD length prefixes cover LLVAR and LLLVAR" {
  assert_eq(hex_encode(bcd_pack_length(19, 2).unwrap()), "19")
  assert_eq(hex_encode(bcd_pack_length(255, 3).unwrap()), "0255")
  assert_eq(
    bcd_unpack_length(hex_decode("0255").unwrap(), 0, 3).unwrap(),
    (255, 2),
  )
}

///|
test "signed BCD round trip preserves sign" {
  let negative = bcd_pack_signed(54, "-12345").unwrap()
  assert_eq(bcd_unpack_signed(54, negative, 5).unwrap(), "-12345")
  let positive = bcd_pack_signed(54, "+1234").unwrap()
  assert_eq(bcd_unpack_signed(54, positive, 4).unwrap(), "+1234")
}
