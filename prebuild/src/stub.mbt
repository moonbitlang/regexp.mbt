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
  @io.println("Hello, world!")
}
