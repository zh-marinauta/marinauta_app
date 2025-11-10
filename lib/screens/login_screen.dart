import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'dashboard_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _senhaController = TextEditingController();
  bool _loading = false;

  Future<void> _loginComEmail() async {
    setState(() => _loading = true);
    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _senhaController.text.trim(),
      );
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao entrar: $e')),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  Future<void> _loginComGoogle() async {
    try {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;
      final googleAuth = await googleUser.authentication;

      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      await FirebaseAuth.instance.signInWithCredential(credential);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const DashboardScreen()),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro Google: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white, // ⚪ fundo branco
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // 🟦 Logo principal PMAP
                Image.asset(
                  'assets/logo_pmap.png',
                  height: 400, // destaque
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 60),

                // 📩 Campo de e-mail
                TextField(
                  controller: _emailController,
                  style: const TextStyle(color: const Color(0xFF00294D)),
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    labelStyle: const TextStyle(color: Colors.black87),
                    hintText: 'exemplo@email.com',
                    hintStyle: TextStyle(color: const Color(0xFF00294D)),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF00294D),
                        width: 1.8,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0xFF00294D),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // 🔒 Campo de senha
                TextField(
                  controller: _senhaController,
                  obscureText: true,
                  style: const TextStyle(color: const Color(0xFF00294D)),
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    labelStyle: const TextStyle(color: Colors.black87),
                    filled: true,
                    fillColor: Colors.grey[100],
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF00294D),
                        width: 1.8,
                      ),
                    ),
                    focusedBorder: const OutlineInputBorder(
                      borderSide: BorderSide(
                        color: Color(0xFF00294D),
                        width: 2.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 40),

                // 🔘 Botão de entrar
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _loginComEmail,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF00294D),
                      foregroundColor: Colors.white,
                      padding:
                          const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _loading
                        ? const CircularProgressIndicator(
                            color: Colors.white,
                          )
                        : const Text(
                            'Entrar',
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold),
                          ),
                  ),
                ),
                const SizedBox(height: 20),

                // ou
                const Row(
                  children: [
                    Expanded(child: Divider(thickness: 1, color: Colors.black26)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: 8),
                      child: Text('ou',
                          style: TextStyle(color: Colors.black54)),
                    ),
                    Expanded(child: Divider(thickness: 1, color: Colors.black26)),
                  ],
                ),
                const SizedBox(height: 20),

                // 🟠 Login com Google (usando google_icon)
                OutlinedButton.icon(
                  onPressed: _loginComGoogle,
                  icon: Image.asset(
                    'assets/google_icon.png',
                    height: 24,
                  ),
                  label: const Text(
                    'Entrar com Google',
                    style: TextStyle(
                      color: Colors.black87,
                      fontSize: 17,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.black26),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 26, vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 50),

                // ⚓ Rodapé — logo Marinauta + texto institucional
                Column(
                  children: [
                    Image.asset(
                      'assets/logo_marinauta.png',
                      height: 40,
                      opacity: const AlwaysStoppedAnimation(0.8),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Marinauta – 24 HS. Sea Works & Marine Science Services',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
