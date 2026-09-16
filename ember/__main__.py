"""Lets the package run as `python -m ember`."""

import sys

if "--doctor" in sys.argv[1:]:
    from .doctor import main as doctor_main

    raise SystemExit(doctor_main())

from .app import main

raise SystemExit(main())