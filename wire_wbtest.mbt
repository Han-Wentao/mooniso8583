///|
fn mini_packager() -> Packager {
  packager("mini", [
    llvar_ascii(2, "PAN", 19, Numeric),
    fixed_numeric(3, "Processing code", 6),
    fixed_numeric(4, "Amount", 12),
    fixed_numeric(11, "STAN", 6),
    fixed_ascii(41, "Terminal ID", 8, Alphanumeric),
    fixed_numeric(49, "Currency", 3),
    fixed_numeric(70, "Network code", 3),
  ]).unwrap()
}

///|
fn sample_message() -> IsoMessage {
  let msg = message("0200").unwrap()
  msg.set_field(2, "6222021234567890").unwrap()
  msg.set_field(3, "000000").unwrap()
  msg.set_field(4, "1234").unwrap()
  msg.set_field(11, "123456").unwrap()
  msg.set_field(41, "TERM0001").unwrap()
  msg.set_field(49, "156").unwrap()
  msg
}

///|
test "complete message round trip supports binary bitmap" {
  let pkg = mini_packager()
  let original = sample_message()
  let wire = pack_message(pkg, ascii_binary_profile(), original).unwrap()
  let decoded = unpack_message(pkg, ascii_binary_profile(), wire).unwrap()
  assert_eq(decoded.mti, "0200")
  assert_eq(decoded.field(2), Some("6222021234567890"))
  assert_eq(decoded.field(4), Some("000000001234"))
  assert_eq(decoded.field(41), Some("TERM0001"))
}

///|
test "ASCII hexadecimal bitmap profile round trips" {
  let pkg = mini_packager()
  let original = sample_message()
  let wire = pack_message(pkg, ascii_hex_profile(), original).unwrap()
  assert_eq(wire[4].to_int(), '7'.to_int())
  let decoded = unpack_message(pkg, ascii_hex_profile(), wire).unwrap()
  assert_eq(decoded.field_numbers(), [2, 3, 4, 11, 41, 49])
}

///|
test "BCD MTI and secondary bitmap round trip" {
  let pkg = mini_packager()
  let msg = message("0800").unwrap()
  msg.set_field(11, "000123").unwrap()
  msg.set_field(70, "001").unwrap()
  let wire = pack_message(pkg, bcd_binary_profile(), msg).unwrap()
  assert_eq(hex_encode(bytes_slice(wire, 0, 2)), "0800")
  let decoded = unpack_message(pkg, bcd_binary_profile(), wire).unwrap()
  assert_eq(decoded.field(70), Some("001"))
}

///|
test "strict decoder rejects trailing bytes and stream mode reports consumption" {
  let pkg = mini_packager()
  let wire = pack_message(pkg, ascii_binary_profile(), sample_message()).unwrap()
  let extended = concat_bytes(wire, hex_decode("00FF").unwrap())
  match unpack_message(pkg, ascii_binary_profile(), extended) {
    Err(TrailingBytes(2)) => ()
    _ => fail("expected trailing byte error")
  }
  let decoded = unpack_message_with_result(
    pkg,
    ascii_binary_profile().allow_trailing(),
    extended,
  ).unwrap()
  assert_eq(decoded.consumed, wire.length())
}
