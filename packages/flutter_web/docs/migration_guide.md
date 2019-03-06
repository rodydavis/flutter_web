This document outlines the changes you'll need to make to existing Flutter code
to run it on the flutter_web preview.

You cannot add support for the flutter_web preview to an existing application.
You have to create a copy of your existing application code and modify it to add
web support.

If you're using Git, we suggest creating a web-specific branch in your project
repository.

# pubspec.yaml

```yaml
 name: flutter_app

version: 1.0.0

dependencies:
  ## REPLACE
  ## You need to update your dependencies to use `flutter_web`
  #flutter:
  #  sdk: flutter
  flutter_web: any

dev_dependencies:
  ## REPLACE
  ## Same goes for test packages
  #flutter_test:
  #  sdk: flutter
  flutter_web_test: any

  ## ADD
  ## You also need to add these dependencies to enable the Dart web build system
  build_runner: ^1.2.2
  build_web_compilers: ^1.1.0

  test: ^1.3.4

## REMOVE
## For the preview, assets are handled differently. You can remove or comment
## out this section. See `Assets` below for more details
# flutter:
#   uses-material-design: true
#   assets:
#     - asset/
#
#   fonts:
#   - family: Plaster
#     fonts:
#     - asset: asset/fonts/plaster/Plaster-Regular.ttf

## ADD
## flutter_web packages are not published to pub.dartlang.org
## These overrides tell the package tools to get them from GitHub
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
