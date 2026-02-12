import SwiftUI

// MARK: - Task Cache Actor
//
// Thread-safe caching layer for task data to improve performance and reduce API calls.
// Implements a simple time-based cache invalidation strategy.
//
// Created: 2026-01-21
// Purpose: UI/UX Enhancement Phase 1 - Performance Optimization

/// Thread-safe cache for tasks and matters
actor TaskCache {
    // MARK: - Singleton

    static let shared = TaskCache()

    // MARK: - Cache Storage

    private var cachedTasks: [TaskItem] = []
    private var cachedMatters: [Matter] = []
    private var cachedNotes: [Note] = []
    private var tasksCacheTime: Date = .distantPast
    private var mattersCacheTime: Date = .distantPast
    private var notesCacheTime: Date = .distantPast

    // MARK: - Cache Configuration

    /// Cache duration in seconds (5 minutes default)
    private let cacheDuration: TimeInterval = 300

    /// Maximum cache age for background refresh (1 minute)
    private let backgroundRefreshThreshold: TimeInterval = 60

    // MARK: - Private Initializer

    private init() {}

    // MARK: - Tasks Cache

    /// Get tasks from cache or fetch from API
    /// - Parameters:
    ///   - forceRefresh: If true, ignores cache and fetches fresh data
    ///   - backgroundRefresh: If true, returns cached data but triggers background refresh
    /// - Returns: Array of tasks
    func getTasks(forceRefresh: Bool = false, backgroundRefresh: Bool = true) async throws -> [TaskItem] {
        let cacheAge = Date().timeIntervalSince(tasksCacheTime)

        // Return cached data if valid
        if !forceRefresh && cacheAge < cacheDuration && !cachedTasks.isEmpty {
            // Trigger background refresh if cache is getting old
            if backgroundRefresh && cacheAge > backgroundRefreshThreshold {
                Task {
                    try? await refreshTasksInBackground()
                }
            }
            return cachedTasks
        }

        // Fetch fresh data
        return try await refreshTasks()
    }

    /// Force refresh tasks from API
    private func refreshTasks() async throws -> [TaskItem] {
        let tasks = try await APIService.shared.getTasks()
        cachedTasks = tasks
        tasksCacheTime = Date()
        return tasks
    }

    /// Background refresh (doesn't throw errors to caller)
    private func refreshTasksInBackground() async {
        do {
            let tasks = try await APIService.shared.getTasks()
            cachedTasks = tasks
            tasksCacheTime = Date()
            print("✅ TaskCache: Background refresh completed (\(tasks.count) tasks)")
        } catch {
            print("⚠️ TaskCache: Background refresh failed: \(error.localizedDescription)")
        }
    }

    /// Invalidate tasks cache
    func invalidateTasksCache() {
        cachedTasks = []
        tasksCacheTime = .distantPast
        print("🗑️ TaskCache: Tasks cache invalidated")
    }

    /// Add a new task to cache (optimistic update)
    func addTask(_ task: TaskItem) {
        cachedTasks.append(task)
        print("➕ TaskCache: Task added to cache")
    }

    /// Update a task in cache (optimistic update)
    func updateTask(_ task: TaskItem) {
        if let index = cachedTasks.firstIndex(where: { $0.id == task.id }) {
            cachedTasks[index] = task
            print("✏️ TaskCache: Task updated in cache")
        }
    }

    /// Remove a task from cache (optimistic update)
    func removeTask(id: String) {
        cachedTasks.removeAll { $0.id == id }
        print("➖ TaskCache: Task removed from cache")
    }

    // MARK: - Matters Cache

    /// Get matters from cache or fetch from API
    /// - Parameters:
    ///   - forceRefresh: If true, ignores cache and fetches fresh data
    ///   - backgroundRefresh: If true, returns cached data but triggers background refresh
    /// - Returns: Array of matters
    func getMatters(forceRefresh: Bool = false, backgroundRefresh: Bool = true) async throws -> [Matter] {
        let cacheAge = Date().timeIntervalSince(mattersCacheTime)

        // Return cached data if valid
        if !forceRefresh && cacheAge < cacheDuration && !cachedMatters.isEmpty {
            // Trigger background refresh if cache is getting old
            if backgroundRefresh && cacheAge > backgroundRefreshThreshold {
                Task {
                    try? await refreshMattersInBackground()
                }
            }
            return cachedMatters
        }

        // Fetch fresh data
        return try await refreshMatters()
    }

    /// Force refresh matters from API
    private func refreshMatters() async throws -> [Matter] {
        let matters = try await APIService.shared.getMatters()
        cachedMatters = matters
        mattersCacheTime = Date()
        return matters
    }

    /// Background refresh (doesn't throw errors to caller)
    private func refreshMattersInBackground() async {
        do {
            let matters = try await APIService.shared.getMatters()
            cachedMatters = matters
            mattersCacheTime = Date()
            print("✅ TaskCache: Background refresh completed (\(matters.count) matters)")
        } catch {
            print("⚠️ TaskCache: Background refresh failed: \(error.localizedDescription)")
        }
    }

    /// Invalidate matters cache
    func invalidateMattersCache() {
        cachedMatters = []
        mattersCacheTime = .distantPast
        print("🗑️ TaskCache: Matters cache invalidated")
    }

    /// Add a new matter to cache (optimistic update)
    func addMatter(_ matter: Matter) {
        cachedMatters.append(matter)
        print("➕ TaskCache: Matter added to cache")
    }

    /// Update a matter in cache (optimistic update)
    func updateMatter(_ matter: Matter) {
        if let index = cachedMatters.firstIndex(where: { $0.id == matter.id }) {
            cachedMatters[index] = matter
            print("✏️ TaskCache: Matter updated in cache")
        }
    }

    /// Remove a matter from cache (optimistic update)
    func removeMatter(id: String) {
        cachedMatters.removeAll { $0.id == id }
        print("➖ TaskCache: Matter removed from cache")
    }

    // MARK: - Notes Cache

    /// Get notes from cache or fetch from API
    func getNotes(forceRefresh: Bool = false, backgroundRefresh: Bool = true) async throws -> [Note] {
        let cacheAge = Date().timeIntervalSince(notesCacheTime)

        if !forceRefresh && cacheAge < cacheDuration && !cachedNotes.isEmpty {
            if backgroundRefresh && cacheAge > backgroundRefreshThreshold {
                Task {
                    try? await refreshNotesInBackground()
                }
            }
            return cachedNotes
        }

        return try await refreshNotes()
    }

    private func refreshNotes() async throws -> [Note] {
        let notes = try await APIService.shared.getNotes()
        cachedNotes = notes
        notesCacheTime = Date()
        return notes
    }

    private func refreshNotesInBackground() async {
        do {
            let notes = try await APIService.shared.getNotes()
            cachedNotes = notes
            notesCacheTime = Date()
            print("✅ TaskCache: Background refresh completed (\(notes.count) notes)")
        } catch {
            print("⚠️ TaskCache: Background refresh failed: \(error.localizedDescription)")
        }
    }

    func invalidateNotesCache() {
        cachedNotes = []
        notesCacheTime = .distantPast
        print("🗑️ TaskCache: Notes cache invalidated")
    }

    func addNote(_ note: Note) {
        cachedNotes.insert(note, at: 0)
        print("➕ TaskCache: Note added to cache")
    }

    func updateNote(_ note: Note) {
        if let index = cachedNotes.firstIndex(where: { $0.id == note.id }) {
            cachedNotes[index] = note
            print("✏️ TaskCache: Note updated in cache")
        }
    }

    func removeNote(id: String) {
        cachedNotes.removeAll { $0.id == id }
        print("➖ TaskCache: Note removed from cache")
    }

    // MARK: - Fitness Cache

    private var cachedSessions: [GymSession] = []
    private var cachedSuggestion: SessionSuggestion?
    private var cachedRunningStats: RunningStats?
    private var sessionsCacheTime: Date = .distantPast
    private var suggestionCacheTime: Date = .distantPast
    private var runningStatsCacheTime: Date = .distantPast

    /// Get gym sessions from cache or fetch from API
    func getSessions(forceRefresh: Bool = false, backgroundRefresh: Bool = true) async throws -> [GymSession] {
        let cacheAge = Date().timeIntervalSince(sessionsCacheTime)

        if !forceRefresh && cacheAge < cacheDuration && !cachedSessions.isEmpty {
            if backgroundRefresh && cacheAge > backgroundRefreshThreshold {
                Task { try? await refreshSessionsInBackground() }
            }
            return cachedSessions
        }

        return try await refreshSessions()
    }

    private func refreshSessions() async throws -> [GymSession] {
        let sessions = try await APIService.shared.getGymSessions()
        cachedSessions = sessions
        sessionsCacheTime = Date()
        return sessions
    }

    private func refreshSessionsInBackground() async {
        do {
            let sessions = try await APIService.shared.getGymSessions()
            cachedSessions = sessions
            sessionsCacheTime = Date()
        } catch {
            print("⚠️ TaskCache: Background sessions refresh failed: \(error.localizedDescription)")
        }
    }

    /// Get session suggestion from cache or fetch from API
    func getSuggestion(forceRefresh: Bool = false) async throws -> SessionSuggestion {
        let cacheAge = Date().timeIntervalSince(suggestionCacheTime)

        if !forceRefresh && cacheAge < cacheDuration, let cached = cachedSuggestion {
            return cached
        }

        let suggestion = try await APIService.shared.getSessionSuggestion()
        cachedSuggestion = suggestion
        suggestionCacheTime = Date()
        return suggestion
    }

    /// Get running stats from cache or fetch from API
    func getRunningStats(forceRefresh: Bool = false) async throws -> RunningStats {
        let cacheAge = Date().timeIntervalSince(runningStatsCacheTime)

        if !forceRefresh && cacheAge < cacheDuration, let cached = cachedRunningStats {
            return cached
        }

        let stats = try await APIService.shared.getRunningStats()
        cachedRunningStats = stats
        runningStatsCacheTime = Date()
        return stats
    }

    /// Invalidate all fitness caches
    func invalidateFitnessCache() {
        cachedSessions = []
        cachedSuggestion = nil
        cachedRunningStats = nil
        sessionsCacheTime = .distantPast
        suggestionCacheTime = .distantPast
        runningStatsCacheTime = .distantPast
    }

    /// Add a session to cache (optimistic update)
    func addSession(_ session: GymSession) {
        cachedSessions.insert(session, at: 0)
    }

    // MARK: - Cache Management

    /// Clear all caches
    func clearAllCaches() {
        invalidateTasksCache()
        invalidateMattersCache()
        invalidateNotesCache()
        invalidateFitnessCache()
        print("🗑️ TaskCache: All caches cleared")
    }

    /// Get cache statistics
    func getCacheStats() -> CacheStats {
        CacheStats(
            tasksCount: cachedTasks.count,
            tasksCacheAge: Date().timeIntervalSince(tasksCacheTime),
            mattersCount: cachedMatters.count,
            mattersCacheAge: Date().timeIntervalSince(mattersCacheTime),
            notesCount: cachedNotes.count,
            notesCacheAge: Date().timeIntervalSince(notesCacheTime),
            sessionsCount: cachedSessions.count,
            sessionsCacheAge: Date().timeIntervalSince(sessionsCacheTime),
            cacheDuration: cacheDuration
        )
    }
}

