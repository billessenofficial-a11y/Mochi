# Mochi

> Temporary private TestFlight configuration: local archives embed the ignored
> `OPENAI_API_KEY` from `.env.local` into the signed app so Mochi can call OpenAI
> without a hosted backend. This is intentionally not the production security
> model; rotate the key after testing and restore the server before public release.

**Hear the moment. Keep the memory.**

Mochi is a native iOS conversation-accessibility app for Deaf and hard-of-hearing people. It adds a semantic repair layer above live captions: questions and important moments stand out, consequential ambiguity can be clarified with one tap, and confirmed details flow into a source-linked recap without rewriting the original transcript.

This repository is an OpenAI Build Week submission in **Apps for Your Life**.

## What works

- Native SwiftUI interface with Dynamic Type-aware captions, high contrast, dark mode, VoiceOver labels, large controls, and visual-plus-haptic alerts.
- Switchable multilingual caption engines: lowest-latency OpenAI Realtime transcription or private, offline WhisperKit with OpenAI Whisper `base`.
- A post-recording `gpt-4o-transcribe-diarize` accuracy pass that rebuilds Realtime transcripts from the full audio with speaker-aware timestamps while retaining the live transcript as an audit trail.
- On-device Sortformer speaker diarization with stable `Speaker 1`–`Speaker 4` labels.
- Live and post-recording speaker naming; names persist into search, recap evidence, and recording chat.
- A dedicated Assist tab where live captions and Voice Lift can run independently or together; Voice Lift supports connected wired, USB, or Bluetooth headphones with conservative speech EQ, dynamics limiting, and three capped lift levels.
- Optional read-only Apple Health audiogram lookup. Mochi never converts audiogram thresholds into an unvalidated hearing-aid fitting.
- A real local session recording with full playback, seeking, and evidence playback from each caption timestamp.
- A persistent on-device recordings library with local full-library search across titles, transcripts, speakers, recaps, and corrections.
- A searchable full-transcript view with every speaker turn and tap-to-play timestamps.
- Conservative local detection for name mentions, direct questions, times, and amounts.
- Clearly labeled offline guided demo with three speakers and a complete `5:15` versus `5:50` repair loop.
- Speaker-facing large-text clarification card.
- Confirmation annotations that preserve the original caption.
- Priority-based GPT-5.6 catch-up brief for requests directed at the user, open questions, decisions, actions, and recent context, with a grounded on-device fallback and transcript links.
- A GPT-5.6 structured recap generated from the real transcript, with Confirmed, Heard, and Unresolved states plus source-linked audio evidence.
- An Apple Watch companion that mirrors the latest caption, taps the wrist for name mentions, shows Catch Me Up, and controls pause/end while the iPhone owns capture and consent.
- Explicit consent, local recording retention, deletion controls, and product limitations.

## Run it

Requirements:

- Xcode 26 or later
- iOS 18 or later
- watchOS 11 or later for the optional Watch companion
- XcodeGen (`brew install xcodegen`) if regenerating the project
- Node.js 20 or later
- An OpenAI API project with available quota for Realtime captions, GPT-5.6 recaps, and recording chat

For this temporary private TestFlight build, add the API key to a workspace-local
`.env.local` file (it is gitignored):

```sh
printf 'OPENAI_API_KEY=%s\n' 'your-key' > .env.local
```

In another terminal:

```sh
xcodegen generate
open ClearCue.xcodeproj
```

Select an iPhone and run the `ClearCue` scheme. The build phase copies the key into
the signed app bundle, so this private build can use Realtime captions, GPT-5.6,
and post-recording diarized transcription without running the Node server.
First-run onboarding downloads multilingual Whisper before Home is available,
then Mochi warms Core ML in the background before its hearing actions become
available; recording never initiates a model download. Physical iPhones use
`base` with Neural Engine acceleration. Simulator builds use `tiny` because
Simulator has no Neural Engine and can stall while specializing the larger model.
If `.env.local` is absent, the existing `ClearCueAPIBaseURL` server path remains
available as the production-oriented fallback.

