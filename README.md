# LispPadCore

`LispPadCore` is the shared runtime package behind `LispPadDev`. It wraps the local `swift-lispkit` fork, provides the portable bootstrap/prelude layer, and exposes the interpreter, console, library manager, environment manager, and history services used by the app shell.

## Dependency Layout

This package expects a sibling checkout of `swift-lispkit`:

```text
Packages/
  LispPadCore/
  swift-lispkit/
```

`Package.swift` resolves LispKit via `../swift-lispkit`.

## Platforms

- iOS 17+
- macOS 14+
- visionOS 1+

## License

This package is distributed under GPLv3.

