# Flutter Web Early Access Program (EAP)

Welcome to the Flutter Web Early Access Program.

This repository contains the source code for an experimental
[Flutter](https://flutter.dev/) Web runtime. Our goal is to add web
support as a first-tier platform in the Flutter SDK alongside iOS and Android.
The code in this repository represents a stepping stone to that goal by
providing web-only packages that implement (almost) the entire Flutter API
surface.

## Important Notes

### Confidentiality

* This is a closed preview, provided under NDA. Access to this repository
  and source code is by invitation only.
* Do not fork, share, or publish any source code from this repository.
* Do not discuss the contents of this repository except via the [issue
  tracker] and
  the [discussion group](https://groups.google.com/forum/#!forum/flutter_web_early_access).

### Limitations

We intend to completely support all of Flutter's API and functionality across
modern browsers – with few, if any, exceptions. However, during this preview,
there are a number of exceptions:

* Existing Flutter code, pub packages, and plugins do not work as-is.
* Not all Flutter APIs are implemented on Flutter Web at this time.
* Currently, UI built with `flutter_web` will feel like a mobile app when
  running on a desktop browser. For example:
  * Mouse wheel scrolling is not yet enabled – use drag instead.
  * Text selection may scroll the view instead.
* The API is not stable at this stage.
* Some widgets will be janky as we have not yet optimized all paint operations.
* The development workflow only works with Chrome at the moment.
* `flutter_web` does not have a plugin system yet. _Temporarily_, we provide
  access to `dart:html`, `dart:js`, `dart:svg`, `dart:indexed_db` and other Web
  libraries that give you access to the vast majority of browser APIs. However,
  expect that these libraries will be replaced by a different plugin API.

## Testing Flutter Web

While we are far from code complete, we're ready for you to start developing
and experimenting with Flutter Web. We are building the product around a number
of target scenarios, and we'd appreciate your feedback on feature gaps or
suitability against these scenarios, as well as other scenarios for which you
find Flutter Web useful. The five scenarios that are informing our development
of Flutter Web to date are:

1. *Standalone app*: an experience built entirely in Flutter Web;
1. *Content island*: a fixed-size `iframe`-like component that is embedded
   within a specific web page and is self-sufficient in content;
1. *Embedded control*: a reusable web component that can be embedded in multiple
   pages and communicates with other content on the page;
1. *Flutter mobile web companion*: a 'lite' version of an existing Flutter mobile app that
   can be used in scenarios where a full mobile app is undesirable (for example,
   try-before-buy).
1. *Embedded Flutter content*: dynamic content for an existing Flutter app
   that can be added at runtime (e.g. code push scenarios on Android).

We'd love to see repros that demonstrate crashes, rendering fidelity issues or
extreme performance issues. We'd also love general feedback on the quality of
the release and the developer experience.

Of particular interest to us is testing across a variety of development
(Windows, Linux, Mac) and deployment
(Chrome/Firefox/Edge on Windows, Linux, Mac, Chrome/Android, Safari/iOS etc.)
platforms and form factors.

Since we are developing this in a separate fork to the main Flutter repo, we are
not yet ready to accept GitHub pull requests at this time. However,
[GitHub issues][issue tracker] are very welcome.

[issue tracker]: https://github.com/flutter/flutter_web/issues

## Getting started

### Get the Dart web compilers

The Dart web compilers were just recently added to the Flutter dev SDK.

To use the Flutter SDK with the flutter_web preview make sure you are on the
dev channel and have upgraded to at least `v1.3.1`.

### Clone the flutter_web source code

Clone the repository locally.

> Note: this is a private repository. Your git client must be authenticated
  with your white-listed GitHub alias.

### Run the hello_world example

1. The example exists at `examples/hello_world` in the repository.

    ```console
    $ cd examples/hello_world/
    ```

2. Update packages.

    ```console
    $ flutter packages upgrade
    ! flutter_web 0.0.0 from path ../../flutter_web
    ! flutter_web_ui 0.0.0 from path ../../flutter_web_ui
    Running "flutter packages upgrade" in hello_world...                5.0s
    ```

    If that succeeds, you're ready to run it!

3. Build and serve the example locally.

    ```console
    $ flutter packages pub run build_runner serve
    [INFO] Generating build script completed, took 331ms
    ...
    [INFO] Building new asset graph completed, took 1.4s
    ...
    [INFO] Running build completed, took 27.9s
    ...
    [INFO] Succeeded after 28.1s with 618 outputs (3233 actions)
    Serving `web` on http://localhost:8080
    ```

    Open <http://localhost:8080> in Chrome and you should see `Hello World` in
    red text in the upper-left corner.

    > Note: We plan to support all modern browsers `flutter_web`, but at the
      moment the default for the development server generates code that may only
      work in Chrome.


## Use flutter_web packages from git

If you'd like to depend on the `flutter_web` packages without cloning the
repository, you can setup your pubspec as follows:

```yaml
name: my_flutter_web_app

environment:
  sdk: '>=2.2.0 <3.0.0'

dependencies:
  flutter_web: any
  flutter_web_ui: any

dev_dependencies:
  # Enables the `pub run build_runner` command
  build_runner: ^1.1.2
  # Includes the JavaScript compilers
  build_web_compilers: ^1.0.0

# flutter_web packages are not published to pub.dartlang.org
# These overrides tell the package tools to get them from GitHub
dependency_overrides:
  flutter_web:
    git:
      url: https://github.com/flutter/flutter_web
      path: packages/flutter_web
  flutter_web_ui:
    git:
      url: https://github.com/flutter/flutter_web
      path: packages/flutter_web_ui
```

> Note: again, `github.com/flutter/flutter_web` this is a private repository.
  Your git client must be authenticated with your white-listed GitHub alias.

