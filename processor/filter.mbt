///|
priv enum Rule {
  All(Array[Rule])
  Any(Array[Rule])
  Not(Rule)
  Exists(String, Bool)
  Equal(String, Json, Bool)
  Prefix(String, String, Bool)
  Severity(String, Int32)
}

///|
/// Bounded exclusion predicate; matching records/data points are removed.
pub struct Filter {
  priv rule : Rule
}

///|
fn filter_value(value : Json) -> Json raise {
  guard value is Object(fields) &&
    fields.length() == 1 &&
    fields
    .keys()
    .all(k => {
      [
        "stringValue", "boolValue", "intValue", "doubleValue", "bytesValue", "arrayValue",
        "kvlistValue",
      ].contains(k)
    }) else {
    raise @component.Configuration("filter equals requires one typed AnyValue")
  }
  let envelope = @data.from_json(Logs, {
    "resourceLogs": [
      { "resource": { "attributes": [{ "key": "operand", "value": value }] } },
    ],
  })
  guard envelope.to_json() is Object(root) &&
    root.get("resourceLogs") is Some(Array(groups)) &&
    groups[0] is Object(group) &&
    group.get("resource") is Some(Object(resource)) &&
    resource.get("attributes") is Some(Array(attrs)) &&
    attrs[0] is Object(attr) &&
    attr.get("value") is Some(normalized) else {
    raise @component.Configuration("invalid filter AnyValue")
  }
  normalized
}

///|
fn parse_rule(value : Json, depth : Int32, nodes : Array[Int32]) -> Rule raise {
  guard depth <= 8 && nodes[0] < 64 else {
    raise @component.Configuration("filter exceeds depth 8 or 64 nodes")
  }
  nodes[0] += 1
  guard value is Object(fields) else {
    raise @component.Configuration("filter condition must be an object")
  }
  for group in ["all", "any", "not"] {
    if fields.get(group) is Some(child) {
      guard fields.length() == 1 else {
        raise @component.Configuration(
          "filter group must not mix condition fields",
        )
      }
      if group == "not" {
        return Not(parse_rule(child, depth + 1, nodes))
      }
      guard child is Array(children) &&
        !children.is_empty() &&
        children.length() <= 16 else {
        raise @component.Configuration("filter group requires 1..16 conditions")
      }
      let rules = children.map(v => parse_rule(v, depth + 1, nodes))
      return if group == "all" { All(rules) } else { Any(rules) }
    }
  }
  guard fields
    .keys()
    .all(k => {
      ["attribute", "resource_attribute", "field", "operator", "value"].contains(
        k,
      )
    }) else {
    raise @component.Configuration("unknown filter condition field")
  }
  let selectors = ["attribute", "resource_attribute", "field"].filter(k => {
    fields.contains(k)
  })
  guard selectors.length() == 1 &&
    fields.get(selectors[0]) is Some(String(key)) &&
    !key.is_empty() &&
    key.length() <= 256 &&
    fields.get("operator") is Some(String(op)) else {
    raise @component.Configuration(
      "filter requires one bounded selector and operator",
    )
  }
  if selectors[0] == "field" {
    guard key == "severityNumber" &&
      ["gte", "lte", "equals"].contains(op) &&
      fields.get("value") is Some(Number(n, ..)) &&
      n >= 0 &&
      n <= 24 &&
      n.to_int().to_double() == n else {
      raise @component.Configuration(
        "severity filter requires equals/gte/lte and integer 0..24",
      )
    }
    return Severity(op, n.to_int())
  }
  let resource = selectors[0] == "resource_attribute"
  match op {
    "exists" => {
      guard !fields.contains("value") else {
        raise @component.Configuration("exists filter does not take a value")
      }
      Exists(key, resource)
    }
    "equals" => {
      guard fields.get("value") is Some(v) else {
        raise @component.Configuration("filter value required")
      }
      Equal(key, filter_value(v), resource)
    }
    "prefix" => {
      guard fields.get("value") is Some(String(prefix)) &&
        !prefix.is_empty() &&
        prefix.length() <= 1024 else {
        raise @component.Configuration(
          "filter prefix requires 1..1024 characters",
        )
      }
      Prefix(key, prefix, resource)
    }
    _ => raise @component.Configuration("unsupported filter operator")
  }
}

///|
pub fn Filter::parse(value : Json) -> Filter raise {
  { rule: parse_rule(value, 1, [0]), }
}

///|
fn record_attrs(record : Json) -> Json {
  match record {
    Object(fields) => fields.get("attributes").unwrap_or(Json::array([]))
    _ => Json::array([])
  }
}

///|
fn attr_match(attrs : Json, key : String, accepts : (Json) -> Bool) -> Bool {
  match attrs {
    Array(values) =>
      values.any(v => {
        v is Object(fields) &&
        fields.get("key") == Some(Json::string(key)) &&
        fields.get("value") is Some(value) &&
        accepts(value)
      })
    _ => false
  }
}

///|
fn Rule::matches(
  self : Rule,
  record : Json,
  resource : Json,
  signal : @data.Signal,
) -> Bool {
  match self {
    All(rules) => rules.all(r => r.matches(record, resource, signal))
    Any(rules) => rules.any(r => r.matches(record, resource, signal))
    Not(rule) => !rule.matches(record, resource, signal)
    Exists(key, from_resource) =>
      attr_match(
        if from_resource {
          resource
        } else {
          record_attrs(record)
        },
        key,
        _ => true,
      )
    Equal(key, expected, from_resource) =>
      attr_match(
        if from_resource {
          resource
        } else {
          record_attrs(record)
        },
        key,
        v => v == expected,
      )
    Prefix(key, prefix, from_resource) =>
      attr_match(
        if from_resource {
          resource
        } else {
          record_attrs(record)
        },
        key,
        v => {
          v is Object(fields) &&
          fields.get("stringValue") is Some(String(text)) &&
          text.has_prefix(prefix)
        },
      )
    Severity(op, expected) => {
      guard signal == Logs && record is Object(fields) else { return false }
      let severity = match fields.get("severityNumber") {
        Some(Number(n, ..)) => n.to_int()
        _ => 0
      }
      match op {
        "gte" => severity >= expected
        "lte" => severity <= expected
        _ => severity == expected
      }
    }
  }
}

///|
fn filter_walk(
  value : Json,
  rule : Rule,
  inherited : Json,
  signal : @data.Signal,
) -> Json {
  match value {
    Object(fields) => {
      let resource = match fields.get("resource") {
        Some(Object(r)) => r.get("attributes").unwrap_or(Json::array([]))
        _ => inherited
      }
      let out : Map[String, Json] = Map([])
      for key, value in fields {
        out[key] = if ["logRecords", "spans", "dataPoints"].contains(key) &&
          value is Array(records) {
          Json::array(
            records
            .filter(v => !rule.matches(v, resource, signal))
            .map(v => filter_walk(v, rule, resource, signal)),
          )
        } else {
          filter_walk(value, rule, resource, signal)
        }
      }
      Json::object(out)
    }
    Array(values) =>
      Json::array(values.map(v => filter_walk(v, rule, inherited, signal)))
    _ => value
  }
}

///|
pub fn Filter::process(
  self : Filter,
  input : @data.Envelope,
) -> @data.Envelope raise {
  @data.from_json(
    input.signal(),
    filter_walk(input.to_json(), self.rule, Json::array([]), input.signal()),
  )
}
