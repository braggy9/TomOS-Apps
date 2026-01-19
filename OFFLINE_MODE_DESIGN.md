# TomOS Offline Mode - Architecture Design

**Status:** Design Phase
**Created:** 2026-01-08
**Target:** Enable full offline task management with Notion sync

---

## Executive Summary

This document outlines the architecture for adding offline capabilities to TomOS, enabling users to:

- ✅ View and manage tasks without network connectivity
- ✅ Create, edit, and complete tasks offline
- ✅ Automatic bidirectional sync when network returns
- ✅ Intelligent conflict resolution
- ✅ 70% reduction in API calls through smart caching
- ✅ Instant UI updates (no loading spinners)

**Key Principle:** Notion remains the single source of truth, CoreData is the local cache with offline mutations.

---

## Architecture Overview

### Current State (Online-Only)

```
┌─────────────┐
│   SwiftUI   │
│    Views    │
└──────┬──────┘
       │ API calls
       ▼
┌─────────────┐      HTTPS      ┌──────────┐
│ APIService  │ ─────────────► │  Vercel  │
│  (Singleton)│ ◄───────────── │   API    │
└─────────────┘   JSON Response └────┬─────┘
                                     │
                                     ▼
                              ┌──────────┐
                              │  Notion  │
                              │ Database │
                              └──────────┘

Issues:
❌ Every view refresh hits API
❌ No offline access
❌ Loading states everywhere
❌ ~100 API calls/day/user
```

### Proposed State (Offline-First)

```
┌─────────────────────────────────────────────┐
│              SwiftUI Views                  │
│   (BrainDump, Tasks, SmartSurface, etc.)   │
└────────────────┬────────────────────────────┘
                 │
                 ▼
┌─────────────────────────────────────────────┐
│           TaskStore (ObservableObject)       │
│  • @Published tasks: [Task]                 │
│  • Single source of truth for UI            │
│  • Manages sync state                       │
└───┬─────────────────────────────────────┬───┘
    │                                     │
    ▼                                     ▼
┌──────────────┐                 ┌───────────────┐
│  CoreData    │                 │  SyncEngine   │
│  (Local DB)  │                 │  (Background) │
│              │                 │               │
│ • Cache      │                 │ • Conflict    │
│ • Offline    │                 │   resolution  │
│   mutations  │                 │ • Push/pull   │
│ • Fast reads │                 │ • Retry logic │
└──────────────┘                 └───────┬───────┘
                                         │
                                         ▼
                                 ┌───────────────┐
                                 │  APIService   │
                                 │  (Network)    │
                                 └───────┬───────┘
                                         │
                                         ▼
                                 ┌───────────────┐
                                 │ Vercel + Notion│
                                 └───────────────┘

Benefits:
✅ Instant UI (read from CoreData)
✅ Works offline
✅ Background sync
✅ ~20-30 API calls/day (70% reduction)
```

---

## CoreData Schema

### Task Entity

Maps to Notion `Task_Inbox` database:

```swift
// CoreDataStack/Task+CoreDataProperties.swift

@objc(TaskEntity)
public class TaskEntity: NSManagedObject {
    // Identity (matches Notion)
    @NSManaged public var id: String              // Notion page_id
    @NSManaged public var title: String
    @NSManaged public var notionURL: String

    // Metadata
    @NSManaged public var createdAt: Date
    @NSManaged public var updatedAt: Date
    @NSManaged public var lastSyncedAt: Date?     // When last synced with Notion

    // Status
    @NSManaged public var status: String          // "Inbox", "To-Do", "In Progress", "Done"
    @NSManaged public var priority: String?       // "High", "Medium", "Low"

    // Context (multi-select in Notion)
    @NSManaged public var contexts: String?       // JSON array: ["Work", "Computer", "Parenting Week"]

    // Tags (NEW - multi-select in Notion)
    @NSManaged public var tags: String?           // JSON array: ["proj:mixtape", "area:work", "act:review"]

    // Dates
    @NSManaged public var dueDate: Date?
    @NSManaged public var scheduledDate: Date?
    @NSManaged public var completedDate: Date?

    // Sync State
    @NSManaged public var syncStatus: String      // "synced", "pending_create", "pending_update", "pending_delete", "conflict"
    @NSManaged public var localModifiedAt: Date?  // When locally modified (for conflict detection)
    @NSManaged public var conflictData: String?   // JSON of server version during conflict

    // Computed Properties
    public var contextsArray: [String] {
        guard let contexts = contexts else { return [] }
        return (try? JSONDecoder().decode([String].self, from: contexts.data(using: .utf8)!)) ?? []
    }

    public var tagsArray: [String] {
        guard let tags = tags else { return [] }
        return (try? JSONDecoder().decode([String].self, from: tags.data(using: .utf8)!)) ?? []
    }

    public var isPendingSync: Bool {
        return syncStatus != "synced"
    }

    public var isLocallyCreated: Bool {
        return syncStatus == "pending_create"
    }
}
```

