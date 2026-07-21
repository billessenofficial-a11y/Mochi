import Combine
import SwiftUI
import UIKit

@MainActor
final class ConversationStore: ObservableObject {
    @Published var route: AppRoute = .home
    @Published var selectedTab: AppTab = .home
    @Published var mode: ConversationMode = .guidedDemo
    @Published var status: ConversationStatus = .ready
    @Published var userName = UserDefaults.standard.string(forKey: "mochi.userName") ?? "" {
        didSet { UserDefaults.standard.set(userName, forKey: "mochi.userName") }
    }
    @Published var nicknames: [String] = UserDefaults.standard.stringArray(forKey: "mochi.nicknames") ?? [] {
        didSet { UserDefaults.standard.set(nicknames, forKey: "mochi.nicknames") }
    }
    @Published var captionScale: Double = 1
    @Published var captionEngine: CaptionEngine = CaptionEngine(
        rawValue: UserDefaults.standard.string(forKey: "mochi.captionEngine") ?? ""
    ) ?? .openAIRealtime {
        didSet {
            UserDefaults.standard.set(captionEngine.rawValue, forKey: "mochi.captionEngine")
            speechService.captionEngine = captionEngine
        }
    }
    @Published var hapticsEnabled = true
    @Published var voiceLiftEnabled = UserDefaults.standard.bool(forKey: "mochi.voiceLiftEnabled") {
        didSet {
            UserDefaults.standard.set(voiceLiftEnabled, forKey: "mochi.voiceLiftEnabled")
            speechService.voiceLiftEnabled = voiceLiftEnabled
        }
    }
    @Published var voiceLiftGainDB = UserDefaults.standard.object(forKey: "mochi.voiceLiftGainDB") as? Double ?? 6 {
        didSet {
            UserDefaults.standard.set(voiceLiftGainDB, forKey: "mochi.voiceLiftGainDB")
            speechService.voiceLiftGainDB = voiceLiftGainDB
        }
    }
    @Published var listeningCaptionsEnabled = UserDefaults.standard.object(forKey: "mochi.listeningCaptionsEnabled") as? Bool ?? true {
        didSet { UserDefaults.standard.set(listeningCaptionsEnabled, forKey: "mochi.listeningCaptionsEnabled") }
    }
    @Published var preferredColorScheme: ColorScheme?
    @Published private(set) var segments: [TranscriptSegment] = []
    @Published private(set) var events: [AttentionEvent] = []
    @Published private(set) var repairs: [RepairAnnotation] = []
    @Published private(set) var recapItems: [RecapItem] = []
    @Published private(set) var recapTitle = "Conversation recap"
    @Published private(set) var recordingURL: URL?
    @Published private(set) var isGeneratingRecap = false
    @Published private(set) var recapErrorMessage: String?
    @Published private(set) var sessionCaptionEngine: CaptionEngine?
    @Published private(set) var sessionCaptionsEnabled = true
    @Published private(set) var sessionVoiceLiftEnabled = false
    @Published private(set) var catchUpBrief: GeneratedCatchUp?
    @Published private(set) var isGeneratingCatchUp = false
    @Published private(set) var catchUpErrorMessage: String?
    @Published private(set) var provisionalSegments: [TranscriptSegment] = []
    @Published private(set) var isRefiningTranscript = false
    @Published private(set) var transcriptRefinedAt: Date?
    @Published private(set) var transcriptRefinementErrorMessage: String?
    @Published private(set) var savedConversations: [SavedConversation] = []
    @Published private(set) var libraryErrorMessage: String?
    @Published var activeEvent: AttentionEvent?
    @Published var showConsent = false
    @Published var showRepair = false
    @Published var showSpeakerCard = false
    @Published var showCatchUp = false
    @Published var showSettings = false
    @Published var selectedEvidenceIDs: [String] = []
    @Published var showEvidence = false
    @Published var elapsedSeconds = 0
    @Published var showSpeakerEditor = false

    private var speakerAliases: [String: String] = [:]

    let speechService = SpeechRecognitionService()
    let playbackService = AudioPlaybackService()
    let audiogramService = AudiogramService()
    let watchConnectivity = PhoneWatchConnectivityService()
    private let analyzer = LocalSemanticAnalyzer()
    private let archive = ConversationArchive()
    private var demoTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    private var currentConversationID: String?
    private var sessionStartedAt = Date()
    private var catchUpSegmentCount = 0

    init() {
        speechService.captionEngine = captionEngine
        speechService.voiceLiftEnabled = voiceLiftEnabled
        speechService.voiceLiftGainDB = voiceLiftGainDB

        // SpeechRecognitionService is a nested ObservableObject. Forward its
        // changes so Home and onboarding immediately reflect readiness,
        // progress, errors, partial captions, and microphone levels.
        speechService.objectWillChange
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)

