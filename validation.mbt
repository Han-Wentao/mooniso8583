///|
/// Validate content according to a data-element character class.
pub fn validate_data_kind(
  field : Int,
  kind : DataKind,
  value : String,
) -> Result[Unit, IsoError] {
  match kind {
    Numeric => validate_numeric_text(field, value)
    Alpha => validate_alpha_text(field, value)
    Alphanumeric => validate_alphanumeric_text(field, value, false)
    AlphanumericSpecial => validate_alphanumeric_text(field, value, true)
    Track2Data => validate_track2_text(field, value)
    BinaryHex => validate_binary_hex_text(field, value)
    AnyText => validate_printable_text(field, value)
  }
}

///|
/// Decimal-only field validation.
pub fn validate_numeric_text(
  field : Int,
  value : String,
) -> Result[Unit, IsoError] {
  if value.length() == 0 {
    return Ok(())
  }
  for i = 0; i < value.length(); i = i + 1 {
    if !ascii_digit(value[i]) {
      return Err(InvalidCharacter(field, i, "numeric"))
    }
  }
  Ok(())
}

///|
/// Alphabetic-only field validation, including space.
pub fn validate_alpha_text(
  field : Int,
  value : String,
) -> Result[Unit, IsoError] {
  for i = 0; i < value.length(); i = i + 1 {
    let c = value[i]
    if !ascii_alpha(c) && c != ' ' {
      return Err(InvalidCharacter(field, i, "alphabetic"))
    }
  }
  Ok(())
}

///|
/// Alphanumeric validation with optional ISO 8583 special characters.
pub fn validate_alphanumeric_text(
  field : Int,
  value : String,
  allow_special : Bool,
) -> Result[Unit, IsoError] {
  for i = 0; i < value.length(); i = i + 1 {
    let c = value[i]
    let common = ascii_alnum(c) || c == ' '
    let special = c == '.' ||
      c == ',' ||
      c == '-' ||
      c == '/' ||
      c == ':' ||
      c == '+' ||
      c == '(' ||
      c == ')' ||
      c == '?'
    if !common && !(allow_special && special) {
      return Err(InvalidCharacter(field, i, "alphanumeric"))
    }
  }
  Ok(())
}

///|
/// Printable seven-bit ASCII validation.
pub fn validate_printable_text(
  field : Int,
  value : String,
) -> Result[Unit, IsoError] {
  for i = 0; i < value.length(); i = i + 1 {
    let code = value[i].to_int()
    if code < 32 || code > 126 {
      return Err(InvalidCharacter(field, i, "printable ASCII"))
    }
  }
  Ok(())
}

///|
/// Track 2 accepts digits, one separator, and common pad markers.
pub fn validate_track2_text(
  field : Int,
  value : String,
) -> Result[Unit, IsoError] {
  let mut separators = 0
  for i = 0; i < value.length(); i = i + 1 {
    let c = value[i]
    if c == '=' || c == 'D' {
      separators += 1
      if separators > 1 {
        return Err(InvalidTrack2("multiple field separators"))
      }
    } else if c == 'F' && i == value.length() - 1 {
      ()
    } else if !ascii_digit(c) {
      return Err(InvalidCharacter(field, i, "Track 2"))
    }
  }
  if separators != 1 {
    return Err(InvalidTrack2("missing field separator"))
  }
  Ok(())
}

///|
/// Hexadecimal API representation for binary fields.
pub fn validate_binary_hex_text(
  field : Int,
  value : String,
) -> Result[Unit, IsoError] {
  if value.length() % 2 != 0 {
    return Err(InvalidLength(field, value.length() + 1, value.length()))
  }
  for i = 0; i < value.length(); i = i + 1 {
    if hex_nibble(value[i]) is None {
      return Err(InvalidCharacter(field, i, "hexadecimal"))
    }
  }
  Ok(())
}

///|
/// Logical field length used by a length prefix.
pub fn field_logical_length(spec : FieldSpec, value : String) -> Int {
  match spec.content_encoding {
    BinaryContent => value.length() / 2
    _ => value.length()
  }
}

///|
/// Maximum logical length for the field.
pub fn field_max_logical_length(spec : FieldSpec) -> Int {
  match spec.content_encoding {
    BinaryContent => spec.max_length / 2
    _ => spec.max_length
  }
}

///|
/// Minimum logical length for the field.
pub fn field_min_logical_length(spec : FieldSpec) -> Int {
  match spec.content_encoding {
    BinaryContent => spec.min_length / 2
    _ => spec.min_length
  }
}

///|
/// Validate and canonicalize a value, applying fixed-field padding.
pub fn canonical_field_value(
  spec : FieldSpec,
  value : String,
) -> Result[String, IsoError] {
  match validate_data_kind(spec.number, spec.data_kind, value) {
    Err(error) => return Err(error)
    Ok(_) => ()
  }
  let logical = field_logical_length(spec, value)
  let maximum = field_max_logical_length(spec)
  let minimum = field_min_logical_length(spec)
  if logical > maximum {
    return Err(FieldTooLong(spec.number, maximum, logical))
  }
  match spec.length_kind {
    Fixed => {
      if logical < minimum {
        return Err(FieldTooShort(spec.number, minimum, logical))
      }
      if logical == maximum {
        return Ok(value)
      }
      match spec.pad_direction {
        NoPadding => Err(InvalidLength(spec.number, maximum, logical))
        PadLeft =>
          if spec.content_encoding == BinaryContent {
            let fill = spec.pad_char.to_int().unsafe_to_char()
            Ok(left_pad(value, spec.max_length, fill.to_int().to_uint16()))
          } else {
            Ok(left_pad(value, spec.max_length, spec.pad_char))
          }
        PadRight =>
          if spec.content_encoding == BinaryContent {
            let fill = spec.pad_char.to_int().unsafe_to_char()
            Ok(right_pad(value, spec.max_length, fill.to_int().to_uint16()))
          } else {
            Ok(right_pad(value, spec.max_length, spec.pad_char))
          }
      }
    }
    Llvar | Lllvar =>
      if logical < minimum {
        Err(FieldTooShort(spec.number, minimum, logical))
      } else {
        Ok(value)
      }
  }
}

///|
/// Validate a message against every referenced field specification.
pub fn validate_message_fields(
  message : IsoMessage,
  packager : Packager,
) -> Array[ValidationIssue] {
  let issues : Array[ValidationIssue] = []
  for entry in message.fields {
    match packager.spec(entry.number) {
      None =>
        issues.push({
          code: "UNKNOWN_FIELD",
          field: entry.number,
          message: "packager has no definition for field \{entry.number}",
          severity: "error",
        })
      Some(spec) =>
        match canonical_field_value(spec, entry.value) {
          Ok(_) => ()
          Err(error) =>
            issues.push({
              code: error.code(),
              field: entry.number,
              message: error.message(),
              severity: "error",
            })
        }
    }
  }
  issues
}

///|
/// True when no error-level field validation findings exist.
pub fn fields_are_valid(message : IsoMessage, packager : Packager) -> Bool {
  validate_message_fields(message, packager).length() == 0
}