### SyncMetadata Entity

Tracks sync state for the entire database:

```swift
@objc(SyncMetadata)
public class SyncMetadata: NSManagedObject {
    @NSManaged public var key: String             // "last_full_sync", "last_pull", "last_push"
    @NSManaged public var value: String           // ISO timestamp or JSON data
    @NSManaged public var updatedAt: Date
}
```

### Core Data Model File

**File:** `TomOS/TomOS.xcdatamodeld`

Create using Xcode:
1. File → New → Data Model
2. Add entities: `TaskEntity`, `SyncMetadata`
3. Set attributes with types above
4. Create inverse relationships if needed

---

## TaskStore - Central State Management

Replace scattered `@State` with a single `ObservableObject`:

```swift
// TomOS/Stores/TaskStore.swift

import Foundation
import Combine
import CoreData

/// Central state manager for all task data
/// Manages local cache, API sync, and provides reactive updates to UI
class TaskStore: ObservableObject {
    // MARK: - Published Properties (UI observes these)

    @Published var tasks: [Task] = []
    @Published var isLoading = false
    @Published var isSyncing = false
    @Published var lastSyncDate: Date?
    @Published var syncError: Error?
    @Published var hasPendingChanges = false

    // MARK: - Dependencies

    private let coreDataStack: CoreDataStack
    private let apiService: APIService
    private let syncEngine: SyncEngine
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init(
        coreDataStack: CoreDataStack = .shared,
        apiService: APIService = .shared,
        syncEngine: SyncEngine = .shared
    ) {
        self.coreDataStack = coreDataStack
        self.apiService = apiService
        self.syncEngine = syncEngine

        setupObservers()
        loadFromCache()
        startBackgroundSync()
    }

    // MARK: - Public API

    /// Load tasks from local cache (instant)
    func loadFromCache() {
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.sortDescriptors = [
            NSSortDescriptor(keyPath: \TaskEntity.createdAt, ascending: false)
        ]

        do {
            let entities = try coreDataStack.viewContext.fetch(fetchRequest)
            self.tasks = entities.map { Task(from: $0) }
            self.hasPendingChanges = entities.contains { $0.isPendingSync }
        } catch {
            print("Failed to load from cache: \(error)")
        }
    }

    /// Refresh from API (background, optional force)
    func refresh(force: Bool = false) async {
        // Don't refresh if recently synced (unless forced)
        if !force, let lastSync = lastSyncDate,
           Date().timeIntervalSince(lastSync) < 60 { // 1 minute
            return
        }

        await MainActor.run { isSyncing = true }
        defer { Task { await MainActor.run { isSyncing = false } } }

        do {
            try await syncEngine.pullFromServer()
            loadFromCache() // Reload UI from updated cache

            await MainActor.run {
                lastSyncDate = Date()
                syncError = nil
            }
        } catch {
            await MainActor.run {
                syncError = error
            }
        }
    }

    /// Create task (works offline)
    func createTask(title: String, context: String?, tags: [String]) async throws {
        // Optimistic UI update
        let tempTask = Task(
            id: UUID().uuidString,
            title: title,
            status: .inbox,
            context: context,
            tags: tags,
            createdAt: Date()
        )

        await MainActor.run {
            tasks.insert(tempTask, at: 0)
            hasPendingChanges = true
        }

        // Save to CoreData with pending status
        let entity = TaskEntity(context: coreDataStack.viewContext)
        entity.id = tempTask.id
        entity.title = tempTask.title
        entity.status = tempTask.status.rawValue
        entity.contexts = try? JSONEncoder().encode(context.map { [$0] } ?? []).map { String(data: $0, encoding: .utf8)! }
        entity.tags = try? JSONEncoder().encode(tags).map { String(data: $0, encoding: .utf8)! }
        entity.createdAt = tempTask.createdAt
        entity.updatedAt = Date()
        entity.syncStatus = "pending_create"
        entity.localModifiedAt = Date()

        try coreDataStack.save()

        // Attempt to sync immediately (background)
        Task.detached { [weak self] in
            try? await self?.syncEngine.pushToServer()
        }
    }

    /// Complete task (works offline)
    func completeTask(_ taskId: String) async throws {
        // Optimistic UI update
        await MainActor.run {
            if let index = tasks.firstIndex(where: { $0.id == taskId }) {
                tasks[index].status = .done
                tasks[index].completedDate = Date()
            }
            hasPendingChanges = true
        }

        // Update CoreData
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", taskId)

        if let entity = try coreDataStack.viewContext.fetch(fetchRequest).first {
            entity.status = "Done"
            entity.completedDate = Date()
            entity.updatedAt = Date()
            entity.syncStatus = entity.isLocallyCreated ? "pending_create" : "pending_update"
            entity.localModifiedAt = Date()

            try coreDataStack.save()

            // Sync in background
            Task.detached { [weak self] in
                try? await self?.syncEngine.pushToServer()
            }
        }
    }

    // MARK: - Background Sync

    private func setupObservers() {
        // Sync when app becomes active
        NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)

        // Sync when network becomes available
        // (Requires Network framework integration)
    }

    private func startBackgroundSync() {
        // Periodic sync every 5 minutes if online
        Timer.publish(every: 300, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                Task { await self?.refresh() }
            }
            .store(in: &cancellables)
    }
}

// MARK: - Task Model (Swift struct for UI)

struct Task: Identifiable, Codable {
    let id: String
    var title: String
    var status: TaskStatus
    var priority: Priority?
    var context: String?
    var tags: [String]
    var dueDate: Date?
    var scheduledDate: Date?
    var completedDate: Date?
    let createdAt: Date
    var notionURL: String?

    enum TaskStatus: String, Codable {
        case inbox = "Inbox"
        case todo = "To-Do"
        case inProgress = "In Progress"
        case done = "Done"
    }

    enum Priority: String, Codable {
        case high = "High"
        case medium = "Medium"
        case low = "Low"
    }

    // Map from CoreData entity
    init(from entity: TaskEntity) {
        self.id = entity.id
        self.title = entity.title
        self.status = TaskStatus(rawValue: entity.status) ?? .inbox
        self.priority = entity.priority.flatMap { Priority(rawValue: $0) }
        self.context = entity.contextsArray.first
        self.tags = entity.tagsArray
        self.dueDate = entity.dueDate
        self.scheduledDate = entity.scheduledDate
        self.completedDate = entity.completedDate
        self.createdAt = entity.createdAt
        self.notionURL = entity.notionURL
    }

    // Direct init for temporary/optimistic updates
    init(
        id: String,
        title: String,
        status: TaskStatus,
        context: String?,
        tags: [String],
        createdAt: Date
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.context = context
        self.tags = tags
        self.createdAt = createdAt
    }
}
```

