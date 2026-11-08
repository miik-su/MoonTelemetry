///|
fn decimal(s : String) -> Int32 {
  if s.is_empty() || s.length() > 4 {
    return -1
  }
  let mut n = 0
  for c in s {
    if c < '0' || c > '9' {
      return -1
    }
    n = n * 10 + c.to_int() - 48
  }
  n
}

///|
fn date_delay(value : String, now_ms : Int64) -> Int32 {
  let parts = value.split(" ").map(s => s.to_owned()).collect()
  if parts.length() != 6 ||
    parts[5] != "GMT" ||
    !["Mon,", "Tue,", "Wed,", "Thu,", "Fri,", "Sat,", "Sun,"].contains(parts[0]) {
    return 0
  }
  let year = decimal(parts[3])
  let day = decimal(parts[1])
  let mut month = -1
  for
    i, name in [
      "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov",
      "Dec",
    ] {
    if name == parts[2] {
      month = i
    }
  }
  let clock = parts[4].split(":").map(s => s.to_owned()).collect()
  if year < 1970 || month < 0 || clock.length() != 3 {
    return 0
  }
  let hour = decimal(clock[0])
  let minute = decimal(clock[1])
  let second = decimal(clock[2])
  if hour < 0 ||
    hour > 23 ||
    minute < 0 ||
    minute > 59 ||
    second < 0 ||
    second > 59 {
    return 0
  }
  let leap = year % 4 == 0 && (year % 100 != 0 || year % 400 == 0)
  let months = [
    31,
    if leap {
      29
    } else {
      28
    },
    31,
    30,
    31,
    30,
    31,
    31,
    30,
    31,
    30,
    31,
  ]
  if day < 1 || day > months[month] {
    return 0
  }
  let mut days = (year - 1970) * 365 +
    (year - 1) / 4 -
    1969 / 4 -
    (year - 1) / 100 +
    1969 / 100 +
    (year - 1) / 400 -
    1969 / 400
  for i in 0..<month {
    days += months[i]
  }
  days += day - 1
  let timestamp = (
      (days.to_int64() * 24L + hour.to_int64()) * 60L + minute.to_int64()
    ) *
    60L +
    second.to_int64()
  (timestamp * 1000L - now_ms).max(0L).min(3600000L).to_int()
}
