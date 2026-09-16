///|
/// Sensitivity class used by safe message diagnostics.
pub(all) enum FieldSensitivity {
  PublicField
  MaskedAccountData
  RedactedTrackData
  RedactedSecret
  SummarizedChipData
} derive(Eq, Debug)

///|
/// One field in a diagnostic view that never contains raw secrets.
pub(all) struct SafeFieldDiagnostic {
  field : Int
  name : String
  logical_length : Int
  sensitivity : FieldSensitivity
  display : String
} derive(Eq, Debug)

///|
/// Classify common payment data elements for safe logging.
pub fn field_sensitivity(field : Int) -> FieldSensitivity {
  match field {
    2 => MaskedAccountData
    35 | 45 => RedactedTrackData
    52 | 53 | 64 | 96 | 128 => RedactedSecret
    55 => SummarizedChipData
    _ => PublicField
  }
}

///|
/// Mask a PAN without trusting that the input has already been validated.
fn safe_pan_mask(value : String) -> String {
  if value.length() < 12 || value.length() > 19 {
    return "[REDACTED PAN len=\{value.length()}]"
  }
  for i = 0; i < value.length(); i = i + 1 {
    if !ascii_digit(value[i]) {
      return "[REDACTED PAN len=\{value.length()}]"
    }
  }
  mask_pan(value)
}

///|
/// Produce a Track 2 summary without expiry, service code, or discretionary data.
fn safe_track2_summary(value : String) -> String {
  match parse_track2(value) {
    Ok(track) =>
      "\{safe_pan_mask(track.pan)}=<REDACTED TRACK2 len=\{value.length()}>"
    Err(_) => "[REDACTED TRACK2 len=\{value.length()}]"
  }
}

///|
/// Collect BER-TLV tags without retaining any values.
fn collect_tlv_tags(nodes : Array[BerTlv], tags : Array[String]) -> Unit {
  for node in nodes {
    tags.push(node.tag)
    if node.constructed {
      collect_tlv_tags(node.children, tags)
    }
  }
}

///|
/// Join text without relying on a platform-specific collection formatter.
fn join_diagnostic_text(values : Array[String], separator : String) -> String {
  let output = StringBuilder()
  for i = 0; i < values.length(); i = i + 1 {
    if i > 0 {
      output.write_string(separator)
    }
    output.write_string(values[i])
  }
  output.to_string()
}

///|
/// Summarize DE55 by encoded size and tags only.
fn safe_de55_summary(value : String) -> String {
  match parse_de55(value) {
    Err(_) => "[REDACTED DE55 invalid-encoding hex-len=\{value.length()}]"
    Ok(nodes) => {
      let tags : Array[String] = []
      collect_tlv_tags(nodes, tags)
      "DE55 bytes=\{value.length() / 2} tags=[\{join_diagnostic_text(tags, ",")}]"
    }
  }
}

///|
/// Render one field value according to its sensitivity class.
pub fn safe_field_display(field : Int, value : String) -> String {
  match field_sensitivity(field) {
    PublicField => value
    MaskedAccountData => safe_pan_mask(value)
    RedactedTrackData =>
      if field == 35 {
        safe_track2_summary(value)
      } else {
        "[REDACTED TRACK1 len=\{value.length()}]"
      }
    RedactedSecret =>
      match field {
        52 => "[REDACTED PIN DATA bytes=\{value.length() / 2}]"
        53 => "[REDACTED SECURITY CONTROL len=\{value.length()}]"
        64 | 128 => "[REDACTED MAC bytes=\{value.length() / 2}]"
        96 => "[REDACTED KEY MANAGEMENT bytes=\{value.length() / 2}]"
        _ => "[REDACTED len=\{value.length()}]"
      }
    SummarizedChipData => safe_de55_summary(value)
  }
}

///|
/// Build structured, log-safe diagnostics in field order.
pub fn safe_field_diagnostics(
  message : IsoMessage,
  packager : Packager,
) -> Array[SafeFieldDiagnostic] {
  let output : Array[SafeFieldDiagnostic] = []
  for entry in message.fields {
    let name = match packager.spec(entry.number) {
      Some(spec) => spec.name
      None => "unknown field"
    }
    output.push({
      field: entry.number,
      name,
      logical_length: entry.value.length(),
      sensitivity: field_sensitivity(entry.number),
      display: safe_field_display(entry.number, entry.value),
    })
  }
  output
}

///|
/// Render a deterministic multi-line message dump suitable for application logs.
pub fn safe_message_dump(message : IsoMessage, packager : Packager) -> String {
  let output = StringBuilder()
  output.write_string("MTI \{message.mti} fields=\{message.field_count()}\n")
  for item in safe_field_diagnostics(message, packager) {
    output.write_string(
      "DE\{item.field} \{item.name} len=\{item.logical_length} value=\{item.display}\n",
    )
  }
  output.to_string()
}

///|
/// Explain the wire layout alongside safe field displays.
pub fn safe_layout_dump(
  message : IsoMessage,
  packager : Packager,
  profile : WireProfile,
) -> Result[String, IsoError] {
  let layout = match message_layout(packager, profile, message) {
    Ok(value) => value
    Err(error) => return Err(error)
  }
  let output = StringBuilder()
  for line in layout {
    output.write_string(line)
    output.write_char('\n')
  }
  output.write_string("-- safe values --\n")
  output.write_string(safe_message_dump(message, packager))
  Ok(output.to_string())
}

///|
/// Return only field numbers whose values require masking or redaction.
pub fn sensitive_fields(message : IsoMessage) -> Array[Int] {
  let fields : Array[Int] = []
  for entry in message.fields {
    if field_sensitivity(entry.number) != PublicField {
      fields.push(entry.number)
    }
  }
  fields
}

///|
/// Defensive check used by tests and host applications before emitting a dump.
pub fn diagnostic_contains_raw_value(
  diagnostic : String,
  field : Int,
  raw_value : String,
) -> Bool {
  if field_sensitivity(field) == PublicField || raw_value.length() == 0 {
    return false
  }
  diagnostic.contains(raw_value)
}