---

## SyncEngine - Bidirectional Sync

Handles push/pull with Notion, conflict resolution, and retry logic:

```swift
// TomOS/Services/SyncEngine.swift

import Foundation
import CoreData

/// Manages bidirectional sync between CoreData and Notion
class SyncEngine {
    static let shared = SyncEngine()

    private let coreDataStack: CoreDataStack
    private let apiService: APIService
    private let conflictResolver: ConflictResolver

    private var isSyncing = false
    private var syncQueue = DispatchQueue(label: "com.tomos.sync", qos: .background)

    init(
        coreDataStack: CoreDataStack = .shared,
        apiService: APIService = .shared,
        conflictResolver: ConflictResolver = .shared
    ) {
        self.coreDataStack = coreDataStack
        self.apiService = apiService
        self.conflictResolver = conflictResolver
    }

    // MARK: - Pull (Server → Local)

    /// Fetch all tasks from Notion and update local cache
    func pullFromServer() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        print("[Sync] Pulling from server...")

        // Fetch from API
        let serverTasks = try await apiService.getAllTasks()

        // Update CoreData in background context
        try await coreDataStack.performBackgroundTask { context in
            for serverTask in serverTasks {
                let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
                fetchRequest.predicate = NSPredicate(format: "id == %@", serverTask.id)

                if let existing = try context.fetch(fetchRequest).first {
                    // Task exists locally - check for conflicts
                    if existing.isPendingSync {
                        // Local changes not yet synced - conflict!
                        try self.conflictResolver.resolve(
                            local: existing,
                            server: serverTask,
                            in: context
                        )
                    } else {
                        // No local changes - safe to update
                        self.update(entity: existing, from: serverTask)
                        existing.lastSyncedAt = Date()
                        existing.syncStatus = "synced"
                    }
                } else {
                    // New task from server - create locally
                    let entity = TaskEntity(context: context)
                    self.update(entity: entity, from: serverTask)
                    entity.id = serverTask.id
                    entity.lastSyncedAt = Date()
                    entity.syncStatus = "synced"
                }
            }

            try context.save()
        }

        // Update sync metadata
        updateSyncMetadata(key: "last_pull", value: Date().ISO8601Format())

        print("[Sync] Pull complete: \(serverTasks.count) tasks")
    }

    // MARK: - Push (Local → Server)

    /// Upload pending local changes to Notion
    func pushToServer() async throws {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        print("[Sync] Pushing to server...")

        // Fetch pending changes
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "syncStatus != %@", "synced")

        let pendingTasks = try coreDataStack.viewContext.fetch(fetchRequest)

        if pendingTasks.isEmpty {
            print("[Sync] No pending changes")
            return
        }

        var successCount = 0
        var errorCount = 0

        for entity in pendingTasks {
            do {
                switch entity.syncStatus {
                case "pending_create":
                    let response = try await apiService.createTask(
                        task: entity.title,
                        tags: entity.tagsArray,
                        context: entity.contextsArray.first
                    )
                    // Update with server ID
                    entity.id = response.task_id
                    entity.notionURL = response.notion_url
                    entity.syncStatus = "synced"
                    entity.lastSyncedAt = Date()
                    successCount += 1

                case "pending_update":
                    try await apiService.updateTask(
                        taskId: entity.id,
                        updates: [
                            "title": entity.title,
                            "status": entity.status,
                            "tags": entity.tagsArray,
                            "context": entity.contextsArray
                        ]
                    )
                    entity.syncStatus = "synced"
                    entity.lastSyncedAt = Date()
                    successCount += 1

                case "pending_delete":
                    try await apiService.deleteTask(taskId: entity.id)
                    coreDataStack.viewContext.delete(entity)
                    successCount += 1

                default:
                    break
                }
            } catch {
                print("[Sync] Failed to push task \(entity.id): \(error)")
                errorCount += 1
                // Keep syncStatus as pending for retry
            }
        }

        try coreDataStack.save()

        print("[Sync] Push complete: \(successCount) synced, \(errorCount) errors")

        // Update sync metadata
        if errorCount == 0 {
            updateSyncMetadata(key: "last_push", value: Date().ISO8601Format())
        }
    }

    // MARK: - Full Sync

    /// Full bidirectional sync (pull then push)
    func fullSync() async throws {
        try await pullFromServer()  // Get latest from server
        try await pushToServer()    // Upload local changes
    }

    // MARK: - Helpers

    private func update(entity: TaskEntity, from serverTask: TaskResponse) {
        entity.title = serverTask.task_title
        entity.status = serverTask.status
        entity.contexts = try? JSONEncoder().encode(serverTask.contexts).map { String(data: $0, encoding: .utf8)! }
        entity.tags = try? JSONEncoder().encode(serverTask.tags).map { String(data: $0, encoding: .utf8)! }
        entity.dueDate = serverTask.due_date
        entity.scheduledDate = serverTask.scheduled_date
        entity.completedDate = serverTask.completed_date
        entity.notionURL = serverTask.notion_url
        entity.updatedAt = Date()
    }

    private func updateSyncMetadata(key: String, value: String) {
        let fetchRequest: NSFetchRequest<SyncMetadata> = SyncMetadata.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "key == %@", key)

        do {
            let metadata = try coreDataStack.viewContext.fetch(fetchRequest).first
                ?? SyncMetadata(context: coreDataStack.viewContext)
            metadata.key = key
            metadata.value = value
            metadata.updatedAt = Date()
            try coreDataStack.save()
        } catch {
            print("[Sync] Failed to update metadata: \(error)")
        }
    }
}

// MARK: - API Response Models

extension APIService {
    struct TaskResponse: Codable {
        let task_id: String
        let task_title: String
        let status: String
        let contexts: [String]
        let tags: [String]
        let due_date: Date?
        let scheduled_date: Date?
        let completed_date: Date?
        let notion_url: String
    }

    func getAllTasks() async throws -> [TaskResponse] {
        let url = URL(string: "\(baseURL)/api/all-tasks")!
        let (data, _) = try await URLSession.shared.data(from: url)
        return try JSONDecoder().decode([TaskResponse].self, from: data)
    }

    func updateTask(taskId: String, updates: [String: Any]) async throws {
        // TODO: Implement PATCH /api/task/:id endpoint
    }

    func deleteTask(taskId: String) async throws {
        // TODO: Implement DELETE /api/task/:id endpoint
    }
}
```

