import ActivityKit
import WidgetKit
import SwiftUI

struct LyricAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var currentLine: String
        var nextLine: String?
        var progress: Double
        var isPlaying: Bool
    }

    var trackName: String
    var artistName: String
    var albumArtURL: String?
}

private let accent = Color(red: 0.12, green: 0.90, blue: 0.45)

struct LyricWidgetLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: LyricAttributes.self) { context in
            LockScreenBanner(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    AlbumArtView(urlString: context.attributes.albumArtURL)
                        .frame(width: 44, height: 44)
                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .padding(.leading, 6)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.trailing, 10)
                        .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.center) {
                    VStack(spacing: 1) {
                        Text(context.attributes.trackName)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(1)
                        Text(context.attributes.artistName)
                            .font(.system(size: 11, design: .rounded))
                            .foregroundColor(.white.opacity(0.5))
                            .lineLimit(1)
                    }
                    .padding(.top, 4)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        Text(context.state.currentLine.isEmpty ? "♪" : context.state.currentLine)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                            .frame(maxWidth: .infinity)

                        ProgressView(value: context.state.progress)
                            .tint(accent)
                            .padding(.horizontal, 4)
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            } compactLeading: {
                Image(systemName: "music.note")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(accent)
            } compactTrailing: {
                ProgressView(value: context.state.progress, total: 1.0)
                    .progressViewStyle(.circular)
                    .tint(accent)
                    .frame(width: 16, height: 16)
            } minimal: {
                Image(systemName: "music.note")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(accent)
            }
            .widgetURL(URL(string: "lyricdrive://"))
            .keylineTint(accent)
        }
    }
}

// MARK: - Lock Screen Banner
// Flat VStack — no ZStack/overlay/GeometryReader which all cause clipping in Live Activities

private struct LockScreenBanner: View {
    let context: ActivityViewContext<LyricAttributes>

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {

            // ── Track row ──
            HStack(spacing: 10) {
                AlbumArtView(urlString: context.attributes.albumArtURL)
                    .frame(width: 44, height: 44)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .shadow(color: .black.opacity(0.4), radius: 4, y: 2)

                VStack(alignment: .leading, spacing: 2) {
                    Text(context.attributes.trackName)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(context.attributes.artistName)
                        .font(.system(size: 12, design: .rounded))
                        .foregroundColor(.white.opacity(0.5))
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: context.state.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
            }

            // ── Current lyric ──
            Text(context.state.currentLine.isEmpty ? "♪" : context.state.currentLine)
                .font(.system(size: 17, weight: .bold, design: .rounded))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(accent.opacity(0.12))
                )

            // ── Next line ──
            if let next = context.state.nextLine, !next.isEmpty {
                Text(next)
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(.white.opacity(0.35))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            // ── Progress ──
            ProgressView(value: context.state.progress)
                .tint(accent)
        }
        .padding(16)
        .activityBackgroundTint(Color(white: 0.05))
        .activitySystemActionForegroundColor(.white)
    }
}

// MARK: - Album Art

private struct AlbumArtView: View {
    let urlString: String?

    var body: some View {
        if let str = urlString, let url = URL(string: str) {
            AsyncImage(url: url) { phase in
                if let img = phase.image {
                    img.resizable().scaledToFill()
                } else {
                    placeholder
                }
            }
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.white.opacity(0.07)
            Image(systemName: "music.note")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.35))
        }
    }
}
