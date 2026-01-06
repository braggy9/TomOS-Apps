import EventKit
import Foundation

// MARK: - Calendar Manager

class CalendarManager: ObservableObject {
    static let shared = CalendarManager()

    private let eventStore = EKEventStore()

    @Published var isAuthorized = false
    @Published var todayEvents: [CalendarEvent] = []
    @Published var upcomingMeetings: [CalendarEvent] = []

    private init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    func checkAuthorization() {
        let status = EKEventStore.authorizationStatus(for: .event)
        if #available(iOS 17.0, macOS 14.0, *) {
            isAuthorized = (status == .fullAccess)
        } else {
            isAuthorized = (status == .authorized)
        }
    }

    func requestAccess() async -> Bool {
        do {
            if #available(iOS 17.0, macOS 14.0, *) {
                let granted = try await eventStore.requestFullAccessToEvents()
                await MainActor.run { isAuthorized = granted }
                return granted
            } else {
                let granted = try await eventStore.requestAccess(to: .event)
                await MainActor.run { isAuthorized = granted }
                return granted
            }
        } catch {
            print("Calendar access error: \(error)")
            return false
        }
    }

    // MARK: - Fetch Events

    func fetchTodayEvents() {
        guard isAuthorized else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!

        let predicate = eventStore.predicateForEvents(
            withStart: startOfDay,
            end: endOfDay,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { CalendarEvent(from: $0) }

        DispatchQueue.main.async {
            self.todayEvents = events
        }
    }

    func fetchUpcomingMeetings(hours: Int = 4) {
        guard isAuthorized else { return }

        let now = Date()
        let endTime = Calendar.current.date(byAdding: .hour, value: hours, to: now)!

        let predicate = eventStore.predicateForEvents(
            withStart: now,
            end: endTime,
            calendars: nil
        )

        let events = eventStore.events(matching: predicate)
            .filter { !$0.isAllDay }
            .sorted { $0.startDate < $1.startDate }
            .map { CalendarEvent(from: $0) }

        DispatchQueue.main.async {
            self.upcomingMeetings = events
        }
    }

    // MARK: - Create Task from Event

    func createTaskFromEvent(_ event: CalendarEvent, completion: @escaping (Bool) -> Void) {
        let taskText = "Prepare for: \(event.title)"

        guard let url = URL(string: "https://tomos-task-api.vercel.app/api/task") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": taskText,
            "source": "calendar",
            "dueDate": ISO8601DateFormatter().string(from: event.startDate),
            "context": "Work"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                completion(success)
            }
        }.resume()
    }

    // MARK: - Next Meeting Info

    var nextMeeting: CalendarEvent? {
        upcomingMeetings.first
    }

    var timeUntilNextMeeting: String? {
        guard let next = nextMeeting else { return nil }

        let minutes = Int(next.startDate.timeIntervalSinceNow / 60)
        if minutes < 1 {
            return "Now"
        } else if minutes < 60 {
            return "in \(minutes)m"
        } else {
            let hours = minutes / 60
            let remainingMinutes = minutes % 60
            return "in \(hours)h \(remainingMinutes)m"
        }
    }
}

// MARK: - Calendar Event Model

struct CalendarEvent: Identifiable {
    let id: String
    let title: String
    let startDate: Date
    let endDate: Date
    let location: String?
    let isAllDay: Bool
    let calendarColor: String?

    init(from event: EKEvent) {
        self.id = event.eventIdentifier ?? UUID().uuidString
        self.title = event.title ?? "Untitled"
        self.startDate = event.startDate
        self.endDate = event.endDate
        self.location = event.location
        self.isAllDay = event.isAllDay
        self.calendarColor = event.calendar?.cgColor?.components?.description
    }

    var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: startDate)
    }

    var durationString: String {
        let duration = endDate.timeIntervalSince(startDate)
        let minutes = Int(duration / 60)
        if minutes < 60 {
            return "\(minutes)m"
        } else {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
    }
}

// MARK: - Calendar View

import SwiftUI

struct CalendarSyncView: View {
    @StateObject private var calendarManager = CalendarManager.shared
    @StateObject private var m365Manager = M365CalendarManager.shared