---

## Conflict Resolution Strategy

When local and server versions differ:

```swift
// TomOS/Services/ConflictResolver.swift

import Foundation
import CoreData

/// Resolves conflicts between local and server task versions
class ConflictResolver {
    static let shared = ConflictResolver()

    enum Resolution {
        case keepLocal      // Local changes win
        case keepServer     // Server version wins
        case merge          // Combine both (smart merge)
        case askUser        // Manual resolution needed
    }

    /// Resolve conflict between local and server task
    func resolve(
        local: TaskEntity,
        server: APIService.TaskResponse,
        in context: NSManagedObjectContext
    ) throws {
        print("[Conflict] Task \(local.id): local=\(local.updatedAt), server=\(server.updated_at)")

        // Strategy: Last-write-wins with smart field-level merging

        let resolution = determineResolution(local: local, server: server)

        switch resolution {
        case .keepLocal:
            // Mark for server update on next push
            local.syncStatus = "pending_update"

        case .keepServer:
            // Discard local changes, accept server version
            update(entity: local, from: server)
            local.syncStatus = "synced"
            local.lastSyncedAt = Date()

        case .merge:
            // Smart merge: keep non-conflicting changes from both
            mergeChanges(local: local, server: server)
            local.syncStatus = "pending_update" // Push merged version

        case .askUser:
            // Store conflict for user resolution
            local.syncStatus = "conflict"
            local.conflictData = try? JSONEncoder().encode(server).map { String(data: $0, encoding: .utf8)! }
        }
    }

    private func determineResolution(
        local: TaskEntity,
        server: APIService.TaskResponse
    ) -> Resolution {
        // If local was modified very recently (< 5 min), keep local
        if let localMod = local.localModifiedAt,
           Date().timeIntervalSince(localMod) < 300 {
            return .keepLocal
        }

        // If server is newer, keep server
        if server.updated_at > local.updatedAt {
            return .keepServer
        }

        // Otherwise try to merge
        return .merge
    }

    private func mergeChanges(
        local: TaskEntity,
        server: APIService.TaskResponse
    ) {
        // Example: Keep local title if changed, but accept server status
        if local.localModifiedAt ?? .distantPast > server.updated_at {
            // Local title wins
        } else {
            local.title = server.task_title
        }

        // Always accept server status (source of truth for workflow)
        local.status = server.status

        // Merge tags (union of both)
        let localTags = Set(local.tagsArray)
        let serverTags = Set(server.tags)
        let mergedTags = Array(localTags.union(serverTags))
        local.tags = try? JSONEncoder().encode(mergedTags).map { String(data: $0, encoding: .utf8)! }

        local.lastSyncedAt = Date()
    }

    private func update(entity: TaskEntity, from server: APIService.TaskResponse) {
        entity.title = server.task_title
        entity.status = server.status
        entity.contexts = try? JSONEncoder().encode(server.contexts).map { String(data: $0, encoding: .utf8)! }
        entity.tags = try? JSONEncoder().encode(server.tags).map { String(data: $0, encoding: .utf8)! }
        entity.updatedAt = Date()
    }
}
```

