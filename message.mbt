///|
/// Create an empty ISO 8583 message.
pub fn message(mti : String) -> Result[IsoMessage, IsoError] {
  if !valid_mti_text(mti) {
    Err(InvalidMti(mti))
  } else {
    Ok({ mti, fields: [], })
  }
}

///|
/// MTI text is exactly four decimal digits.
fn valid_mti_text(mti : String) -> Bool {
  if mti.length() != 4 {
    return false
  }
  for i = 0; i < 4; i = i + 1 {
    if !ascii_digit(mti[i]) {
      return false
    }
  }
  true
}

///|
/// Change the message MTI after validating it.
pub fn IsoMessage::set_mti(
  self : IsoMessage,
  mti : String,
) -> Result[Unit, IsoError] {
  if !valid_mti_text(mti) {
    Err(InvalidMti(mti))
  } else {
    self.mti = mti
    Ok(())
  }
}

///|
/// Locate a field by number.
fn IsoMessage::index_of(self : IsoMessage, number : Int) -> Int {
  for i = 0; i < self.fields.length(); i = i + 1 {
    if self.fields[i].number == number {
      return i
    }
  }
  -1
}

///|
/// Insert or replace a field while keeping entries sorted.
pub fn IsoMessage::set_field(
  self : IsoMessage,
  number : Int,
  value : String,
) -> Result[Unit, IsoError] {
  if number < 2 || number > 128 {
    return Err(InvalidFieldNumber(number))
  }
  let index = self.index_of(number)
  if index >= 0 {
    self.fields[index] = { number, value, }
    return Ok(())
  }
  let mut position = self.fields.length()
  for i = 0; i < self.fields.length(); i = i + 1 {
    if self.fields[i].number > number {
      position = i
      break
    }
  }
  self.fields.push({ number, value, })
  let mut i = self.fields.length() - 1
  while i > position {
    self.fields[i] = self.fields[i - 1]
    i -= 1
  }
  self.fields[position] = { number, value, }
  Ok(())
}

///|
/// Retrieve a field value.
pub fn IsoMessage::field(self : IsoMessage, number : Int) -> String? {
  let index = self.index_of(number)
  if index < 0 {
    None
  } else {
    Some(self.fields[index].value)
  }
}

///|
/// Test whether a field is present.
pub fn IsoMessage::has_field(self : IsoMessage, number : Int) -> Bool {
  self.index_of(number) >= 0
}

///|
/// Remove a field and report whether it existed.
pub fn IsoMessage::remove_field(self : IsoMessage, number : Int) -> Bool {
  let index = self.index_of(number)
  if index < 0 {
    return false
  }
  ignore(self.fields.remove(index))
  true
}

///|
/// Return field numbers in wire order.
pub fn IsoMessage::field_numbers(self : IsoMessage) -> Array[Int] {
  self.fields.map(fn(entry) { entry.number })
}

///|
/// Number of populated data elements.
pub fn IsoMessage::field_count(self : IsoMessage) -> Int {
  self.fields.length()
}

///|
/// Clone a message so callers can edit independently.
pub fn IsoMessage::copy(self : IsoMessage) -> IsoMessage {
  let fields = self.fields.map(fn(entry) {
    { number: entry.number, value: entry.value, }
  })
  { mti: self.mti, fields, }
}

///|
/// Create a packager after validating field definitions.
pub fn packager(
  name : String,
  specs : Array[FieldSpec],
) -> Result[Packager, IsoError] {
  let ordered : Array[FieldSpec] = []
  for spec in specs {
    match validate_spec(spec) {
      Err(error) => return Err(error)
      Ok(_) => ()
    }
    for existing in ordered {
      if existing.number == spec.number {
        return Err(DuplicateField(spec.number))
      }
    }
    let mut position = ordered.length()
    for i = 0; i < ordered.length(); i = i + 1 {
      if ordered[i].number > spec.number {
        position = i
        break
      }
    }
    ordered.push(spec)
    let mut i = ordered.length() - 1
    while i > position {
      ordered[i] = ordered[i - 1]
      i -= 1
    }
    ordered[position] = spec
  }
  Ok({ name, specs: ordered, })
}

///|
/// Validate structural invariants on one field definition.
fn validate_spec(spec : FieldSpec) -> Result[Unit, IsoError] {
  if spec.number < 2 || spec.number > 128 {
    return Err(InvalidSpec(spec.number, "number must be in 2..128"))
  }
  if spec.max_length <= 0 {
    return Err(InvalidSpec(spec.number, "maximum length must be positive"))
  }
  if spec.min_length < 0 || spec.min_length > spec.max_length {
    return Err(
      InvalidSpec(spec.number, "minimum length is outside valid range"),
    )
  }
  match spec.length_kind {
    Fixed =>
      if spec.min_length != spec.max_length && spec.pad_direction == NoPadding {
        return Err(
          InvalidSpec(spec.number, "unpadded fixed fields need exact length"),
        )
      }
    Llvar =>
      if spec.max_length > 99 {
        return Err(InvalidSpec(spec.number, "LLVAR maximum exceeds 99"))
      }
    Lllvar =>
      if spec.max_length > 999 {
        return Err(InvalidSpec(spec.number, "LLLVAR maximum exceeds 999"))
      }
  }
  if spec.content_encoding == BinaryContent && spec.max_length % 2 != 0 {
    return Err(
      InvalidSpec(spec.number, "binary hexadecimal length must be even"),
    )
  }
  Ok(())
}

///|
/// Find a field definition.
pub fn Packager::spec(self : Packager, number : Int) -> FieldSpec? {
  for spec in self.specs {
    if spec.number == number {
      return Some(spec)
    }
  }
  None
}

///|
/// True if the packager defines the field.
pub fn Packager::contains(self : Packager, number : Int) -> Bool {
  self.spec(number) is Some(_)
}

///|
/// Return all defined field numbers.
pub fn Packager::field_numbers(self : Packager) -> Array[Int] {
  self.specs.map(fn(spec) { spec.number })
}
