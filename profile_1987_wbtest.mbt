///|
test "ISO 1987 profile covers the complete data element range" {
  let specs = iso1987_specs()
  assert_eq(specs.length(), 127)
  assert_eq(specs[0].number, 2)
  assert_eq(specs[126].number, 128)
  assert_eq(iso1987_variable_field_count() > 40, true)
  assert_eq(require_iso1987_field(55).unwrap().data_kind, BinaryHex)
}

///|
test "standard profile packs a secondary-bitmap network message" {
  let pkg = iso1987_packager()
  let msg = message("0800").unwrap()
  msg.set_field(7, "0916123456").unwrap()
  msg.set_field(11, "000123").unwrap()
  msg.set_field(70, "001").unwrap()
  let wire = pack_message(pkg, ascii_binary_profile(), msg).unwrap()
  let decoded = unpack_message(pkg, ascii_binary_profile(), wire).unwrap()
  assert_eq(decoded.field(70), Some("001"))
}

///|
test "BCD numeric variant changes numeric field representation" {
  let pkg = iso1987_bcd_packager().unwrap()
  let msg = message("0200").unwrap()
  msg.set_field(3, "000000").unwrap()
  msg.set_field(4, "000000001234").unwrap()
  msg.set_field(11, "000123").unwrap()
  let wire = pack_message(pkg, bcd_binary_profile(), msg).unwrap()
  let decoded = unpack_message(pkg, bcd_binary_profile(), wire).unwrap()
  assert_eq(decoded.field(4), Some("000000001234"))
}
