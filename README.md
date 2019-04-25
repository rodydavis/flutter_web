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
* Similarly, do not share or publish code that depends on Flutter Web (for
  example, if you create a separate branch of an existing Flutter project that
  supports Flutter Web, you may not publish that branch externally).
* Do not discuss the contents of this repository except via the [issue
  tracker] and the [discussion
  group](https://groups.google.com/forum/#!forum/flutter_web_early_access).

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
1. *Flutter mobile web companion*: a 'lite' version of an existing Flutter
   mobile app that can be used in scenarios where a full mobile app is
   undesirable (for example, try-before-buy).
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

### Using from VS Code

- [install](https://flutter.dev/docs/get-started/install) the Flutter SDK
- [set up](https://flutter.dev/docs/get-started/editor?tab=vscode) your copy of
  VS Code
- configure VS Code to point to your local Flutter SDK
- run the `Flutter: New Web Project` command from VS Code
- after the project is created, run your app by pressing F5 or
  "Debug -> Start Debugging"
- VS Code will use the `webdev` command-line tool to build and run your app; a
  new Chrome window should open, showing your running app

### Using from IntelliJ

- [install](https://flutter.dev/docs/get-started/install) the Flutter SDK
- [set up](https://flutter.dev/docs/get-started/editor) your copy of IntelliJ or
  Android Studio
- configure IntelliJ or Android Studio to point to your local Flutter SDK
- create a new Dart project; note, for a Flutter for web app, you want to start
  from the Dart project wizard, not the Flutter project wizard
- from the Dart project wizard, select the 'Flutter for web' option for the
  application template
- create the project; `pub get` will be run automatically
- once the project is created, hit the `run` button on the main toolbar
- IntelliJ will use the `webdev` command-line tool to build and run your app; a
  new Chrome window should open, showing your running app

## Workflow

### Use flutter_web packages from git

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

### Getting (stateless) hot-reload with `webdev`

The [webdev](https://pub.dartlang.org/packages/webdev) package offers features
beyond the `build_runner` command.

To install `webdev`:

```console
$ flutter packages pub global activate webdev
```

To use `webdev` with hot-reload, run the following within your `flutter_web`
project directory:

```console
$ flutter packages pub global run webdev serve --hot-reload
```

You'll notice a similar output to `flutter packages pub run build_runner serve`
but now changes to your application code should cause a quick refresh of the
application on save.

> Note: the `--hot-reload` option is not perfect. If you notice unexpected
  behavior, you may want to manually refresh the page.

> Note: the `--hot-reload` option is currently "stateless". Application state
  will be lost on reload. We do hope to offer "stateful" hot-reload on the web
  – we're actively working on it!


### Building with the production JavaScript compiler

The `serve` workflow documented above (with `build_runner` and `webdev`) uses
the [Dart Dev Compiler](https://webdev.dartlang.org/tools/dartdevc) which is
designed for fast, incremental compilation and easy debugging.

If you'd like evaluate production performance and code size, you can enable
our release compiler, [dart2js](https://webdev.dartlang.org/tools/dart2js).

For the `serve` command, pass in the `--release` flag (or just `-r`).

```console
$ flutter packages pub run build_runner serve -r
```

or

```console
$ flutter packages pub global run webdev serve -r
```

> Note: Builds will be *much* slower in this configuration.

If you'd like to generate output to disk, we recommend you use `webdev`.

```console
$ flutter packages pub global run webdev build
```

This will create a `build` directory with `index.html`, `main.dart.js` and the
rest of the files needed to run the application using a static HTTP server.

> Note: **DO NOT** deploy anything built with `flutter_web` publicly during the
  early-access program.

To optimize the output JavaScript, you can enable optimization flags using a
`build.yaml` file in the root of your project with the following contents:

```yaml
# See https://github.com/dart-lang/build/tree/master/build_web_compilers#configuration
targets:
  $default:
    builders:
      build_web_compilers|entrypoint:
        generate_for:
        - web/**.dart
        options:
          dart2js_args:
            - --no-source-maps
            - -O4
```

> Note: the `-O4` option enables a number of advanced optimizations that may
  cause runtime errors in code that has not been thoroughly tested.
