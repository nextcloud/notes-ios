This is an Xcode project for a native app written in Swift.
It provides an iOS app as the main product.
The app is a native client for Nextcloud Notes with offline capability.
Please follow these guidelines when contributing:

## Code Standards

### Required Before Each Commit
- Run `swiftlint` before committing any changes to ensure proper code formatting
- This will run SwiftLint on all Swift source code files in `iOCNotes/` to maintain consistent style

### Development Flow
- Build: `xcodebuild build -project iOCNotes.xcodeproj -scheme iOCNotes`
- Test: `xcodebuild test -project iOCNotes.xcodeproj -scheme iOCNotes`

## Repository Structure
- `Brand/`: Meta information and branding code for the app.
- `Editor/`: Code for the markdown editor with syntax highlighting.
- `Extensions/`: Extensions for types provided by the first-party platform or frameworks.
- `iOCNotes/`: The new main app code for the main target written with SwiftUI which is supposed to replace the rest in the future.
- `iOCNotesTests/`: Unit tests for the `iOCNotes` app.
- `Models/`: Code related to data models which is supposed to be replaced with `iOCNotes/` in the future.
- `Networking/`: Code related to network requests which is supposed to be replaced with `iOCNotes/` in the future.
- `README/`: Assets referenced from the README.md file written for GitHub.
- `Server/`: Isolated scripts to set up a test backend based on Docker on developer machines when required.
- `Source/`: The main source code for the app which is supposed to be replaced with `iOCNotes/` in the future.
- `svg/`: Graphics assets possibly still used in the user interface.

## Key Guidelines
1. Follow Swift best practices and idiomatic patterns
2. Use dependency injection patterns where appropriate
3. Write unit tests for new functionality. Use table-driven unit tests when possible
4. Consider strict concurrency checking and thread safety in your code