import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @StateObject private var vm = AudioPlayerViewModel()
    @State private var showFilePicker = false

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    // Title
                    Text("Local Audio Player")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(Theme.textPrimary)
                        .padding(.bottom, 20)

                    // Main card
                    VStack(spacing: 0) {
                        // File picker area
                        if vm.tracks.isEmpty {
                            FilePickerArea {
                                showFilePicker = true
                            }
                        }

                        // Playlist
                        if !vm.tracks.isEmpty {
                            PlaylistView(vm: vm)

                            // Add more button
                            Button {
                                showFilePicker = true
                            } label: {
                                Text("+ \(NSLocalizedString("add.files", comment: ""))")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 6)
                                    .overlay(
                                        Capsule()
                                            .stroke(Theme.border, lineWidth: 1)
                                    )
                            }
                            .padding(.top, 12)
                        }

                        // Player controls
                        if vm.currentTrack != nil {
                            PlayerControlsView(vm: vm)
                                .padding(.top, 20)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 28)
                    .background(Theme.card)
                    .cornerRadius(20)
                    .shadow(color: .black.opacity(0.4), radius: 16, y: 8)

                    // Privacy note
                    Text(NSLocalizedString("privacy.note", comment: ""))
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textTertiary)
                        .padding(.top, 16)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 24)
            }
        }
        .fileImporter(
            isPresented: $showFilePicker,
            allowedContentTypes: [.audio, .mp3, .mpeg4Audio, .wav, .aiff],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .success(let urls):
                vm.importFiles(urls: urls)
            case .failure(let error):
                print("File picker error: \(error)")
            }
        }
    }
}

// MARK: - File Picker Area
struct FilePickerArea: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: "folder.badge.plus")
                    .font(.system(size: 36))
                    .foregroundColor(Theme.textSecondary)

                Text(NSLocalizedString("picker.label", comment: ""))
                    .font(.system(size: 14))
                    .foregroundColor(Theme.textSecondary)

                Text(NSLocalizedString("picker.sublabel", comment: ""))
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
            .padding(.horizontal, 16)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                    .foregroundColor(Theme.border)
            )
        }
    }
}

// MARK: - Playlist
struct PlaylistView: View {
    @ObservedObject var vm: AudioPlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(vm.tracks.enumerated()), id: \.element.id) { index, track in
                TrackRow(
                    track: track,
                    index: index,
                    isActive: index == vm.currentIndex,
                    onTap: { vm.selectTrack(at: index) },
                    onDelete: { vm.deleteTrack(at: index) }
                )
            }
            .onMove { source, destination in
                vm.moveTrack(from: source, to: destination)
            }
        }
        .frame(maxHeight: 264)
    }
}

struct TrackRow: View {
    let track: Track
    let index: Int
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                // Now playing dot
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
                    .opacity(isActive ? 1 : 0)

                // Track number
                Text("\(index + 1)")
                    .font(.system(size: 12))
                    .foregroundColor(isActive ? Theme.accent : Theme.textTertiary)
                    .frame(width: 20)

                // Track name
                Text(track.name)
                    .font(.system(size: 13))
                    .foregroundColor(isActive ? Theme.textPrimary : Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                // Duration
                Text(track.duration.map { formatTime($0) } ?? "--:--")
                    .font(.system(size: 11).monospacedDigit())
                    .foregroundColor(Theme.textTertiary)

                // Delete button
                Button(action: onDelete) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textTertiary)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .background(isActive ? Theme.controlBg : .clear)
            .cornerRadius(10)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Player Controls
struct PlayerControlsView: View {
    @ObservedObject var vm: AudioPlayerViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Now playing title
            Text(vm.currentTrack?.name ?? "")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 8)
                .padding(.bottom, 16)

            // Progress bar
            ProgressBarView(
                progress: vm.totalDuration > 0 ? vm.currentTime / vm.totalDuration : 0,
                onSeek: { fraction in vm.seek(to: fraction) }
            )
            .padding(.bottom, 8)

