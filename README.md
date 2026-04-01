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

This package is distributed under the Apache License, Version 2.0.

`LispPadCore` is intended to remain independently reusable outside the
`LispPadDev` app bundle. When it is combined with GPL-covered components in
`LispPadDev`, the resulting app distribution follows the app's GPLv3 terms,
but this standalone package remains Apache-2.0.