---

## CoreData Stack Setup

```swift
// TomOS/Services/CoreDataStack.swift

import Foundation
import CoreData

class CoreDataStack {
    static let shared = CoreDataStack()

    private let modelName = "TomOS"

    lazy var persistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: modelName)

        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                fatalError("CoreData load failed: \(error), \(error.userInfo)")
            }

            print("[CoreData] Loaded store: \(storeDescription.url?.lastPathComponent ?? "unknown")")
        }

        // Enable automatic migration
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        return container
    }()

    var viewContext: NSManagedObjectContext {
        return persistentContainer.viewContext
    }

    func save() throws {
        guard viewContext.hasChanges else { return }
        try viewContext.save()
    }

    func performBackgroundTask(_ block: @escaping (NSManagedObjectContext) async throws -> Void) async throws {
        try await persistentContainer.performBackgroundTask { context in
            do {
                try await block(context)
            } catch {
                print("[CoreData] Background task error: \(error)")
                throw error
            }
        }
    }
}
```

---

## API Changes Required

### New Endpoints Needed

**1. GET /api/all-tasks**
```python
# api/all_tasks.py

@app.route('/api/all-tasks', methods=['GET'])
def get_all_tasks():
    """
    Fetch all tasks from Task_Inbox for sync
    Returns full task data including tags, context, dates
    """
    notion_service = NotionService()
    tasks = notion_service.get_all_tasks()

    return jsonify([
        {
            'task_id': task['id'],
            'task_title': task['title'],
            'status': task['status'],
            'priority': task.get('priority'),
            'contexts': task.get('contexts', []),
            'tags': task.get('tags', []),
            'due_date': task.get('due_date'),
            'scheduled_date': task.get('scheduled_date'),
            'completed_date': task.get('completed_date'),
            'notion_url': task['url'],
            'created_at': task['created_at'],
            'updated_at': task['updated_at']
        }
        for task in tasks
    ])
```

