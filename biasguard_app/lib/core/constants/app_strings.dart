// BiasGuard — App-wide string constants

class AppStrings {
  // App
  static const appName = 'BiasGuard';
  static const appTagline = 'FairAI for Every Decision';
  static const appVersion = 'v1.0.0';
  static const madeIn = 'Made in Patna, Bihar, India';

  // Auth
  static const signIn = 'Sign In';
  static const signInWithGoogle = 'Continue with Google';
  static const email = 'Email address';
  static const password = 'Password';
  static const forgotPassword = 'Forgot password?';
  static const signOut = 'Sign Out';

  // Modes
  static const auditMode = 'Audit Mode';
  static const directMode = 'Direct Mode';

  // Upload
  static const uploadTitle = 'Upload CSV Dataset';
  static const uploadSubtitle = 'Detect and fix AI bias in minutes';
  static const dragDrop = 'Drag & drop your CSV here';
  static const browseFiles = 'Browse Files';
  static const useDemoDataset = 'Use Demo Dataset';
  static const uploadFormat = 'Supports: .csv up to 10MB';

  // Processing
  static const processingStep1 = 'Parsing CSV columns';
  static const processingStep2 = 'Calculating fairness metrics';
  static const processingStep3 = 'Gemini AI analysis';
  static const processingStep4 = 'Generating report';
  static const processingNote = 'First scan takes ~15 seconds';

  // Results
  static const equityScore = 'Equity Score';
  static const criticalBias = 'CRITICAL BIAS';
  static const moderateBias = 'MODERATE BIAS';
  static const fair = 'FAIR';
  static const fixBias = 'Fix Bias — Apply Mitigation';
  static const downloadReport = 'Download Report';
  static const proxyFeatures = 'Detected Proxy Features';
  static const aiAnalysis = 'AI Analysis';

  // Metrics
  static const demographicParity = 'Demographic Parity';
  static const equalOpportunity = 'Equal Opportunity';
  static const equalizedOdds = 'Equalized Odds';
  static const predictiveParity = 'Predictive Parity';

  // Direct Mode
  static const directTitle = 'Direct Fair Decision';
  static const directSubtitle = 'Get an unbiased AI recommendation for any decision scenario';
  static const useCaseType = 'Use Case Type';
  static const describeScenario = 'Describe the scenario';
  static const getFairDecision = 'Get Fair Decision';
  static const recommendation = 'Recommendation';
  static const factorsConsidered = 'Factors Considered';
  static const factorsIgnored = 'Factors Explicitly Ignored';
  static const whatIfScenarios = 'What-If Scenarios';

  // Navigation
  static const dashboard = 'Dashboard';
  static const history = 'Audit History';
  static const settings = 'Settings';
  static const profile = 'Profile';
  static const about = 'About';

  // Errors
  static const errorGeneric = 'Something went wrong. Please try again.';
  static const errorNoFile = 'Please select a CSV file first.';
  static const errorUpload = 'Upload failed. Check your connection.';

  // Use Case Types
  static const useCaseTypes = [
    'Scholarship Application',
    'Loan Application',
    'Job Hiring',
    'University Admission',
    'Healthcare Allocation',
    'Housing Application',
    'General Decision',
  ];
}
