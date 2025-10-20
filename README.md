# aic8800

[![Release](https://github.com/radxa-pkg/aic8800/actions/workflows/release.yaml/badge.svg)](https://github.com/radxa-pkg/aic8800/actions/workflows/release.yaml)

## Build

1. `git clone --recurse-submodules https://github.com/radxa-pkg/aic8800.git`
2. Open in [`devcontainer`](https://code.visualstudio.com/docs/devcontainers/containers)
3. `make deb`

## RPM

Use the helper script to generate an RPM that bundles the firmware and RF test
utilities. The script creates both binary and source RPMs under `dist/rpm`.

```
scripts/install-rpm.sh
```

Pass `--help` for the full list of options, including custom output
directories, version overrides, and automatic installation of the generated
package.
