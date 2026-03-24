## ADDED Requirements

### Requirement: App initialization
The system SHALL initialize the `chinese_popup_dict` package via `setupChinesePopupDict()` at startup before rendering any UI, and SHALL display a loading indicator while initialization is in progress.

#### Scenario: Startup initialization
- **WHEN** the app starts
- **THEN** `setupChinesePopupDict()` is called and the main UI is displayed only after it completes

### Requirement: Material 3 theme
The system SHALL use a clean Material 3 theme with both light and dark mode support and use `google_fonts` for typography.

#### Scenario: Theme applied
- **WHEN** the app renders
- **THEN** the UI uses Material 3 design tokens and the selected Google Font

### Requirement: Tab bar for open documents
The system SHALL display a tab bar showing all currently open documents, with each tab showing the document's filename.

#### Scenario: Multiple documents open
- **WHEN** the user opens two or more files
- **THEN** each file appears as a separate tab and the user can switch between them by tapping

#### Scenario: Close a tab
- **WHEN** the user closes a tab
- **THEN** the tab is removed and the next adjacent tab becomes active

### Requirement: Open file action
The system SHALL provide a menu/button to open a file, supporting `.txt` and `.pdf` file types via a native file picker dialog.

#### Scenario: Open a text file
- **WHEN** the user selects a `.txt` file from the file picker
- **THEN** the file contents are loaded into a new text-editor tab

#### Scenario: Open a PDF file
- **WHEN** the user selects a `.pdf` file from the file picker
- **THEN** the file is loaded into a new PDF-reader tab

### Requirement: New text document
The system SHALL provide an action to create a new, empty text document in a new tab.

#### Scenario: Create new document
- **WHEN** the user selects "New"
- **THEN** an empty text-editor tab opens with a default name like "Untitled"

### Requirement: Responsive layout
The system SHALL provide a responsive layout that works on desktop (wide), tablet, and mobile (narrow) screen sizes.

#### Scenario: Desktop layout
- **WHEN** the window width is large (>= 800px)
- **THEN** tabs are displayed horizontally with comfortable spacing

#### Scenario: Mobile layout
- **WHEN** the window width is small (< 800px)
- **THEN** tabs are scrollable and the UI adapts to the narrower viewport
