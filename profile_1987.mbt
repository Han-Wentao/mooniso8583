///|
/// Profile families used by the built-in ISO 8583 definitions.
pub(all) enum ProfileVariant {
  Ascii
  BcdNumeric
} derive(Eq, Debug)

///|
/// Return the standard field specification for a common 1987 data element.
pub fn iso1987_field(number : Int) -> FieldSpec? {
  match number {
    2 => Some(llvar_ascii(2, "Primary account number", 19, Numeric))
    3 => Some(fixed_numeric(3, "Processing code", 6))
    4 => Some(fixed_numeric(4, "Amount transaction", 12))
    5 => Some(fixed_numeric(5, "Amount settlement", 12))
    6 => Some(fixed_numeric(6, "Amount cardholder billing", 12))
    7 => Some(fixed_numeric(7, "Transmission date and time", 10))
    8 => Some(fixed_numeric(8, "Amount cardholder billing fee", 8))
    9 => Some(fixed_numeric(9, "Conversion rate settlement", 8))
    10 => Some(fixed_numeric(10, "Conversion rate billing", 8))
    11 => Some(fixed_numeric(11, "Systems trace audit number", 6))
    12 => Some(fixed_numeric(12, "Local transaction time", 6))
    13 => Some(fixed_numeric(13, "Local transaction date", 4))
    14 => Some(fixed_numeric(14, "Expiration date", 4))
    15 => Some(fixed_numeric(15, "Settlement date", 4))
    16 => Some(fixed_numeric(16, "Conversion date", 4))
    17 => Some(fixed_numeric(17, "Capture date", 4))
    18 => Some(fixed_numeric(18, "Merchant type", 4))
    19 => Some(fixed_numeric(19, "Acquiring institution country", 3))
    20 => Some(fixed_numeric(20, "PAN extended country", 3))
    21 => Some(fixed_numeric(21, "Forwarding institution country", 3))
    22 => Some(fixed_numeric(22, "Point of service entry mode", 3))
    23 => Some(fixed_numeric(23, "Card sequence number", 3))
    24 => Some(fixed_numeric(24, "Function code", 3))
    25 => Some(fixed_numeric(25, "Point of service condition", 2))
    26 => Some(fixed_numeric(26, "Point of service capture code", 2))
    27 =>
      Some(fixed_numeric(27, "Authorizing identification response length", 1))
    28 => Some(fixed_numeric(28, "Amount transaction fee", 9))
    29 => Some(fixed_numeric(29, "Amount settlement fee", 9))
    30 => Some(fixed_numeric(30, "Amount transaction processing fee", 9))
    31 => Some(fixed_numeric(31, "Amount settlement processing fee", 9))
    32 =>
      Some(llvar_ascii(32, "Acquiring institution identification", 11, Numeric))
    33 =>
      Some(
        llvar_ascii(33, "Forwarding institution identification", 11, Numeric),
      )
    34 =>
      Some(llvar_ascii(34, "Primary account number extended", 28, Alphanumeric))
    35 => Some(llvar_ascii(35, "Track 2 data", 37, Track2Data))
    36 => Some(lllvar_ascii(36, "Track 3 data", 104, AlphanumericSpecial))
    37 => Some(fixed_ascii(37, "Retrieval reference number", 12, Alphanumeric))
    38 =>
      Some(
        fixed_ascii(
          38,
          "Authorization identification response",
          6,
          Alphanumeric,
        ),
      )
    39 => Some(fixed_ascii(39, "Response code", 2, Alphanumeric))
    40 => Some(fixed_ascii(40, "Service restriction code", 3, Alphanumeric))
    41 =>
      Some(
        fixed_ascii(
          41,
          "Card acceptor terminal identification",
          8,
          Alphanumeric,
        ),
      )
    42 =>
      Some(fixed_ascii(42, "Card acceptor identification", 15, Alphanumeric))
    43 =>
      Some(
        fixed_ascii(
          43,
          "Card acceptor name and location",
          40,
          AlphanumericSpecial,
        ),
      )
    44 =>
      Some(llvar_ascii(44, "Additional response data", 25, AlphanumericSpecial))
    45 => Some(llvar_ascii(45, "Track 1 data", 76, AlphanumericSpecial))
    46 =>
      Some(lllvar_ascii(46, "Additional data ISO", 999, AlphanumericSpecial))
    47 =>
      Some(
        lllvar_ascii(47, "Additional data national", 999, AlphanumericSpecial),
      )
    48 =>
      Some(
        lllvar_ascii(48, "Additional data private", 999, AlphanumericSpecial),
      )
    49 => Some(fixed_numeric(49, "Currency code transaction", 3))
    50 => Some(fixed_numeric(50, "Currency code settlement", 3))
    51 => Some(fixed_numeric(51, "Currency code cardholder billing", 3))
    52 => Some(binary_hex(52, "Personal identification number data", 8, false))
    53 => Some(fixed_numeric(53, "Security related control information", 16))
    54 => Some(lllvar_ascii(54, "Additional amounts", 120, AlphanumericSpecial))
    55 => Some(lllvar_bcd_binary(55, "Integrated circuit card data", 255))
    56 =>
      Some(lllvar_ascii(56, "Original data elements", 999, AlphanumericSpecial))
    57 =>
      Some(
        lllvar_ascii(
          57,
          "Authorization life cycle data",
          999,
          AlphanumericSpecial,
        ),
      )
    58 =>
      Some(
        lllvar_ascii(
          58,
          "Authorizing agent institution",
          999,
          AlphanumericSpecial,
        ),
      )
    59 => Some(lllvar_ascii(59, "Transport data", 999, AlphanumericSpecial))
    60 => Some(lllvar_ascii(60, "Reserved national", 999, AlphanumericSpecial))
    61 => Some(lllvar_ascii(61, "Reserved private", 999, AlphanumericSpecial))
    62 => Some(lllvar_ascii(62, "Reserved private", 999, AlphanumericSpecial))
    63 => Some(lllvar_ascii(63, "Reserved private", 999, AlphanumericSpecial))
    64 => Some(binary_hex(64, "Primary message authentication code", 8, false))
    65 => Some(binary_hex(65, "Reserved bit map", 8, false))
    66 => Some(fixed_numeric(66, "Settlement code", 1))
    67 => Some(fixed_numeric(67, "Extended payment code", 2))
    68 => Some(fixed_numeric(68, "Receiving institution country", 3))
    69 => Some(fixed_numeric(69, "Settlement institution country", 3))
    70 => Some(fixed_numeric(70, "Network management information code", 3))
    71 => Some(fixed_numeric(71, "Message number", 4))
    72 => Some(lllvar_ascii(72, "Data record", 999, AlphanumericSpecial))
    73 => Some(fixed_numeric(73, "Date action", 6))
    74 => Some(fixed_numeric(74, "Credits number", 10))
    75 => Some(fixed_numeric(75, "Credits reversal number", 10))
    76 => Some(fixed_numeric(76, "Debits number", 10))
    77 => Some(fixed_numeric(77, "Debits reversal number", 10))
    78 => Some(fixed_numeric(78, "Transfer number", 10))
    79 => Some(fixed_numeric(79, "Transfer reversal number", 10))
    80 => Some(fixed_numeric(80, "Inquiries number", 10))
    81 => Some(fixed_numeric(81, "Authorizations number", 10))
    82 => Some(fixed_numeric(82, "Credits processing fee amount", 12))
    83 => Some(fixed_numeric(83, "Credits transaction fee amount", 12))
    84 => Some(fixed_numeric(84, "Debits processing fee amount", 12))
    85 => Some(fixed_numeric(85, "Debits transaction fee amount", 12))
    86 => Some(fixed_numeric(86, "Credits amount", 16))
    87 => Some(fixed_numeric(87, "Credits reversal amount", 16))
    88 => Some(fixed_numeric(88, "Debits amount", 16))
    89 => Some(fixed_numeric(89, "Debits reversal amount", 16))
    90 => Some(fixed_numeric(90, "Original data elements", 42))
    91 => Some(fixed_numeric(91, "File update code", 1))
    92 => Some(fixed_numeric(92, "File security number", 2))
    93 => Some(fixed_numeric(93, "Response indicator", 5))
    94 => Some(fixed_numeric(94, "Service indicator", 7))
    95 => Some(fixed_ascii(95, "Replacement amounts", 42, AlphanumericSpecial))
    96 => Some(binary_hex(96, "Message security code", 8, false))
    97 => Some(fixed_numeric(97, "Amount net settlement", 17))
    98 => Some(fixed_ascii(98, "Payee", 25, AlphanumericSpecial))
    99 =>
      Some(
        llvar_ascii(99, "Settlement institution identification", 11, Numeric),
      )
    100 =>
      Some(
        llvar_ascii(100, "Receiving institution identification", 11, Numeric),
      )
    101 => Some(llvar_ascii(101, "File name", 17, AlphanumericSpecial))
    102 =>
      Some(
        llvar_ascii(102, "Account identification 1", 28, AlphanumericSpecial),
      )
    103 =>
      Some(
        llvar_ascii(103, "Account identification 2", 28, AlphanumericSpecial),
      )
    104 =>
      Some(
        lllvar_ascii(104, "Transaction description", 100, AlphanumericSpecial),
      )
    105 => Some(lllvar_ascii(105, "Reserved ISO", 999, AlphanumericSpecial))
    106 => Some(lllvar_ascii(106, "Reserved ISO", 999, AlphanumericSpecial))
    107 => Some(lllvar_ascii(107, "Reserved ISO", 999, AlphanumericSpecial))
    108 => Some(lllvar_ascii(108, "Reserved ISO", 999, AlphanumericSpecial))
    109 => Some(lllvar_ascii(109, "Reserved ISO", 999, AlphanumericSpecial))
    110 => Some(lllvar_ascii(110, "Reserved ISO", 999, AlphanumericSpecial))
    111 => Some(lllvar_ascii(111, "Reserved ISO", 999, AlphanumericSpecial))
    112 =>
      Some(lllvar_ascii(112, "Reserved national", 999, AlphanumericSpecial))
    113 =>
      Some(lllvar_ascii(113, "Reserved national", 999, AlphanumericSpecial))
    114 =>
      Some(lllvar_ascii(114, "Reserved national", 999, AlphanumericSpecial))
    115 =>
      Some(lllvar_ascii(115, "Reserved national", 999, AlphanumericSpecial))
    116 =>
      Some(lllvar_ascii(116, "Reserved national", 999, AlphanumericSpecial))
    117 =>
      Some(lllvar_ascii(117, "Reserved national", 999, AlphanumericSpecial))
    118 =>
      Some(lllvar_ascii(118, "Reserved national", 999, AlphanumericSpecial))
    119 =>
      Some(lllvar_ascii(119, "Reserved national", 999, AlphanumericSpecial))
    120 => Some(lllvar_ascii(120, "Reserved private", 999, AlphanumericSpecial))
    121 => Some(lllvar_ascii(121, "Reserved private", 999, AlphanumericSpecial))
    122 => Some(lllvar_ascii(122, "Reserved private", 999, AlphanumericSpecial))
    123 => Some(lllvar_ascii(123, "Reserved private", 999, AlphanumericSpecial))
    124 => Some(lllvar_ascii(124, "Reserved private", 999, AlphanumericSpecial))
    125 => Some(lllvar_ascii(125, "Reserved private", 999, AlphanumericSpecial))
    126 => Some(lllvar_ascii(126, "Reserved private", 999, AlphanumericSpecial))
    127 => Some(lllvar_ascii(127, "Reserved private", 999, AlphanumericSpecial))
    128 =>
      Some(binary_hex(128, "Secondary message authentication code", 8, false))
    _ => None
  }
}

