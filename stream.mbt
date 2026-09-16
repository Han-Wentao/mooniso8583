///|
/// Length-prefix format used by common ISO 8583 TCP integrations.
pub(all) enum FrameHeader {
  BinaryBigEndian16
  AsciiDecimal4
} derive(Eq, Debug)

///|
/// Incremental decoder for length-prefixed byte streams.
pub(all) struct StreamDecoder {
  header : FrameHeader
  max_frame : Int
  mut buffer : Array[Byte]
} derive(Debug)

///|
/// Create an incremental decoder with an explicit payload limit.
pub fn stream_decoder(
  header : FrameHeader,
  max_frame : Int,
) -> Result[StreamDecoder, IsoError] {
  let format_limit = frame_format_limit(header)
  if max_frame <= 0 || max_frame > format_limit {
    return Err(
      InvalidStreamFrame(
        "maximum frame must be in 1..\{format_limit}, got \{max_frame}",
      ),
    )
  }
  Ok({ header, max_frame, buffer: [], })
}

///|
/// Maximum payload encodable by the selected header.
fn frame_format_limit(header : FrameHeader) -> Int {
  match header {
    BinaryBigEndian16 => 65535
    AsciiDecimal4 => 9999
  }
}

///|
/// Header width in bytes.
pub fn frame_header_width(header : FrameHeader) -> Int {
  match header {
    BinaryBigEndian16 => 2
    AsciiDecimal4 => 4
  }
}

///|
/// Prefix one payload with the selected length format.
pub fn encode_frame(
  header : FrameHeader,
  payload : Bytes,
) -> Result[Bytes, IsoError] {
  let length = payload.length()
  if length <= 0 {
    return Err(InvalidStreamFrame("empty payloads are not valid ISO messages"))
  }
  let limit = frame_format_limit(header)
  if length > limit {
    return Err(
      InvalidStreamFrame(
        "payload length \{length} exceeds \{limit} for selected header",
      ),
    )
  }
  let output : Array[Byte] = []
  match header {
    BinaryBigEndian16 => {
      output.push(((length >> 8) & 255).to_byte())
      output.push((length & 255).to_byte())
    }
    AsciiDecimal4 => {
      let text = match decimal_width(length, 4) {
        Ok(value) => value
        Err(_) =>
          return Err(InvalidStreamFrame("payload length does not fit ASCII4"))
      }
      for i = 0; i < text.length(); i = i + 1 {
        output.push(text[i].to_int().to_byte())
      }
    }
  }
  append_stream_bytes(output, payload)
  Ok(Bytes::from_array(output))
}

///|
/// Decode a header from the beginning of a byte buffer.
fn decode_frame_length(
  header : FrameHeader,
  buffer : Array[Byte],
) -> Result[Int, IsoError] {
  match header {
    BinaryBigEndian16 => Ok((buffer[0].to_int() << 8) | buffer[1].to_int())
    AsciiDecimal4 => {
      let mut length = 0
      for i = 0; i < 4; i = i + 1 {
        let digit = buffer[i].to_int() - 48
        if digit < 0 || digit > 9 {
          return Err(
            InvalidStreamFrame(
              "ASCII4 header contains a non-decimal byte at offset \{i}",
            ),
          )
        }
        length = length * 10 + digit
      }
      Ok(length)
    }
  }
}

///|
/// Feed an arbitrary stream chunk and return every complete payload.
pub fn StreamDecoder::feed(
  self : StreamDecoder,
  chunk : Bytes,
) -> Result[Array[Bytes], IsoError] {
  append_stream_bytes(self.buffer, chunk)
  let frames : Array[Bytes] = []
  let width = frame_header_width(self.header)
  let mut consumed = 0
  while self.buffer.length() - consumed >= width {
    let header_buffer : Array[Byte] = []
    for i = 0; i < width; i = i + 1 {
      header_buffer.push(self.buffer[consumed + i])
    }
    let length = match decode_frame_length(self.header, header_buffer) {
      Ok(value) => value
      Err(error) => {
        self.buffer = []
        return Err(error)
      }
    }
    if length <= 0 {
      self.buffer = []
      return Err(InvalidStreamFrame("zero-length frame is not allowed"))
    }
    if length > self.max_frame {
      self.buffer = []
      return Err(
        InvalidStreamFrame(
          "declared payload length \{length} exceeds configured maximum \{self.max_frame}",
        ),
      )
    }
    let frame_end = consumed + width + length
    if frame_end > self.buffer.length() {
      break
    }
    frames.push(
      Bytes::makei(length, fn(i) { self.buffer[consumed + width + i] }),
    )
    consumed = frame_end
  }
  if consumed > 0 {
    let remaining : Array[Byte] = []
    for i = consumed; i < self.buffer.length(); i = i + 1 {
      remaining.push(self.buffer[i])
    }
    self.buffer = remaining
  }
  Ok(frames)
}

///|
/// Number of undecoded bytes currently retained.
pub fn StreamDecoder::buffered_bytes(self : StreamDecoder) -> Int {
  self.buffer.length()
}

///|
/// Drop a partial frame after a connection reset.
pub fn StreamDecoder::reset(self : StreamDecoder) -> Unit {
  self.buffer = []
}

///|
/// Assert that the stream ended on a complete frame boundary.
pub fn StreamDecoder::finish(self : StreamDecoder) -> Result[Unit, IsoError] {
  if self.buffer.length() == 0 {
    return Ok(())
  }
  let width = frame_header_width(self.header)
  if self.buffer.length() < width {
    return Err(
      InvalidStreamFrame(
        "stream ended in a partial \{width}-byte length header",
      ),
    )
  }
  let length = match decode_frame_length(self.header, self.buffer) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let actual = self.buffer.length() - width
  Err(
    InvalidStreamFrame("stream ended with \{actual} of \{length} payload bytes"),
  )
}

///|
/// Pack an ISO message and add a transport length header.
pub fn pack_framed_message(
  packager : Packager,
  profile : WireProfile,
  header : FrameHeader,
  message : IsoMessage,
) -> Result[Bytes, IsoError] {
  let payload = match pack_message(packager, profile, message) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  encode_frame(header, payload)
}

///|
/// Decode exactly one framed message and reject extra frames or partial data.
pub fn unpack_framed_message(
  packager : Packager,
  profile : WireProfile,
  header : FrameHeader,
  frame : Bytes,
) -> Result[IsoMessage, IsoError] {
  let decoder = match stream_decoder(header, frame_format_limit(header)) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let payloads = match decoder.feed(frame) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  match decoder.finish() {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  if payloads.length() != 1 {
    return Err(
      InvalidStreamFrame(
        "expected exactly one frame, decoded \{payloads.length()}",
      ),
    )
  }
  unpack_message(packager, profile, payloads[0])
}

///|
fn append_stream_bytes(target : Array[Byte], source : Bytes) -> Unit {
  for byte in source {
    target.push(byte)
  }
}
