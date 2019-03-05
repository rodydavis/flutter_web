Welcome! Thank you for trying Flutter Web Early Tech Preview!

This repository contains the source code for an experimental
[Flutter](https://flutter.dev/) Web runtime.
The long term goal is to add web support as a first-tier platform in
the Flutter SDK alongside iOS and Android.
The code in this repository represents a stepping stone to that goal by
providing web-only packages that implement (almost) the entire Flutter API
surface.

# DISCLAIMER

## This is a closed preview

* Access to this repository and source code is invitation-only.
* Do not fork, share, or publish any source code from this repository.
* Do not discuss the contents of this repository except via the [issue
  tracker] and the
  [discussion group](https://groups.google.com/forum/#!forum/flutter_web_early_access).

## Limitations

We intend to completely support all of Flutter's API and functionality across
modern browsers – with few, if any, exceptions. However, during this preview,
there are a number of exceptions:

* Existing Flutter code, pub packages, and plugins do not work as-is.
* Not all Flutter APIs are implemented for Web – including whole classes and
  members.
* Some APIs will misbehave – from rendering issues to crashes.
* Currently, UI built with `flutter_web` will feel like a mobile app when
  running on a desktop browser. For example:
  * Mouse wheel scrolling is not yet enabled – use drag instead.
  * Text selection may scroll the view instead.
* We plan to address these issues over the coming months.
* The code in the repository will change without notice.
* Some widgets will be janky as we have not yet optimized all paint operations.
* The development workflow only works with Chrome at the moment.

## How to implement plugins/access browser API?

`flutter_web` does not have a plugin system yet. _Temporarily_, we provide
access to `dart:html`, `dart:js`, `dart:svg`, `dart:indexed_db` and other Web
libraries that give you access to the vast majority of browser APIs. However,
expect that these libraries will be replaced by a different plugin API.

# Getting started

## Install the Dart SDK

The Flutter SDK does not (yet) include the web tools required to compile Dart
code to JavaScript, so you'll have to install the Dart SDK, too. The Dart SDK
installs independently of Flutter – there should be no issues having both
installed on the same machine.

Follow the directions at
<https://www.dartlang.org/tools/sdk> to get
started.

Make sure you have Dart 2.2.0 installed by running `dart --version` on the
console.

## Clone the flutter_web source code

Clone the repository locally.

> Note: this is a private repository. Your git client must be authenticated
  with your white-listed GitHub alias.

## Run the hello_world example

1. The example exists at `examples/hello_world` in the repository.

    ```console
    $ cd examples/hello_world/
    ```

2. Update packages.

    > Note: `pub upgrade` is analogous to `flutter packages upgrade`.

    ```console
    $ pub upgrade
    Resolving dependencies... (4.9s)
    ...
    Warning: You are using these overridden dependencies:
    ! flutter_web 0.0.0 from path ../../packages/flutter_web
    ! flutter_web_ui 0.0.0 from path ../../packages/flutter_web_ui
    Precompiling executables... (11.9s)
    ...
    ```

    If that succeeds, you're ready to run it!

3. Build and serve the example locally.

    ```console
    $ pub run build_runner serve
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


# Use flutter_web packages from git

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

# How to help!

We are not yet ready to accept GitHub pull requests at this time. However,
[GitHub issues][issue tracker] are very welcome.

Of particular interest to us is testing across a variety of platforms. Please
try Windows if you have it for example.

[issue tracker]: https://github.com/flutter/flutter_web/issues
