# Project Analysis Design Document

## Overview

This document outlines the design for a comprehensive code analysis system for the Miji project. The system will analyze both frontend (TypeScript/Vue) and backend (Rust) code to identify issues, optimization opportunities, and areas requiring refactoring.

### Goals

1. **Automated Code Quality Analysis** - Detect code smells, anti-patterns, and quality issues
2. **Performance Optimization** - Identify bottlenecks and optimization opportunities
3. **Security Assessment** - Find security vulnerabilities and best practice violations
4. **Technical Debt Tracking** - Catalog TODO items, deprecated code, and missing tests
5. **Actionable Recommendations** - Provide prioritized, effort-estimated improvement suggestions

### Non-Goals

- Automatic code refactoring (analysis only, not modification)
- Real-time analysis during development (batch analysis)
- Integration with CI/CD pipelines (manual execution)

## Architecture

### High-Level Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Analysis Orchestrator                     │
│                  (Coordinates all analyzers)                 │
└─────────────────────────────────────────────────────────────┘
                              │
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐   ┌───────────────┐   ┌───────────────┐
│   Frontend    │   │   Backend     │   │   Metrics     │
│   Analyzer    │   │   Analyzer    │   │   Collector   │
└───────────────┘   └───────────────┘   └───────────────┘
        │                     │                     │
        ▼                     ▼                     ▼
┌───────────────────────────────────────────────────────────┐
│                    Issue Aggregator                        │
│         (Collects, categorizes, prioritizes)               │
└───────────────────────────────────────────────────────────┘
                              │
                              ▼
┌───────────────────────────────────────────────────────────┐
│                    Report Generator                        │
│         (Markdown, JSON, HTML outputs)                     │
└───────────────────────────────────────────────────────────┘
```

### Component Breakdown

#### 1. Analysis Orchestrator
- Entry point for analysis execution
- Coordinates multiple analyzers
- Manages analysis configuration
- Handles parallel execution

#### 2. Frontend Analyzer
Sub-analyzers:
- **TypeScript Analyzer**: Unused code, type safety, complexity
- **Vue Component Analyzer**: Component structure, props, complexity
- **Store Analyzer**: State management patterns, consistency
- **Composable Analyzer**: Code duplication, reusability
- **Performance Analyzer**: Bundle size, rendering optimization

#### 3. Backend Analyzer
Sub-analyzers:
- **Rust Code Analyzer**: Unused dependencies, error handling patterns
- **Database Query Analyzer**: N+1 queries, missing indexes
- **Async Code Analyzer**: Blocking operations, async patterns
- **Memory Analyzer**: Cloning patterns, potential leaks

#### 4. Metrics Collector
- Lines of code counter
- Cyclomatic complexity calculator
- Maintainability index calculator
- Test coverage reporter
- Dependency tracker

#### 5. Issue Aggregator
- Collects issues from all analyzers
- Categorizes by type (Quality, Performance, Security, etc.)
- Assigns severity levels (Critical, High, Medium, Low)
- Estimates effort (Small, Medium, Large)
- Prioritizes based on impact

#### 6. Report Generator
- Generates Markdown reports
- Exports JSON data for tooling
- Creates HTML dashboards (optional)
- Provides actionable recommendations

## Components and Interfaces

### Core Interfaces

```typescript
// Issue representation
interface AnalysisIssue {
  id: string;
  category: IssueCategory;
  severity: IssueSeverity;
  title: string;
  description: string;
  file: string;
  line?: number;
  column?: number;
  code?: string;
  recommendation: string;
  effort: EffortLevel;
  impact: ImpactArea[];
  examples?: CodeExample[];
}

enum IssueCategory {
  CODE_QUALITY = 'code_quality',
  ARCHITECTURE = 'architecture',
  PERFORMANCE = 'performance',
  TECHNICAL_DEBT = 'technical_debt',
  SECURITY = 'security',
  CONSISTENCY = 'consistency',
  REUSABILITY = 'reusability',
  BACKEND = 'backend',
}

enum IssueSeverity {
  CRITICAL = 'critical',
  HIGH = 'high',
  MEDIUM = 'medium',
  LOW = 'low',
}

enum EffortLevel {
  SMALL = 'small',      // < 1 day
  MEDIUM = 'medium',    // 1-3 days
  LARGE = 'large',      // > 3 days
}