The `MochiWatch` scheme installs the companion on a paired Apple Watch. Install Apple’s watchOS platform from Xcode Settings → Components before using a Watch simulator. Launch the iPhone app once so Watch Connectivity can activate. The Watch intentionally does not open the microphone or bypass consent: it requests a session, then asks the user to confirm recording on iPhone. Apple requires a physical paired iPhone and Watch for final Watch Connectivity and wrist-haptic validation.

Mochi defaults to Realtime captions for the lowest latency. Preferences can switch back to the downloaded on-device Whisper model at any time, and a failed Realtime connection falls back to Whisper before capture begins. Recording, playback, search, and Whisper captions do not require API quota. If a GPT recap receives HTTP 429, Mochi keeps the real transcript and recording and shows a labeled transcript-grounded fallback recap. Realtime captions and recording chat require available API quota.

Run tests from Xcode or with:

```sh
xcodebuild test -project ClearCue.xcodeproj -scheme ClearCue -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=26.5'
```

The temporary private TestFlight archive embeds the API key. Anyone who can obtain
and inspect that app can recover it. Rotate the key after judging and restore the
server boundary before any public distribution.

## Architecture

```text
microphone
  ├─ local CAF recording ───────────────► playback/evidence
  ├─ caption engine switch
  │    ├─ OpenAI Realtime WebSocket ────► lowest-latency partials/finals
  │    └─ WhisperKit + Whisper base ────► private multilingual partials/finals
  └─ FluidAudio Sortformer (on-device) ─► speaker slots
                         │
                         ▼
  TranscriptSegment[] ──────► immutable evidence
           │
           ▼
 LocalSemanticAnalyzer ─────► AttentionEvent[]
           │
           ├──────── Watch Connectivity ─────► caption glance / name haptic / controls
           │
           ▼
  user clarification ───────► RepairAnnotation
           │                         │
           └──────────┬──────────────┘
                      ▼
      OpenAI diarized audio pass ──────► corrected speaker turns/timestamps
      GPT-5.6 structured output ────────► source-linked recap
```

The guided demo and live mode use the same transcript, attention, repair, and recap state machine. Guided demo is deliberately labeled and never presented as live model output. One microphone tap records locally and feeds a user-selected caption engine plus FluidAudio. Realtime mode sends 24 kHz PCM through a direct WebSocket authenticated by a short-lived client secret; the permanent key never enters the app. Its optional language hint is omitted so the model can infer language during English/Tagalog code-switching. Whisper mode uses the multilingual `base` model with per-utterance language detection. FluidAudio runs Sortformer locally on the ANE-efficient Core ML path in either mode. Labels begin as `Speaker 1`, `Speaker 2`, and so on because diarization separates voices but does not identify people; the user can assign names live or afterward without claiming biometric speaker identification.

The Watch companion receives a compact, replaceable current-state snapshot through Watch Connectivity and immediate messages while both apps are reachable. It advances the session timer locally instead of sending a message every second. Name mentions use the Watch notification haptic only while the companion is active; background wrist alerts require a separate notification capability and are not implied by this prototype.

The Assist tab treats Voice Lift and captions as complementary controls in one session: audio lift helps the user hear directly, while captions remain an optional visual safety net. Voice Lift uses a separate monitor branch in the audio graph: clean microphone audio continues to recording and, when enabled, captions and diarization while the headphone branch applies a low cut, a small speech-presence lift, capped user gain, and dynamics limiting. It refuses to start without an external output route to prevent speaker feedback. This is an assistive prototype, not a hearing aid, and Bluetooth latency varies by device. AirPods and compatible Beats users should prefer Apple's system Live Listen or Hearing Assistance features when available.

The intended production architecture keeps the permanent OpenAI key in the Node
server. For the private hackathon TestFlight requested here, a build phase instead
embeds the ignored local key and the iOS client directly mints a ten-minute Realtime
client secret, uploads completed audio to `gpt-4o-transcribe-diarize`, and calls
GPT-5.6 for recaps, catch-up, and recording chat. GPT-5.6 uses strict structured
output; both paths reject citations that do not match a real transcript segment.
If either cloud pass fails, Mochi retains the real recording and live transcript
with an explicit retry path.