**2. PATCH /api/task/:id**
```python
# api/task/update.py

@app.route('/api/task/<task_id>', methods=['PATCH'])
def update_task(task_id):
    """
    Update specific fields of a task
    Body: { "title": "...", "status": "...", "tags": [...] }
    """
    body = request.get_json()

    notion_service = NotionService()
    task = notion_service.update_task(task_id, updates=body)

    return jsonify({
        'success': True,
        'task_id': task['id'],
        'updated_fields': list(body.keys())
    })
```

**3. DELETE /api/task/:id**
```python
# api/task/delete.py

@app.route('/api/task/<task_id>', methods=['DELETE'])
def delete_task(task_id):
    """
    Mark task as deleted (archive in Notion)
    """
    notion_service = NotionService()
    notion_service.archive_task(task_id)

    return jsonify({
        'success': True,
        'task_id': task_id
    })
```

---

## Implementation Phases

### Phase 3.1: CoreData Foundation (Week 1)

**Goal:** Set up local storage without sync

- [ ] Create `TomOS.xcdatamodeld` with `TaskEntity` and `SyncMetadata`
- [ ] Implement `CoreDataStack.swift`
- [ ] Create `Task` Swift struct (view model)
- [ ] Add sample data for testing
- [ ] Test: App can read/write to CoreData

**Files Created:**
- `TomOS/TomOS.xcdatamodeld`
- `TomOS/Services/CoreDataStack.swift`
- `TomOS/Models/Task.swift`

### Phase 3.2: TaskStore Migration (Week 1-2)

**Goal:** Replace `@State` with centralized `TaskStore`

- [ ] Implement `TaskStore.swift` with `@Published` properties
- [ ] Update `TomOSApp.swift` to inject `TaskStore` as `@EnvironmentObject`
- [ ] Migrate `TasksView` to use `@EnvironmentObject var taskStore: TaskStore`
- [ ] Migrate `BrainDumpView` to use `TaskStore.createTask()`
- [ ] Test: UI updates reactively when tasks change

**Files Modified:**
- `TomOS/TomOSApp.swift`
- `TomOS/Views/TasksView.swift`
- `TomOS/Views/BrainDumpView.swift`
- `TomOS/Views/SmartSurfaceView.swift`

**Files Created:**
- `TomOS/Stores/TaskStore.swift`

### Phase 3.3: Read-Only Sync (Week 2)

**Goal:** Pull tasks from Notion, populate CoreData cache

- [ ] Implement `SyncEngine.pullFromServer()`
- [ ] Create `/api/all-tasks` endpoint
- [ ] Add "Refresh" button to TasksView
- [ ] Test: Tasks appear in app from Notion

**Files Created:**
- `TomOS/Services/SyncEngine.swift`
- `api/all_tasks.py`

### Phase 3.4: Offline Create (Week 2-3)

**Goal:** Create tasks offline, sync when online

- [ ] Implement `TaskStore.createTask()` with offline support
- [ ] Add `syncStatus = "pending_create"` to new tasks
- [ ] Implement `SyncEngine.pushToServer()` for creates
- [ ] Add sync indicator in UI
- [ ] Test: Create task offline, watch it sync when online

**Files Modified:**
- `TomOS/Stores/TaskStore.swift`
- `TomOS/Services/SyncEngine.swift`

### Phase 3.5: Offline Updates (Week 3)

**Goal:** Complete, edit, delete tasks offline

- [ ] Implement `TaskStore.completeTask()` with offline support
- [ ] Implement `TaskStore.updateTask()` for edits
- [ ] Implement `TaskStore.deleteTask()` for deletions
- [ ] Create `/api/task/:id` PATCH endpoint
- [ ] Create `/api/task/:id` DELETE endpoint
- [ ] Test: All operations work offline

