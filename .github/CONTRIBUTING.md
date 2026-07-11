# Contributing

Thank you for considering contributing to this project. Please follow these guidelines to ensure a smooth process.

## Getting Started

1. Fork the repository
2. Clone your fork: `git clone https://github.com/<your-username>/Rails-8-API-Authentication.git`
3. Set up the project:
   ```bash
   bundle install
   bin/rails db:prepare
   ```
4. Create a feature branch: `git checkout -b feat/my-feature`

## Development

### Prerequisites

- Ruby 3.2+ (see `.ruby-version`)
- SQLite3
- `RAILS_MASTER_KEY` environment variable (ask maintainer or use `bin/rails secret` to generate a new key, then `bin/rails credentials:edit`)

### Running Tests

```bash
# Full test suite
bin/rails test

# Specific test file
bin/rails test test/integration/auth_flow_test.rb

# With coverage
COVERAGE=1 bin/rails test
```

### Linting

```bash
bin/rubocop
bin/brakeman --no-pager
```

## Commit Messages

We use [Conventional Commits](https://www.conventionalcommits.org/):

```
type: short description

Longer explanation if needed.
```

Types: `feat`, `fix`, `refactor`, `test`, `docs`, `ci`, `chore`.

## Pull Request Process

1. Ensure all tests pass and rubocop is clean
2. Update documentation if needed
3. Submit a PR with a clear description of the changes
4. A maintainer will review and provide feedback

## Code of Conduct

Please note that this project follows a Code of Conduct. By participating, you agree to uphold its standards.
