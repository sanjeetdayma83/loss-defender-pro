<#
  Loss Defender Pro — One-shot bootstrap (Windows PowerShell)

  Run from the folder where you downloaded the scaffold zip:
      powershell -ExecutionPolicy Bypass -File .\setup.ps1

  What it does, in order:
    1. Extracts loss-defender-pro-scaffold.zip (if project folder not already extracted)
    2. Checks Flutter / Node / git are on PATH
    3. Creates a Flutter app (android, ios, web, windows, macos, linux) under frontend/
    4. Adds required Flutter packages + writes the starter architecture (lib/core, lib/features/*)
    5. Installs backend npm deps + generates Prisma client
    6. git init + first commit
#>

param(
    [string]$ZipPath = "",
    [string]$ProjectDir = "loss-defender-pro"
)

$ErrorActionPreference = "Stop"

function Write-Step($msg) {
    Write-Host ""
    Write-Host "==> $msg" -ForegroundColor Cyan
}

# ---------- 1. Extract ----------
if (-not (Test-Path $ProjectDir)) {
    if ([string]::IsNullOrWhiteSpace($ZipPath)) {
        $found = Get-ChildItem -Filter "loss-defender-pro-scaffold*.zip" -File | Select-Object -First 1
        if (-not $found) {
            Write-Error "Could not find loss-defender-pro-scaffold*.zip in this folder. Pass -ZipPath 'C:\path\to\file.zip'."
            exit 1
        }
        $ZipPath = $found.FullName
    }
    Write-Step "Extracting $ZipPath -> $ProjectDir"
    Expand-Archive -Path $ZipPath -DestinationPath $ProjectDir -Force
} else {
    Write-Step "$ProjectDir already exists — skipping extraction"
}

Set-Location $ProjectDir

# ---------- 2. Prerequisites ----------
Write-Step "Checking prerequisites"
$flutterOk = Get-Command flutter -ErrorAction SilentlyContinue
$nodeOk    = Get-Command node -ErrorAction SilentlyContinue
$gitOk     = Get-Command git -ErrorAction SilentlyContinue

if (-not $flutterOk) {
    Write-Error "Flutter SDK not found on PATH. Install: https://docs.flutter.dev/get-started/install/windows then re-run this script."
    exit 1
}
if (-not $nodeOk) {
    Write-Error "Node.js not found on PATH. Install Node 20 LTS: https://nodejs.org then re-run this script."
    exit 1
}
if (-not $gitOk) {
    Write-Warning "git not found — will skip git init. Install git later and run 'git init' yourself."
}

flutter --version
node --version

# ---------- 3. Flutter project (all platforms) ----------
if (-not (Test-Path "frontend")) {
    Write-Step "Creating Flutter project: android, ios, web, windows, macos, linux"
    flutter create --platforms=android,ios,web,windows,macos,linux --org com.primecore.lossdefender --project-name loss_defender_pro frontend
} else {
    Write-Step "frontend/ already exists — skipping flutter create"
}

Set-Location frontend

Write-Step "Adding Flutter packages (dio, secure storage, go_router, riverpod, offline queue, camera/video)"
flutter pub add dio flutter_secure_storage go_router flutter_riverpod connectivity_plus sqflite path_provider camera video_player intl

Write-Step "Writing app architecture (lib/core + lib/features/*)"

New-Item -ItemType Directory -Force -Path "lib/core/network"                    | Out-Null
New-Item -ItemType Directory -Force -Path "lib/core/theme"                      | Out-Null
New-Item -ItemType Directory -Force -Path "lib/core/storage"                    | Out-Null
New-Item -ItemType Directory -Force -Path "lib/core/router"                     | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/auth/data"              | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/auth/presentation"      | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/dashboard/presentation" | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/orders/presentation"    | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/scanner/presentation"   | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/recording/presentation" | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/evidence/presentation"  | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/claims/presentation"    | Out-Null
New-Item -ItemType Directory -Force -Path "lib/features/returns/presentation"   | Out-Null

@'
import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

/// Central Dio instance. Base URL is injected at build/run time via
/// --dart-define=API_BASE_URL=... so the SAME build works against local
/// backend, staging, or ExCloud prod without code changes.
class ApiClient {
  ApiClient._internal() {
    _dio = Dio(
      BaseOptions(
        baseUrl: const String.fromEnvironment(
          'API_BASE_URL',
          defaultValue: 'http://10.0.2.2:3000/api/v1', // Android emulator -> host localhost
        ),
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 30),
      ),
    );

    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final token = await SecureStorage.instance.getAccessToken();
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          handler.next(options);
        },
        onError: (error, handler) async {
          // TODO: on 401, call /auth/refresh with the stored refresh token and retry once.
          handler.next(error);
        },
      ),
    );
  }

  static final ApiClient instance = ApiClient._internal();
  late final Dio _dio;

  Dio get dio => _dio;
}
'@ | Set-Content -Path "lib/core/network/api_client.dart" -Encoding UTF8

@'
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage — tokens never touch SharedPreferences or plain files.
class SecureStorage {
  SecureStorage._internal();
  static final SecureStorage instance = SecureStorage._internal();

  final _storage = const FlutterSecureStorage();

  static const _accessTokenKey = 'access_token';
  static const _refreshTokenKey = 'refresh_token';

  Future<void> saveTokens({required String accessToken, required String refreshToken}) async {
    await _storage.write(key: _accessTokenKey, value: accessToken);
    await _storage.write(key: _refreshTokenKey, value: refreshToken);
  }

  Future<String?> getAccessToken() => _storage.read(key: _accessTokenKey);
  Future<String?> getRefreshToken() => _storage.read(key: _refreshTokenKey);

  Future<void> clear() async {
    await _storage.delete(key: _accessTokenKey);
    await _storage.delete(key: _refreshTokenKey);
  }
}
'@ | Set-Content -Path "lib/core/storage/secure_storage.dart" -Encoding UTF8

@'
import 'package:flutter/material.dart';

/// Matches the brand palette from the approved UI screens (primary blue, clean whites).
class AppTheme {
  static const Color primaryBlue = Color(0xFF2563EB);
  static const Color darkNavy = Color(0xFF0F172A);
  static const Color successGreen = Color(0xFF16A34A);
  static const Color warningAmber = Color(0xFFF59E0B);
  static const Color dangerRed = Color(0xFFDC2626);

  static ThemeData get light => ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: primaryBlue),
        scaffoldBackgroundColor: const Color(0xFFF8FAFC),
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.white,
          foregroundColor: darkNavy,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryBlue,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
      );
}
'@ | Set-Content -Path "lib/core/theme/app_theme.dart" -Encoding UTF8

@'
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/auth/presentation/register_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/orders/presentation/orders_screen.dart';
import '../../features/scanner/presentation/scanner_screen.dart';
import '../../features/recording/presentation/recording_screen.dart';
import '../../features/evidence/presentation/evidence_screen.dart';
import '../../features/claims/presentation/claims_screen.dart';
import '../../features/returns/presentation/returns_screen.dart';

/// Screen list matches SRS section on Flutter Mobile/Desktop Screens.
final appRouter = GoRouter(
  initialLocation: '/login',
  routes: [
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    GoRoute(path: '/register', builder: (context, state) => const RegisterScreen()),
    GoRoute(path: '/dashboard', builder: (context, state) => const DashboardScreen()),
    GoRoute(path: '/orders', builder: (context, state) => const OrdersScreen()),
    GoRoute(path: '/scanner', builder: (context, state) => const ScannerScreen()),
    GoRoute(path: '/recording', builder: (context, state) => const RecordingScreen()),
    GoRoute(path: '/evidence', builder: (context, state) => const EvidenceScreen()),
    GoRoute(path: '/claims', builder: (context, state) => const ClaimsScreen()),
    GoRoute(path: '/returns', builder: (context, state) => const ReturnsScreen()),
  ],
);
'@ | Set-Content -Path "lib/core/router/app_router.dart" -Encoding UTF8

@'
import '../../../core/network/api_client.dart';
import '../../../core/storage/secure_storage.dart';

/// Talks to POST /auth/login and /auth/register exactly per the backend contract.
class AuthRepository {
  final _dio = ApiClient.instance.dio;

  Future<void> login({required String email, required String password, String? deviceId}) async {
    final response = await _dio.post('/auth/login', data: {
      'email': email,
      'password': password,
      if (deviceId != null) 'deviceId': deviceId,
    });
    final data = response.data['data'];
    await SecureStorage.instance.saveTokens(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
    );
  }

  Future<void> register({
    required String companyName,
    required String ownerName,
    required String email,
    required String password,
    required String phone,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'companyName': companyName,
      'ownerName': ownerName,
      'email': email,
      'password': password,
      'phone': phone,
    });
    final data = response.data['data'];
    await SecureStorage.instance.saveTokens(
      accessToken: data['accessToken'],
      refreshToken: data['refreshToken'],
    );
  }

  Future<void> logout() async {
    await SecureStorage.instance.clear();
  }
}
'@ | Set-Content -Path "lib/features/auth/data/auth_repository.dart" -Encoding UTF8

@'
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../data/auth_repository.dart';

/// Wired end-to-end to POST /auth/login. Rebuild the visual design against the
/// approved Login screen reference once you're iterating in Claude Code.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authRepository = AuthRepository();
  bool _loading = false;
  String? _error;

  Future<void> _submit() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await _authRepository.login(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
      if (mounted) context.go('/dashboard');
    } catch (e) {
      setState(() => _error = 'Invalid email or password');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 400),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Welcome Back', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                const SizedBox(height: 24),
                TextField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email Address', border: OutlineInputBorder()),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password', border: OutlineInputBorder()),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 8),
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                ],
                const SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: _loading
                      ? const SizedBox(
                          height: 20, width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Sign In'),
                ),
                TextButton(
                  onPressed: () => context.go('/register'),
                  child: const Text("Don't have an account? Create Account"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
'@ | Set-Content -Path "lib/features/auth/presentation/login_screen.dart" -Encoding UTF8

@'
import 'package:flutter/material.dart';

// TODO: build the full form per the /auth/register contract
// (companyName, ownerName, email, password, phone).
class RegisterScreen extends StatelessWidget {
  const RegisterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: Text('Register screen — placeholder')));
  }
}
'@ | Set-Content -Path "lib/features/auth/presentation/register_screen.dart" -Encoding UTF8

$placeholders = @{
  "lib/features/dashboard/presentation/dashboard_screen.dart" = @("DashboardScreen", "Dashboard — wire to GET /analytics/kpis once that endpoint exists.")
  "lib/features/orders/presentation/orders_screen.dart"       = @("OrdersScreen", "Orders — wire to GET /orders (build this backend module next).")
  "lib/features/scanner/presentation/scanner_screen.dart"     = @("ScannerScreen", "Scanner — use the camera package + POST /scanner/validate.")
  "lib/features/recording/presentation/recording_screen.dart" = @("RecordingScreen", "Recording — POST /recordings/start + /upload/init per the sequence diagram.")
  "lib/features/evidence/presentation/evidence_screen.dart"   = @("EvidenceScreen", "Evidence — GET /evidence/:id for signed URL + frame metadata.")
  "lib/features/claims/presentation/claims_screen.dart"       = @("ClaimsScreen", "Claims — POST/GET /claims lifecycle.")
  "lib/features/returns/presentation/returns_screen.dart"     = @("ReturnsScreen", "Returns — POST/GET /returns lifecycle.")
}

foreach ($key in $placeholders.Keys) {
    $className = $placeholders[$key][0]
    $comment = $placeholders[$key][1]
    $content = @"
import 'package:flutter/material.dart';

// TODO: $comment
class $className extends StatelessWidget {
  const $className({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text('$className — placeholder')));
  }
}
"@
    Set-Content -Path $key -Value $content -Encoding UTF8
}

@'
import 'package:flutter/material.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';

class LossDefenderApp extends StatelessWidget {
  const LossDefenderApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Loss Defender Pro',
      theme: AppTheme.light,
      routerConfig: appRouter,
      debugShowCheckedModeBanner: false,
    );
  }
}
'@ | Set-Content -Path "lib/app.dart" -Encoding UTF8

@'
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';

void main() {
  runApp(const ProviderScope(child: LossDefenderApp()));
}
'@ | Set-Content -Path "lib/main.dart" -Encoding UTF8

Set-Location ..

# ---------- 4. Backend ----------
Write-Step "Installing backend dependencies"
Set-Location backend
npm install
if (-not (Test-Path ".env")) {
    Copy-Item ".env.example" ".env"
    Write-Host "Created backend/.env from .env.example — fill in real Neon/B2/SMTP values later." -ForegroundColor Yellow
}
Write-Step "Generating Prisma client (needs internet access)"
npx prisma generate
Set-Location ..

# ---------- 5. Git ----------
if ($gitOk -and -not (Test-Path ".git")) {
    Write-Step "git init + first commit"
    git init | Out-Null
    git add .
    git commit -m "chore: v3 architecture scaffold - Flutter frontend + NestJS backend, auth + multi-tenant foundation" | Out-Null
}

Write-Step "Done"
Write-Host ""
Write-Host "Project ready at: $(Resolve-Path .)" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Green
Write-Host "  1. docker compose up -d postgres redis        (run from this folder)"
Write-Host "  2. cd backend; npx prisma migrate dev --name init"
Write-Host "  3. npm run start:dev                            (inside backend/)"
Write-Host "  4. cd ../frontend; flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:3000/api/v1"
Write-Host "     (or: flutter run -d windows / flutter devices  to see other targets)"
Write-Host "  5. Push to GitHub:"
Write-Host "       git remote add origin https://github.com/sanjeetdayma83/loss-defender-pro-backend.git"
Write-Host "       git checkout -b rebuild/v3-architecture"
Write-Host "       git push -u origin rebuild/v3-architecture"
