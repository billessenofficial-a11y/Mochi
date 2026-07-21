# Product decisions made during implementation

## Native iOS replaces the PWA assumption

The PRD's PWA stack was an implementation assumption, not part of the core user promise. The requested product is now a native SwiftUI app. Native development improves haptics, speech permission handling, Dynamic Type, VoiceOver behavior, and the speaker-facing experience.

## Guided demo is honest and first-class

The original PRD asked for a seeded fallback while live mode remained the default. For a three-minute judged demo, guided demo is directly available from the home screen and unmistakably labeled **Simulated conversation** throughout. It exercises the same models and state machine as live mode, so it demonstrates product behavior without claiming the authored ambiguity came from real acoustic inference.

## Live diarization labels speakers without claiming identity

FluidAudio's streaming Sortformer separates up to four acoustic speaker slots on-device. Mochi exposes those slots as `Speaker 1`, `Speaker 2`, and so on; it does not turn them into names without an explicit enrollment flow. This provides useful turn separation without fabricating identity.

## Captioning is switchable; FluidAudio owns diarization

Mochi defaults to `gpt-realtime-whisper` for the lowest-latency multilingual captions and manually commits speech chunks over a direct Realtime WebSocket. The language hint is intentionally omitted so English/Tagalog code-switching is not forced through an English-only decoder. The app receives only a ten-minute client secret from its backend, never the permanent API key. Users can switch to WhisperKit at any time; its multilingual OpenAI Whisper `base` model downloads during onboarding and detects language per utterance so private, offline captioning remains available. If Realtime setup fails before capture, Mochi automatically falls back to Whisper. FluidAudio runs Sortformer on-device using CPU plus Neural Engine for speaker separation in either mode. One AVAudioEngine tap feeds recording, the selected caption engine, and diarization so their timestamps share the same clock.

## Importance and uncertainty remain separate

The local analyzer may highlight a clear time or amount as important, but it never creates competing candidates from text alone. Candidate repair choices appear only when supplied by documented revision evidence in the guided scenario. With one interpretation, the prompt asks for repetition.

## Saved Realtime transcripts receive one authoritative accuracy pass

Low latency and durable accuracy are different jobs. Realtime captions remain visible immediately, then Mochi compresses the completed recording and sends it to `gpt-4o-transcribe-diarize`. Its unified speaker turns and timestamps replace the provisional transcript before GPT-5.6 creates the final recap; the original live segments remain archived as an audit trail. This is less fragile than combining a separate cloud transcript with locally segmented speaker turns. On-device Whisper sessions do not upload audio automatically and expose an explicit opt-in refinement action instead.

## OpenAI credentials stay behind a server boundary

The iOS app never contains the permanent key. A small Node server generates recaps with GPT-5.6 strict structured output, mints short-lived Realtime client secrets, and relays only the temporary compressed recording used for an explicitly disclosed accuracy pass. It does not persist uploaded audio. Recap source IDs are validated again before display. Runtime API use is a product choice, not a hackathon eligibility requirement, and users can select local Whisper when the API project has no available quota.

## Evaluation claims stay modest

The UI says this is an accessibility aid and asks users to confirm high-stakes details. It does not claim clinical accuracy or DHH-user validation that has not happened.

## Recording retention is explicit and limited

Mochi records each active session to a local CAF file so users can replay the complete conversation or jump to evidence behind a recap or chat answer. Audio, transcripts, repairs, and recaps persist in an on-device library until individually deleted. The consent screen discloses both cloud transcript processing and local retention before capture starts.
