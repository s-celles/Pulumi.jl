# Contributing to Pulumi.jl

Thank you for your interest in contributing to Pulumi.jl!

## Getting Started

1. Fork the repository
2. Clone your fork:
   ```bash
   git clone https://github.com/<your-username>/Pulumi.jl.git
   ```
3. Install dependencies:
   ```bash
   julia --project=. -e 'using Pkg; Pkg.instantiate()'
   ```

## Development Workflow

### Running Tests

```bash
julia --project=. -e 'using Pkg; Pkg.test()'
```

### Building Documentation

```bash
julia --project=docs docs/make.jl
```

### Code Style

- Follow Julia naming conventions: `snake_case` for functions, `PascalCase` for types
- Add docstrings to all public functions
- Run Aqua.jl quality checks before submitting

## Submitting Changes

1. Create a feature branch: `git checkout -b feature/my-feature`
2. Make your changes and add tests
3. Ensure all tests pass
4. Commit using conventional commit format:
   - `feat:` for new features
   - `fix:` for bug fixes
   - `docs:` for documentation
   - `test:` for tests
   - `refactor:` for refactoring
   - `chore:` for maintenance
5. Push and open a Pull Request

## Reporting Issues

- Use GitHub Issues for bug reports and feature requests
- For security vulnerabilities, see [SECURITY.md](SECURITY.md)

## Dependencies

This project depends on [gRPCServer.jl](https://github.com/s-celles/gRPCServer.jl) (develop branch), which is not yet registered in the Julia General Registry. When developing locally, you may need to:

```bash
git clone --branch develop https://github.com/s-celles/gRPCServer.jl /tmp/gRPCServer.jl
julia --project=. -e 'using Pkg; Pkg.develop(PackageSpec(path="/tmp/gRPCServer.jl"))'
```

## License

By contributing, you agree that your contributions will be licensed under the MIT License.
