# BYOLLM Assistant OS

A beautiful, modern iOS chat interface for local LLM integration, inspired by Locally AI.

## Features

### Chat Interface
- **Gradient Background**: Beautiful teal-to-blue gradient matching the reference design
- **Message Bubbles**: Clean, rounded message bubbles for user and AI responses
- **Welcome Screen**: Introduction screen for first-time users with "Meet Apple Foundation" messaging
- **Suggestion Chips**: Quick action buttons for common queries (Plan, Tell me, Begin)
- **Input Controls**: 
  - Text input field with auto-focus option
  - Plus button for attachments
  - Lightbulb for suggestions
  - Voice input button
  - Send button when typing

### Settings View
- **Siri Shortcuts Integration**: Card promoting voice assistant integration
- **Server Connection Section**:
  - Server address input field for connecting to your LLM server
  - Supports IP addresses with ports (e.g., 192.168.1.100:8080)
  - Real-time connection testing with "Test" button
  - Visual connection status indicator with color-coded states:
    - Gray: Not Connected
    - Yellow: Connecting...
    - Green: Connected (with checkmark)
    - Red: Connection Failed (with X)
  - Auto-saves configuration
  - URL-optimized keyboard for easy input
  - Gradient button design matching app theme
- **App Settings Section**:
  - **Manage models** (full screen view):
    - Scrollable content for easy navigation
    - **Ollama section** with models:
      - Plus button to add/install new models
      - Llama 3.2 (3 models)
      - Qwen 2.5 (5 models)
      - Phi 3.5 (2 models)
    - **Hugging Face section** with models:
      - SmolLM 2 (4 models) - with "New" badge
      - Mistral 7B (2 models)
      - Falcon (3 models)
    - Model cards with emoji icons, descriptions, and model counts
    - Chevron navigation to model details
  - **Personalization** (full screen editor with tabs):
    - **About Me Tab**:
      - Base style and tone picker with 8 options (Default, Professional, Friendly, Candid, Quirky, Efficient, Nerdy, Cynical)
      - Custom instructions text editor with placeholder
      - Personality trait chips (Chatty, Witty, Straight shooting, Encouraging, Generous)
      - Nickname field
      - Occupation field
      - "More about you" text editor
      - Memory section (coming soon)
    - **Experience Tab** (Visual Customization):
      - **Pre-configured Themes** (Dropdown picker with 14 popular presets):
        - Compact button to open theme picker sheet
        - **System Themes:**
          - Dark Mode (Classic dark with high contrast)
          - Light Mode (Clean light interface)
        - **Popular IDE & Terminal Themes:**
          - Dracula (Dark purple with vibrant colors)
          - Monokai (Warm dark with rich highlighting)
          - Solarized Dark/Light (Precision colors, reduced eyestrain)
          - Nord (Arctic north-bluish palette)
          - Gruvbox (Retro groove with earth tones)
          - Tokyo Night (Clean dark inspired by Tokyo)
          - One Dark (Iconic Atom editor theme)
          - Material Theme (Google Material Design)
          - Night Owl (Fine-tuned for night coding)
          - Cobalt 2 (Dusty blue with vibrant accents)
          - Synthwave '84 (Neon retro cyberpunk)
        - One-tap to apply color + font combo
        - Circular gradient previews with descriptions
        - Auto-dismiss after selection
      - **Custom Theme Builder**:
        - 8 gradient color options (Ocean, Sunset, Forest, Midnight, Lavender, Crimson, Coral, Arctic)
        - Horizontal scrollable theme cards with live previews
        - Independent color selection
      - **Font Style Selector**: 4 options (System, Rounded, Serif, Monospaced)
      - Visual preview of each font style
      - Selected theme/font indicated with checkmarks
      - All changes apply instantly
    - Save confirmation dialog
  - Show keyboard on launch toggle
  - Delete conversation history
- **About Section**:
  - Terms & Conditions
  - Privacy Policy
  - Licenses
  - Version information (1.39.1)
- **Modern Design**: Dark theme with semi-transparent cards and SF Symbols icons

### Top Bar
- Settings button (gear icon)
- New conversation button (message icon)
- Model selector (currently shows "SmolLM 3 3B")
- New chat button (square and pencil icon)

### Conversation Management
- Create new conversations
- Message history tracking
- Delete conversation history with confirmation
- Simulated AI responses (ready for LLM integration)

## Architecture

The app is structured with clean separation of concerns:

### Files Created
1. **Models.swift** - Data models and state management
   - `Message`: Individual chat messages
   - `AIModel`: LLM model configuration
   - `Conversation`: Conversation container
   - `ConversationManager`: ObservableObject for state management with server address support

2. **ChatView.swift** - Main chat interface
   - Welcome screen when no messages
   - Scrollable message list
   - Input area with controls
   - Suggestion chips
   - Message bubbles
   - Server address state management

3. **SettingsView.swift** - Settings modal
   - Complete settings UI matching reference
   - Server connection section with test functionality
   - Connection status enum with visual states
   - All sections and options
   - Toggle controls
   - Delete confirmation alert

4. **NetworkManager.swift** - Network utilities
   - Async/await connection testing
   - URL validation
   - HTTP health check implementation
   - Error handling

5. **PersonalizationView.swift** - Comprehensive AI personalization with tabs
   - **About Me Tab**:
     - Base style picker with 8 personality options
     - Custom instructions text editor
     - Personality trait chips for quick selection
     - User profile fields (nickname, occupation)
     - "More about you" section
     - Memory integration placeholder
     - System prompt generation from all fields
   - **Experience Tab**:
     - 8 color theme options with gradient previews
     - 4 font style options (System, Rounded, Serif, Monospaced)
     - Live preview cards with selection indicators
     - VSCode/Oh-My-Zsh style theming system

6. **ManageModelsView.swift** - Model library browser
   - Scrollable content for browsing all models
   - Organized sections for Ollama and Hugging Face
   - Plus button in Ollama section to add new models
   - Model cards with emoji icons and descriptions
   - Model count badges
   - "New" badges for recently added models
   - Navigation to individual model details

7. **ContentView.swift** - App entry point (updated)

## Design Features

- **SF Symbols**: Native iOS icons throughout
- **Blur Effects**: Semi-transparent backgrounds
- **Rounded Corners**: Modern iOS design language
- **Gradient Backgrounds**: Eye-catching color schemes
- **Dark Theme**: Optimized for OLED displays
- **Smooth Animations**: Native SwiftUI transitions

## Next Steps for Integration

To connect to a real LLM:

1. Replace the simulated response in `ConversationManager.sendMessage()` with actual LLM API calls
2. Add model selection functionality in the top bar
3. Implement the "Manage models" settings screen
4. Add streaming response support
5. Implement conversation persistence
6. Add Siri Shortcuts functionality

## Requirements

- iOS 18.5+
- Xcode 16.4+
- Swift 5.0+

## Usage

Simply open the project in Xcode and run on the iOS Simulator or a physical device. The UI is fully functional with simulated responses ready for LLM integration.

