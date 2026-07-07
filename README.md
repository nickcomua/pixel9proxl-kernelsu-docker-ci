# Pixel 9 Pro XL KernelSU Next + Docker CI

Public GitHub Actions build wrapper for Pixel 9 Pro XL (`komodo` / `caimito`) kernel artifacts.

This builds from Google's public Android kernel manifest branch:

- `android-gs-caimito-6.1-android16`
- device target: `//private/devices/google/caimito:zumapro_caimito_dist`
- KernelSU Next tag: `v3.3.0`
- stock-style localversion suffix: `-gbd23337e42e7-ab14791245`

The workflow uploads these Actions artifacts:

- `boot.img`
- `vendor_kernel_boot.img`
- `dtbo.img`
- `vendor_dlkm.img`
- `system_dlkm.img`
- `Image`
- `.config`

## Run

Open **Actions -> Build Pixel kernel -> Run workflow**.

The job is large. It needs disk, network, and time. GitHub-hosted runners may time out or run out of disk; if that happens, use a larger self-hosted Linux runner.

## Local Build

```bash
./scripts/sync-source.sh work/caimito
./scripts/apply-patches.sh work/caimito
./scripts/build.sh work/caimito
```

Artifacts are copied to `artifacts/`.

## Notes

This repo stores only scripts and patches. It does not vendor Google's kernel source tree or local build outputs.

Current status: the device dist build completes and produces images/modules, but the direct source GKI `boot.img` rebuild is still being debugged. Do not flash CI artifacts until the `boot.img` kernel string is verified to match the custom source kernel.
