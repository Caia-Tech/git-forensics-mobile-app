# Git Manager TODO

## Current Implementation
The current GitManager uses shell commands which won't work on iOS due to sandboxing restrictions.

## Next Steps
1. Integrate SwiftGit2 or libgit2 for proper Git operations
2. Replace shell commands with library calls
3. Handle repository initialization properly
4. Implement proper error handling

## Temporary Solution
For MVP development and testing, we can:
1. Use a simple file-based system that mimics Git structure
2. Focus on the cryptographic integrity and UI
3. Add proper Git integration in the next phase

## Libraries to Consider
- SwiftGit2: https://github.com/SwiftGit2/SwiftGit2
- libgit2: Direct C library integration
- Custom implementation using file operations