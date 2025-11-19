# BYOLLM Assistant OS

A beautiful, modern iOS chat interface for local LLM integration, inspired by Locally AI.

## Features

### Chat Interface
- **Gradient Background**: Beautiful teal-to-blue gradient matching the reference design
- **Message Bubbles**: Clean, rounded message bubbles for user and AI responses
  - Full markdown rendering support (bold, italic, headers, lists, code blocks)
  - Automatically formats LLM responses with proper styling
  - Preserves formatting while maintaining consistent white text color
  - **Thinking Tokens Display**: Collapsible section showing model reasoning (Qwen3)
    - Brain icon indicator when thinking content is present
    - Tap to expand/collapse thinking process
    - Monospaced font for better readability
    - Automatically separates thinking from actual response
- **Welcome Screen**: Introduction screen with "Meet AssistantOS" messaging and BYOLLM information
- **Input Controls**: 
  - Text input field with auto-focus option
  - Plus button for attachments
  - Lightbulb for suggestions
  - Voice input button
  - Send button when typing
  - Loading indicator during AI response generation

### Side Panel (Chat History)
- **Slide-in Navigation**:
  - Slides in from left edge (85% width for chat history)
  - Smooth 0.3s animation
  - Dimmed background overlay for focus
  - Tap background or X button to dismiss
- **Chat History View**:
  - Shows all previous conversations
  - Each entry displays:
    - Relative timestamp (e.g., "2 hours ago")
    - Message count indicator
    - Preview of first message (truncated to 2 lines)
  - Empty state with helpful message for new users
  - Scrollable list of conversation history
- **Settings Navigation**:
  - Settings button pinned to bottom of side panel
  - Seamless horizontal transition to settings
  - **Settings expands to full screen width** for better usability
  - Back button returns to chat history (no panel dismiss)
  - Maintains panel state throughout navigation

### Settings View
- **Siri Shortcuts Integration**: Card promoting voice assistant integration
- **Server Connection Section**:
  - Server address input field for connecting to your LLM server
  - Supports IP addresses with ports (e.g., 192.168.1.100:8080)
  - **Persistent storage**: IP address is automatically saved and restored on app restart
  - Keyboard dismissal: Tap outside field, press "Done" button, or hit return
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
- **Side Panel button** (hamburger menu icon) - Opens chat history panel
- New conversation button (message icon)
- **Dynamic Model Selector**:
  - Displays currently selected model (simplified name: "qwen2.5")
  - Native iOS Menu dropdown with checkmarks
  - Instantly shows available models from server
  - Automatically loads available models from connected server via `/v1/models` API
  - Falls back to default "qwen2.5:latest" if server is not configured
  - Selection persists across app usage
- New chat button (square and pencil icon)

### Conversation Management
- Create new conversations
- Message history tracking
- Delete conversation history with confirmation
- **Real LLM Integration** via OpenAI-compatible API:
  - Connects to BYOLLM server backend
  - Supports custom system prompts
  - Automatic error handling with user-friendly messages
  - Loading indicators during API calls
  - Temperature and max_tokens configuration

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

4. **NetworkManager.swift** - Complete API integration
   - **Health Check**: `/health` endpoint for server status
   - **Models List**: `/v1/models` to get available models
   - **Chat Completions**: `/v1/chat/completions` for LLM responses
   - OpenAI-compatible API structure
   - Proper request/response models with Codable
   - System prompt integration
   - Temperature and max_tokens configuration
   - Async/await with proper error handling
   - 60-second timeout for chat requests

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

## Server Setup & Connection

### Prerequisites

1. **Start the BYOLLM Server**:
   ```bash
   cd path/to/byollm-server
   uv run uvicorn server.main:app --reload --host 0.0.0.0 --port 8080
   ```

2. **Start Ollama** (if using Ollama backend):
   ```bash
   ollama serve
   ```

3. **Pull a Model**:
   ```bash
   ollama pull llama3
   # or any other model like: qwen2.5, phi3.5, mistral, etc.
   ollama pull qwen3  # For thinking/reasoning models
   ```

### Qwen3 Thinking Models

Qwen3 models support "thinking mode" which generates internal reasoning before producing the final answer:
- **Thinking tokens** are generated in `<think>` or `<thinking>` tags showing the model's reasoning process
- The app automatically detects and separates thinking content from the actual response
- **Collapsible Thinking Display**: 
  - Brain icon indicator appears when thinking content is detected
  - Tap to expand/collapse the thinking process
  - View the model's internal reasoning step-by-step
- **No Token Limits**: The app removes `max_tokens` restrictions, allowing unlimited response length
  - Prevents truncation issues entirely
  - Models can generate as much content as needed
  - Thinking + response can be any length

### Connecting the App

1. Open the app and tap **Settings** (gear icon)
2. In **Server Connection** section:
   - Enter your server address (e.g., `localhost:8080` or `192.168.1.100:8080`)
   - Tap **Test** to verify connection
   - Green checkmark = connected! ✅
3. Go to **Personalization** to set your system prompt
4. Start chatting!

### API Endpoints Used

- **Health Check**: `GET /health` - Verifies server is running
- **List Models**: `GET /v1/models` - Gets available models from backend
- **Chat**: `POST /v1/chat/completions` - Sends messages and receives responses

### Supported Parameters

- `model`: Model to use (e.g., "llama3", "qwen2.5", "qwen3")
- `messages`: Array of chat messages with role and content
- `temperature`: 0.0-2.0 (default 0.7) - Controls randomness
- `max_tokens`: **Removed** (previously limited responses)
  - No token limit imposed by the app
  - Models can generate unlimited response length
  - Prevents truncation issues with thinking models
- `stream`: Boolean (default true) - Real-time streaming responses

## Next Steps

1. ✅ ~~Connect to real LLM server~~ **DONE!**
2. ✅ ~~Add model selection functionality in the top bar~~ **DONE!**
3. ✅ ~~Implement dynamic model loading from `/v1/models` endpoint~~ **DONE!**
4. Add streaming response support with real-time text display
5. Implement conversation persistence to local storage
6. Add Siri Shortcuts functionality
7. Support for image/multimodal inputs

## Requirements

- iOS 18.5+
- Xcode 16.4+
- Swift 5.0+

## Usage

Simply open the project in Xcode and run on the iOS Simulator or a physical device. The UI is fully functional with simulated responses ready for LLM integration.

