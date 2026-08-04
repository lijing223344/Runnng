# Mini Hurdle Copy Polish Implementation Plan

Goal: Make the Chinese mini-hurdle spacing copy field-first while keeping professional details in supporting sections.

Files:
- Modify `Running/Resources/zh-Hans.lproj/Localizable.strings` only.

Steps:
1. Update hero/setup/result headings and subtitles to use shorter, field-oriented language.
2. Keep GT, Clark/Mann, progression, and quality-check content, but rename supporting sections to clearer coach-facing labels.
3. Validate the strings file remains parseable with `plutil -lint`.
