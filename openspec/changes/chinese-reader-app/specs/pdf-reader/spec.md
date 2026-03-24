## ADDED Requirements

### Requirement: Render PDF pages
The system SHALL render PDF pages using `pdfrx` with pinch-to-zoom and scroll support.

#### Scenario: Open and view a PDF
- **WHEN** the user opens a PDF file
- **THEN** all pages are rendered in a scrollable view with correct layout

#### Scenario: Zoom a PDF page
- **WHEN** the user pinch-zooms on a PDF page
- **THEN** the page scales accordingly

### Requirement: Popup dictionary on PDF text layer
The system SHALL overlay `TappableTextWrapper` widgets on the PDF text layer fragments so that tapping a Chinese character shows the popup dictionary.

#### Scenario: Tap a word in a PDF
- **WHEN** the user taps a Chinese character in the PDF text layer
- **THEN** the popup dictionary appears with the word's definition

### Requirement: No text layer notification
The system SHALL inform the user when a PDF page has no extractable text layer.

#### Scenario: PDF without text layer
- **WHEN** a PDF page has no text fragments
- **THEN** a subtle message indicates that dictionary lookup is unavailable for that page

### Requirement: Page navigation
The system SHALL display the current page number and total pages, and allow the user to jump to a specific page.

#### Scenario: View page indicator
- **WHEN** the user is viewing a PDF
- **THEN** the current page number and total are displayed

#### Scenario: Jump to page
- **WHEN** the user enters a page number
- **THEN** the view scrolls to that page
