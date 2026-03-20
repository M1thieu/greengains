Run static analysis on both the Flutter app and the TypeScript backend. Report any errors or warnings found.

Steps:
1. Run `flutter analyze` from the project root
2. Run `cd backend && npx tsc --noEmit` for TypeScript type checking
3. Report a summary: total issues found, files affected, and whether each check passed or failed
