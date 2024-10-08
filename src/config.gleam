import glaml.{type DocNode}
import gleam/dict
import gleam/int
import gleam/list
import gleam/result
import simplifile

pub type Config {
  Config(websites: List(Website))
}

pub type Website {
  Website(url: String, interval: Int, pattern: String)
}

pub type ConfigError {
  ConfigError(message: String)
}

pub fn load(filename: String) -> Result(Config, ConfigError) {
  use file_data <- result.try(open_config_file(filename))
  use websites <- result.try(parse_config_file(file_data))

  Ok(Config(websites))
}

fn open_config_file(filename: String) -> Result(String, ConfigError) {
  case simplifile.read(filename) {
    Ok(data) -> Ok(data)
    Error(_) -> Error(ConfigError(message: "Failed to read config file"))
  }
}

pub fn parse_config_file(data: String) -> Result(List(Website), ConfigError) {
  use doc <- result.try(
    glaml.parse_string(data)
    |> result.map_error(fn(_) {
      ConfigError(message: "Failed to parse config file")
    }),
  )

  let doc = glaml.doc_node(doc)

  use node <- result.try(
    glaml.get(doc, [glaml.Map("websites")])
    |> result.map_error(fn(_) {
      ConfigError(message: "websites key not found in config file")
    }),
  )

  use items <- require_doc_node_seq(node)

  let websites =
    list.map(items, fn(item) {
      case item {
        glaml.DocNodeMap(pairs) -> {
          let tuples =
            list.map(pairs, fn(pair) {
              let #(key, value) = pair
              let val_str = case value {
                glaml.DocNodeStr(val_str) -> val_str
                glaml.DocNodeInt(val_int) -> val_int |> int.to_string
                _ -> ""
              }
              let key_str = case key {
                glaml.DocNodeStr(key_str) -> {
                  key_str
                }
                _ -> ""
              }
              #(key_str, val_str)
            })

          let d = dict.from_list(tuples)
          let interval = case
            int.base_parse(get_dict_optional_key(d, "interval"), 10)
          {
            Ok(value) -> value
            Error(_) -> 10
          }

          Website(
            url: get_dict_optional_key(d, "url"),
            interval: interval,
            pattern: get_dict_optional_key(d, "pattern"),
          )
        }
        _ -> Website(url: "", interval: 0, pattern: "")
      }
    })
    |> list.filter(fn(w) { w.url != "" })

  Ok(websites)
}

fn get_dict_optional_key(d: dict.Dict(String, String), key: String) -> String {
  case d |> dict.get(key) {
    Ok(value) -> value
    Error(_) -> ""
  }
}

fn require_doc_node_seq(
  node: DocNode,
  callback: fn(List(DocNode)) -> Result(b, ConfigError),
) {
  case node {
    glaml.DocNodeSeq(items) -> callback(items)
    _ -> Error(ConfigError(message: "Invalid config file format"))
  }
}
