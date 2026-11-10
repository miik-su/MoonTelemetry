///|
priv struct Options {
  seconds : Int32
  clients : Int32
  scenario : String
}

///|
fn positive(value : String, maximum : Int32) -> Int32 {
  let mut n = 0
  for c in value {
    guard c >= '0' && c <= '9' && n <= maximum else {
      abort("invalid benchmark integer")
    }
    n = n * 10 + c.to_int() - 48
  }
  guard n >= 1 && n <= maximum else { abort("benchmark integer out of range") }
  n
}

///|
fn options(args : Array[String]) -> Options {
  let mut seconds = 5
  let mut clients = 8
  let mut scenario = "small"
  let mut i = 1
  while i < args.length() {
    if args[i] == "--soak" {
      seconds = 60
      i += 1
      continue
    }
    guard i + 1 < args.length() else {
      abort("benchmark option requires a value")
    }
    match args[i] {
      "--seconds" => seconds = positive(args[i + 1], 86400)
      "--clients" => clients = positive(args[i + 1], 64)
      "--scenario" => scenario = args[i + 1]
      _ =>
        abort(
          "usage: collector [--seconds 1..86400] [--clients 1..64] [--scenario small|large|slow]",
        )
    }
    i += 2
  }
  guard ["small", "large", "slow"].contains(scenario) else {
    abort("unknown benchmark scenario")
  }
  { seconds, clients, scenario, }
}
