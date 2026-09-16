///|
fn main raise {
  let packager = @iso.iso1987_packager()
  let purchase = @iso.message("0200").unwrap()
  purchase.set_field(2, "6222021234567890").unwrap()
  purchase.set_field(3, "000000").unwrap()
  purchase.set_field(4, "000000005800").unwrap()
  purchase.set_field(7, "0916123456").unwrap()
  purchase.set_field(11, "234567").unwrap()
  purchase.set_field(22, "051").unwrap()
  purchase.set_field(32, "123456").unwrap()
  purchase.set_field(37, "609160234567").unwrap()
  purchase.set_field(41, "TERM0002").unwrap()
  purchase.set_field(42, "MERCHANT0000002").unwrap()
  purchase.set_field(49, "156").unwrap()
  let reversal = @iso.reversal_skeleton(purchase, "234568", "0916123656").unwrap()
  assert_eq(@iso.validate_reversal_correlation(purchase, reversal).length(), 0)
  assert_eq(
    @iso.validate_message_template(reversal, @iso.reversal_request_template()).length(),
    0,
  )
  let wire = @iso.pack_message(packager, @iso.ascii_binary_profile(), reversal).unwrap()
  let decoded = @iso.unpack_message(packager, @iso.ascii_binary_profile(), wire).unwrap()
  let original = @iso.parse_original_data(decoded.field(90).unwrap()).unwrap()
  println("reversal bytes=\{wire.length()}")
  println("DE90 original MTI=\{original.original_mti}")
  println("DE90 original STAN=\{original.original_stan}")
  println(@iso.safe_message_dump(decoded, packager))
}