///|
/// Collect all standard field definitions in ascending order.
pub fn iso1987_specs() -> Array[FieldSpec] {
  let specs : Array[FieldSpec] = []
  for number = 2; number <= 128; number = number + 1 {
    match iso1987_field(number) {
      Some(spec) => specs.push(spec)
      None => ()
    }
  }
  specs
}

///|
/// Make a built-in ISO 8583-1987 ASCII profile.
pub fn iso1987_packager() -> Packager {
  packager("iso8583-1987-ascii", iso1987_specs()).unwrap()
}

///|
/// Use BCD length headers and BCD content for numeric fields.
pub fn iso1987_bcd_packager() -> Result[Packager, IsoError] {
  let specs : Array[FieldSpec] = []
  for number = 2; number <= 128; number = number + 1 {
    match iso1987_field(number) {
      None => ()
      Some(spec) => {
        let numeric = spec.data_kind == Numeric
        let converted = if numeric {
          {
            number: spec.number,
            name: spec.name,
            length_kind: spec.length_kind,
            max_length: spec.max_length,
            min_length: spec.min_length,
            length_encoding: if spec.length_kind == Fixed {
              BcdLength
            } else {
              BcdLength
            },
            content_encoding: if spec.length_kind == Fixed {
              BcdContent
            } else {
              BcdContent
            },
            data_kind: spec.data_kind,
            pad_direction: spec.pad_direction,
            pad_char: spec.pad_char,
          }
        } else {
          spec
        }
        specs.push(converted)
      }
    }
  }
  packager("iso8583-1987-bcd-numeric", specs)
}

///|
/// Return a built-in field spec or a stable unknown-field error.
pub fn require_iso1987_field(number : Int) -> Result[FieldSpec, IsoError] {
  match iso1987_field(number) {
    Some(spec) => Ok(spec)
    None => Err(UnknownField(number))
  }
}

///|
/// Count how many standard fields are variable length.
pub fn iso1987_variable_field_count() -> Int {
  let mut count = 0
  for spec in iso1987_specs() {
    match spec.length_kind {
      Fixed => ()
      Llvar | Lllvar => count += 1
    }
  }
  count
}