    var body: some View {
        List {
            // Work Calendar Status (Power Automate sync)
            if !m365Manager.powerAutomateEvents.isEmpty {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        VStack(alignment: .leading) {
                            Text("Work Calendar")
                                .font(.headline)
                            Text("Synced via Power Automate")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Text("\(m365Manager.powerAutomateEvents.count) events")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Microsoft 365")
                }
            }

            // M365 Events (from direct OAuth or Power Automate sync)
            if m365Manager.isSignedIn || !m365Manager.powerAutomateEvents.isEmpty {
                let allM365Events = m365Manager.allEvents
                let todayEvents = allM365Events.filter { $0.isToday && !$0.isAllDay }
                let upcomingEvents = allM365Events.filter { !$0.isToday && !$0.isAllDay }

                if !todayEvents.isEmpty {
                    Section("Today (M365)") {
                        ForEach(todayEvents) { event in
                            M365EventRow(event: event)
                        }
                    }
                }

                if !upcomingEvents.isEmpty {
                    Section("Upcoming (M365)") {
                        ForEach(upcomingEvents.prefix(10)) { event in
                            M365EventRow(event: event)
                        }
                    }
                }

                if todayEvents.isEmpty && upcomingEvents.isEmpty && !m365Manager.isLoading {
                    Section("M365 Events") {
                        Text("No upcoming events")
                            .foregroundColor(.secondary)
                    }
                }
            }

            // iOS Calendar Section
            if !calendarManager.isAuthorized {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.largeTitle)
                            .foregroundColor(.orange)

                        Text("iOS Calendar Access")
                            .font(.headline)

                        Text("Also show events from your iPhone calendar")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)

                        Button("Enable Calendar Access") {
                            Task {
                                _ = await calendarManager.requestAccess()
                                if calendarManager.isAuthorized {
                                    calendarManager.fetchTodayEvents()
                                    calendarManager.fetchUpcomingMeetings()
                                }
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.purple)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                } header: {
                    Text("Personal Calendar")
                }
            } else {
                // iOS Calendar Events
                if !calendarManager.todayEvents.isEmpty {
                    Section("Today (iOS)") {
                        ForEach(calendarManager.todayEvents) { event in
                            CalendarEventRow(event: event, calendarManager: calendarManager)
                        }
                    }
                }

                if !calendarManager.upcomingMeetings.isEmpty {
                    Section("Upcoming (iOS)") {
                        ForEach(calendarManager.upcomingMeetings) { event in
                            CalendarEventRow(event: event, calendarManager: calendarManager)
                        }
                    }
                }
            }

            // Error display
            if let error = m365Manager.error {
                Section {
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.red)
                }
            }
        }
        .navigationTitle("Calendar")
        .onAppear {
            if calendarManager.isAuthorized {
                calendarManager.fetchTodayEvents()
                calendarManager.fetchUpcomingMeetings()
            }
            if m365Manager.isSignedIn {
                Task { await m365Manager.fetchCalendarEvents() }
            }
        }
        .refreshable {
            calendarManager.fetchTodayEvents()
            calendarManager.fetchUpcomingMeetings()
            if m365Manager.isSignedIn {
                await m365Manager.fetchCalendarEvents()
            }
        }
    }
}

// MARK: - M365 Event Row

struct M365EventRow: View {
    let event: M365CalendarEvent
    @State private var isCreatingTask = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if !event.isToday {
                        Text(event.dateString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(event.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(event.durationString)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button {
                isCreatingTask = true
                createTaskFromM365Event(event) { _ in
                    isCreatingTask = false
                }
            } label: {
                if isCreatingTask {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.blue)
                }
            }
            .buttonStyle(.plain)
            .disabled(isCreatingTask)
        }
        .padding(.vertical, 4)
    }

    private func createTaskFromM365Event(_ event: M365CalendarEvent, completion: @escaping (Bool) -> Void) {
        let taskText = "Prepare for: \(event.title)"

        guard let url = URL(string: "https://tomos-task-api.vercel.app/api/task") else {
            completion(false)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": taskText,
            "source": "m365-calendar",
            "dueDate": ISO8601DateFormatter().string(from: event.startDate),
            "context": "Work"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            let success = error == nil && (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async {
                completion(success)
            }
        }.resume()
    }
}

struct CalendarEventRow: View {
    let event: CalendarEvent
    let calendarManager: CalendarManager
    @State private var isCreatingTask = false

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title)
                    .font(.headline)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    Text(event.timeString)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(event.durationString)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.2))
                        .cornerRadius(4)

                    if let location = event.location, !location.isEmpty {
                        Text(location)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer()

            Button {
                isCreatingTask = true
                calendarManager.createTaskFromEvent(event) { success in
                    isCreatingTask = false
                }
            } label: {
                if isCreatingTask {
                    ProgressView()
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: "plus.circle")
                        .foregroundColor(.purple)
                }
            }
            .buttonStyle(.plain)
            .disabled(isCreatingTask)
        }
        .padding(.vertical, 4)
    }
}
