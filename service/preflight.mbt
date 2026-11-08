///|
/// Resolve existing parents before opening any listeners. Configuration is a
/// trusted administrative input; this check is not a hostile-filesystem sandbox.
pub async fn Runtime::preflight(self : Runtime) -> Unit {
  let paths : Map[String, String] = Map([])
  for id, spec in self.config.exporters {
    let file = match spec {
      File(path) => Some((path, 1))
      RotatingFile(path~, max_files~, ..) => Some((path, max_files))
      _ => None
    }
    if file is Some((path, count)) {
      for i in 0..<count {
        let path = @config.file_path(path + (if i == 0 { "" } else { ".\{i}" }))
        let pieces = path.split("/").map(s => s.to_owned()).collect()
        let name = pieces.pop().unwrap()
        let parent = @fs.realpath(pieces.join("/")) catch {
          _ =>
            raise @component.Configuration(
              "exporter parent directory unavailable: " + id,
            )
        }
        if @fs.exists(path) {
          if @fs.kind(path, follow_symlink=false) != Regular {
            raise @component.Configuration(
              "exporter output must be a regular non-symlink file: " + id,
            )
          }
        }
        let canonical = @config.file_path(parent + "/" + name)
        if paths.contains(canonical) {
          raise @component.Configuration(
            "exporter files or rotation archives overlap: " + id,
          )
        }
        paths[canonical] = id
      }
    }
  }
}
