# temp-draft

# Quest Worksheet Builder

This project provides a lightweight local development environment for Quest Worksheet JavaScript scripts.

## Requirements

- Node.js (LTS version recommended)

- npm

- Visual Studio Code

## Setup

Clone the repository and install the project dependencies:

```bash

npm install

```

This command installs all required development dependencies listed in `package.json`.

## Build

Open a `worksheet.js` file in Visual Studio Code.

Use one of the following methods to build the worksheet:

- **Terminal → Run Task → Build current worksheet**

- **Ctrl + Shift + B**

The builder will:

- Resolve all named imports.

- Expand imported constants and functions.

- Remove `import` and `export` keywords.

- Preserve comments and formatting whenever possible.

- Generate `worksheet.bundle.js` in the same directory.

## Project Structure

```text

common/

    Shared reusable functions and constants.

scripts/

    build.js

    Worksheet build tool.

worksheet/

    Individual worksheet implementations.

```

## Notes

- Only `worksheet.js` should use `import` statements.

- Shared reusable code should be placed under the `common` directory.

- Generated `worksheet.bundle.js` files are build artifacts and should not be committed.
