# Library Evaluation

This document captures the evaluation gate that must be completed before
`searchlight_pdf` implementation starts in earnest.

## Evaluation Questions

The chosen library or library stack must answer:

- Can it extract text reliably from real PDFs?
- Which platforms does it support?
- Can it operate on PDF bytes, not only bundled assets?
- Can it support user-imported and remotely downloaded PDFs?
- Does it expose page-level structure?
- Does it expose text geometry that could support future in-view highlights?
- Is it pure Dart, Flutter-only, or platform-specific?
- What is the dependency and licensing profile?

## Current Direction

Earlier design notes suggested evaluating a pure Dart library first so the
package can stay usable outside Flutter where possible.

That is still the preferred starting point, but it is not a locked decision
yet.

## Acceptance Threshold For V1

To unblock a first implementation, the chosen stack must support at minimum:

- loading PDF bytes or files
- extracting page-level text
- preserving page numbers
- stable enough behavior for fixture-driven tests

Geometry support is desirable, but not required for the first searchable
version.

## Suggested Evaluation Output

When this doc is completed for real, it should include:

1. candidate libraries
2. platform matrix
3. extraction reliability notes
4. geometry/highlight support notes
5. recommended choice
6. explicit rejected alternatives and why

## Current Unknowns

- whether the best extraction library will be pure Dart
- whether geometry support is good enough for later viewer integration
- whether one library can cover both extraction and rendering-adjacent needs
- whether a separate Flutter-side viewer package will eventually be needed