        speechService.$activeCaptionEngine
            .compactMap { $0 }
            .sink { [weak self] engine in self?.sessionCaptionEngine = engine }
            .store(in: &cancellables)

        speechService.onUtterance = { [weak self] utterance in
            self?.applyLiveUtterance(utterance)
        }

        watchConnectivity.onCommand = { [weak self] command in
            self?.handleWatchCommand(command)
        }

        Publishers.CombineLatest4($status, $segments, $activeEvent, $catchUpBrief)
            .sink { [weak self] _, _, _, _ in self?.publishWatchSnapshot() }
            .store(in: &cancellables)

        Publishers.CombineLatest($route, $showConsent)
            .sink { [weak self] _, _ in self?.publishWatchSnapshot() }
            .store(in: &cancellables)

        reloadSavedConversations()
        if ProcessInfo.processInfo.arguments.contains("-homePreview") {
            selectedTab = .home
        }
        if ProcessInfo.processInfo.arguments.contains("-recordingsPreview") {
            selectedTab = .recordings
        }
        if ProcessInfo.processInfo.arguments.contains("-assistPreview") {
            selectedTab = .home
        }
        if ProcessInfo.processInfo.arguments.contains("-settingsPreview") {
            selectedTab = .settings
        }
        if ProcessInfo.processInfo.arguments.contains("-consentPreview") {
            begin(.live)
        }

