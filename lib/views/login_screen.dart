import 'package:flutter/material.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../controllers/auth_controller.dart';
import '../services/auth_service.dart';
import '../config/onboarding_config.dart';
import 'session_conflict_screen.dart';
import 'main_shell.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authController = AuthController();
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    serverClientId:
        '452121335838-prdjordjglcbjroi476amr6990ipft7m.apps.googleusercontent.com',
  );

  String _errorMessage = '';
  bool _isLoading = false;

  Future<void> _handleGoogleSignIn({
    bool force = false,
    String? cachedIdToken,
    int? terminateSessionId,
  }) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    String? idToken = cachedIdToken;

    try {
      if ((!force && terminateSessionId == null) || idToken == null) {
        // Sign out only if we are taking a fresh start or fixing an error state
        // that isn't just a force retry or termination re-attempt
        if (!force && terminateSessionId == null) {
          await _googleSignIn.signOut();
        }

        final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();
        if (googleUser != null) {
          final GoogleSignInAuthentication googleAuth =
              await googleUser.authentication;
          idToken = googleAuth.idToken;
        } else {
          // User cancelled
          setState(() {
            _isLoading = false;
          });
          return;
        }
      }

      if (idToken != null) {
        await _authController.signInWithGoogle(
          idToken,
          force: force,
          terminateSessionId: terminateSessionId,
        );
        if (mounted) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const MainShell()),
          );
        }
      }
    } on AuthException catch (e) {
      if ((e.code == 'MAX_SESSIONS_EXCEEDED' ||
              e.code == 'ACTIVE_SESSION_EXISTS') &&
          mounted) {
        // Normalize data to list
        List<dynamic> sessions = [];
        if (e.data is List) {
          sessions = e.data;
        } else if (e.data is Map) {
          sessions = [e.data];
        }

        // Show styled conflict screen
        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => SessionConflictScreen(sessions: sessions),
          ),
        );

        if (result == true) {
          // Force replace oldest
          await _handleGoogleSignIn(force: true, cachedIdToken: idToken);
        } else if (result is int) {
          // Terminate specific session
          await _handleGoogleSignIn(
            terminateSessionId: result,
            cachedIdToken: idToken,
          );
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = e.message;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted && _errorMessage.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _login({bool force = false, int? terminateSessionId}) async {
    setState(() {
      _isLoading = true;
      _errorMessage = '';
    });

    try {
      await _authController.login(
        _emailController.text,
        _passwordController.text,
        force: force,
        terminateSessionId: terminateSessionId,
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const MainShell()),
        );
      }
    } on AuthException catch (e) {
      if ((e.code == 'MAX_SESSIONS_EXCEEDED' ||
              e.code == 'ACTIVE_SESSION_EXISTS') &&
          mounted) {
        List<dynamic> sessions = [];
        if (e.data is List) {
          sessions = e.data;
        } else if (e.data is Map) {
          sessions = [e.data];
        }

        final result = await Navigator.push<dynamic>(
          context,
          MaterialPageRoute(
            fullscreenDialog: true,
            builder: (context) => SessionConflictScreen(sessions: sessions),
          ),
        );

        if (result == true) {
          await _login(force: true);
        } else if (result is int) {
          await _login(terminateSessionId: result);
        } else {
          setState(() {
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = e.message;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString().replaceAll('Exception: ', '');
        });
      }
    } finally {
      if (mounted &&
          _errorMessage.isEmpty &&
          !force &&
          terminateSessionId == null) {
        setState(() {
          _isLoading = false;
        });
      }
      if (mounted && _errorMessage.isNotEmpty) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              // Login GIF
              Image.asset(AppAssets.login, height: 200, fit: BoxFit.contain),
              const SizedBox(height: 32),
              Text(
                'Welcome Back',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sign in to continue',
                style: Theme.of(
                  context,
                ).textTheme.bodyLarge?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.email_outlined),
                ),
                keyboardType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: 'Password',
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
              ),
              const SizedBox(height: 24),
              if (_errorMessage.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.red),
                  ),
                  child: Text(
                    _errorMessage,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              const SizedBox(height: 24),
              _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ElevatedButton(
                          onPressed: _login,
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Text('Login'),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _handleGoogleSignIn,
                          icon: const Icon(Icons.g_mobiledata, size: 24),
                          label: const Text('Sign in with Google'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.white,
                            side: const BorderSide(color: Colors.white),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ],
                    ),
              const SizedBox(height: 24),
              TextButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const SignupScreen(),
                    ),
                  );
                },
                child: const Text("Don't have an account? Sign up"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
