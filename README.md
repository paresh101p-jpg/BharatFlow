# BharatFlow: Smart Mandi Intelligence Suite

BharatFlow is a premium, AI-powered citizen utility super-app designed for the modern Indian agricultural ecosystem. Built with a high-fidelity Emerald-toned design system, it provides real-time market intelligence, logistics optimization, and financial management tools for farmers and traders.

## ✨ Key Features

- **Mandi Intelligence**: Real-time prices, arrival predictions, and market sentiment analysis powered by Supabase.
- **Logistics & Routing**: Multi-modal transport booking and toll-aware route optimization.
- **Digital Khata**: A comprehensive ledger for tracking sales, expenses, and payments with local caching.
- **Bharat Brand Store**: Direct access to government-certified agricultural products.
- **Agri Map**: Interactive topographic maps for crop comparison and mandi proximity.
- **Market News**: Curated agricultural news with impact analysis.

## 🛠️ Tech Stack

- **Framework**: Flutter
- **State Management**: Riverpod (Provider-based architecture)
- **Backend**: Supabase (PostgreSQL, Auth, Functions)
- **Local Storage**: Hive (Offline-first caching)
- **Styling**: Custom Glassmorphic Design System (Emerald Theme)

## 🚀 Getting Started

1. **Clone the repository**
2. **Setup Supabase**: Run the SQL schema provided in the documentation.
3. **Configure .env**: Add your Supabase URL and Anon Key.
4. **Run the app**:
   ```bash
   flutter run
   ```

## 📐 Architecture

The project follows a clean, feature-first modular architecture:
- `lib/core`: Theme, global utilities, and design tokens.
- `lib/features`: Independent modules (Dashboard, Mandi, Khata, etc.) with their own data and presentation layers.