        if ProcessInfo.processInfo.arguments.contains("-catchUpPreview") {
            mode = .guidedDemo
            route = .conversation
            status = .paused
            segments = Self.demoBeats.map(\.segment)
            events = Self.demoBeats.compactMap(\.event)
            elapsedSeconds = 18
            showCatchUp = true
        } else if ProcessInfo.processInfo.arguments.contains("-nameMentionPreview") {
            mode = .guidedDemo
            route = .conversation
            status = .paused
            let beats = Array(Self.demoBeats.prefix(2))
            segments = beats.map(\.segment)
            events = beats.compactMap(\.event)
            activeEvent = events.last
            elapsedSeconds = 8
        } else if ProcessInfo.processInfo.arguments.contains("-recapPreview"),
                  let conversation = savedConversations.first(where: { !$0.segments.isEmpty }) {
            openSavedConversation(conversation)
        } else if ProcessInfo.processInfo.arguments.contains("-guidedDemoPreview") {
            mode = .guidedDemo
            route = .conversation
            status = .listening
            startClock()
            startGuidedDemo()
        } else if ProcessInfo.processInfo.arguments.contains("-conversationPreview") {
            mode = .live
            route = .conversation
            status = .listening
            sessionCaptionsEnabled = true
            sessionVoiceLiftEnabled = false
            startClock()
        } else if ProcessInfo.processInfo.arguments.contains("-livePreview") {
            mode = .live
            route = .conversation
            status = .listening
            startClock()
            Task { [weak self] in
                await self?.speechService.prepareCaptionModel()
                await self?.speechService.start()
            }
        } else if ProcessInfo.processInfo.arguments.contains("-refinementPreview"),
                  let conversation = savedConversations
                    .filter({ !$0.segments.isEmpty })
                    .min(by: { $0.durationSeconds < $1.durationSeconds }) {
            openSavedConversation(conversation)
            retryTranscriptRefinement()
        }
    }

    var activeSegments: [TranscriptSegment] {
        if speechService.partialText.isEmpty { return segments }
        return segments + [
            TranscriptSegment(
                id: "partial-live",
                speaker: speaker(for: speechService.partialSpeakerIndex),
                startSeconds: TimeInterval(elapsedSeconds),
                text: speechService.partialText,
                isFinal: false
            )
        ]
    }

    var currentCatchUp: [CatchUpItem] {
        var items: [CatchUpItem] = []
        var usedSources = Set<String>()

        func append(_ item: CatchUpItem) {
            guard item.sourceSegmentIDs.contains(where: { !usedSources.contains($0) }) else { return }
            items.append(item)
            usedSources.formUnion(item.sourceSegmentIDs)
        }

        if let mention = events.last(where: { $0.type == .nameMention && $0.state != .dismissed }) {
            append(CatchUpItem(
                id: "catch-name-\(mention.id)",
                kind: .needsYou,
                title: "You were mentioned",
                text: mention.sourceQuote,
                sourceSegmentIDs: mention.sourceSegmentIDs
            ))
        }

        if let question = events.last(where: { $0.type == .directQuestion && $0.state != .dismissed }) {
            append(CatchUpItem(
                id: "catch-question-\(question.id)",
                kind: .needsYou,
                title: "A question is open",
                text: question.sourceQuote,
                sourceSegmentIDs: question.sourceSegmentIDs
            ))
        }

        if let repair = repairs.last(where: { $0.userConfirmed }), let value = repair.resolvedValue {
            append(CatchUpItem(
                id: "catch-repair-\(repair.id)",
                kind: .decision,
                title: "Confirmed detail",
                text: value,
                sourceSegmentIDs: repair.sourceSegmentIDs
            ))
        } else if let detail = events.last(where: {
            ($0.type == .criticalDetail || $0.type == .importantAmbiguity) && $0.state != .dismissed
        }) {
            append(CatchUpItem(
                id: "catch-detail-\(detail.id)",
                kind: detail.type == .importantAmbiguity ? .needsYou : .detail,
                title: detail.type == .importantAmbiguity ? "Worth confirming" : "Important detail",
                text: detail.sourceQuote,
                sourceSegmentIDs: detail.sourceSegmentIDs
            ))
        }

        if let recent = segments.last {
            append(CatchUpItem(
                id: "catch-recent-\(recent.id)",
                kind: .recent,
                title: "Most recent",
                text: "\(recent.speaker.displayName): \(recent.text)",
                sourceSegmentIDs: [recent.id]
            ))
        }
        return Array(items.prefix(4))
    }

    var catchUpOverview: String {
        if let overview = catchUpBrief?.overview, !overview.isEmpty { return overview }
        if segments.isEmpty { return "Mochi will summarize the conversation as it develops." }
        return "Here’s what may need your attention from the latest part of the conversation."
    }

    private var watchCatchUpItems: [CatchUpItem] {
        guard let generated = catchUpBrief else { return currentCatchUp }
        return generated.items.map {
            CatchUpItem(
                id: "generated-\($0.id)",
                kind: $0.kind,
                title: $0.title,
                text: $0.text,
                sourceSegmentIDs: $0.sourceSegmentIDs
            )
        }
    }

    private func publishWatchSnapshot() {
        let sessionState: String
        if showConsent {
            sessionState = "consent"
        } else if route == .recap {
            sessionState = "complete"
        } else {
            switch status {
            case .ready: sessionState = "ready"
            case .listening: sessionState = "listening"
            case .paused: sessionState = "paused"
            case .finishing: sessionState = "finishing"
            }
        }

        let nameMention = activeEvent.flatMap { event in
            event.type == .nameMention && (event.state == .new || event.state == .repairing)
                ? event
                : nil
        }

        watchConnectivity.publish(
            PhoneWatchSnapshot(
                sessionState: sessionState,
                elapsedSeconds: elapsedSeconds,
                consentRequired: showConsent,
                latestSegment: segments.last,
                nameMention: nameMention,
                catchUpOverview: catchUpOverview,
                catchUpItems: watchCatchUpItems
            )
        )
    }

    private func handleWatchCommand(_ command: WatchCommand) {
        switch command {
        case .requestStart:
            guard status == .ready, !showConsent else { return }
            selectedTab = .home
            route = .home
            begin(.live)
        case .togglePause:
            guard status == .listening || status == .paused else { return }
            togglePause()
        case .endConversation:
            guard status == .listening || status == .paused else { return }
            endConversation()
        case .refreshCatchUp:
            refreshCatchUp(force: true)
        case .dismissNameMention:
            guard let activeEvent, activeEvent.type == .nameMention else { return }
            dismiss(activeEvent)
        }
    }

    var isHearingReady: Bool { speechService.isCaptioningReady }
    var isHearingModelDownloaded: Bool { speechService.isCaptionModelDownloaded }
    var canRefineTranscript: Bool {
        recordingURL != nil && transcriptRefinedAt == nil && !isRefiningTranscript
    }

    var knownSpeakers: [Speaker] {
        var speakers: [String: Speaker] = [:]
        for segment in segments { speakers[segment.speaker.id] = segment.speaker }
        if mode.capturesAudio, status == .listening || status == .paused {
            let current = speaker(for: speechService.partialSpeakerIndex)
            speakers[current.id] = current
        }
        if speakers.isEmpty { speakers[Speaker.live(index: 0).id] = speaker(for: 0) }
        return speakers.values.sorted { $0.id.localizedStandardCompare($1.id) == .orderedAscending }
    }

    func speaker(for index: Int) -> Speaker {
        var speaker = Speaker.live(index: index)
        if let alias = speakerAliases[speaker.id] { speaker.displayName = alias }
        return speaker
    }

    func renameSpeaker(id: String, to rawName: String) {
        let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty else { return }
        objectWillChange.send()
        speakerAliases[id] = name
        for index in segments.indices where segments[index].speaker.id == id {
            segments[index] = replacingSpeaker(in: segments[index], displayName: name)
        }
        for index in provisionalSegments.indices where provisionalSegments[index].speaker.id == id {
            provisionalSegments[index] = replacingSpeaker(in: provisionalSegments[index], displayName: name)
        }
        archiveCurrentConversationIfNeeded()
        haptic(.success)
    }

    func selectionHaptic() {
        guard hapticsEnabled else { return }
        UISelectionFeedbackGenerator().selectionChanged()
    }

    func prepareHearingModel() async {
        await speechService.prepareCaptionModel()
    }

    func begin(
        _ selectedMode: ConversationMode,
        captionsEnabled: Bool = true,
        voiceLiftEnabled: Bool = false
    ) {
        selectionHaptic()
        mode = selectedMode
        resetSession()
        sessionCaptionsEnabled = captionsEnabled
        sessionVoiceLiftEnabled = voiceLiftEnabled
        speechService.captionsEnabled = captionsEnabled
        speechService.voiceLiftEnabled = voiceLiftEnabled
        speechService.voiceLiftGainDB = voiceLiftGainDB
        currentConversationID = UUID().uuidString
        sessionStartedAt = Date()
        showConsent = true
    }

    func confirmConsentAndStart() {
        showConsent = false
        route = .conversation
        status = .listening
        startClock()

        if mode == .guidedDemo {
            startGuidedDemo()
        } else {
            Task { await speechService.start() }
        }
    }

    func togglePause() {
        selectionHaptic()
        switch status {
        case .listening:
            status = .paused
            if mode == .guidedDemo {
                demoTask?.cancel()
            } else {
                speechService.stop()
            }
        case .paused:
            status = .listening
            if mode == .guidedDemo {
                startGuidedDemo(from: segments.count)
            } else {
                Task { await speechService.start() }
            }
        default:
            break
        }
    }

    func endConversation() {
        guard status != .finishing else { return }
        demoTask?.cancel()
        clockTask?.cancel()
        status = .finishing
        isGeneratingRecap = true

        Task { [weak self] in
            guard let self else { return }
            let conversationID = self.currentConversationID
            if self.mode.capturesAudio {
                self.recordingURL = await self.speechService.finishSession()
                self.provisionalSegments = self.segments
                // Playback and the provisional transcript are available while
                // the slower speaker-aware accuracy pass is in flight.
                self.route = .recap
                if self.sessionCaptionEngine == .openAIRealtime,
                   let recordingURL = self.recordingURL {
                    await self.refineTranscript(
                        using: recordingURL,
                        expectedConversationID: conversationID
                    )
                }
            }
            guard self.currentConversationID == conversationID else { return }
            await self.buildRecap()
            self.archiveCurrentConversationIfNeeded()
            self.isGeneratingRecap = false
            self.route = .recap
        }
    }

    func openRepair(_ event: AttentionEvent) {
        activeEvent = event
        updateEvent(event.id, state: .repairing)
        showRepair = true
    }

    func dismiss(_ event: AttentionEvent) {
        updateEvent(event.id, state: .dismissed)
        if activeEvent?.id == event.id { activeEvent = nil }
    }

    func resolveActiveEvent(with value: String) {
        guard let event = activeEvent else { return }
        let annotation = RepairAnnotation(
            id: "fix-\(UUID().uuidString)",
            eventID: event.id,
            sourceSegmentIDs: event.sourceSegmentIDs,
            resolvedValue: value,
            createdAt: Date(),
            userConfirmed: true
        )
        repairs.append(annotation)
        updateEvent(event.id, state: .resolved)
        showSpeakerCard = false
        showRepair = false
        activeEvent = nil
        haptic(.success)
    }

    func markActiveEventUnresolved() {
        guard let event = activeEvent else { return }
        repairs.append(
            RepairAnnotation(
                id: "fix-\(UUID().uuidString)",
                eventID: event.id,
                sourceSegmentIDs: event.sourceSegmentIDs,
                resolvedValue: nil,
                createdAt: Date(),
                userConfirmed: false
            )
        )
        updateEvent(event.id, state: .unresolved)
        showRepair = false
        activeEvent = nil
    }

    func showEvidence(for ids: [String]) {
        selectionHaptic()
        selectedEvidenceIDs = ids
        showEvidence = true
    }

    func refreshCatchUp(force: Bool = false) {
        guard !segments.isEmpty, !isGeneratingCatchUp else { return }
        if !force, catchUpBrief != nil, catchUpSegmentCount == segments.count { return }

        let snapshot = Array(segments.suffix(20))
        let latestID = snapshot.last?.id
        isGeneratingCatchUp = true
        catchUpErrorMessage = nil
        Task { [weak self] in
            guard let self else { return }
            do {
                let generated = try await MochiAPI.shared.generateCatchUp(
                    segments: snapshot,
                    userName: self.userName,
                    aliases: self.nicknames
                )
                guard self.segments.last?.id == latestID else {
                    self.isGeneratingCatchUp = false
                    return
                }
                self.catchUpBrief = generated
                self.catchUpSegmentCount = self.segments.count
            } catch {
                self.catchUpErrorMessage = "Using live transcript highlights while the AI brief is unavailable."
            }
            self.isGeneratingCatchUp = false
        }
    }

    func toggleRecordingPlayback() {
        guard let recordingURL else { return }
        selectionHaptic()
        playbackService.toggle(url: recordingURL)
    }

    func playEvidence(_ segment: TranscriptSegment) {
        guard let recordingURL else { return }
        playbackService.play(url: recordingURL, from: max(0, segment.startSeconds - 0.35))
    }

    func deleteConversation() {
        if let currentConversationID,
           let conversation = savedConversations.first(where: { $0.id == currentConversationID }) {
            deleteSavedConversation(conversation)
        } else if let recordingURL {
            try? FileManager.default.removeItem(at: recordingURL)
        }
        resetSession()
        selectedTab = .home
        route = .home
    }

    func startAnotherConversation() {
        resetSession()
        selectedTab = .home
        route = .home
    }

    func showRecordings() {
        selectedTab = .recordings
        route = .home
    }

    func openSavedConversation(_ conversation: SavedConversation) {
        resetSession()
        currentConversationID = conversation.id
        sessionStartedAt = conversation.createdAt
        mode = .live
        status = .ready
        segments = conversation.segments
        speakerAliases = conversation.segments.reduce(into: [:]) { aliases, segment in
            aliases[segment.speaker.id] = segment.speaker.displayName
        }
        events = conversation.events
        repairs = conversation.repairs
        recapItems = conversation.recapItems
        recapTitle = conversation.title
        recapErrorMessage = conversation.recapErrorMessage
        sessionCaptionEngine = conversation.captionEngine
        provisionalSegments = conversation.provisionalSegments ?? []
        transcriptRefinedAt = conversation.transcriptRefinedAt
        transcriptRefinementErrorMessage = conversation.transcriptRefinementErrorMessage
        isRefiningTranscript = false
        elapsedSeconds = conversation.durationSeconds
        recordingURL = archive.recordingURL(for: conversation)
        route = .recap
    }

    func deleteSavedConversation(_ conversation: SavedConversation) {
        playbackService.stop()
        do {
            savedConversations = try archive.delete(conversation, from: savedConversations)
            libraryErrorMessage = nil
        } catch {
            libraryErrorMessage = "That recording could not be deleted. Please try again."
        }
    }

    func recordingURL(for conversation: SavedConversation) -> URL {
        archive.recordingURL(for: conversation)
    }

    func retryRecap() {
        guard mode.capturesAudio, !segments.isEmpty, !isGeneratingRecap else { return }
        isGeneratingRecap = true
        Task { [weak self] in
            guard let self else { return }
            await self.buildRecap()
            self.archiveCurrentConversationIfNeeded()
            self.isGeneratingRecap = false
        }
    }

    func retryTranscriptRefinement() {
        guard let recordingURL,
              let conversationID = currentConversationID,
              canRefineTranscript else { return }
        if provisionalSegments.isEmpty { provisionalSegments = segments }
        isGeneratingRecap = true
        Task { [weak self] in
            guard let self else { return }
            await self.refineTranscript(
                using: recordingURL,
                expectedConversationID: conversationID
            )
            guard self.currentConversationID == conversationID else { return }
            if self.transcriptRefinedAt != nil {
                await self.buildRecap()
            }
            self.archiveCurrentConversationIfNeeded()
            self.isGeneratingRecap = false
        }
    }

    private func refineTranscript(
        using recordingURL: URL,
        expectedConversationID: String?
    ) async {
        guard !isRefiningTranscript else { return }
        isRefiningTranscript = true
        transcriptRefinementErrorMessage = nil
        defer { isRefiningTranscript = false }

        do {
            let generated = try await MochiAPI.shared.refineRecording(at: recordingURL)
            guard currentConversationID == expectedConversationID else { return }
            applyRefinedTranscript(generated)
            transcriptRefinedAt = Date()
        } catch {
            guard currentConversationID == expectedConversationID else { return }
            transcriptRefinementErrorMessage = refinementFailureMessage(for: error)
        }
    }

    private func applyRefinedTranscript(_ generated: GeneratedRefinedTranscript) {
        guard !generated.segments.isEmpty else { return }
        let original = segments
        if provisionalSegments.isEmpty { provisionalSegments = original }

        var speakerIndexes: [String: Int] = [:]
        var nextSpeakerIndex = 0
        let refined = generated.segments.enumerated().map { index, segment in
            let normalizedSpeaker = segment.speaker.lowercased()
            let speakerIndex: Int
            if let existing = speakerIndexes[normalizedSpeaker] {
                speakerIndex = existing
            } else {
                speakerIndex = nextSpeakerIndex
                speakerIndexes[normalizedSpeaker] = nextSpeakerIndex
                nextSpeakerIndex += 1
            }
            return TranscriptSegment(
                id: "refined-\(index + 1)",
                speaker: speaker(for: speakerIndex),
                startSeconds: max(0, segment.startSeconds),
                text: segment.text,
                isFinal: true,
                emphasis: inferEmphasis(segment.text)
            )
        }

        var replacementIDs: [String: String] = [:]
        for segment in original {
            replacementIDs[segment.id] = refined.min {
                abs($0.startSeconds - segment.startSeconds) < abs($1.startSeconds - segment.startSeconds)
            }?.id
        }
        repairs = repairs.map { repair in
            let remapped = Array(Set(repair.sourceSegmentIDs.compactMap { replacementIDs[$0] }))
            return RepairAnnotation(
                id: repair.id,
                eventID: repair.eventID,
                sourceSegmentIDs: remapped.isEmpty ? repair.sourceSegmentIDs : remapped,
                resolvedValue: repair.resolvedValue,
                createdAt: repair.createdAt,
                userConfirmed: repair.userConfirmed
            )
        }

        segments = refined
        events = refined.flatMap { analyzer.analyze(segment: $0, userName: userName, aliases: nicknames) }
        let confirmedSources = Set(
            repairs.filter(\.userConfirmed).flatMap(\.sourceSegmentIDs)
        )
        for index in events.indices where !confirmedSources.isDisjoint(with: events[index].sourceSegmentIDs) {
            events[index].state = .resolved
        }
    }

    private func applyLiveUtterance(_ utterance: RecognizedUtterance) {
        if utterance.isRevision,
           let index = segments.firstIndex(where: { $0.id == utterance.id }) {
            segments[index].text = utterance.text
            segments[index].emphasis = inferEmphasis(utterance.text)
            catchUpBrief = nil
            return
        }

        let segment = TranscriptSegment(
            id: utterance.id,
            speaker: speaker(for: utterance.speakerIndex),
            startSeconds: utterance.startSeconds,
            text: utterance.text,
            isFinal: true,
            emphasis: inferEmphasis(utterance.text)
        )
        segments.append(segment)
        catchUpBrief = nil
        let found = analyzer.analyze(segment: segment, userName: userName, aliases: nicknames)
        addEvents(found)
    }

    private func addEvents(_ newEvents: [AttentionEvent]) {
        for event in newEvents where !events.contains(where: { $0.id == event.id }) {
            events.append(event)
            if event.type == .importantAmbiguity || event.type == .nameMention {
                activeEvent = event
                haptic(event.type == .nameMention ? .success : .warning)
            }
        }
    }

    private func inferEmphasis(_ text: String) -> SegmentEmphasis? {
        let lower = text.lowercased()
        let names = ([userName] + nicknames).filter { !$0.isEmpty }
        if names.contains(where: { lower.contains($0.lowercased()) }) { return .nameMention }
        if text.hasSuffix("?") || ["who", "what", "when", "where", "why", "how", "can", "could", "would", "are", "is", "do", "did"].contains(where: { lower.hasPrefix($0 + " ") }) { return .question }
        if text.range(of: #"\b\d{1,2}(:\d{2})?\b"#, options: .regularExpression) != nil { return .importantDetail }
        return nil
    }

    private func startGuidedDemo(from index: Int = 0) {
        demoTask?.cancel()
        let beats = Self.demoBeats
        demoTask = Task { [weak self] in
            guard let self else { return }
            for beat in beats.dropFirst(index) {
                do {
                    try await Task.sleep(nanoseconds: beat.delayNanoseconds)
                    try Task.checkCancellation()
                } catch { return }
                guard self.status == .listening else { return }
                self.segments.append(beat.segment)
                if let event = beat.event {
                    self.addEvents([event])
                }
            }
        }
    }

    private func updateEvent(_ id: String, state: AttentionState) {
        guard let index = events.firstIndex(where: { $0.id == id }) else { return }
        events[index].state = state
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(1))
                guard let self else { return }
                if self.status == .listening { self.elapsedSeconds += 1 }
            }
        }
    }

    private func buildRecap() async {
        recapErrorMessage = nil
        if mode.capturesAudio {
            guard !segments.isEmpty else {
                recapTitle = sessionCaptionsEnabled ? "Quiet conversation" : "Listening assistance"
                recapItems = []
                return
            }

            do {
                let generated = try await MochiAPI.shared.generateRecap(
                    segments: segments,
                    repairs: repairs,
                    userName: userName,
                    durationSeconds: elapsedSeconds
                )
                let validIDs = Set(segments.map(\.id))
                recapTitle = generated.title
                recapItems = generated.items.compactMap { item in
                    let sources = item.sourceSegmentIDs.filter { validIDs.contains($0) }
                    guard !sources.isEmpty else { return nil }
                    return RecapItem(
                        id: "recap-\(UUID().uuidString)",
                        kind: item.kind,
                        text: item.text,
                        status: item.status,
                        owner: item.owner,
                        sourceSegmentIDs: sources,
                        confirmationID: nil
                    )
                }
                if recapItems.isEmpty { buildGroundedFallbackRecap() }
            } catch {
                recapErrorMessage = recapFailureMessage(for: error)
                buildGroundedFallbackRecap()
            }
            return
        }

        buildDemoRecap()
    }

    private func buildDemoRecap() {
        recapTitle = "Tuesday café planning"
        let timeSource = ["seg-time"]
        if let repair = repairs.last(where: { $0.eventID == "evt-time" }), let value = repair.resolvedValue {
            recapItems = [
                RecapItem(id: "recap-meeting", kind: .decision, text: "Meet Tuesday at \(value) at Central Café.", status: .confirmed, owner: nil, sourceSegmentIDs: timeSource + ["seg-cafe"], confirmationID: repair.id),
                RecapItem(id: "recap-folder", kind: .action, text: "Bring the blue folder.", status: .heard, owner: userName, sourceSegmentIDs: ["seg-folder"], confirmationID: nil)
            ]
        } else {
            recapItems = [
                RecapItem(id: "recap-folder", kind: .action, text: "Bring the blue folder.", status: .heard, owner: userName, sourceSegmentIDs: ["seg-folder"], confirmationID: nil),
                RecapItem(id: "recap-time", kind: .unresolved, text: "Confirm Tuesday's meeting time.", status: .unresolved, owner: nil, sourceSegmentIDs: timeSource, confirmationID: nil)
            ]
        }
    }

    private func buildGroundedFallbackRecap() {
        recapTitle = "Conversation at \(Date.now.formatted(date: .omitted, time: .shortened))"
        var items: [RecapItem] = []

        for event in events where event.state == .unresolved || event.type == .importantAmbiguity {
            items.append(
                RecapItem(
                    id: "fallback-unresolved-\(event.id)",
                    kind: .unresolved,
                    text: "Confirm: \(event.sourceQuote)",
                    status: .unresolved,
                    owner: nil,
                    sourceSegmentIDs: event.sourceSegmentIDs,
                    confirmationID: nil
                )
            )
        }

        for segment in segments.reversed() where items.count < 5 {
            guard !items.contains(where: { $0.sourceSegmentIDs.contains(segment.id) }) else { continue }
            items.append(
                RecapItem(
                    id: "fallback-detail-\(segment.id)",
                    kind: segment.emphasis == .question ? .unresolved : .detail,
                    text: segment.text,
                    status: segment.emphasis == .question ? .unresolved : .heard,
                    owner: nil,
                    sourceSegmentIDs: [segment.id],
                    confirmationID: nil
                )
            )
        }
        recapItems = items
    }

    private func recapFailureMessage(for error: Error) -> String {
        if let urlError = error as? URLError,
           [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut]
            .contains(urlError.code) {
            return "Mochi's API server is offline. Showing a transcript-grounded fallback."
        }
        return "GPT-5.6 recap unavailable: \(error.localizedDescription)"
    }

    private func refinementFailureMessage(for error: Error) -> String {
        if let urlError = error as? URLError,
           [.cannotConnectToHost, .cannotFindHost, .networkConnectionLost, .notConnectedToInternet, .timedOut]
            .contains(urlError.code) {
            return "Accuracy pass paused because Mochi's API server is offline. Your live transcript is still saved."
        }
        return "Accuracy pass unavailable: \(error.localizedDescription) Your live transcript is still saved."
    }

    private func reloadSavedConversations() {
        do {
            savedConversations = try archive.load()
            libraryErrorMessage = nil
        } catch {
            savedConversations = []
            libraryErrorMessage = "Your recordings library could not be loaded."
        }
    }

    private func archiveCurrentConversationIfNeeded() {
        guard mode.capturesAudio,
              let recordingURL,
              let currentConversationID else { return }

        let conversation = SavedConversation(
            id: currentConversationID,
            createdAt: sessionStartedAt,
            title: recapTitle,
            durationSeconds: elapsedSeconds,
            recordingFileName: recordingURL.lastPathComponent,
            segments: segments,
            events: events,
            repairs: repairs,
            recapItems: recapItems,
            recapErrorMessage: recapErrorMessage,
            captionEngine: sessionCaptionEngine,
            provisionalSegments: provisionalSegments.isEmpty ? nil : provisionalSegments,
            transcriptRefinedAt: transcriptRefinedAt,
            transcriptRefinementErrorMessage: transcriptRefinementErrorMessage
        )

        do {
            savedConversations = try archive.upsert(conversation, in: savedConversations)
            libraryErrorMessage = nil
            speechService.releaseArchivedSession()
        } catch {
            libraryErrorMessage = "This conversation is open, but it could not be added to your recordings library."
        }
    }

    private func resetSession() {
        demoTask?.cancel()
        clockTask?.cancel()
        playbackService.stop()
        speechService.discardSession()
        status = .ready
        segments = []
        events = []
        repairs = []
        recapItems = []
        recapTitle = "Conversation recap"
        recordingURL = nil
        isGeneratingRecap = false
        recapErrorMessage = nil
        sessionCaptionEngine = nil
        sessionCaptionsEnabled = true
        sessionVoiceLiftEnabled = false
        catchUpBrief = nil
        isGeneratingCatchUp = false
        catchUpErrorMessage = nil
        catchUpSegmentCount = 0
        provisionalSegments = []
        isRefiningTranscript = false
        transcriptRefinedAt = nil
        transcriptRefinementErrorMessage = nil
        activeEvent = nil
        elapsedSeconds = 0
        showRepair = false
        showSpeakerCard = false
        showCatchUp = false
        showEvidence = false
        currentConversationID = nil
        speakerAliases = [:]
    }

    private func replacingSpeaker(in segment: TranscriptSegment, displayName: String) -> TranscriptSegment {
        var namedSpeaker = segment.speaker
        namedSpeaker.displayName = displayName
        return TranscriptSegment(
            id: segment.id,
            speaker: namedSpeaker,
            startSeconds: segment.startSeconds,
            text: segment.text,
            isFinal: segment.isFinal,
            emphasis: segment.emphasis
        )
    }

    private func haptic(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        guard hapticsEnabled else { return }
        UINotificationFeedbackGenerator().notificationOccurred(type)
    }

    static let demoBeats: [GuidedDemoBeat] = [
        GuidedDemoBeat(
            delayNanoseconds: 650_000_000,
            segment: TranscriptSegment(id: "seg-opening", speaker: .leo, startSeconds: 2, text: "Okay, let's make sure Tuesday still works for everyone.", isFinal: true),
            event: nil
        ),
        GuidedDemoBeat(
            delayNanoseconds: 1_050_000_000,
            segment: TranscriptSegment(id: "seg-folder", speaker: .maya, startSeconds: 5, text: "James, can you bring the blue folder?", isFinal: true, emphasis: .nameMention),
            event: AttentionEvent(id: "evt-name", type: .nameMention, sourceSegmentIDs: ["seg-folder"], title: "Maya mentioned you", explanation: "You may need to respond.", sourceQuote: "James, can you bring the blue folder?", detailType: "name", candidates: [], clarificationPrompt: "Could you say that again for me?", state: .new)
        ),
        GuidedDemoBeat(
            delayNanoseconds: 1_300_000_000,
            segment: TranscriptSegment(id: "seg-cafe", speaker: .leo, startSeconds: 9, text: "Are we still meeting at Central Café?", isFinal: true, emphasis: .question),
            event: AttentionEvent(id: "evt-question", type: .directQuestion, sourceSegmentIDs: ["seg-cafe"], title: "Question in the conversation", explanation: "Leo asked whether the location is still Central Café.", sourceQuote: "Are we still meeting at Central Café?", detailType: "location", candidates: [], clarificationPrompt: "Are we still meeting at Central Café?", state: .new)
        ),
        GuidedDemoBeat(
            delayNanoseconds: 1_500_000_000,
            segment: TranscriptSegment(id: "seg-time", speaker: .maya, startSeconds: 13, text: "Yes—Tuesday at five… fifty, by the front window.", isFinal: true, emphasis: .importantDetail),
            event: AttentionEvent(id: "evt-time", type: .importantAmbiguity, sourceSegmentIDs: ["seg-time"], title: "Check the meeting time", explanation: "The rolling caption changed between two important times.", sourceQuote: "Tuesday at five… fifty", detailType: "time", candidates: ["5:15 PM", "5:50 PM"], clarificationPrompt: "Sorry—did you say 5:15 or 5:50?", state: .new)
        )
    ]
}
