# CLI Template

This is a project template for developing CLI application.

## Prerequisites

In addition to MoonBit toolchain, you will need:
- [wasm-tools](https://github.com/bytecodealliance/wasm-tools)
- [wasmtime](https://wasmtime.dev/)
- (Optional) [just](https://just.systems/)

## Get started

Execute `just run` to see the output, and execute `just build release` to get a release build under `target/cli.wasm`.

- Modify the `top` function in `src/stub.mbt` to implement your CLI application.
- Modify the `run` function if you need finer control on the event loop.