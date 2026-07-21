# Mochi — demo script

Target runtime: **2:40–2:50**

## Before recording

- Start the Mochi API and confirm Realtime is available.
- Finish onboarding and clear old test recordings.
- Pair the Watch or prepare a short Watch insert.
- Use one short conversation with two clearly separated speakers.
- Record the narration separately if needed so every required point is audible.

## Script and screen direction

### 0:00–0:18 — The problem

**Screen:** Mochi's Assist screen, with the mascot centered.

**Say:**

> I don't have the best hearing. I can understand most of a conversation and still miss the one part that matters—my name, a question, or a time that changed. So I built Mochi, an iPhone app with an Apple Watch companion for people who are hard of hearing.

### 0:18–0:33 — Start listening

**Screen:** Briefly show the Live Captions and Voice Lift controls, then tap Mochi and accept the concise consent screen.

**Say:**

> Mochi combines multilingual live captions with optional Voice Lift for connected headphones. Capture begins only when I tap, and recordings stay on my device until I delete them.

### 0:33–0:58 — Live conversation and attention cue

**Screen:** Live captions. Have another person say the demo lines naturally.

**Demo speaker says:**

> James, can you bring the blue folder to Tuesday's meeting at five fifteen? Actually, let's make that five fifty.

**Screen:** Show separate speaker labels and the name-mention highlight. Briefly cut to the Watch receiving the caption and haptic cue.

**Say:**

> OpenAI Realtime captions the conversation while on-device diarization separates the speakers. When Mochi hears my name or a question for me, the moment is highlighted—and my Watch can tap my wrist—so the important part does not disappear into a wall of text.

### 0:58–1:18 — Catch Me Up

**Screen:** Tap **Catch me up** and show the concise brief with the request and changed time.

**Say:**

> If I lose the thread, Catch Me Up does more than repeat the last sentence. GPT-5.6 prioritizes what needs my attention: direct requests, open questions, decisions, actions, and recent context. Every item links back to the caption that supports it.

### 1:18–1:48 — Finish and verify

**Screen:** End the session. Show the generated title and simplified recap. Play a few seconds of the recording, open the full transcript, then tap an evidence link to seek to the supporting timestamp.

**Say:**

> Afterward, Mochi generates a useful title and a simple recap instead of another transcript dump. I can replay the audio, inspect or rename speakers, search recordings, and jump from an AI item to the exact moment supporting it. Unclear details stay unresolved instead of being silently invented.

### 1:48–2:07 — Chat with the recording

**Screen:** Ask: **“What do I need to bring, and when?”** Show the answer and its playable citations.

**Say:**

> I can also chat with the recording. GPT-5.6 answers only from this conversation and returns playable transcript citations. If the evidence is not there, Mochi is instructed to say so.

### 2:07–2:28 — How it was built

**Screen:** Quick architecture graphic or clean montage of iPhone, Watch, transcript, and recap.

**Say:**

> Mochi is native SwiftUI. OpenAI Realtime handles low-latency captions, WhisperKit provides an on-device multilingual fallback, FluidAudio separates speakers locally, and GPT-5.6 powers grounded catch-up, recaps, and recording chat using strict structured output.

### 2:28–2:50 — Codex and closing

**Screen:** End card with the Mochi logo and slogan.

**Say:**

> I built Mochi with Codex. It turned my brief into the iPhone and Watch architecture, helped implement the audio pipeline, traced microphone and concurrency crashes, built tests, and refined the experience. I made the human decisions about trust, consent, and what deserves the user's attention. Mochi helps people who are hard of hearing stay in the conversation—not just read what they missed.

## Recording notes

- Keep the final video under three minutes; aim for 2:50 to leave upload and edit margin.
- Show real interaction whenever possible. If a prepared scenario is used, label it clearly.
- Do not wait silently for model responses; tighten those pauses in the edit.
- Add captions to the video itself.
- Keep the cursor or touch indicator visible so judges can follow each action.
- End on the logo and the slogan: **Stay in the conversation.**
