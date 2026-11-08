///|
pub(all) enum Action {
  Insert(String, Json)
  Update(String, Json)
  Upsert(String, Json)
  Delete(String)
}

///|
pub(all) enum Transform {
  Attributes(Array[Action])
  Resource(Array[Action])
  DropAttribute(String, Json)
}

///|
fn actions(attrs : Json, rules : Array[Action]) -> Json {
  let fields : Map[String, Json] = Map([])
  if attrs is Array(a) {
    for item in a {
      if item is Object(m) &&
        m.get("key") is Some(String(k)) &&
        m.get("value") is Some(v) {
        fields[k] = v
      }
    }
  }
  for action in rules {
    match action {
      Insert(k, v) => if !fields.contains(k) { fields[k] = v }
      Update(k, v) => if fields.contains(k) { fields[k] = v }
      Upsert(k, v) => fields[k] = v
      Delete(k) => fields.remove(k)
    }
  }
  Json::array(
    fields
    .iter()
    .map(kv => ({ "key": Json::string(kv.0), "value": kv.1 } : Json))
    .collect(),
  )
}

///|
fn matches(attrs : Json, key : String, expected : Json) -> Bool {
  match attrs {
    Array(a) =>
      a.any(v => {
        match v {
          Object(m) =>
            m.get("key") == Some(Json::string(key)) &&
            m.get("value") == Some(expected)
          _ => false
        }
      })
    _ => false
  }
}

///|
fn walk(
  j : Json,
  transform : Transform,
  record : Bool,
  resource : Bool,
) -> Json {
  match j {
    Object(m) => {
      let out : Map[String, Json] = Map([])
      for k, v in m {
        out[k] = match v {
          Array(a) => {
            let records = k == "logRecords" || k == "spans" || k == "dataPoints"
            let a = a.filter(v => {
              !(records &&
              transform is DropAttribute(key, expected) &&
              v is Object(fields) &&
              matches(
                fields.get("attributes").unwrap_or(Json::array([])),
                key,
                expected,
              ))
            })
            Json::array(a.map(v => walk(v, transform, records, false)))
          }
          _ => walk(v, transform, false, k == "resource")
        }
      }
      match transform {
        Attributes(a) =>
          if record {
            out["attributes"] = actions(
              m.get("attributes").unwrap_or(Json::array([])),
              a,
            )
          }
        Resource(a) => {
          if resource {
            out["attributes"] = actions(
              m.get("attributes").unwrap_or(Json::array([])),
              a,
            )
          }
          if m.contains("scopeLogs") ||
            m.contains("scopeSpans") ||
            m.contains("scopeMetrics") {
            if !m.contains("resource") {
              out["resource"] = { "attributes": actions(Json::array([]), a) }
            }
          }
        }
        _ => ()
      }
      Json::object(out)
    }
    _ => j
  }
}

///|
pub fn Transform::process(
  self : Transform,
  input : @data.Envelope,
) -> @data.Envelope raise {
  @data.from_json(input.signal(), walk(input.to_json(), self, false, false))
}

///|
pub impl @component.Processor for Transform with fn process(self, input) {
  self.process(input)
}