## How Codex and GPT-5.6 were used

This project was built in Codex with GPT-5.6. The collaboration covered:

- Converting a web-first PRD into a native SwiftUI architecture.
- Ruthlessly narrowing scope to the complete alert → clarification → confirmation → evidence-linked recap loop.
- Designing a reliable guided demo that never impersonates live processing.
- Implementing the data model, interaction state machine, on-device WhisperKit path, local recording/playback, haptics, accessibility semantics, tests, and documentation.
- Challenging risky assumptions: no fabricated speaker identity, no invented ambiguity candidates, no medical/accessibility guarantees, and a documented temporary exception to the production no-client-key boundary for the private judging build.

Important human product decisions still require DHH-led research, including alert wording and frequency, speaker-facing etiquette, acceptable retention defaults, and whether the experience actually reduces cognitive or social load.

## Known limitations

- This is an accessibility prototype, not a medical device, interpreter, CART replacement, emergency service, hearing aid, or transcript-accuracy guarantee.
- Voice Lift has not yet completed calibrated acoustic-output, end-to-end latency, or DHH-participant validation across headphone models. Test it on a physical iPhone at low volume before any demo; Simulator cannot validate external-route DSP.
- Apple Health audiograms are displayed only as user-controlled context and are never sent to OpenAI or used to calculate gain.
- First-run onboarding downloads the WhisperKit fallback before Home is available. Sortformer assets prepare when a physical-device live session starts; a production release should add explicit Wi-Fi/download management for diarization too.
- Realtime captions require a network connection and API quota; builds without the temporary embedded key also require the backend. Whisper remains available for private/offline use; physical-device profiling should tune both engines' silence boundaries and confirmation window.
- Speaker diarization separates acoustic speakers but does not identify people automatically; names are user-assigned.
- Local semantic detection is intentionally conservative and does not infer acoustic uncertainty from text.
- The polished ambiguity candidates in guided demo come from authored transcript-revision evidence.
- The app has not yet completed the PRD's proposed compensated DHH-participant evaluation.
- Recordings, transcripts, repairs, and recaps persist in an on-device library until the user deletes them.
- Watch Connectivity and wrist haptics require final testing on a physical paired iPhone and Apple Watch; Apple’s simulators do not validate radio delivery or real haptic feel.

## Privacy

Capture starts only after an explicit user action and participant-notification acknowledgement. In Realtime mode, session audio is streamed to OpenAI for captions and the compressed completed recording receives one OpenAI speaker-aware accuracy pass. In Whisper mode, captioning and audio remain on-device unless the user explicitly taps “Improve transcript with OpenAI.” Transcript text and explicit repairs are sent for GPT-5.6 recaps and recording chat. Playable CAF recordings and transcript metadata are stored in the app's Application Support directory until the user deletes each conversation. The prototype does not add conversation content to analytics. Recording and consent laws vary by jurisdiction.

## Core source layout

- `ClearCue/App` — app entry and root routing
- `ClearCue/Models` — transcript, attention, repair, and recap evidence models
- `ClearCue/Services` — Realtime and WhisperKit transcription, FluidAudio diarization, recording/playback, API client, and conservative semantic analysis
- `Server` — permanent-key boundary, short-lived Realtime credentials, diarized full-recording transcription, grounded GPT-5.6 recap, and recording chat
- `ClearCue/Store` — session state machine and guided demo engine
- `ClearCue/Features` — home, consent, conversation, repair, catch-up, evidence, and recap views
- `MochiWatch` — glanceable watchOS companion and Watch Connectivity state model
- `ClearCueTests` — grounding, candidate-safety, and repair-provenance tests

## Hackathon submission reminder

Before submitting, add the primary Codex `/feedback` Session ID, a public under-three-minute YouTube demo, and a repository URL. If the repository remains private, share it with `testing@devpost.com` and `build-week-event@openai.com` before the deadline.
