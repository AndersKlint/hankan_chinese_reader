## ADDED Requirements

### Requirement: Text editing area
The system SHALL provide a multi-line text editing area where users can type or paste Chinese text.

#### Scenario: Enter text
- **WHEN** the user is in edit mode
- **THEN** a full-screen text field is displayed where the user can type freely

### Requirement: Toggle between edit and read modes
The system SHALL allow the user to toggle between an edit mode (text field) and a read mode (text rendered with popup dictionary).

#### Scenario: Switch to read mode
- **WHEN** the user taps the read/view toggle while in edit mode
- **THEN** the text is displayed using `TappableTextWrapper` with `showPopupDict: true`

#### Scenario: Switch to edit mode
- **WHEN** the user taps the edit toggle while in read mode
- **THEN** the text field is displayed with the current contents for editing

### Requirement: Undo and redo
The system SHALL support undo and redo actions for text editing via toolbar buttons and keyboard shortcuts.

#### Scenario: Undo a change
- **WHEN** the user performs an undo action
- **THEN** the most recent text change is reverted

#### Scenario: Redo a change
- **WHEN** the user performs a redo action after an undo
- **THEN** the previously undone change is reapplied

### Requirement: Text search
The system SHALL provide a search function that highlights and navigates to matching text within the document.

#### Scenario: Search for text
- **WHEN** the user opens the search bar and types a query
- **THEN** matching occurrences are highlighted and the view scrolls to the first match

#### Scenario: Navigate search results
- **WHEN** the user presses next/previous in the search bar
- **THEN** the view navigates to the next/previous match

### Requirement: Save text file
The system SHALL allow the user to save the current text content to a file on disk (or download on web).

#### Scenario: Save existing file
- **WHEN** the user saves a file that was opened from disk
- **THEN** the file is overwritten with the current contents

#### Scenario: Save new file
- **WHEN** the user saves an untitled document
- **THEN** a save-as dialog is shown to choose the file path

### Requirement: Unsaved changes indicator
The system SHALL indicate when a text document has unsaved changes.

#### Scenario: Document modified
- **WHEN** the user edits text after the last save
- **THEN** the tab title shows a modification indicator (e.g., a dot or asterisk)