enum ImpactArea {
  SECURITY = 'security',
  PERFORMANCE = 'performance',
  MAINTAINABILITY = 'maintainability',
  RELIABILITY = 'reliability',
  SCALABILITY = 'scalability',
}

// Analyzer interface
interface Analyzer {
  name: string;
  analyze(config: AnalysisConfig): Promise<AnalysisIssue[]>;
}

// Configuration
interface AnalysisConfig {
  rootPath: string;
  include: string[];
  exclude: string[];
  thresholds: {
    maxComplexity: number;
    maxFileLines: number;
    maxComponentProps: number;
    minTestCoverage: number;
  };
  rules: {
    [key: string]: 'error' | 'warn' | 'off';
  };
}

// Metrics
interface CodeMetrics {
  linesOfCode: {
    total: number;
    byLanguage: Record<string, number>;
    byModule: Record<string, number>;
  };
  complexity: {
    average: number;
    max: number;
    byFile: Record<string, number>;
  };
  maintainability: {
    average: number;
    byFile: Record<string, number>;
  };
  testCoverage: {
    overall: number;
    byModule: Record<string, number>;
  };
  dependencies: {
    direct: DependencyInfo[];
    transitive: DependencyInfo[];
  };
}

interface DependencyInfo {
  name: string;
  version: string;
  size: number;
  vulnerabilities: number;
}
```

## Data Models

### Analysis Result Model

```typescript
interface AnalysisResult {
  timestamp: string;
  projectName: string;
  version: string;
  summary: {
    totalIssues: number;
    bySeverity: Record<IssueSeverity, number>;
    byCategory: Record<IssueCategory, number>;
  };
  issues: AnalysisIssue[];
  metrics: CodeMetrics;
  recommendations: Recommendation[];
}

interface Recommendation {
  priority: number;
  title: string;
  description: string;
  relatedIssues: string[];
  effort: EffortLevel;
  impact: ImpactArea[];
  steps: string[];
  examples: CodeExample[];
}

interface CodeExample {
  title: string;
  before: string;
  after: string;
  explanation: string;
}
```

### File System Model

```typescript
interface FileNode {
  path: string;
  type: 'file' | 'directory';
  extension?: string;
  size: number;
  lines?: number;
  children?: FileNode[];
}

