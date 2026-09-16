///|
fn main raise {
  let packager = @iso.iso1987_packager()
  let request = @iso.message("0100").unwrap()
  request.set_field(2, "6222021234567890").unwrap()
  request.set_field(3, "000000").unwrap()
  request.set_field(4, "000000001500").unwrap()
  request.set_field(7, "0916123456").unwrap()
  request.set_field(11, "123456").unwrap()
  request.set_field(14, "2912").unwrap()
  request.set_field(22, "051").unwrap()
  request.set_field(41, "TERM0001").unwrap()
  request.set_field(42, "MERCHANT0000001").unwrap()
  request.set_field(49, "156").unwrap()
  request.set_field(55, "9F260811223344556677889F270180").unwrap()
  let template_issues = @iso.validate_known_message_template(request).unwrap()
  assert_eq(template_issues.length(), 0)
  let request_wire = @iso.pack_message(
    packager,
    @iso.ascii_binary_profile(),
    request,
  ).unwrap()
  let received = @iso.unpack_message(
    packager,
    @iso.ascii_binary_profile(),
    request_wire,
  ).unwrap()
  let response = @iso.response_skeleton(received, "00").unwrap()
  response.set_field(38, "A12345").unwrap()
  assert_true(@iso.response_correlates(received, response))
  println("authorization request bytes=\{request_wire.length()}")
  println(@iso.safe_message_dump(received, packager))
  println(@iso.safe_message_dump(response, packager))
}
