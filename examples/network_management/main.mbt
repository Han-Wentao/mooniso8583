///|
fn main raise {
  let packager = @iso.iso1987_packager()
  let sign_on = @iso.message("0800").unwrap()
  sign_on.set_field(7, "0916123456").unwrap()
  sign_on.set_field(11, "000001").unwrap()
  sign_on.set_field(70, "001").unwrap()
  assert_eq(
    @iso.validate_message_template(
      sign_on,
      @iso.network_management_request_template(),
    ).length(),
    0,
  )
  let frame = @iso.pack_framed_message(
    packager,
    @iso.ascii_binary_profile(),
    @iso.BinaryBigEndian16,
    sign_on,
  ).unwrap()
  let received = @iso.unpack_framed_message(
    packager,
    @iso.ascii_binary_profile(),
    @iso.BinaryBigEndian16,
    frame,
  ).unwrap()
  assert_eq(
    @iso.parse_network_management_code(received.field(70).unwrap()),
    Ok(@iso.SignOn),
  )
  let response = @iso.response_skeleton(received, "00").unwrap()
  assert_true(@iso.response_correlates(received, response))
  let response_frame = @iso.pack_framed_message(
    packager,
    @iso.ascii_binary_profile(),
    @iso.BinaryBigEndian16,
    response,
  ).unwrap()
  println("0800 frame bytes=\{frame.length()}")
  println("0810 frame bytes=\{response_frame.length()}")
  println(@iso.safe_message_dump(response, packager))
}
