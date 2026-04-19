# AIKit

A Swift Package Manager library with a small executable playground.

## Structure

- `Sources/AIKit`: the reusable library target
- `Tests/AIKitTests`: tests for the library target
- `Sources/AIKitPlayground`: an executable playground target that imports `AIKit`

## Usage

Run the tests:

```sh
swift test
```

Run the playground:

```sh
swift run AIKitPlayground
```

Pass an environment value into the playground:

```sh
AIKIT_NAME=Apple swift run AIKitPlayground
```
