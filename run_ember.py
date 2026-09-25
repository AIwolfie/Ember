"""Entrypoint launcher for Ember standalone binary."""

import sys
from ember.app import main

if __name__ == "__main__":
    sys.exit(main())