**Files Created:**
- `api/task/update.py`
- `api/task/delete.py`

### Phase 3.6: Conflict Resolution (Week 3-4)

**Goal:** Handle conflicts when local and server versions differ

- [ ] Implement `ConflictResolver.swift`
- [ ] Add conflict detection in `SyncEngine.pullFromServer()`
- [ ] Create conflict resolution UI (simple: show both versions)
- [ ] Test: Create conflict scenario, verify resolution

**Files Created:**
- `TomOS/Services/ConflictResolver.swift`
- `TomOS/Views/ConflictResolutionView.swift`

### Phase 3.7: Polish & Optimization (Week 4)

**Goal:** Production-ready offline mode

- [ ] Add background sync (every 5 minutes)
- [ ] Add network reachability detection
- [ ] Show sync status in UI ("Synced", "Syncing", "Offline")
- [ ] Add pull-to-refresh gesture
- [ ] Add "Pending Changes" indicator
- [ ] Optimize CoreData queries with NSFetchedResultsController
- [ ] Add migration for existing users
- [ ] Test: Full offline workflow on airplane mode

---

## Network Reachability

Use Network framework to detect connectivity:

```swift
// TomOS/Services/NetworkMonitor.swift

import Network
import Combine

class NetworkMonitor: ObservableObject {
    static let shared = NetworkMonitor()

    @Published var isConnected = true
    @Published var connectionType: NWInterface.InterfaceType?

    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.tomos.network")

    init() {
        monitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isConnected = path.status == .satisfied
                self?.connectionType = path.availableInterfaces.first?.type

                if path.status == .satisfied {
                    print("[Network] Connected via \(path.availableInterfaces.first?.type.debugDescription ?? "unknown")")
                    // Trigger sync when network returns
                    Task {
                        try? await SyncEngine.shared.fullSync()
                    }
                } else {
                    print("[Network] Disconnected")
                }
            }
        }

        monitor.start(queue: queue)
    }
}
```

**Usage in UI:**
```swift
struct TasksView: View {
    @EnvironmentObject var taskStore: TaskStore
    @StateObject private var networkMonitor = NetworkMonitor.shared

    var body: some View {
        List(taskStore.tasks) { task in
            TaskRow(task: task)
        }
        .overlay(alignment: .top) {
            if !networkMonitor.isConnected {
                OfflineBanner()
            } else if taskStore.hasPendingChanges {
                SyncingBanner()
            }
        }
    }
}
```

---

## UI Updates Required

### Sync Status Indicators

**1. Offline Banner:**
```swift
struct OfflineBanner: View {
    var body: some View {
        HStack {
            Image(systemName: "wifi.slash")
            Text("Offline - Changes will sync when online")
        }
        .font(.caption)
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.orange.opacity(0.2))
        .foregroundColor(.orange)
    }
}
```

**2. Syncing Indicator:**
```swift
struct SyncingBanner: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.7)
            Text("Syncing changes...")
        }
        .font(.caption)
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(Color.blue.opacity(0.1))
        .foregroundColor(.blue)
    }
}
```

**3. Pull-to-Refresh:**
```swift
List(taskStore.tasks) { task in
    TaskRow(task: task)
}
.refreshable {
    await taskStore.refresh(force: true)
}
```

---

## Testing Strategy

### Unit Tests

```swift
// TomOSTests/TaskStoreTests.swift

import XCTest
@testable import TomOS

class TaskStoreTests: XCTestCase {
    var taskStore: TaskStore!
    var mockCoreData: CoreDataStack!
    var mockAPI: MockAPIService!

    override func setUp() {
        super.setUp()
        mockCoreData = CoreDataStack(inMemory: true)
        mockAPI = MockAPIService()
        taskStore = TaskStore(
            coreDataStack: mockCoreData,
            apiService: mockAPI
        )
    }

    func testCreateTaskOffline() async throws {
        // Given: No network
        mockAPI.isOnline = false

        // When: Create task
        try await taskStore.createTask(
            title: "Test task",
            context: "Work",
            tags: ["proj:tomos"]
        )

        // Then: Task exists locally with pending status
        XCTAssertEqual(taskStore.tasks.count, 1)
        XCTAssertTrue(taskStore.hasPendingChanges)
    }

    func testSyncWhenOnline() async throws {
        // Given: Task created offline
        mockAPI.isOnline = false
        try await taskStore.createTask(title: "Test", context: nil, tags: [])

        // When: Network returns
        mockAPI.isOnline = true
        try await taskStore.refresh()

        // Then: Task synced to server
        XCTAssertFalse(taskStore.hasPendingChanges)
        XCTAssertEqual(mockAPI.createCallCount, 1)
    }
}
```

