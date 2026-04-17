# Contributing to BiasGuard

Thank you for your interest in BiasGuard! This project was built for the
Google Solution Challenge 2026 under the Unbiased AI Decision Making theme.

## Team Setup

- **Member A** owns: Flutter UI, Riverpod, Charts, PDF, Direct Mode UI
- **Member B** owns: Firebase Cloud Functions, Python, Gemini prompts, fairness metrics

## Branch Strategy

| Branch | Contents |
|--------|---------|
| `feature/cloud-functions-core` | CF1 + CF2 (Day 1) |
| `feature/mitigation-proxy-direct-mode` | Proxy detection + mitigation + CF4 (Day 2) |
| `feature/security-rules` | Firestore + Storage rules |
| `feature/auth-and-upload-screen` | Flutter login + upload (Member A, Day 1) |
| `feature/results-and-charts` | Flutter results + fl_chart (Member A, Day 2) |
| `feature/direct-decision-mode` | Flutter direct mode UI (Member A, Day 2) |
| `polish/prompts-and-error-handling` | Gemini tuning + retries (Day 3) |
| `docs/readme-and-schema` | README, schema, LICENSE |

**Rule:** Never push directly to `main`. Always PR → review → merge.

## Running Locally

### Cloud Functions (Python)
```bash
cd functions
pip install -r requirements.txt
python -m pytest tests/ -v       # Run unit tests
python ../../test_local.py        # Run engine test
```

### Flutter App
```bash
cd biasguard
flutter pub get
flutter run -d chrome             # Web
flutter run                       # Android
```

## Code Style

### Python (Cloud Functions)
- Follow PEP 8
- Type hints on all public functions
- Docstrings on every module and public function
- No hardcoded secrets — use `os.environ.get()` or Firebase Secrets

### Dart (Flutter)
- Follow Dart style guide
- All providers use Riverpod 2.0 `@riverpod` annotation
- Models use Freezed for immutability
- No hardcoded strings — use `AppStrings` constants

## Firestore Schema

All Firestore paths and field names are documented in `README.md`.
**Do not change field names** without notifying the other member — both
Flutter providers and Python writers depend on the exact same keys.

## Reporting Bugs

This is a 4-day sprint prototype. Log issues in the GitHub Issues tab
with the label `bug` or `enhancement`.

## License

By contributing, you agree your contributions are licensed under Apache 2.0.
