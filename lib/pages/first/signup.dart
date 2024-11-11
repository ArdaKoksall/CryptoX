import 'dart:async';
import 'dart:math';
import 'package:cryptox/design/matrix.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  SignupPageState createState() => SignupPageState();
}

class SignupPageState extends State<SignupPage> {
  Timer? _timer;
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _usernameIsValid = false;
  bool _emailIsValid = false;
  bool _passwordIsValid = false;
  bool agreeToTerms = false;
  final random = Random();

  String _emailErrorMessage = '';

  bool isValidEmail(String email) {
    const emailRegex = r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$';
    return RegExp(emailRegex).hasMatch(email);
  }

  Future<bool> checkIfEmailExists(String email) async {
    try {
      final querySnapshot =
          await FirebaseFirestore.instance.collection('users').doc(email).get();
      return querySnapshot.exists;
    } catch (_) {
      return false;
    }
  }

  Future<void> registerUser(
      String email, String password, String username) async {
    try {
      UserCredential userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(email: email, password: password);

      User? user = userCredential.user;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(email).set({
          'id': user.uid,
          'mail': email,
          'username': username,
          'balance': 10000,
          'total_balance': 10000 + random.nextInt(90000),
        });
        mounted
            ? ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('User registered successfully'),
                backgroundColor: Colors.green,
              ))
            : null;
      }
    } catch (_) {
      mounted
          ? ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Failed to register user'),
              backgroundColor: Colors.red,
            ))
          : null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _emailController.dispose();
    _passwordController.dispose();
    _usernameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MatrixRain(),
          Center(
            child: Container(
              width: 500,
              height: 700,
              padding: const EdgeInsets.all(20.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.green),
                color: Colors.black.withOpacity(0.7),
                borderRadius: BorderRadius.circular(12.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    spreadRadius: 5,
                    blurRadius: 7,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  const Icon(Icons.person_add,
                      size: 60, color: Colors.greenAccent),
                  const SizedBox(height: 40),
                  buildInputField(
                    labelText: "Username",
                    controller: _usernameController,
                    icon: Icons.person,
                    isValid: _usernameIsValid,
                    suffixIcon: _usernameController.text.isNotEmpty
                        ? Tooltip(
                            message: _usernameIsValid
                                ? ""
                                : "Username must be at least 3-12 characters",
                            child: Icon(
                              _usernameIsValid ? Icons.check : Icons.close,
                              color: _usernameIsValid
                                  ? Colors.greenAccent
                                  : Colors.red,
                            ),
                          )
                        : null,
                    onChanged: (value) {
                      setState(() {
                        _usernameIsValid =
                            value.length >= 3 && value.length <= 12;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  buildInputField(
                    labelText: "Email",
                    controller: _emailController,
                    icon: Icons.email,
                    isValid: _emailIsValid,
                    suffixIcon: _emailController.text.isNotEmpty
                        ? Tooltip(
                            message: _emailIsValid ? "" : _emailErrorMessage,
                            child: Icon(
                              _emailIsValid ? Icons.check : Icons.close,
                              color: _emailIsValid
                                  ? Colors.greenAccent
                                  : Colors.red,
                            ),
                          )
                        : null,
                    onChanged: (value) {
                      setState(() {
                        if (_timer?.isActive ?? false) _timer!.cancel();
                        _timer =
                            Timer(const Duration(milliseconds: 500), () async {
                          if (isValidEmail(value)) {
                            bool emailExists = await checkIfEmailExists(value);
                            setState(() {
                              _emailErrorMessage =
                                  emailExists ? 'Email already exists' : '';
                              _emailIsValid = !emailExists;
                            });
                          } else {
                            setState(() {
                              _emailErrorMessage = 'Invalid email format';
                              _emailIsValid = false;
                            });
                          }
                        });
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  buildInputField(
                    labelText: "Password",
                    controller: _passwordController,
                    icon: Icons.lock,
                    isValid: _passwordIsValid,
                    suffixIcon: _passwordController.text.isNotEmpty
                        ? Tooltip(
                            message: _passwordIsValid
                                ? ""
                                : "Password must be at least 6 characters",
                            child: Icon(
                              _passwordIsValid ? Icons.check : Icons.close,
                              color: _passwordIsValid
                                  ? Colors.greenAccent
                                  : Colors.red,
                            ),
                          )
                        : null,
                    onChanged: (value) {
                      setState(() {
                        _passwordIsValid = value.length >= 6;
                      });
                    },
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Checkbox(
                        value: agreeToTerms,
                        onChanged: (bool? value) {
                          setState(() {
                            agreeToTerms = value ?? false;
                          });
                        },
                        activeColor: Colors.black,
                        checkColor: Colors.greenAccent,
                      ),
                      const Text('Agree to terms',
                          style: TextStyle(
                              color: Colors.greenAccent,
                              fontFamily: 'Source Code Pro')),
                    ],
                  ),
                  const SizedBox(height: 30),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () {
                        if (_usernameIsValid &&
                            _emailIsValid &&
                            _passwordIsValid &&
                            agreeToTerms) {
                          registerUser(
                              _emailController.text,
                              _passwordController.text,
                              _usernameController.text);
                          setState(() {
                            _usernameIsValid = false;
                            _emailIsValid = false;
                            _passwordIsValid = false;
                            agreeToTerms = false;
                          });
                          _emailController.text = '';
                          _passwordController.text = '';
                          _usernameController.text = '';
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        foregroundColor: Colors.greenAccent,
                        side: BorderSide(color: Colors.greenAccent),
                        overlayColor: Colors.green.withOpacity(0.3),
                        textStyle:
                            const TextStyle(fontFamily: 'Source Code Pro'),
                      ),
                      child: const Text(
                        'Sign Up',
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: Colors.greenAccent,
                    ),
                    child: const Text(
                      "Already have an account? Login",
                      style: TextStyle(
                          color: Colors.greenAccent,
                          fontFamily: 'Source Code Pro'),
                    ),
                  ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget buildInputField({
    required String labelText,
    required TextEditingController controller,
    required IconData icon,
    required bool isValid,
    bool isObscure = false,
    Widget? suffixIcon,
    void Function(String)? onChanged,
  }) {
    return TextField(
      controller: controller,
      obscureText: isObscure,
      onChanged: onChanged,
      cursorColor: Colors.greenAccent,
      style: const TextStyle(
          color: Colors.greenAccent, fontFamily: 'Source Code Pro'),
      decoration: InputDecoration(
        labelText: labelText,
        labelStyle: const TextStyle(
            color: Colors.greenAccent, fontFamily: 'Source Code Pro'),
        filled: true,
        fillColor: Colors.black,
        prefixIcon: Icon(icon, color: Colors.greenAccent),
        suffixIcon: suffixIcon,
        enabledBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.green.withOpacity(0.7)),
          borderRadius: BorderRadius.circular(8.0),
        ),
        focusedBorder: OutlineInputBorder(
          borderSide: BorderSide(color: Colors.greenAccent),
          borderRadius: BorderRadius.circular(8.0),
        ),
      ),
    );
  }
}
