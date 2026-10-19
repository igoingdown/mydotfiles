#!/usr/bin/env python3
"""CLI entry; dependencies and identity metadata live outside the repository."""
from slowquery_report.pipeline import main

if __name__ == "__main__":
    raise SystemExit(main())
