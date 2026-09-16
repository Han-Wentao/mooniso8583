///|
/// Stable errors returned by codecs, packagers and domain parsers.
pub(all) enum IsoError {
  InvalidMti(String)
  InvalidFieldNumber(Int)
  DuplicateField(Int)
  MissingField(Int)
  UnknownField(Int)
  InvalidLength(Int, Int, Int)
  InvalidCharacter(Int, Int, String)
  InvalidNumeric(Int, String)
  InvalidHex(String)
  InvalidBcd(Int, Int)
  InvalidBitmapLength(Int)
  BitmapFieldOneReserved
  Truncated(String, Int, Int)
  LengthPrefixOverflow(Int, Int)
  FieldTooLong(Int, Int, Int)
  FieldTooShort(Int, Int, Int)
  InvalidSpec(Int, String)
  InvalidTrack2(String)
  InvalidProcessingCode(String)
  InvalidAmount(String)
  InvalidDateTime(String)
  InvalidPan(String)
  InvalidCurrency(String)
  InvalidTlv(String)
  InvalidOriginalData(String)
  InvalidStreamFrame(String)
  TrailingBytes(Int)
  TemplateViolation(String)
} derive(Eq, Debug)

///|
pub fn IsoError::code(self : IsoError) -> String {
  match self {
    InvalidMti(_) => "ISO001"
    InvalidFieldNumber(_) => "ISO002"
    DuplicateField(_) => "ISO003"
    MissingField(_) => "ISO004"
    UnknownField(_) => "ISO005"
    InvalidLength(_) => "ISO006"
    InvalidCharacter(_) => "ISO007"
    InvalidNumeric(_) => "ISO008"
    InvalidHex(_) => "ISO009"
    InvalidBcd(_) => "ISO010"
    InvalidBitmapLength(_) => "ISO011"
    BitmapFieldOneReserved => "ISO012"
    Truncated(_) => "ISO013"
    LengthPrefixOverflow(_) => "ISO014"
    FieldTooLong(_) => "ISO015"
    FieldTooShort(_) => "ISO016"
    InvalidSpec(_) => "ISO017"
    InvalidTrack2(_) => "ISO018"
    InvalidProcessingCode(_) => "ISO019"
    InvalidAmount(_) => "ISO020"
    InvalidDateTime(_) => "ISO021"
    InvalidPan(_) => "ISO022"
    InvalidCurrency(_) => "ISO023"
    InvalidTlv(_) => "ISO024"
    InvalidOriginalData(_) => "ISO025"
    InvalidStreamFrame(_) => "ISO026"
    TrailingBytes(_) => "ISO027"
    TemplateViolation(_) => "ISO028"
  }
}

///|
pub fn IsoError::message(self : IsoError) -> String {
  match self {
    InvalidMti(value) => "invalid four-digit MTI: \{value}"
    InvalidFieldNumber(field) => "field number \{field} is outside 2..128"
    DuplicateField(field) => "field \{field} occurs more than once"
    MissingField(field) => "required field \{field} is missing"
    UnknownField(field) => "packager has no specification for field \{field}"
    InvalidLength(field, expected, actual) =>
      "field \{field} expects length \{expected}, got \{actual}"
    InvalidCharacter(field, offset, kind) =>
      "field \{field} has invalid \{kind} character at offset \{offset}"
    InvalidNumeric(field, value) => "field \{field} is not numeric: \{value}"
    InvalidHex(value) => "invalid hexadecimal text: \{value}"
    InvalidBcd(offset, nibble) =>
      "invalid BCD nibble \{nibble} at offset \{offset}"
    InvalidBitmapLength(length) =>
      "bitmap must contain 8 or 16 bytes, got \{length}"
    BitmapFieldOneReserved =>
      "field 1 is reserved as the secondary-bitmap indicator"
    Truncated(section, expected, actual) =>
      "truncated \{section}: need \{expected} bytes, have \{actual}"
    LengthPrefixOverflow(width, value) =>
      "value \{value} does not fit a \{width}-digit length prefix"
    FieldTooLong(field, maximum, actual) =>
      "field \{field} maximum length is \{maximum}, got \{actual}"
    FieldTooShort(field, minimum, actual) =>
      "field \{field} minimum length is \{minimum}, got \{actual}"
    InvalidSpec(field, reason) =>
      "invalid specification for field \{field}: \{reason}"
    InvalidTrack2(reason) => "invalid Track 2 data: \{reason}"
    InvalidProcessingCode(value) => "invalid processing code: \{value}"
    InvalidAmount(value) => "invalid amount: \{value}"
    InvalidDateTime(value) => "invalid ISO 8583 date/time value: \{value}"
    InvalidPan(value) => "invalid PAN: \{value}"
    InvalidCurrency(value) => "invalid ISO 4217 numeric currency: \{value}"
    InvalidTlv(reason) => "invalid BER-TLV data: \{reason}"
    InvalidOriginalData(reason) => "invalid DE90 original data: \{reason}"
    InvalidStreamFrame(reason) =>
      "invalid length-prefixed stream frame: \{reason}"
    TrailingBytes(count) => "message has \{count} trailing bytes"
    TemplateViolation(reason) => "message template violation: \{reason}"
  }
}
