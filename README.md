bansan
======

bansan checks swift code structures instead of your eyes.

![xcode-integration](misc/xcode-integration.png)

## Checks Implemented

* requirements for super call of:
    * `viewDidLoad()`
    * `viewWillAppear(_:)`
    * `viewDidAppear(_:)`
    * `viewWillDisappear(_:)`
    * `viewDidDisappear(_:)`

## Usage

### Command Line

```
# clone and install dependencies
carthage bootstrap

# bansan.swift is executable
./bansan.swift YourViewController.swift
```

### Xcode

Add `Run Script` Build Phase executed by `/bin/zsh`:

```
if which bansan >/dev/null; then
bansan ${SRCROOT}/**/*.swift
else
echo "warning: bansan does not exist, download from https://github.com/banjun/bansan"
fi
```

with `ln -s /path/to/bansan.swift /path/to/bin/bansan`.
