# QuoteBuilder

Simple Flutter app to build and manage product/service quotes locally.

## Quick overview

- Purpose: allow entering client details and line items, compute totals (tax inclusive/exclusive), save drafts locally, load/edit/delete drafts, and generate/print a PDF preview.
- Platform: Flutter (mobile, desktop, web).

## Prerequisites

- Install Flutter (stable) and the platform SDKs you need (Android/iOS/Windows/Linux/macOS). See https://flutter.dev for installation steps.
- A recent Dart/Flutter toolchain (tested with Flutter SDK active in PATH).

## Setup

1. From the project root run:

```bash
flutter pub get
```

2. Run the app (choose a device/emulator or use web):

```bash
flutter run
```

## Features

- Enter client information: name, reference/PO, address.
- Add line items with quantity, rate, discount and tax %.
- Toggle Tax Mode: Tax Exclusive or Tax Inclusive.
- Choose currency symbol for display.
- Save drafts locally (SharedPreferences). Drafts include all fields and line item data.
- Load/Edit/Delete saved drafts via the Draft Manager.
- Generate and print a simple PDF of the quote.

## Where to edit

- Main UI & logic: `lib/screens/quote_builder_page.dart`
- Shared UI helpers: `lib/widgets/form_helpers.dart`
- Line item model: `lib/models/line_item.dart`
- Small action widgets: `lib/screens/save_draft_button.dart`, `lib/screens/load_draft_button.dart`, etc.
