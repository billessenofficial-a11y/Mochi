# OpenAI Build Week — durable project brief

Source: OpenAI Build Week on Devpost, fetched July 20, 2026. The [live challenge page](https://openai.devpost.com/) and [Official Rules](https://openai.devpost.com/rules) remain authoritative. Re-check announcements and rules before submission.

## North star

Build a working project with Codex and GPT-5.6 that solves a real problem for a specific audience. The result should feel like a complete, coherent product—not a technical proof of concept—and should make the value of Codex/GPT-5.6 visible and necessary.

The host's central advice is to start with the problem, not the model. The strongest entry will demonstrate a real before/after outcome, not merely place a chat interface over an existing workflow.

## Categories (choose exactly one)

- **Apps for Your Life** — consumer apps for everyday life, including productivity, creativity, home, family, travel, health, and personal finance.
- **Work & Productivity** — tools that make teams faster or more effective, including workflow automation, support, analytics, sales, and back-office operations.
- **Developer Tools** — tools for developers, including testing, DevOps, agentic workflows, and security.
- **Education** — projects that advance AI for students, teachers, or educational organizations.

Each category awards one first place ($15,000) and one second place ($10,000). Total prize pool: $100,000.

Do not choose a category by perceived competitiveness alone. Pick the one in which the user, problem, workflow, demo, and impact claim fit most naturally.

## Judging

Stage 1 is pass/fail: the project must be viable, fit the theme, and reasonably apply the required technology.

Stage 2 uses four **equally weighted** criteria:

1. **Technological Implementation** — thorough and skillful Codex use; genuine effort; working, non-trivial implementation.
2. **Design** — runnable project with a complete, coherent product experience rather than only a proof of concept.
3. **Potential Impact** — credible, specific real problem and audience, with a demonstrated solution that actually addresses it.
4. **Quality of the Idea** — creativity, novelty, and meaningful differentiation from existing concepts.

Tie-break order follows the criteria above, so Technological Implementation is strategically important even though the base weights are equal.

### Practical win bar

- A judge understands the user, pain, and promise in the first 20–30 seconds.
- The demo shows a real end-to-end workflow with a visible outcome.
- GPT-5.6/Codex enables something difficult to reproduce with a shallow prompt wrapper.
- The core path is polished, reliable, and fast; secondary features do not weaken it.
- Claims are backed by the working demo, sample data, tests, or a measurable before/after.
- The repository tells a credible collaboration story: what Codex accelerated, what key product/engineering/design decisions humans made, and how GPT-5.6 affected the result.
- The idea has a crisp differentiation sentence: “Unlike ___, this ___.”

## Hard project rules

- The project must be built with Codex and GPT-5.6 and fit one category.
- It must install/run consistently on its intended platform and work as shown and described.
- A new project may be built during the submission period. A pre-existing project must be **meaningfully extended** during the submission period; only new work will be evaluated.
- For pre-existing work, clearly distinguish old from new and preserve evidence such as timestamped Codex sessions and dated commits.
- Third-party SDKs, APIs, data, trademarks, music, and copyrighted material require appropriate authorization/licensing.
- The submission must be original, owned by the entrant, and must not infringe third-party rights.
- Multiple submissions are permitted only when each is unique and substantially different.
- The project must remain free and accessible to judges through the judging period. Provide credentials for private test environments.
- Work remains the entrant's IP; submission grants the sponsor a non-exclusive judging license and promotional rights described in the Official Rules.

Official eligibility language relevant to this project:

> “Individuals who are at least the age of majority where they reside as of the time of entry”

> “Individuals who are residents of countries and territories that currently support access to OpenAI’s API services listed here and are not excluded below”

The Philippines appears in the included-country list returned by Devpost. Teams are optional; all occupations are allowed; a company is not required. Consult the full Official Rules for exclusions and conflicts of interest.

## Required submission package

- A working project.
- Exactly one category.
- A project description explaining what was created and how it works, edited into the team's own voice.
- A public or unlisted, viewable YouTube demo **under 3 minutes**. It must show the project working and include audio explaining:
  - what was built;
  - how Codex was used; and
  - how GPT-5.6 was used.
- A code repository URL. It may be public with appropriate licensing or private and shared before the deadline with:
  - `testing@devpost.com`
  - `build-week-event@openai.com`
- A README with setup/run instructions, sample data where needed, and a clear account of Codex/GPT-5.6 usage and key human decisions.
- The `/feedback` Codex Session ID for the primary thread in which most core functionality was built.
- If the entry is a plugin or developer tool: installation instructions, supported platforms, and a test path that does not require judges to rebuild from scratch (demo instance, sandbox, or test account).
- All teammates added to Devpost and invitations accepted before the deadline.
- Submission status must be **Submitted**, not Draft.

Devpost's current form also requires submitter type and country of residence. A website and zip file are not globally required, but judge access to a working project is required by the rules.

## Deadline and dates

- Submission deadline: **Tuesday, July 21, 2026 at 5:00 PM Pacific Time**.
- Equivalent in Manila: **Wednesday, July 22, 2026 at 8:00 AM PHT**.
- After the deadline, the hackathon submission cannot be substantively changed.
- Official Rules state judging runs July 22 through August 5, 2026 (Pacific Time), with winners announced on or around August 12 at 2:00 PM PT.

Note: Devpost's structured key-dates field currently shows a later judging end than the Official Rules. The Official Rules explicitly say they prevail over conflicting hackathon materials, so use the rules unless an official amendment is posted.

## Pre-submit failure checks

- [ ] The core workflow runs cleanly from a fresh setup.
- [ ] The demo link works in an incognito/private window and the video is under 3 minutes.
- [ ] The video audibly explains both Codex and GPT-5.6 usage.
- [ ] The repo is public with licensing or shared with both judging addresses.
- [ ] The README is accurate, includes setup/sample data, and documents the Codex collaboration story.
- [ ] The primary `/feedback` Session ID is recorded.
- [ ] New-vs-existing work is documented with timestamps/commits if applicable.
- [ ] Judges have a free, low-friction test route and any required credentials.
- [ ] All teammate invitations are accepted.
- [ ] One category is selected and the submission is not left in Draft.

## Decision rule for the rest of the build

For every proposed feature, ask:

1. Which judging criterion does this materially improve?
2. Will a judge see the improvement in the three-minute demo?
3. Does it strengthen the core user outcome or merely add surface area?
4. Can it be completed and verified without risking submission readiness?

If the answers are weak, defer the feature and improve reliability, differentiation, evidence, onboarding, or the demo instead.
