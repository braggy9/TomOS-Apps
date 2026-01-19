# Tag System Integration Guide

## What Was Created

1. **TAG_GUIDELINES.md** - Complete tagging philosophy and examples
2. **Vercel API Updates** - Backend now supports tags
3. **TagPicker.swift** - Full SwiftUI tag picker component
4. **tag_suggester.py** - Python service for intelligent tag suggestions

## How to Add Tags to Your App

### Step 1: Add TagPicker.swift to Xcode

The file `TomOS/TagPicker.swift` has been created. Add it to your Xcode project:

1. Open `TomOS.xcodeproj`
2. Right-click on the `TomOS` folder
3. Select "Add Files to TomOS..."
4. Select `TagPicker.swift`
5. Ensure it's added to all targets (iOS, macOS)

### Step 2: Update APIService.swift

Add tag support to the API service:

```swift
// Add to APIService.swift

// MARK: - Create Task with Tags
func createTask(task: String, tags: [String], context: String? = nil) async throws -> TaskResponse {
    let url = URL(string: "\(baseURL)/api/task/capture")!
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")

    let body: [String: Any] = [
        "task": task,
        "tags": tags,
        "context": context as Any,
        "suggest_tags": true  // Get suggested tags from API
    ]
    request.httpBody = try JSONSerialization.data(withJSONObject: body)

    let (data, response) = try await URLSession.shared.data(for: request)

    if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
        throw APIError.networkError(statusCode: httpResponse.statusCode)
    }

    struct TaskResponse: Codable {
        let success: Bool
        let task_id: String
        let task_title: String
        let detected_context: String
        let tags: [String]
        let suggested_tags: [String]?
        let notion_url: String
    }

    return try JSONDecoder().decode(TaskResponse.self, from: data)
}
```

### Step 3: Integrate into Brain Dump View

Here's how to add tag selection to BrainDumpView:

```swift
import SwiftUI

struct BrainDumpView: View {
    @State private var tasksText = ""
    @State private var selectedTags: Set<String> = []  // NEW
    @State private var showTagPicker = false  // NEW
    @State private var suggestedTags: [Tag] = []  // NEW
    @State private var isLoading = false
    @State private var toast: Toast?
    @FocusState private var isTextEditorFocused: Bool
    @StateObject private var tagService = TagService()  // NEW

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                // Header (unchanged)
                VStack(spacing: 8) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 60))
                        .foregroundStyle(.purple.gradient)

                    Text("Brain Dump")
                        .font(.title.bold())
                }
                .padding(.top)

                // Text Editor (unchanged)
                ZStack(alignment: .topLeading) {
                    if tasksText.isEmpty {
                        Text("dentist tomorrow 2pm\nreview contract...")
                            .foregroundColor(.secondary.opacity(0.5))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 12)
                    }

                    TextEditor(text: $tasksText)
                        .frame(minHeight: 200)
                        .padding(4)
                        .background(Color.secondarySystemBackground)
                        .cornerRadius(8)
                        .focused($isTextEditorFocused)
                        .onChange(of: tasksText) { _, newValue in
                            // Auto-suggest tags as user types
                            updateSuggestedTags()
                        }
                }
                .padding(.horizontal)

                // NEW: Selected Tags Display
                if !selectedTags.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Tags:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)

                        SelectedTagsView(selectedTags: $selectedTags)
                            .padding(.horizontal)
                    }
                }

                // NEW: Tag Picker Button
                Button {
                    showTagPicker = true
                } label: {
                    HStack {
                        Image(systemName: "tag")
                        Text(selectedTags.isEmpty ? "Add Tags" : "Edit Tags (\(selectedTags.count))")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .foregroundColor(.blue)
                    .cornerRadius(12)
                }
                .padding(.horizontal)

                // Submit Button (updated)
                Button(action: submitTasks) {
                    HStack {
                        if isLoading {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "sparkles")
                            Text("Create Tasks")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(tasksText.isEmpty ? Color.gray : Color.purple)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(tasksText.isEmpty || isLoading)
                .padding(.horizontal)

                Spacer()
            }
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toast($toast)
            .sheet(isPresented: $showTagPicker) {
                NavigationStack {
                    TagPickerView(
                        selectedTags: $selectedTags,
                        suggestedTags: suggestedTags
                    )
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Cancel") {
                                showTagPicker = false
                            }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") {
                                showTagPicker = false
                            }
                        }
                    }
                }
            }
        }
    }

    // NEW: Update suggested tags based on task text
    func updateSuggestedTags() {
        guard !tasksText.isEmpty else {
            suggestedTags = []
            return
        }

        // Auto-detect context
        let context = detectContextFromText(tasksText)

        // Get tag suggestions
        suggestedTags = tagService.suggestTags(for: tasksText, context: context)
    }

    func detectContextFromText(_ text: String) -> String? {
        let lower = text.lowercased()
        if lower.contains("meeting") || lower.contains("client") { return "Work" }
        if lower.contains("kids") || lower.contains("school") { return "Parenting" }
        if lower.contains("mixtape") || lower.contains("supplier") { return "MixTape" }
        return nil
    }

    // UPDATED: Submit tasks with tags
    func submitTasks() {
        isLoading = true
        isTextEditorFocused = false

        Task {
            do {
                // If using batch import, we need to update the API
                // For now, create tasks individually with tags
                let taskLines = tasksText
                    .components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }

                var successCount = 0

                for taskLine in taskLines {
                    // Create task with tags
                    _ = try await APIService.shared.createTask(
                        task: taskLine,
                        tags: Array(selectedTags),
                        context: nil
                    )
                    successCount += 1
                }

                await MainActor.run {
                    isLoading = false

                    withAnimation {
                        toast = .success("Created \(successCount) task\(successCount == 1 ? "" : "s")!")
                    }

                    tasksText = ""
                    selectedTags = []

                    #if os(iOS)
                    HapticManager.shared.taskAdded()
                    #endif
                }
            } catch {
                await MainActor.run {
                    isLoading = false

                    withAnimation {
                        toast = .error("Failed to create tasks")
                    }

                    #if os(iOS)
                    HapticManager.shared.error()
                    #endif
                }
            }
        }
    }
}
```

