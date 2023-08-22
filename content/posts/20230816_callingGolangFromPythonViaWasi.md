+++
title = "Python call Golang functions via Wasm/Wasi"
description = "Python call Golang functions via Wasm/Wasi for codebase migration across multiple languages"
tags = [
    "python",
    "golang",
]
date = "2023-08-16"
categories = [
    "python",
    "golang",
]
+++

## Inspirations

While I was watching the following video of a talk by Richard Feldman: https://www.youtube.com/watch?v=zX-kazAtX0c&ab_channel=ChariotSolutions. He was covering a pretty interesting concept/topic of how would one "slowly" migrate codebases from one language to another. Let's say the codebase for an application is pretty large - how would we safely move it over and change it without increasing the deployment targets? Let's say we're not in microservices land and it is difficult for us to do the whole deployment for a whole other server just to begin the migration of languages. 

There were a few ideas presented within the video:

- Create a local running server that communicates over sockets with the main application
- Wasi/wasm binaries to communicate with the main application
- A translation layer between languages (in most languages, the common layer would be a c layer) - due to differences in memory management of different languages.

We won't be covering the main idea of that video but instead, focus on the wasi aspect ideas presented within the video. One of the reasons was because in Golang 1.21 release, there is now a `wasip1` target available as a compilation target. I was curious to see if the support for this is sufficient to have something easily working which allows for this happen.

## Implementation

To get something working, we would first need to have some sample golang code that we would want to get exposed into the python script.

```golang
package main

import "fmt"

func sum(x, y int) int {
	return x + y
}

func main() {
	fmt.Println("testing")
}

```

For the above function, we would want to get the `sum` function into python - it should be callable from python with little to no issues. We can create wasm binary file with the following command to compile the binary:

```bash
GOOS=wasip1 GOARCH=wasm go build -o lol.wasm main
```

There isn't too much information for how python can call Golang wasm binaries. However, there is a website called wasmer: https://wasmer.io/ that covers of how such wasm binaries can be called. It is available as a python library:

```python
from wasmer import engine, wasi, Store, Module, ImportObject, Instance
from wasmer_compiler_cranelift import Compiler

wasm_bytes = open('lol.wasm', 'rb').read()
store = Store(engine.Universal(Compiler))
module = Module(store, wasm_bytes)
wasi_version = wasi.get_version(module, strict=True)
wasi_env = \
    wasi.StateBuilder('wasi_test_program'). \
        argument('--test'). \
        environment('COLOR', 'true'). \
        environment('APP_SHOULD_LOG', 'false'). \
        map_directory('the_host_current_dir', '.'). \
        finalize()
import_object = wasi_env.generate_import_object(store, wasi_version)
instance = Instance(module, import_object)
yahoo = instance.exports.sum(12, 12)
print(yahoo)

```

