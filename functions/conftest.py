"""
BiasGuard — pytest conftest
Adds functions/ to sys.path so all test files can import helpers directly.
This avoids E402 (module-level import not at top) in every test file.
"""
import sys
import os

# Add functions/ directory to Python path
sys.path.insert(0, os.path.dirname(__file__))
