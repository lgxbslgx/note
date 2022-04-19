[NFC][libc] Find the benchmark package and adjust the dependency targets

This [commit](https://reviews.llvm.org/rG02022ccccc878421384d4473cd46ef0324e753a8) removed unneeded gtest and benchmark configuration.

But it could not find the right benchmark package and provided the non-existent dependency targets.

This patch fixes it and the test `check-llvmlibc` passed locally(x86-linux).

Thanks for taking the time to review.

Best Regards,
-- Guoxiong

