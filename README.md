# roller
`roller` is a command line tool that colorizes text based on regular expression patterns. Reads from either a file or standard input. `roller` supports Linux and MacOS/OS X.

## Usage
```
$ roller [-h] [--help] [--color=<pattern>] file
```

### Examples
Reading from a file:
```
$ roller --blue='hello' --bright-yellow='world' file.txt
```
Reading from stdin:
```
$ echo "abcdefg" | roller --red='abc' --black='fg' --blue='de'
```
`roller` warns you when, and where, there's an overlapping pattern:
```
$ echo "abcdefg" | roller --yellow='abc' --cyan='cde'
warning: Overlapping match at 2:5
```
`roller` doesn't take the order of patterns into account, so overlapping matches may result in unexpected highlighting.

### Help
```
$ roller --help
Usage: roller [--color <pattern>]... [files]...
Colorize text based on regex patterns.

With no file, or when file is -, read standard input.

  -h, --help                              Display this help and exit.
      --usage                             Display usage and exit.
      --bold <pattern>                    Pattern to display in bold.
      --black <pattern>                   Pattern to display in black.
      --red <pattern>                     Pattern to display in red.
      --green <pattern>                   Pattern to display in green.
      --yellow <pattern>                  Pattern to display in yellow.
      --blue <pattern>                    Pattern to display in blue.
      --magenta <pattern>                 Pattern to display in magenta.
      --cyan <pattern>                    Pattern to display in cyan.
      --white <pattern>                   Pattern to display in white.
      --gray <pattern>                    Pattern to display in gray.
      --bright-red <pattern>              Pattern to display in bright red.
      --bright-green <pattern>            Pattern to display in bright green.
      --bright-yellow <pattern>           Pattern to display in bright yellow.
      --bright-blue <pattern>             Pattern to display in bright blue.
      --bright-magenta <pattern>          Pattern to display in bright magenta.
      --bright-cyan <pattern>             Pattern to display in bright cyan.
      --bright-white <pattern>            Pattern to display in bright white.
  <file>...

Examples:
  roller --red='[0-9]' f - g
      Output contents of f, then stdin, then g, with numbers in red.
  roller --red='[a-zA-Z]' --blue='[0-9]'
      Copy stdin to stdout, with letters in red and numbers in blue.
```

## Building
`roller` is written in Zig and thus requires Zig (version 0.13.0) in order to be built.
To build `roller`:
```
$ git clone https://github.com/KripperOldman/roller.git
$ cd roller
$ zig build --release=safe
```
The binary will be put in the `zig-out/bin/` directory.
