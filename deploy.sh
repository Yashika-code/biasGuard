#!/bin/bash
# BiasGuard — Member B Deployment Script
# Run this after Firebase project is set up.
# Usage: bash deploy.sh [--functions-only] [--rules-only] [--all]

set -e

echo "═══════════════════════════════════════════════════"
echo "  BiasGuard — Firebase Deployment Script"
echo "  Project: biasguard-2026"
echo "═══════════════════════════════════════════════════"

# Check Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI not found. Install: npm install -g firebase-tools"
    exit 1
fi

# Check logged in
echo "🔑 Checking Firebase login..."
firebase projects:list --json > /dev/null 2>&1 || {
    echo "❌ Not logged in. Run: firebase login"
    exit 1
}

# Set Gemini API key if not already set
echo ""
echo "🔐 Checking GEMINI_API_KEY secret..."
if ! firebase functions:secrets:access GEMINI_API_KEY > /dev/null 2>&1; then
    echo "⚠️  GEMINI_API_KEY secret not found."
    echo "   Get your key: https://aistudio.google.com/app/apikey"
    read -p "   Paste Gemini API key: " GEMINI_KEY
    echo "$GEMINI_KEY" | firebase functions:secrets:set GEMINI_API_KEY
    echo "✅ GEMINI_API_KEY set."
else
    echo "✅ GEMINI_API_KEY already set."
fi

# Parse args
DEPLOY_TARGET="${1:---all}"

if [[ "$DEPLOY_TARGET" == "--functions-only" ]]; then
    echo ""
    echo "🚀 Deploying Cloud Functions only..."
    firebase deploy --only functions --project biasguard-2026
    echo "✅ Functions deployed."

elif [[ "$DEPLOY_TARGET" == "--rules-only" ]]; then
    echo ""
    echo "🔒 Deploying Security Rules only..."
    firebase deploy --only firestore:rules,storage --project biasguard-2026
    echo "✅ Security rules deployed."

else
    # Deploy everything
    echo ""
    echo "🚀 Deploying ALL (Functions + Rules + Hosting)..."

    echo "  → Deploying Firestore + Storage rules..."
    firebase deploy --only firestore:rules,storage --project biasguard-2026

    echo "  → Deploying Cloud Functions..."
    firebase deploy --only functions --project biasguard-2026

    echo ""
    echo "📁 Uploading demo dataset to Storage..."
    gsutil cp assets/demo/bihar_scholarship_2026.csv \
        gs://biasguard-2026.appspot.com/demo/bihar_scholarship_2026.csv || \
        echo "⚠️  gsutil not found. Upload demo CSV manually via Firebase Console."

    gsutil cp assets/demo/loan_application_demo.csv \
        gs://biasguard-2026.appspot.com/demo/loan_application_demo.csv 2>/dev/null || true

    gsutil cp assets/demo/hiring_bias_demo.csv \
        gs://biasguard-2026.appspot.com/demo/hiring_bias_demo.csv 2>/dev/null || true

    gsutil cp assets/demo/healthcare_bias_demo.csv \
        gs://biasguard-2026.appspot.com/demo/healthcare_bias_demo.csv 2>/dev/null || true

    echo ""
    echo "═══════════════════════════════════════════════════"
    echo "  ✅ DEPLOYMENT COMPLETE"
    echo ""
    echo "  Cloud Function URLs:"
    echo "  CF1: https://us-central1-biasguard-2026.cloudfunctions.net/parseAndCalculateMetrics"
    echo "  CF2: https://us-central1-biasguard-2026.cloudfunctions.net/geminiAnalysisAndMitigation"
    echo "  CF3: https://us-central1-biasguard-2026.cloudfunctions.net/triggerMitigation"
    echo "  CF4: https://us-central1-biasguard-2026.cloudfunctions.net/getDirectFairDecision"
    echo ""
    echo "  Share these URLs with Member A!"
    echo "═══════════════════════════════════════════════════"
fi