### Integration Tests

1. **Offline Create Flow:**
   - Turn on airplane mode
   - Create 5 tasks
   - Verify tasks appear in UI
   - Turn off airplane mode
   - Verify tasks sync to Notion
   - Check Notion web UI

2. **Conflict Scenario:**
   - Create task on iPhone
   - Edit same task on macOS before sync
   - Let both devices sync
   - Verify conflict resolution

3. **Background Sync:**
   - Create task
   - Close app
   - Wait 5 minutes
   - Reopen app
   - Verify task was synced in background

---

## Performance Targets

| Metric | Before (Online-Only) | After (Offline Mode) | Improvement |
|--------|---------------------|---------------------|-------------|
| Task list load | ~1-2s (API call) | <100ms (CoreData) | 10-20x faster |
| Task creation | ~800ms (API roundtrip) | <50ms (local save) | 16x faster |
| API calls/day/user | ~100 | ~20-30 | 70% reduction |
| Works offline | ❌ No | ✅ Yes | ∞ |
| Data freshness | Real-time | <5 min stale | Acceptable |

---

## Migration for Existing Users

When updating app with offline mode:

```swift
// TomOS/Migrations/InitialCoreDataMigration.swift

class InitialCoreDataMigration {
    static func migrate(coreDataStack: CoreDataStack, apiService: APIService) async {
        // Check if migration needed
        let fetchRequest: NSFetchRequest<TaskEntity> = TaskEntity.fetchRequest()
        let count = (try? coreDataStack.viewContext.count(for: fetchRequest)) ?? 0

        if count > 0 {
            print("[Migration] CoreData already populated, skipping")
            return
        }

        print("[Migration] First launch - seeding CoreData from Notion...")

        do {
            // Pull all tasks from server
            try await SyncEngine.shared.pullFromServer()
            print("[Migration] Migration complete")
        } catch {
            print("[Migration] Failed: \(error)")
        }
    }
}

// Call in TomOSApp.swift:
.task {
    await InitialCoreDataMigration.migrate(
        coreDataStack: .shared,
        apiService: .shared
    )
}
```

---

## Risks & Mitigations

### Risk 1: Data Loss

**Scenario:** User creates task offline, app crashes before sync

**Mitigation:**
- CoreData persists immediately to disk
- Sync queue retries on app restart
- Tasks marked `pending_create` never deleted until synced

### Risk 2: Sync Loop

**Scenario:** Two devices ping-pong updates forever

**Mitigation:**
- `lastSyncedAt` timestamp prevents re-processing
- Conflict resolver breaks loops with "last write wins"
- Rate limiting on sync endpoint

### Risk 3: Large Dataset Performance

**Scenario:** User has 10,000+ tasks, CoreData slow

**Mitigation:**
- Implement pagination in UI (NSFetchedResultsController)
- Sync only recent tasks (last 30 days) by default
- Archive old completed tasks

### Risk 4: Notion API Rate Limits

**Scenario:** Sync hits Notion rate limits (3 req/sec)

**Mitigation:**
- Batch operations where possible
- Exponential backoff on 429 errors
- Queue sync operations (don't spam API)

---

## Success Criteria

Offline mode is production-ready when:

- ✅ App loads task list in <100ms from cache
- ✅ Tasks can be created/edited/completed offline
- ✅ Sync happens automatically in background
- ✅ Conflicts are detected and resolved
- ✅ UI shows clear sync status
- ✅ Zero data loss in testing (offline → online transitions)
- ✅ API calls reduced by 70%
- ✅ Works seamlessly on airplane mode

---

## Future Enhancements (Post-MVP)

1. **Smart Prefetching:** Predict which tasks user will need, prefetch related data
2. **Differential Sync:** Only sync changed fields, not full task objects
3. **CloudKit Sync:** Sync between user's devices without hitting Notion API
4. **Offline Search:** Full-text search in local CoreData
5. **Attachment Support:** Cache images/files locally
6. **Multi-User Collaboration:** Handle shared projects with real-time updates

---

*Design Date: 2026-01-08*
*Target Implementation: Phases 3.1-3.7 over 4 weeks*
*Dependencies: Tag system (Phase 1), Architecture audit (Phase 2)*
