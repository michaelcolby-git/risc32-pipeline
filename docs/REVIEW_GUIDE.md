# Reviewer walkthrough

1. Read the operation/interface specification in the repository README.
2. Run `python scripts/verify.py` from this repository directory.
3. Inspect `build/results.json` and the per-run logs. Read the measurement definitions
   before comparing numbers across designs.
4. Change an input sequence and predict the expected result before rerunning.
5. Compare the current implementation with any original artifacts listed in
   `PROVENANCE.md`; historical resume measurements require their original setup.

The checked-in report records one local validation. GitHub Actions provides an
independent rerun when this repository is published. A green run establishes only
the checks that actually execute; it is not formal proof or hardware sign-off.
