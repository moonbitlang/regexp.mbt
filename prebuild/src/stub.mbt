///| Run the program.
pub fn run() -> Result[Unit, Unit] {
  let mut result = Ok(())
  @promise.spawn(async fn(_defer) {
    top() catch {
      error => {
        result = Err(())
        @io.println_sync("Error \{error}", stream=@io.stderr)
      }
    }
  })
  |> ignore
  @io.event_loop.run()
  result
}

///|
/// User should change this function to do what they want
async fn top() -> Unit raise {
  // Get the case folding data from Unicode.org
  let request = @http.request(
    "www.unicode.org",
    path="/Public/UCD/latest/ucd/CaseFolding.txt",
  )
  let data = @http.fetch(request)
  guard data.consume() is Ok(body)
  guard body.stream() is Ok(input_stream)

  // Prepare file. Assume preopen is where the file needs to be written
  guard @preopens.get_directories() is [(preopen, _), ..] else {
    fail("Error: No preopen directories found")
  }
  let file = preopen
    .open_at(
      @fs.PathFlags::default(),
      "case_folding.mbt",
      @fs.OpenFlags::default().set(CREATE).set(TRUNCATE),
      @fs.DescriptorFlags::default().set(@fs.DescriptorFlagsFlag::WRITE),
    )
    .unwrap_or_error()
  let output_stream = file.write_via_stream(0).unwrap_or_error()

  // Start writing template
  @io.println(
    "let simple_case_folding_data : Map[Char, Char] = {",
    stream=output_stream,
  )
  // We only do simple case folding
  let regexp = @regexp.compile("^([0-9A-F]+);\\s+[CS];\\s+([0-9A-F]+);")
  while true {
    let next = @io.read_line(stream=input_stream)
    if next.contains("EOF") {
      break
    }
    let result = regexp.execute(next)
    if result.matched() {
      @io.println(
        $|  '\\u{\{result.group(1).unwrap()}}' : '\\u{\{result.group(2).unwrap()}}',
        ,
        stream=output_stream,
      )
    }
  }
  @io.println("}", stream=output_stream)
  output_stream.flush().unwrap()
  output_stream.drop()
  file.drop()
  input_stream.drop()
  body.drop()
  data.drop()
}