// MARK: - Cache Statistics

struct CacheStats {
    let tasksCount: Int
    let tasksCacheAge: TimeInterval
    let mattersCount: Int
    let mattersCacheAge: TimeInterval
    let notesCount: Int
    let notesCacheAge: TimeInterval
    let sessionsCount: Int
    let sessionsCacheAge: TimeInterval
    let cacheDuration: TimeInterval

    var tasksIsValid: Bool {
        tasksCacheAge < cacheDuration
    }

    var mattersIsValid: Bool {
        mattersCacheAge < cacheDuration
    }

    var notesIsValid: Bool {
        notesCacheAge < cacheDuration
    }

    var sessionsIsValid: Bool {
        sessionsCacheAge < cacheDuration
    }

    var description: String {
        """
        TaskCache Statistics:
        • Tasks: \(tasksCount) cached (age: \(String(format: "%.1f", tasksCacheAge))s, valid: \(tasksIsValid))
        • Matters: \(mattersCount) cached (age: \(String(format: "%.1f", mattersCacheAge))s, valid: \(mattersIsValid))
        • Notes: \(notesCount) cached (age: \(String(format: "%.1f", notesCacheAge))s, valid: \(notesIsValid))
        • Sessions: \(sessionsCount) cached (age: \(String(format: "%.1f", sessionsCacheAge))s, valid: \(sessionsIsValid))
        • Cache duration: \(String(format: "%.0f", cacheDuration))s
        """
    }
}
