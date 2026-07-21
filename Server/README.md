# Mochi API

This tiny server keeps the permanent OpenAI API key out of the iOS app. It creates source-grounded GPT-5.6 recaps and recording-chat answers, and mints short-lived client secrets for the optional OpenAI Realtime caption engine. Mochi can switch back to fully on-device WhisperKit captions at any time.

```bash
npm --prefix Server start
```

The server reads `OPENAI_API_KEY` from the workspace `.env.local` and listens on port `8787` by default. The iOS Simulator uses `http://127.0.0.1:8787`. For a physical iPhone, set `MochiAPIBaseURL` to an HTTPS deployment or a reachable development-machine address.

When Realtime captions are selected, session microphone audio is sent directly from the app to OpenAI using a short-lived token. The permanent API key is never embedded in the app. Local recordings remain on the device.
