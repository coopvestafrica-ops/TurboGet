# Contributing to TurboGet

Thank you for your interest in contributing to TurboGet! This document provides guidelines and instructions for contributing.

## Code of Conduct

By participating in this project, you agree to maintain a respectful and inclusive environment for everyone.

## Getting Started

### Prerequisites

Before you begin, ensure you have:

- Flutter SDK 3.24.0 or higher
- Dart SDK 3.5.0 or higher
- Android Studio or VS Code with Flutter extensions
- Git configured on your machine

### Development Setup

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR-USERNAME/turboget.git
   cd turboget
   ```

3. **Add upstream remote**:
   ```bash
   git remote add upstream https://github.com/original-owner/turboget.git
   ```

4. **Create a feature branch**:
   ```bash
   git checkout -b feature/your-feature-name
   ```

5. **Install dependencies**:
   ```bash
   flutter pub get
   ```

6. **Run the app** to verify setup:
   ```bash
   flutter run
   ```

## Making Changes

### Code Style

We follow the [Effective Dart](https://effective-dart.com/) style guide with Flutter-specific conventions:

- Use `flutter analyze` to check for issues
- Run `flutter format` before committing
- Prefer `const` constructors where applicable
- Use meaningful variable and function names
- Add documentation comments for public APIs

### Commits

We use [Conventional Commits](https://www.conventionalcommits.org/) for commit messages:

```
<type>(<scope>): <description>

[optional body]

[optional footer]
```

**Types:**
- `feat` - New feature
- `fix` - Bug fix
- `docs` - Documentation changes
- `style` - Code style changes (formatting, etc.)
- `refactor` - Code refactoring
- `test` - Adding or updating tests
- `chore` - Maintenance tasks

**Examples:**
```
feat(auth): add biometric authentication
fix(download): resolve pause/resume issue
docs(readme): update installation instructions
test(auth): add password validation tests
```

### Pull Requests

1. **Keep PRs focused** - One feature or fix per PR
2. **Update documentation** - Update README and docs as needed
3. **Add tests** - Include tests for new functionality
4. **Follow the template** - Use the PR template provided

### PR Description Template

```markdown
## Summary
Brief description of the changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
Describe how this was tested

## Screenshots
If applicable, add screenshots

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] Tests added/updated
- [ ] All tests pass
```

## Testing

### Running Tests

```bash
# Run all tests
flutter test

# Run tests with coverage
flutter test --coverage

# Run specific test file
flutter test test/services/auth_service_test.dart

# Run tests in watch mode
flutter test --watch
```

### Writing Tests

- Place tests in the `test/` directory
- Follow naming convention: `*_test.dart`
- Use descriptive test names
- Follow the Arrange-Act-Assert pattern

```dart
test('should login successfully with valid credentials', () async {
  // Arrange
  await authService.initialize();
  
  // Act
  final result = await authService.login('valid_password');
  
  // Assert
  expect(result, isTrue);
  expect(authService.isLoggedIn, isTrue);
});
```

### Code Coverage

We target 80%+ code coverage. To check coverage:

```bash
flutter test --coverage
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

## Project Structure

```
lib/
├── main.dart                 # Entry point
├── providers/                # Riverpod providers
│   ├── auth_provider.dart
│   ├── download_provider.dart
│   ├── settings_provider.dart
│   └── theme_provider.dart
├── models/                  # Data models
│   ├── download_item.dart
│   └── user.dart
├── screens/                 # UI screens
├── services/                # Business services
│   ├── auth_service.dart
│   ├── database_service.dart
│   ├── logger_service.dart
│   └── validation_service.dart
└── widgets/                 # Reusable widgets
```

## Reporting Issues

### Bug Reports

Include:
- Clear description of the issue
- Steps to reproduce
- Expected vs actual behavior
- Flutter version and environment
- Error logs if applicable

### Feature Requests

Include:
- Clear description of the feature
- Use case / motivation
- Possible implementation approach
- Any relevant examples or references

## Questions?

- Open an issue for bugs or feature requests
- Join our community discussions
- Check existing issues before creating new ones

## License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to TurboGet! 🎉
