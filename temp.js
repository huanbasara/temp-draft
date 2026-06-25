
const fs = require("fs");
const path = require("path");
const ts = require("typescript");

const worksheetPathArg = process.argv[2];

if (!worksheetPathArg) {
    console.error("Usage: node scripts/build.js <worksheet-js-path>");
    process.exit(1);
}

const worksheetPath = path.resolve(worksheetPathArg);
const worksheetDir = path.dirname(worksheetPath);
const worksheetFileName = path.basename(worksheetPath, ".js");
const outputPath = path.join(worksheetDir, `${worksheetFileName}.bundle.js`);

const worksheetSource = fs.readFileSync(worksheetPath, "utf8");

const worksheetAst = ts.createSourceFile(
    worksheetPath,
    worksheetSource,
    ts.ScriptTarget.Latest,
    true,
    ts.ScriptKind.JS
);

function getStatementTextWithoutExport(sourceText, sourceFile, statement) {
    const start = statement.getFullStart();
    const end = statement.end;

    const originalText = sourceText.substring(start, end);

    if (!statement.modifiers) {
        return originalText.trimStart();
    }

    const exportModifier = statement.modifiers.find(
        modifier => modifier.kind === ts.SyntaxKind.ExportKeyword
    );

    if (!exportModifier) {
        return originalText.trimStart();
    }

    const exportStart = exportModifier.getStart(sourceFile) - start;
    const exportEnd = exportModifier.end - start;

    return (
        originalText.substring(0, exportStart) +
        originalText.substring(exportEnd).trimStart()
    ).trimStart();
}

function getExportedStatementName(statement) {
    if (ts.isFunctionDeclaration(statement) && statement.name) {
        return statement.name.text;
    }

    if (ts.isVariableStatement(statement)) {
        if (statement.declarationList.declarations.length !== 1) {
            return null;
        }

        const declaration = statement.declarationList.declarations[0];

        if (ts.isIdentifier(declaration.name)) {
            return declaration.name.text;
        }
    }

    return null;
}

function extractExportedMember(importedFilePath, memberName) {
    const sourceText = fs.readFileSync(importedFilePath, "utf8");

    const sourceFile = ts.createSourceFile(
        importedFilePath,
        sourceText,
        ts.ScriptTarget.Latest,
        true,
        ts.ScriptKind.JS
    );

    for (const statement of sourceFile.statements) {
        const statementName = getExportedStatementName(statement);

        if (statementName !== memberName) {
            continue;
        }

        return getStatementTextWithoutExport(sourceText, sourceFile, statement);
    }

    throw new Error(`Cannot find exported member "${memberName}" in ${importedFilePath}`);
}

function parseNamedImports(importDeclaration) {
    const importClause = importDeclaration.importClause;

    if (!importClause || !importClause.namedBindings) {
        return [];
    }

    if (!ts.isNamedImports(importClause.namedBindings)) {
        throw new Error("Only named imports are supported.");
    }

    return importClause.namedBindings.elements.map(element => element.name.text);
}

const importDeclarations = worksheetAst.statements.filter(ts.isImportDeclaration);

const expandedBlocks = [];
const importRanges = [];

for (const importDeclaration of importDeclarations) {
    const moduleSpecifier = importDeclaration.moduleSpecifier;

    if (!ts.isStringLiteral(moduleSpecifier)) {
        continue;
    }

    const importPath = moduleSpecifier.text;
    const importedFilePath = path.resolve(worksheetDir, importPath);
    const importedNames = parseNamedImports(importDeclaration);

    for (const importedName of importedNames) {
        const block = extractExportedMember(importedFilePath, importedName);
        expandedBlocks.push(block);
    }

    importRanges.push({
        start: importDeclaration.getFullStart(),
        end: importDeclaration.end
    });
}

let worksheetWithoutImports = worksheetSource;

for (const range of importRanges.sort((a, b) => b.start - a.start)) {
    worksheetWithoutImports =
        worksheetWithoutImports.substring(0, range.start) +
        worksheetWithoutImports.substring(range.end);
}

const outputSource =
    expandedBlocks.join("\n\n") +
    "\n\n" +
    worksheetWithoutImports.trimStart();

fs.writeFileSync(outputPath, outputSource, "utf8");

console.log(`Generated: ${outputPath}`);