            // Time labels
            HStack {
                Text(formatTime(vm.currentTime))
                Spacer()
                Text(formatTime(vm.totalDuration))
            }
            .font(.system(size: 12).monospacedDigit())
            .foregroundColor(Theme.textTertiary)
            .padding(.bottom, 20)

            // Transport controls
            HStack(spacing: 16) {
                // Previous
                ControlButton(icon: "backward.end.fill", size: 18) {
                    vm.previousTrack()
                }
                .frame(width: 36, height: 36)

                // -15s
                ControlButton(icon: "gobackward.15", size: 20) {
                    vm.skipBackward()
                }
                .frame(width: 36, height: 36)

                // Play/Pause
                Button(action: { vm.togglePlayPause() }) {
                    ZStack {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 60, height: 60)
                        Image(systemName: vm.isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24))
                            .foregroundColor(.white)
                            .offset(x: vm.isPlaying ? 0 : 2)
                    }
                }

                // +15s
                ControlButton(icon: "goforward.15", size: 20) {
                    vm.skipForward()
                }
                .frame(width: 36, height: 36)

                // Next
                ControlButton(icon: "forward.end.fill", size: 18) {
                    vm.nextTrack()
                }
                .frame(width: 36, height: 36)
            }
            .padding(.bottom, 20)

            // Options: Loop
            HStack(spacing: 8) {
                OptionPill(
                    title: "Loop",
                    isActive: vm.loopMode == .one
                ) {
                    vm.setLoopMode(.one)
                }

                OptionPill(
                    title: "All",
                    isActive: vm.loopMode == .all
                ) {
                    vm.setLoopMode(.all)
                }
            }

            // Speed row
            VStack(spacing: 6) {
                Text(NSLocalizedString("speed", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)

                HStack(spacing: 8) {
                    ForEach(vm.speeds, id: \.self) { speed in
                        OptionPill(
                            title: speedLabel(speed),
                            isActive: vm.playbackSpeed == speed
                        ) {
                            vm.setSpeed(speed)
                        }
                    }
                }
            }
            .padding(.top, 12)

            // Sleep timer row
            VStack(spacing: 6) {
                Text(NSLocalizedString("sleep.timer", comment: ""))
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textTertiary)

                HStack(spacing: 8) {
                    OptionPill(title: "OFF", isActive: vm.sleepMinutes == 0) {
                        vm.cancelSleepTimer()
                    }
                    ForEach([15, 30, 60], id: \.self) { min in
                        OptionPill(
                            title: "\(min)m",
                            isActive: vm.sleepMinutes == min
                        ) {
                            vm.setSleepTimer(minutes: min)
                        }
                    }
                }

                if !vm.sleepStatusText.isEmpty {
                    Text(vm.sleepStatusText)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.accentGradEnd)
                        .padding(.top, 4)
                }
            }
            .padding(.top, 12)
        }
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == Float(Int(speed)) {
            return "\(Int(speed))x"
        }
        return String(format: "%.2gx", speed)
    }
}

// MARK: - Progress Bar
struct ProgressBarView: View {
    let progress: Double
    let onSeek: (Double) -> Void

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Theme.controlBg)
                    .frame(height: 6)

                // Filled portion
                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [Theme.accent, Theme.accentGradEnd],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * CGFloat(progress)), height: 6)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let fraction = max(0, min(1, value.location.x / geo.size.width))
                        onSeek(fraction)
                    }
            )
        }
        .frame(height: 6)
    }
}

// MARK: - Reusable Components
struct ControlButton: View {
    let icon: String
    let size: CGFloat
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: size))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

struct OptionPill: View {
    let title: String
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12))
                .foregroundColor(isActive ? .white : Theme.textSecondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background(isActive ? Theme.accent : Theme.controlBg)
                .clipShape(Capsule())
        }
    }
}

// MARK: - Helpers
func formatTime(_ time: TimeInterval) -> String {
    guard time.isFinite, time >= 0 else { return "0:00" }
    let minutes = Int(time) / 60
    let seconds = Int(time) % 60
    return "\(minutes):\(String(format: "%02d", seconds))"
}
