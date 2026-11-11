# Deenflow
An open-source, gamified Islamic habit tracker, interactive quiz engine, and offline-first Fiqh library built with Flutter and Supabase.
# 🌙 DeenFlow 

**DeenFlow** is a premium, cross-platform Flutter application designed to help Muslims build consistent spiritual habits. It combines a classical Islamic library with modern gamification, allowing users to earn rewards for reading the Quran, learning Fiqh, and completing daily prayers.

## ✨ Core Features

* **Gamified Habit Tracker:** Earn points and unlock badge tiers (Seeker, Scholar, Guardian, Pioneer) by logging daily prayers and Quran reading.
* **Serverless Cloud Library:** A dynamic, offline-first PDF reader. Books are streamed from this GitHub repository's JSON API, downloaded locally, and feature automatic page-bookmarking.
* **Interactive Quiz Engine:** Test your knowledge on Seerah, Fiqh, and Islamic History with a dynamic quiz module that rewards correct answers with profile points.
* **Secure Privacy (Supabase):** Built with Row Level Security (RLS) to ensure that every user's progress, points, and profile data remain 100% private and secure.

## 🛠️ Technical Stack

* **Frontend:** Flutter & Dart
* **Backend & Auth:** Supabase (PostgreSQL, Google One-Tap Sign-In)
* **Storage APIs:** GitHub Raw JSON (For free, instant content updates without App Store approvals)
* **Local Caching:** `shared_preferences` and `path_provider` (For offline reading and zero-latency point tracking)

## 📡 The JSON APIs

This repository acts as the live content delivery network (CDN) for the DeenFlow app. 
* `library_api.json`: Contains the categorized catalog of free public-domain Islamic PDFs.
* `quiz_data.json`: Contains the dynamic multiple-choice questions for the Gamification engine.

## Tasawwuf, Tazkiyah & Ihsan

A new source-linked learning section provides a 12-week path, 24 lessons and knowledge checks, 9 book entries, 20 glossary terms, and a Flutter screen with local study progress.

- [Learning content API](tasawwuf_api.json)
- [Flutter section](lib/tasawwuf_screen.dart)
- [Learning path, book catalog and app integration guide](docs/tasawwuf.md)

The host app still needs to add a navigation entry and dependencies. See the guide for offline assets, content status and verification limits. Complete Arabic source texts and a historical English scan/OCR are included in [the book folder](books/tasawwuf/README.md), alongside an Urdu hosted-reader link. Modern translations remain external publisher references.