This is the first error that appeared unfortunately. From initial checks on various stack overflow pages (e.g.https://github.com/wasmerio/wasmer-python/issues/657) - it could be an issue where wasmer isn't fully supported on the macos environment? I haven't gotten around to investigate this error further - it could also be some dependency that I didn't install.

```bash
% python yyy.py
3
Traceback (most recent call last):
  File "/XXXX/static-python/yyy.py", line 1, in <module>
    from wasmer import engine, wasi, Store, Module, ImportObject, Instance
  File "/XXX/static-python-p5Sx-hLS/lib/python3.11/site-packages/wasmer/__init__.py", line 1, in <module>
    raise ImportError("Wasmer is not available on this system")
ImportError: Wasmer is not available on this system
```

A quick fix to resolve this is to simply chuck it into a python docker container where it'll run on a linux kernel (usually open source tooling have better support on linux environments). We can set that up by having the following Dockerfile:

```Dockerfile
FROM python:3.9
WORKDIR /lol
COPY . .
RUN pip install -r /lol/requirements.txt
```

The requirements.txt file here:

```text
wasmer
wasmer_compiler_cranelift
```

After which, we can simply run the following set of commands to build the docker container which we can then use to try to run the python script (that would contain the wasm/wasi binary.)

```bash
docker build -t lol .
docker run -it lol /bin/bash
```

We now face a new problem. I thought it could be issue where Golang only exports functions that start with capital letters so that is tried but I faced the same issue of missing issue.

```bash
Traceback (most recent call last):
  File "/lol/yyy.py", line 19, in <module>
    yahoo = instance.exports.Sum(12, 12)
LookupError: Export `sum` does not exist.
```

Apparently, the wasmer cli command is a pretty useful command when it comes to debugging the issues we're facing here: https://github.com/golang/go/issues/58141

```bash
% wasmer inspect lol.wasm
Type: wasm
Size: 2.0 MB
Imports:
  Functions:
    "wasi_snapshot_preview1"."sched_yield": [] -> [I32]
    "wasi_snapshot_preview1"."proc_exit": [I32] -> []
    "wasi_snapshot_preview1"."args_get": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."args_sizes_get": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."clock_time_get": [I32, I64, I32] -> [I32]
    "wasi_snapshot_preview1"."environ_get": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."environ_sizes_get": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."fd_write": [I32, I32, I32, I32] -> [I32]
    "wasi_snapshot_preview1"."random_get": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."poll_oneoff": [I32, I32, I32, I32] -> [I32]
    "wasi_snapshot_preview1"."fd_close": [I32] -> [I32]
    "wasi_snapshot_preview1"."fd_write": [I32, I32, I32, I32] -> [I32]
    "wasi_snapshot_preview1"."fd_fdstat_get": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."fd_fdstat_set_flags": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."fd_prestat_get": [I32, I32] -> [I32]
    "wasi_snapshot_preview1"."fd_prestat_dir_name": [I32, I32, I32] -> [I32]
  Memories:
  Tables:
  Globals:
Exports:
  Functions:
    "_start": [] -> []
  Memories:
    "memory": not shared (271 pages..)
  Tables:
  Globals:
```

It turns out that we need to "expose" functions out from our binaries and that's not fully supported at the moment...

> WASI Libraries (AKA Reactors)
>
> The WASI concept of libraries allow compiled binaries to expose single functions for consumption from the host. This is not something that will be supported in the initial WASI port, as it requires a concept of marking Go functions as exported (i.e. //go:wasmexport), and somehow facilitating the execution of a single function. For more discussions on why this is complicated, see #42372.

Seeing that we're already at this stage, I was wondering if there was any way to get this example working without needing to wait for Golang's team to release a the function exporing feature for wasi binaries.

Apparently, we can rely on Tinygo - they've been dealing with them for a long time even when the wasm/wasi project was in its infant stages.

```bash
brew tap tinygo-org/tools
brew install tinygo
```

With that, we can try to compile it but with a slight modification to our golang code

```golang
package main

import "fmt"

//export sum
func sum(x, y int) int {
	return x + y
}

func main() {
	fmt.Println("testing")
}

```

We introduced the `//export sum` comment to inform the compiler to expose our sum function so that our python script can use it.

We can compile the above binary by running the following command:

```bash
tinygo build -o lol.wasm -target wasm ./main.go
```

With that, we have a built wasm/wasi binary file which we can then use in our python script. To ensure that the function is exported, we can try to inspect it. Notice within the `exports` field - we now have a sum function that somewhat resembles our function signature.

```bash
% wasmer inspect lol.wasm 
Type: wasm
Size: 410.7 KB
Imports:
  Functions:
    "env"."runtime.ticks": [] -> [F64]
    "wasi_snapshot_preview1"."fd_write": [I32, I32, I32, I32] -> [I32]
    "env"."syscall/js.valueGet": [I32, I32, I32, I32, I32] -> []
    "env"."syscall/js.valuePrepareString": [I32, I32, I32] -> []
    "env"."syscall/js.valueLoadString": [I32, I32, I32, I32, I32] -> []
    "env"."syscall/js.finalizeRef": [I32, I32] -> []
    "env"."syscall/js.stringVal": [I32, I32, I32, I32] -> []
    "env"."syscall/js.valueSet": [I32, I32, I32, I32, I32] -> []
    "env"."syscall/js.valueLength": [I32, I32] -> [I32]
    "env"."syscall/js.valueIndex": [I32, I32, I32, I32] -> []
    "env"."syscall/js.valueCall": [I32, I32, I32, I32, I32, I32, I32, I32] -> []
  Memories:
  Tables:
  Globals:
Exports:
  Functions:
    "malloc": [I32] -> [I32]
    "free": [I32] -> []
    "calloc": [I32, I32] -> [I32]
    "realloc": [I32, I32] -> [I32]
    "_start": [] -> []
    "resume": [] -> []
    "go_scheduler": [] -> []
    "sum": [I32, I32] -> [I32]
    "asyncify_start_unwind": [I32] -> []
    "asyncify_stop_unwind": [] -> []
    "asyncify_start_rewind": [I32] -> []
    "asyncify_stop_rewind": [] -> []
    "asyncify_get_state": [] -> [I32]
  Memories:
    "memory": not shared (2 pages..)
  Tables:
  Globals:
```

Once we have everything setup, we can simply rebuild the docker container and then try to run the python script

```bash
% docker run -it lol /bin/bash
root@4227988ec17f:/lol# python yyy.py
24
```

## Reflections

There are a few points that came up in my head as I go through the steps above:

- Apparently the documentation for getting wasi/wasm working is quite fragmented and unclear. There is no one clear way of building out the wasi/wasm binaries and there is no clear and obvious way for the languages to consume such wasm/wasi binaries.
- The above step introduces quite a significant amount of complexity -> it somewhat almost convince me that it might be better to simply just do the strangle approach when moving applications between different programming languages (although it would cost quite a bit.)
- The above example is an extremely simple example and we didn't use any/most of the useful Golang functionality yet. Since we're using tinygo, we need to realize that there is possibility that not all functionality is ported over - some things may not work as expected, we will probably need to experiment further to see what the differences are.
- The devils are always in the details; who would have known that we would need to have some sort of step to mention of which function we would want to set as exported or not.

## References

- Hopefully there will be the introduction of `go:wasmexport` https://github.com/golang/go/issues/42372
- The issue for closing compiling `GOOS=wasip1 GOARCH=wasm` to create wasi binaries https://github.com/golang/go/issues/58141
- Instructions for installing tinygo: https://tinygo.org/getting-started/install/macos/
- Stack overflow article for "exported" functions issue. https://stackoverflow.com/questions/67978442/go-wasm-export-functions
- Example python script: https://github.com/wasmerio/wasmer-python/blob/master/examples/engine_universal.py