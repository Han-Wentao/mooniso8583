///|
fn ascii_bytes(text : String) -> Bytes {
  text_to_ascii(0, text).unwrap()
}

///|
test "binary two-byte frame round trip" {
  let framed = encode_frame(BinaryBigEndian16, ascii_bytes("HELLO")).unwrap()
  assert_eq(hex_encode(framed), "000548454C4C4F")
  let decoder = stream_decoder(BinaryBigEndian16, 1024).unwrap()
  let frames = decoder.feed(framed).unwrap()
  assert_eq(frames.length(), 1)
  assert_eq(ascii_to_text(0, frames[0]), Ok("HELLO"))
  assert_eq(decoder.finish(), Ok(()))
}

///|
test "ASCII4 frame round trip" {
  let framed = encode_frame(AsciiDecimal4, ascii_bytes("PING")).unwrap()
  assert_eq(ascii_to_text(0, framed), Ok("0004PING"))
  let decoder = stream_decoder(AsciiDecimal4, 9999).unwrap()
  let frames = decoder.feed(framed).unwrap()
  assert_eq(frames.map(fn(frame) { ascii_to_text(0, frame).unwrap() }), ["PING"])
}

///|
test "incremental decoder handles split headers and split payloads" {
  let decoder = stream_decoder(BinaryBigEndian16, 1024).unwrap()
  assert_eq(decoder.feed(hex_decode("00").unwrap()).unwrap().length(), 0)
  assert_eq(decoder.buffered_bytes(), 1)
  assert_eq(decoder.feed(hex_decode("054845").unwrap()).unwrap().length(), 0)
  assert_eq(decoder.feed(hex_decode("4C4C4F").unwrap()).unwrap().length(), 1)
  assert_eq(decoder.finish(), Ok(()))
}

///|
test "incremental decoder separates sticky packets" {
  let first = encode_frame(BinaryBigEndian16, ascii_bytes("ONE")).unwrap()
  let second = encode_frame(BinaryBigEndian16, ascii_bytes("TWO")).unwrap()
  let third = encode_frame(BinaryBigEndian16, ascii_bytes("THREE")).unwrap()
  let decoder = stream_decoder(BinaryBigEndian16, 1024).unwrap()
  let frames = decoder
    .feed(concat_bytes(concat_bytes(first, second), third))
    .unwrap()
  assert_eq(frames.length(), 3)
  assert_eq(ascii_to_text(0, frames[0]), Ok("ONE"))
  assert_eq(ascii_to_text(0, frames[1]), Ok("TWO"))
  assert_eq(ascii_to_text(0, frames[2]), Ok("THREE"))
}

///|
test "decoder preserves a trailing partial frame after complete packets" {
  let first = encode_frame(AsciiDecimal4, ascii_bytes("READY")).unwrap()
  let partial = ascii_bytes("0006ABC")
  let decoder = stream_decoder(AsciiDecimal4, 100).unwrap()
  let frames = decoder.feed(concat_bytes(first, partial)).unwrap()
  assert_eq(frames.length(), 1)
  assert_eq(decoder.buffered_bytes(), 7)
  match decoder.finish() {
    Err(InvalidStreamFrame(_)) => ()
    _ => fail("partial frame must be reported")
  }
  decoder.reset()
  assert_eq(decoder.buffered_bytes(), 0)
}

///|
test "frame decoder rejects malformed and oversized lengths" {
  let ascii = stream_decoder(AsciiDecimal4, 100).unwrap()
  match ascii.feed(ascii_bytes("00A4PING")) {
    Err(InvalidStreamFrame(_)) => ()
    _ => fail("non-decimal header must fail")
  }
  let binary = stream_decoder(BinaryBigEndian16, 4).unwrap()
  match binary.feed(hex_decode("000548454C4C4F").unwrap()) {
    Err(InvalidStreamFrame(_)) => ()
    _ => fail("oversized frame must fail before buffering")
  }
  match encode_frame(AsciiDecimal4, Bytes::make(0, 0)) {
    Err(InvalidStreamFrame(_)) => ()
    _ => fail("empty frame must fail")
  }
}

///|
test "framed ISO message round trip" {
  let packager = iso1987_packager()
  let request = message("0800").unwrap()
  request.set_field(7, "0916123456").unwrap()
  request.set_field(11, "000001").unwrap()
  request.set_field(70, "001").unwrap()
  let frame = pack_framed_message(
    packager,
    ascii_binary_profile(),
    BinaryBigEndian16,
    request,
  ).unwrap()
  let decoded = unpack_framed_message(
    packager,
    ascii_binary_profile(),
    BinaryBigEndian16,
    frame,
  ).unwrap()
  assert_eq(decoded.mti, "0800")
  assert_eq(decoded.field(70), Some("001"))
}