interface ParsedFile {
  path: string;
  language: 'typescript' | 'vue' | 'rust';
  ast: any; // Language-specific AST
  imports: ImportStatement[];
  exports: ExportStatement[];
  functions: FunctionDeclaration[];
  classes: ClassDeclaration[];
  components?: ComponentDeclaration[];
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system-essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*

### Code Quality Properties

**Property 1: Unused Code Detection Completeness**
*For any* TypeScript or Vue file in the codebase, if it contains unused imports, variables, or functions, the analyzer should detect and report them.
**Validates: Requirements 1.1**

**Property 2: Component Complexity Threshold**
*For any* Vue component file, if it exceeds 300 lines or has more than 10 props, the analyzer should flag it as overly complex.
**Validates: Requirements 1.2**

**Property 3: Store Pattern Consistency**
*For any* Pinia store file, if it doesn't follow the established patterns (withLoadingSafe, error handling, immutable updates), the analyzer should identify the inconsistency.
**Validates: Requirements 1.3**

**Property 4: Composable Duplication Detection**
*For any* pair of composable files, if they contain similar logic above a threshold (e.g., 80% similarity), the analyzer should flag them as candidates for extraction.
**Validates: Requirements 1.4**

**Property 5: Error Handling Uniformity**
*For any* try-catch block in the codebase, if it doesn't use the AppError.wrap pattern, the analyzer should report it as inconsistent error handling.
**Validates: Requirements 1.5**

### Architecture Properties

**Property 6: Circular Dependency Detection**
*For any* set of modules in the dependency graph, if there exists a cycle, the analyzer should identify all modules involved in the circular dependency.
**Validates: Requirements 2.1**

**Property 7: Component Coupling Measurement**
*For any* pair of components, if they have high coupling (direct imports, shared mutable state) but are not in a parent-child relationship, the analyzer should flag tight coupling.
**Validates: Requirements 2.2**

**Property 8: Single Responsibility Validation**
*For any* store, if it manages more than one domain entity or has more than 15 actions, the analyzer should flag it as violating single responsibility principle.
**Validates: Requirements 2.3**

**Property 9: Abstraction Layer Enforcement**
*For any* component file, if it directly imports database or ORM code, the analyzer should report missing abstraction layer.
**Validates: Requirements 2.4**

**Property 10: Prop Drilling Detection**
*For any* component tree, if a prop is passed through 3 or more levels without being used in intermediate components, the analyzer should suggest provide/inject.
**Validates: Requirements 2.5**

### Performance Properties

**Property 11: Expensive Computation Detection**
*For any* computed property, if it contains loops, recursion, or API calls without memoization, the analyzer should flag it as potentially expensive.
**Validates: Requirements 3.1**

**Property 12: V-for Key Validation**
*For any* v-for directive in Vue templates, if it lacks a :key binding or uses a non-unique key (like index), the analyzer should report it.
**Validates: Requirements 3.2**

**Property 13: Deep Watcher Detection**
*For any* watcher in Vue components, if it uses { deep: true } option, the analyzer should flag it as a potential performance issue.
**Validates: Requirements 3.3**

**Property 14: Large Dependency Identification**
*For any* imported dependency, if its bundle size exceeds 100KB and it's not lazy-loaded, the analyzer should suggest code-splitting.
**Validates: Requirements 3.4**

**Property 15: API Call Optimization**
*For any* API call in event handlers (input, scroll, resize), if it lacks debounce or throttle wrapper, the analyzer should recommend optimization.
**Validates: Requirements 3.5**

### Technical Debt Properties

**Property 16: TODO Marker Extraction**
*For any* code file, all comments containing TODO, FIXME, HACK, or XXX markers should be extracted and cataloged with file location.
**Validates: Requirements 4.1**

**Property 17: Deprecated API Detection**
*For any* code that uses deprecated Vue 3 APIs (e.g., $on, $off) or deprecated library methods, the analyzer should identify and suggest alternatives.
**Validates: Requirements 4.2**

**Property 18: Test Coverage Threshold**
*For any* module, if test coverage is below 60%, the analyzer should flag it as having insufficient tests.
**Validates: Requirements 4.3**

**Property 19: Documentation Completeness**
*For any* exported function or component, if it lacks JSDoc comments with @param and @returns tags, the analyzer should report missing documentation.
**Validates: Requirements 4.4**

**Property 20: Type Safety Validation**
*For any* TypeScript file, all occurrences of 'any' type or 'as' type assertions should be detected and reported as type safety issues.
**Validates: Requirements 4.5**

### Security Properties

**Property 21: Token Storage Security**
*For any* code that stores authentication tokens, if it uses localStorage without encryption or transmits tokens without HTTPS, the analyzer should flag security risk.
**Validates: Requirements 5.1**

**Property 22: Input Validation Enforcement**
*For any* function that accepts user input, if it doesn't validate input using Zod schemas or similar validation, the analyzer should report missing validation.
**Validates: Requirements 5.2**

**Property 23: Credential Detection**
*For any* string literal in code, if it matches patterns for API keys, passwords, or tokens (e.g., contains "key", "secret", "password"), the analyzer should flag potential hardcoded credentials.
**Validates: Requirements 5.3**

**Property 24: Dependency Vulnerability Check**
*For any* dependency in package.json, if it has known security vulnerabilities in the npm advisory database, the analyzer should report them with severity.
**Validates: Requirements 5.4**

**Property 25: Sensitive Data Encryption**
*For any* code that persists sensitive data (passwords, tokens, personal info), if it doesn't use encryption before storage, the analyzer should flag unencrypted storage.
**Validates: Requirements 5.5**

### Consistency Properties

**Property 26: Naming Convention Consistency**
*For any* variable, function, or component name, if it doesn't follow the established conventions (camelCase for variables, PascalCase for components), the analyzer should report inconsistency.
**Validates: Requirements 6.1**

**Property 27: File Organization Validation**
*For any* file, if it's placed in an incorrect directory (e.g., component in utils/, store in components/), the analyzer should suggest correct location.
**Validates: Requirements 6.2**

**Property 28: Import Statement Organization**
*For any* file with imports, if imports are not grouped and ordered (external → internal → types), the analyzer should report inconsistent import organization.
**Validates: Requirements 6.3**

**Property 29: Component Structure Consistency**
*For any* Vue component, if it doesn't follow the standard structure order (script setup → template → style), the analyzer should flag structural inconsistency.
**Validates: Requirements 6.4**

**Property 30: I18n Usage Validation**
*For any* user-facing string in components, if it's hardcoded instead of using i18n translation keys, the analyzer should report missing internationalization.
**Validates: Requirements 6.5**

### Reusability Properties

**Property 31: Code Duplication Detection**
*For any* pair of functions with similar logic (>70% code similarity), the analyzer should identify them as candidates for extraction into shared utilities.
**Validates: Requirements 7.1**

**Property 32: UI Pattern Extraction**
*For any* set of components with similar template structures (>80% similarity), the analyzer should suggest creating a shared component.
**Validates: Requirements 7.2**

**Property 33: Utility Function Generalization**
*For any* utility function that's specific to one module but could be generalized (e.g., accepts specific types that could be generic), the analyzer should suggest generalization.
**Validates: Requirements 7.3**

**Property 34: Type Definition Deduplication**
*For any* pair of type definitions that are structurally identical, the analyzer should flag them as duplicate types that should be consolidated.
**Validates: Requirements 7.4**

**Property 35: Validation Schema Consolidation**
*For any* validation logic that's repeated across multiple files, the analyzer should suggest creating shared Zod schemas.
**Validates: Requirements 7.5**

### Backend Properties

**Property 36: Unused Rust Dependencies**
*For any* dependency listed in Cargo.toml, if it's not imported in any Rust source file, the analyzer should flag it as unused.
**Validates: Requirements 8.1**

**Property 37: Result/Option Handling Consistency**
*For any* Rust function returning Result or Option, if it uses .unwrap() or .expect() in non-test code, the analyzer should report unsafe error handling.
**Validates: Requirements 8.2**

**Property 38: N+1 Query Detection**
*For any* database query inside a loop, the analyzer should flag it as a potential N+1 query problem and suggest batch loading.
**Validates: Requirements 8.3**

**Property 39: Async Blocking Detection**
*For any* async function in Rust, if it contains blocking operations (std::fs, thread::sleep, blocking I/O), the analyzer should report blocking in async context.
**Validates: Requirements 8.4**

**Property 40: Memory Efficiency Check**
*For any* Rust code with excessive .clone() calls or large allocations in loops, the analyzer should flag potential memory inefficiency.
**Validates: Requirements 8.5**

### Reporting Properties

**Property 41: Issue Severity Categorization**
*For any* detected issue, it should be assigned exactly one severity level (Critical, High, Medium, Low) based on its impact on security, performance, and maintainability.
**Validates: Requirements 9.1**

**Property 42: Issue Grouping Consistency**
*For any* set of related issues (e.g., all unused imports), they should be grouped together under the same category in the report.
**Validates: Requirements 9.2**

**Property 43: Effort Estimation Completeness**
*For any* improvement suggestion, it should include an effort estimate (Small, Medium, Large) based on the scope of changes required.
**Validates: Requirements 9.3**

**Property 44: Recommendation Actionability**
*For any* recommendation in the report, it should include at least one code example or reference to best practices documentation.
**Validates: Requirements 9.4**

**Property 45: Priority Calculation Correctness**
*For any* issue, its priority should be calculated considering security impact (highest weight), performance impact (medium weight), and maintainability impact (lower weight).
**Validates: Requirements 9.5**

### Metrics Properties

**Property 46: LOC Calculation Accuracy**
*For any* codebase, the total lines of code should equal the sum of lines across all language categories, and the sum across all modules.
**Validates: Requirements 10.1**

**Property 47: Complexity Calculation Consistency**
*For any* function or component, its cyclomatic complexity should be calculated using the standard formula: E - N + 2P (edges - nodes + 2*connected components).
**Validates: Requirements 10.2**

**Property 48: Maintainability Index Formula**
*For any* file, its maintainability index should be calculated using the standard formula: 171 - 5.2*ln(HV) - 0.23*CC - 16.2*ln(LOC), where HV=Halstead Volume, CC=Cyclomatic Complexity, LOC=Lines of Code.
**Validates: Requirements 10.3**

**Property 49: Coverage Percentage Accuracy**
*For any* module, its test coverage percentage should be calculated as (covered lines / total executable lines) * 100, rounded to 2 decimal places.
**Validates: Requirements 10.4**

**Property 50: Dependency Completeness**
*For any* project, the dependency list should include all direct dependencies from package.json and Cargo.toml, plus all transitive dependencies from lock files.
**Validates: Requirements 10.5**

## Error Handling

### Error Categories

```typescript
enum AnalysisErrorCode {
  FILE_NOT_FOUND = 'FILE_NOT_FOUND',
  PARSE_ERROR = 'PARSE_ERROR',
  INVALID_CONFIG = 'INVALID_CONFIG',
  ANALYZER_FAILED = 'ANALYZER_FAILED',
  INSUFFICIENT_PERMISSIONS = 'INSUFFICIENT_PERMISSIONS',
  TIMEOUT = 'TIMEOUT',
}

class AnalysisError extends Error {
  constructor(
    public code: AnalysisErrorCode,
    public message: string,
    public file?: string,
    public details?: unknown,
  ) {
    super(message);
    this.name = 'AnalysisError';
  }
}
```

### Error Handling Strategy

1. **Graceful Degradation**: If one analyzer fails, continue with others
2. **Detailed Logging**: Log all errors with context for debugging
3. **Partial Results**: Return partial analysis results even if some analyzers fail
4. **Error Reporting**: Include failed analyzers in the final report
5. **Retry Logic**: Retry transient failures (file locks, network issues)

## Testing Strategy

### Unit Testing

**Test Coverage Goals:**
- Core analyzers: 80% coverage
- Utility functions: 90% coverage
- Issue aggregation logic: 85% coverage
- Report generation: 75% coverage

**Key Test Areas:**
1. **Parser Tests**: Verify AST parsing for TypeScript, Vue, and Rust
2. **Pattern Detection Tests**: Test each detection rule with positive and negative cases
3. **Metrics Calculation Tests**: Verify accuracy of LOC, complexity, maintainability calculations
4. **Prioritization Tests**: Ensure correct severity and effort assignment
5. **Report Generation Tests**: Validate output format and completeness

### Property-Based Testing

**Testing Framework**: fast-check (for TypeScript/JavaScript)

**Property Test Strategy:**
- Generate random code samples with known issues
- Verify analyzers detect all injected issues
- Ensure no false positives on clean code
- Test edge cases (empty files, very large files, deeply nested structures)

**Key Properties to Test:**
1. **Detection Completeness**: All injected issues are found
2. **No False Positives**: Clean code produces no issues
3. **Idempotency**: Running analysis twice produces same results
4. **Consistency**: Same issue always gets same severity/effort
5. **Metrics Accuracy**: Calculated metrics match expected values

### Integration Testing

**Test Scenarios:**
1. **Full Project Analysis**: Run on Miji codebase and verify known issues are detected
2. **Incremental Analysis**: Analyze only changed files and verify correctness
3. **Large Codebase**: Test performance on projects with 100k+ LOC
4. **Multi-Language**: Verify correct handling of mixed TypeScript/Rust projects
5. **Error Scenarios**: Test behavior with invalid files, missing dependencies

### Test Data

**Sample Projects:**
- Minimal project with known issues (for fast tests)
- Medium project with diverse patterns (for integration tests)
- Miji project itself (for real-world validation)

**Issue Injection:**
- Create test files with specific anti-patterns
- Verify each analyzer detects its target issues
- Ensure no cross-contamination between analyzers

## Implementation Considerations

### Performance Optimization

1. **Parallel Analysis**: Run independent analyzers concurrently
2. **Incremental Analysis**: Cache results and only re-analyze changed files
3. **AST Caching**: Parse each file once and share AST across analyzers
4. **Lazy Loading**: Load analyzers on-demand based on file types
5. **Streaming Results**: Report issues as they're found, don't wait for completion

### Scalability

1. **File Batching**: Process files in batches to manage memory
2. **Worker Threads**: Use worker threads for CPU-intensive analysis
3. **Progress Reporting**: Show progress for long-running analysis
4. **Cancellation**: Support cancelling analysis mid-execution
5. **Resource Limits**: Set memory and time limits per analyzer

### Extensibility

1. **Plugin Architecture**: Allow custom analyzers to be added
2. **Rule Configuration**: Enable/disable specific rules via config
3. **Custom Thresholds**: Allow users to set their own complexity/size limits
4. **Output Formats**: Support multiple output formats (Markdown, JSON, HTML)
5. **Integration Hooks**: Provide hooks for CI/CD integration

### Technology Stack

**Frontend Analysis:**
- **TypeScript Compiler API**: For TypeScript AST parsing and type checking
- **Vue Template Compiler**: For Vue SFC parsing
- **ESLint**: For leveraging existing rules
- **ts-morph**: For easier TypeScript AST manipulation

**Backend Analysis:**
- **syn**: Rust parser for AST generation
- **cargo-metadata**: For dependency analysis
- **rustc**: For compilation checks

**Metrics:**
- **cloc**: For lines of code counting
- **complexity-report**: For cyclomatic complexity
- **istanbul/c8**: For test coverage

**Reporting:**
- **markdown-it**: For Markdown generation
- **chart.js**: For visualization in HTML reports
- **json-schema**: For structured JSON output

## Analysis Workflow

### Execution Flow

```
1. Load Configuration
   ├─ Read analysis config file
   ├─ Validate configuration
   └─ Set up analyzers

2. Discover Files
   ├─ Scan project directory
   ├─ Apply include/exclude patterns
   └─ Group by file type

3. Parse Files
   ├─ Parse TypeScript/Vue files → AST
   ├─ Parse Rust files → AST
   └─ Cache parsed results

4. Run Analyzers (Parallel)
   ├─ Frontend Analyzers
   │  ├─ TypeScript Analyzer
   │  ├─ Vue Component Analyzer
   │  ├─ Store Analyzer
   │  ├─ Composable Analyzer
   │  └─ Performance Analyzer
   ├─ Backend Analyzers
   │  ├─ Rust Code Analyzer
   │  ├─ Database Query Analyzer
   │  ├─ Async Code Analyzer
   │  └─ Memory Analyzer
   └─ Metrics Collector
      ├─ LOC Counter
      ├─ Complexity Calculator
      ├─ Maintainability Calculator
      ├─ Coverage Reporter
      └─ Dependency Tracker

5. Aggregate Results
   ├─ Collect all issues
   ├─ Remove duplicates
   ├─ Categorize by type
   ├─ Assign severity
   ├─ Estimate effort
   └─ Calculate priority

6. Generate Recommendations
   ├─ Group related issues
   ├─ Create actionable steps
   ├─ Add code examples
   └─ Prioritize by impact

7. Generate Reports
   ├─ Create Markdown report
   ├─ Export JSON data
   ├─ Generate HTML dashboard (optional)
   └─ Save to output directory

8. Display Summary
   ├─ Show issue counts
   ├─ Display top priorities
   └─ Provide next steps
```

### Configuration Example

```typescript
// analysis.config.ts
export default {
  rootPath: '.',
  include: [
    'src/**/*.ts',
    'src/**/*.vue',
    'src-tauri/**/*.rs',
  ],
  exclude: [
    'node_modules/**',
    'dist/**',
    'target/**',
    '**/*.test.ts',
    '**/*.spec.ts',
  ],
  thresholds: {
    maxComplexity: 10,
    maxFileLines: 300,
    maxComponentProps: 10,
    minTestCoverage: 60,
    maxDependencySize: 100 * 1024, // 100KB
  },
  rules: {
    'unused-imports': 'error',
    'component-complexity': 'warn',
    'store-patterns': 'error',
    'code-duplication': 'warn',
    'error-handling': 'error',
    'circular-dependencies': 'error',
    'tight-coupling': 'warn',
    'single-responsibility': 'warn',
    'missing-abstraction': 'error',
    'prop-drilling': 'warn',
    'expensive-computed': 'warn',
    'missing-keys': 'error',
    'deep-watchers': 'warn',
    'large-dependencies': 'warn',
    'unoptimized-api-calls': 'warn',
    'todo-markers': 'warn',
    'deprecated-apis': 'error',
    'insufficient-tests': 'warn',
    'missing-docs': 'warn',
    'type-safety': 'error',
    'insecure-storage': 'error',
    'missing-validation': 'error',
    'hardcoded-credentials': 'error',
    'dependency-vulnerabilities': 'error',
    'unencrypted-data': 'error',
    'naming-conventions': 'warn',
    'file-organization': 'warn',
    'import-organization': 'warn',
    'component-structure': 'warn',
    'missing-i18n': 'warn',
    'code-duplication-functions': 'warn',
    'ui-pattern-duplication': 'warn',
    'utility-generalization': 'warn',
    'duplicate-types': 'warn',
    'validation-consolidation': 'warn',
    'unused-rust-deps': 'warn',
    'unsafe-error-handling': 'error',
    'n-plus-one-queries': 'error',
    'blocking-in-async': 'error',
    'memory-inefficiency': 'warn',
  },
  output: {
    directory: '.kiro/analysis',
    formats: ['markdown', 'json'],
    includeMetrics: true,
    includeExamples: true,
  },
};
```

## Report Format

### Markdown Report Structure

```markdown
# Miji Project Analysis Report

**Generated:** 2025-01-13 10:30:00
**Version:** 0.1.0
**Analysis Duration:** 45.2s

## Executive Summary

- **Total Issues:** 127
- **Critical:** 3
- **High:** 15
- **Medium:** 54
- **Low:** 55

### Top Priorities

1. [CRITICAL] Insecure token storage in localStorage (3 occurrences)
2. [CRITICAL] Hardcoded API credentials detected (2 occurrences)
3. [HIGH] Circular dependency between stores (5 modules affected)
4. [HIGH] N+1 query in transaction listing (1 occurrence)
5. [HIGH] Missing input validation (12 occurrences)

## Metrics

### Lines of Code
- **Total:** 45,234
- **TypeScript:** 32,156 (71%)
- **Vue:** 8,945 (20%)
- **Rust:** 4,133 (9%)

### Complexity
- **Average Cyclomatic Complexity:** 4.2
- **Max Complexity:** 18 (src/stores/todoStore.ts:compareTodos)
- **Files > 10 Complexity:** 8

### Maintainability
- **Average Maintainability Index:** 72.5
- **Files < 60 (Poor):** 5
- **Files 60-80 (Fair):** 23
- **Files > 80 (Good):** 145

### Test Coverage
- **Overall:** 58.3%
- **Frontend:** 62.1%
- **Backend:** 51.7%
- **Modules < 60%:** 12

### Dependencies
- **Direct:** 45
- **Transitive:** 312
- **With Vulnerabilities:** 2 (low severity)
- **Large (>100KB):** 3

## Issues by Category

### 1. Code Quality (32 issues)

#### Unused Imports (15 issues)
**Severity:** Low | **Effort:** Small

- `src/stores/auth.ts:5` - Unused import: `computed`
- `src/components/TodoList.vue:3` - Unused import: `watch`
- ...

**Recommendation:** Remove unused imports to reduce bundle size and improve code clarity.

#### Component Complexity (8 issues)
**Severity:** Medium | **Effort:** Large

- `src/pages/money.vue` - 456 lines, 12 props
- `src/features/todos/TodoManager.vue` - 387 lines, 8 props
- ...

**Recommendation:** Break down large components into smaller, focused components.

**Example:**
```vue
<!-- Before -->
<script setup>
// 456 lines of logic
</script>

<!-- After -->
<script setup>
import TodoList from './components/TodoList.vue';
import TodoFilters from './components/TodoFilters.vue';
import TodoStats from './components/TodoStats.vue';
// Focused logic
</script>
```

### 2. Architecture (18 issues)

#### Circular Dependencies (5 issues)
**Severity:** High | **Effort:** Medium

**Cycle 1:** `moneyStore.ts` → `accountStore.ts` → `transactionStore.ts` → `moneyStore.ts`

**Recommendation:** Use event bus pattern to decouple stores.

**Example:**
```typescript
// Before: Direct import
import { useAccountStore } from './accountStore';

// After: Event-based communication
import { emitStoreEvent } from './store-events';
emitStoreEvent('transaction:created', { accountSerialNum });
```

### 3. Performance (24 issues)

#### Expensive Computed Properties (6 issues)
**Severity:** Medium | **Effort:** Small

- `src/stores/todoStore.ts:filteredTodos` - Contains filter + map + sort
- ...

**Recommendation:** Add memoization or move to getter with caching.

### 4. Security (8 issues)

#### Insecure Token Storage (3 issues)
**Severity:** Critical | **Effort:** Medium

- `src/stores/auth.ts:45` - Token stored in localStorage without encryption
- ...

**Recommendation:** Use Tauri's secure storage or encrypt tokens before storing.

### 5. Technical Debt (28 issues)

#### TODO Markers (18 issues)
**Severity:** Low | **Effort:** Varies

- `src-tauri/src/mobiles/system_monitor.rs:23` - TODO: Integrate Android BatteryManager
- `src-tauri/src/mobiles/system_monitor.rs:51` - TODO: Integrate iOS UIDevice API
- ...

### 6. Consistency (17 issues)

#### Hardcoded Strings (12 issues)
**Severity:** Low | **Effort:** Small

- `src/components/TodoItem.vue:45` - "Delete" should use i18n
- ...

## Recommendations

### Priority 1: Security Fixes (Effort: Medium, Impact: Critical)

**Issues:** 8 security issues
**Estimated Time:** 2-3 days

**Steps:**
1. Implement secure token storage using Tauri's keychain
2. Remove hardcoded credentials and use environment variables
3. Add input validation using Zod schemas
4. Encrypt sensitive data before persistence

### Priority 2: Architecture Improvements (Effort: Large, Impact: High)

**Issues:** 18 architecture issues
**Estimated Time:** 5-7 days

**Steps:**
1. Refactor circular dependencies using event bus
2. Extract shared logic into composables
3. Add abstraction layers for database access
4. Implement provide/inject for deep prop passing

### Priority 3: Performance Optimization (Effort: Medium, Impact: High)

**Issues:** 24 performance issues
**Estimated Time:** 3-4 days

**Steps:**
1. Add memoization to expensive computed properties
2. Implement lazy loading for large dependencies
3. Add debouncing to API calls in event handlers
4. Fix v-for key issues

## Appendix

### Analysis Configuration
[Configuration details...]

### Analyzer Versions
- TypeScript Analyzer: 1.0.0
- Vue Analyzer: 1.0.0
- Rust Analyzer: 1.0.0
- Metrics Collector: 1.0.0

### Failed Analyzers
None

### Analysis Logs
[Detailed logs...]
```

### JSON Output Format

```json
{
  "timestamp": "2025-01-13T10:30:00Z",
  "projectName": "miji",
  "version": "0.1.0",
  "duration": 45.2,
  "summary": {
    "totalIssues": 127,
    "bySeverity": {
      "critical": 3,
      "high": 15,
      "medium": 54,
      "low": 55
    },
    "byCategory": {
      "code_quality": 32,
      "architecture": 18,
      "performance": 24,
      "security": 8,
      "technical_debt": 28,
      "consistency": 17
    }
  },
  "metrics": {
    "linesOfCode": {
      "total": 45234,
      "byLanguage": {
        "typescript": 32156,
        "vue": 8945,
        "rust": 4133
      }
    },
    "complexity": {
      "average": 4.2,
      "max": 18
    },
    "maintainability": {
      "average": 72.5
    },
    "testCoverage": {
      "overall": 58.3
    }
  },
  "issues": [
    {
      "id": "SEC-001",
      "category": "security",
      "severity": "critical",
      "title": "Insecure token storage",
      "description": "Authentication token stored in localStorage without encryption",
      "file": "src/stores/auth.ts",
      "line": 45,
      "recommendation": "Use Tauri's secure storage or encrypt tokens",
      "effort": "medium",
      "impact": ["security"]
    }
  ],
  "recommendations": [
    {
      "priority": 1,
      "title": "Security Fixes",
      "effort": "medium",
      "impact": ["security"],
      "relatedIssues": ["SEC-001", "SEC-002", "SEC-003"]
    }
  ]
}
```

## Future Enhancements

1. **Real-time Analysis**: Watch mode for continuous analysis during development
2. **IDE Integration**: VS Code extension for inline issue highlighting
3. **Historical Tracking**: Track metrics over time to show improvement trends
4. **AI-Powered Suggestions**: Use LLM to generate context-aware refactoring suggestions
5. **Automated Fixes**: Auto-fix simple issues (unused imports, formatting)
6. **Team Dashboards**: Web dashboard for team-wide code quality metrics
7. **Custom Rules**: Allow teams to define project-specific analysis rules
8. **Baseline Support**: Set baseline to only show new issues since last analysis
