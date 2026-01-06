import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = WatchViewModel()

    var body: some View {
        NavigationStack {
            List {
                // Quick Add Section
                Section {
                    NavigationLink {
                        QuickAddView(viewModel: viewModel)
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.purple)
                            Text("Quick Add")
                        }
                    }
                }

                // Current Task Section
                Section("Next Up") {
                    if let task = viewModel.currentTask {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(task)
                                .font(.headline)
                                .lineLimit(2)

                            HStack(spacing: 12) {
                                Button {
                                    viewModel.completeTask()
                                } label: {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.green)
                                }
                                .buttonStyle(.plain)

                                Button {
                                    viewModel.snoozeTask()
                                } label: {
                                    Image(systemName: "clock")
                                        .foregroundColor(.orange)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } else {
                        Text("No tasks")
                            .foregroundColor(.secondary)
                    }
                }

                // Quick Actions Section
                Section("Actions") {
                    Button {
                        viewModel.triggerMorningOverview()
                    } label: {
                        Label("Morning Overview", systemImage: "sunrise")
                    }

                    Button {
                        viewModel.triggerEODSummary()
                    } label: {
                        Label("EOD Summary", systemImage: "sunset")
                    }
                }
            }
            .navigationTitle("TomOS")
            .refreshable {
                await viewModel.refresh()
            }
        }
        .onAppear {
            viewModel.fetchCurrentTask()
        }
    }
}

// MARK: - Quick Add View

struct QuickAddView: View {
    @ObservedObject var viewModel: WatchViewModel
    @State private var taskText = ""
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            TextField("What needs doing?", text: $taskText)
                .textFieldStyle(.plain)

            Button {
                viewModel.addTask(taskText)
                dismiss()
            } label: {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Task")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
            .disabled(taskText.isEmpty)
        }
        .padding()
        .navigationTitle("Quick Add")
    }
}

// MARK: - View Model

class WatchViewModel: ObservableObject {
    @Published var currentTask: String?
    @Published var isLoading = false

    private let baseURL = "https://tomos-task-api.vercel.app"

    func fetchCurrentTask() {
        guard let url = URL(string: "\(baseURL)/api/task/smart-surface") else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let recommendations = json["recommendations"] as? [[String: Any]],
                  let firstTask = recommendations.first,
                  let title = firstTask["title"] as? String else {
                return
            }

            DispatchQueue.main.async {
                self?.currentTask = title
            }
        }.resume()
    }

    func refresh() async {
        await MainActor.run { isLoading = true }

        guard let url = URL(string: "\(baseURL)/api/task/smart-surface") else { return }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let recommendations = json["recommendations"] as? [[String: Any]],
               let firstTask = recommendations.first,
               let title = firstTask["title"] as? String {
                await MainActor.run {
                    self.currentTask = title
                    self.isLoading = false
                }
            }
        } catch {
            await MainActor.run { isLoading = false }
        }
    }

    func addTask(_ text: String) {
        guard !text.isEmpty,
              let url = URL(string: "\(baseURL)/api/task") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "source": "watch"
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { [weak self] _, _, _ in
            DispatchQueue.main.async {
                self?.fetchCurrentTask()
            }
        }.resume()
    }

    func completeTask() {
        // Haptic feedback
        WKInterfaceDevice.current().play(.success)

        // For now, just refresh to get next task
        fetchCurrentTask()
    }

    func snoozeTask() {
        // Haptic feedback
        WKInterfaceDevice.current().play(.click)

        // Refresh
        fetchCurrentTask()
    }

    func triggerMorningOverview() {
        guard let url = URL(string: "\(baseURL)/api/notifications/morning-overview") else { return }
        URLSession.shared.dataTask(with: url).resume()
        WKInterfaceDevice.current().play(.notification)
    }

    func triggerEODSummary() {
        guard let url = URL(string: "\(baseURL)/api/notifications/eod-summary") else { return }
        URLSession.shared.dataTask(with: url).resume()
        WKInterfaceDevice.current().play(.notification)
    }
}

#Preview {
    ContentView()
}