### Step 4: Simpler Quick Capture Integration

For QuickCaptureWindow.swift or simpler capture flows:

```swift
struct QuickCaptureView: View {
    @State private var taskText = ""
    @State private var selectedTags: Set<String> = []
    @State private var showTagPicker = false
    @StateObject private var tagService = TagService()

    var suggestedTags: [Tag] {
        tagService.suggestTags(for: taskText, context: nil)
    }

    var body: some View {
        VStack(spacing: 16) {
            TextField("What do you need to do?", text: $taskText)
                .textFieldStyle(.roundedBorder)

            // Show auto-suggested tags as chips
            if !suggestedTags.isEmpty {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(suggestedTags) { tag in
                            Button {
                                if selectedTags.contains(tag.name) {
                                    selectedTags.remove(tag.name)
                                } else {
                                    selectedTags.insert(tag.name)
                                }
                            } label: {
                                HStack {
                                    Image(systemName: tag.prefix.icon)
                                    Text(tag.name)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    selectedTags.contains(tag.name) ?
                                    tag.prefix.color : Color(white: 0.9)
                                )
                                .foregroundColor(
                                    selectedTags.contains(tag.name) ?
                                    .white : .primary
                                )
                                .cornerRadius(16)
                            }
                        }
                    }
                }
            }

            Button("Create Task") {
                createTask()
            }
        }
        .padding()
    }

    func createTask() {
        Task {
            try? await APIService.shared.createTask(
                task: taskText,
                tags: Array(selectedTags),
                context: nil
            )
        }
    }
}
```

## API Usage Examples

### Create Task with Tags

```bash
curl -X POST https://tomos-task-api.vercel.app/api/task/capture \
  -H "Content-Type: application/json" \
  -d '{
    "task": "Review MixTape supplier contract for AU jurisdiction",
    "tags": ["proj:mixtape", "area:work", "act:review", "topic:contracts"],
    "context": "Work"
  }'
```

### Get Tag Suggestions

```bash
curl -X POST https://tomos-task-api.vercel.app/api/task/capture \
  -H "Content-Type: application/json" \
  -d '{
    "task": "Call Ziggy school lunch order",
    "suggest_tags": true
  }'

# Response includes suggested_tags array
```

## Deployment

Once you've integrated the tag picker:

1. **Test locally** in Xcode Simulator/device
2. **Update Vercel** - Your API changes are already deployed when you push
3. **Build TestFlight** - New iOS build with tag support
4. **Update macOS app** - Copy to /Applications

## Migration Plan

See `scripts/migrate-tags.py` (coming next) to migrate existing tasks to use prefixed tags.

## Next Steps

- Phase 2: Architecture audit
- Phase 4: Tag migration script
- Phase 3: Offline mode with CoreData

---

**Questions?** Check TAG_GUIDELINES.md for tag usage philosophy.
