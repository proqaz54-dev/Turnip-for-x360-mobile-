CI build for Turnip (Adreno 735)

This repository includes a GitHub Actions workflow that attempts to build the Turnip (freedreno Vulkan) driver for Android aarch64 using Android NDK r25.

Usage notes:
- The workflow downloads the NDK and clones Mesa at tag `v26.2.0-R6` and runs a meson build for `freedreno` + `turnip`.
- Cross-file and build flags are a minimal template. You will likely need to adjust NDK API level, meson options (llvm, shader compiler, GLES/GL support) and additional dependencies.
- Building Mesa for Android can be resource- and time-intensive; consider using a larger runner or caching sources.
- A known-good working build from the R5 patched release has been added as `vendor/Turnip_v26.2.0-R5_patched.zip` for comparison and fallback.

If you want, I can now push these workflow and scripts to the repo and iterate based on CI failures.
