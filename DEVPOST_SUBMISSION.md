# Mochi — Devpost Submission Copy

## Elevator pitch

**Mochi helps people who are hard of hearing stay in the conversation with live captions, Voice Lift, timely cues, and AI-powered catch-up.**

**Brand slogan:** Stay in the conversation.

## Short project description

Mochi is an iPhone and Apple Watch conversation companion for people who are hard of hearing. It combines multilingual live captions, speaker-aware cues, name-mention alerts, Voice Lift, AI catch-up, and evidence-linked recaps so users can follow what is happening now and confidently revisit what they missed later.

## Category

**Apps for Your Life**

## Project story

## Inspiration

My hearing is not always reliable, and I know the feeling of being physically present in a conversation while still missing the part that matters: a name, a question directed at me, a time, or the one sentence everyone else understood.

Traditional captions help recover words, but conversation is more than a wall of text. When captions move quickly, I still have to work out who spoke, whether someone needs my response, which detail changed, and what I should remember afterward. That cognitive load inspired Mochi.

I named the app after my white cat, Mochi. I wanted the experience to feel calm and companionable—not clinical—while still treating accessibility, privacy, and accuracy seriously.

## What it does

Mochi helps before, during, and after a conversation:

- **Live multilingual captions** use OpenAI Realtime for low latency, with an on-device WhisperKit fallback.
- **On-device speaker diarization** separates voices into stable speaker slots that the user can name during or after a session.
- **Attention cues** highlight direct questions, important details, and mentions of the user's name or nicknames. A paired Apple Watch can mirror the latest caption and tap the user's wrist when their name is detected while the Watch app is active.
- **Catch Me Up** uses GPT-5.6 to identify what currently needs the user's attention: requests, open questions, decisions, actions, and recent context.
- **Conversation recap** turns the completed session into a simpler list of what matters, with a searchable transcript, local audio playback, speaker editing, and chat with the recording.
- **Evidence links** connect AI-generated items back to real transcript segment IDs and playable timestamps instead of presenting unsupported summaries as fact.
- **Voice Lift** is an optional, conservative listening-assistance prototype for connected headphones. It is clearly presented as an accessibility convenience, not a hearing aid or medical treatment.

The iPhone remains responsible for microphone capture, recording consent, transcription, and local storage. The Apple Watch receives only compact conversation state—never raw audio.

## How I built it

Mochi is a native SwiftUI app for iPhone and Apple Watch.

The audio pipeline records the conversation locally while feeding a selectable caption engine. OpenAI Realtime provides low-latency streaming captions, while WhisperKit provides a multilingual on-device fallback. FluidAudio's Sortformer diarization runs locally to separate speakers without claiming to identify them biometrically. After a recording ends, a speaker-aware transcription pass can rebuild the transcript from the full audio for higher accuracy while preserving the live version as an audit trail.

GPT-5.6 powers Mochi's semantic layer. It creates structured Catch Me Up briefs and recaps, and answers questions about saved recordings. Each response must cite transcript segment IDs that actually exist; the server and client reject invalid evidence references. If the cloud request fails, Mochi keeps the recording and transcript and shows a clearly labeled local fallback.

The permanent OpenAI API key stays on a small Node.js server. The server mints short-lived Realtime credentials and handles GPT-5.6, recording chat, and completed-audio requests. No permanent API key is embedded in the app.

I built Mochi in Codex with GPT-5.6. Codex helped me turn a product brief into a native architecture, implement and refactor the SwiftUI flows, integrate the audio and AI pipelines, generate tests, inspect simulator output, diagnose microphone and concurrency crashes from logs, add the watchOS target, and repeatedly tighten the interface. I made the core human decisions: who the product serves, which moments should interrupt the user, what must stay verifiable, where consent belongs, and which medical or biometric claims the app must not make.

## Challenges I ran into

### Latency versus accuracy

The fastest live transcript is not always the best final transcript. Mochi therefore treats live captions as the immediate experience and the completed recording as a chance to run a more accurate speaker-aware pass. Preserving both versions was important so refinement never silently rewrites the evidence.

### Running several audio features together

Recording, streaming captions, on-device diarization, microphone-level feedback, and Voice Lift all need the same microphone without fighting over the audio session. I had to design a single audio graph with separate clean recording/caption and headphone-monitor branches, then handle simulator and physical-device behavior differently.

### Grounding AI output

A fluent recap is not enough for an accessibility product. GPT-5.6 responses use strict structured output and must reference real transcript IDs. This lets the interface take the user from a summary back to the exact caption and recording timestamp.

### Designing for trust

Diarization separates voices but does not know who people are. Mochi begins with labels such as Speaker 1 and lets the user assign names. Likewise, uncertain details are marked for confirmation instead of being silently “fixed.”

### Apple Watch concurrency

The Watch companion exposed a Swift 6 actor-isolation crash because a Watch Connectivity reply arrived on a utility queue. Codex helped trace the crash report to the exact callback, replace the unsafe path with delegate-driven state updates, and verify the paired iPhone–Watch build in simulators.

## Accomplishments I am proud of

- Mochi is a working end-to-end native app rather than a caption mockup.
- A user can listen, receive a name or question cue, catch up, confirm an ambiguous detail, end the session, replay the audio, inspect the full transcript, search saved recordings, and chat with the result.
- The live experience still works when GPT is unavailable because recording, local captions, and conservative local cues have fallback paths.
- AI summaries remain connected to evidence instead of becoming an untraceable second version of the conversation.
- The same design language now works across iPhone and Apple Watch.

## What I learned

I learned that accessibility is not simply an accuracy benchmark. Timing, cognitive load, source visibility, consent, and recovery from failure matter just as much as the transcript itself.

I also learned that the best role for GPT-5.6 here is not to replace the conversation or pretend certainty. It is to organize attention: identify what may need a response, compress what was missed, and make a long recording useful—while staying grounded in evidence the user can check.

Most importantly, building Mochi reinforced that tools for people who are hard of hearing should be shaped with those users, not merely built for them. A next step is compensated testing with a broader group of Deaf and hard-of-hearing participants to tune alert frequency, wording, latency, and social comfort.

## What's next

- Test with Deaf and hard-of-hearing participants across noisy real-world settings.
- Profile latency, battery use, and speaker diarization on more physical iPhones and Watches.
- Add optional background Watch notifications for name mentions with user-controlled frequency.
- Improve code-switching and domain vocabulary without weakening multilingual detection.
- Explore user-controlled sharing and export while keeping recordings private by default.

## Built with

Suggested tags (18 of 25 maximum):

1. OpenAI
2. GPT-5.6
3. Codex
4. OpenAI Realtime API
5. OpenAI Audio API
6. Swift
7. SwiftUI
8. iOS
9. watchOS
10. Apple Watch
11. WatchConnectivity
12. WhisperKit
13. FluidAudio
14. Core ML
15. AVFoundation
16. HealthKit
17. Node.js
18. XcodeGen
