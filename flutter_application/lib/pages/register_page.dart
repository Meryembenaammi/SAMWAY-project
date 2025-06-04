import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Assure-toi que ce service API existe et est correct pour ta logique d'inscription

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _handleRegister() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // --- Logique d'inscription --- 
      // Ici, tu intégrerais l'appel à ton API d'inscription
      
      ApiService.register(
        _nameController.text,
        _emailController.text,
        _passwordController.text,
      ).then((response) {
        // Gérer la réponse (succès ou échec)
        setState(() {
          _isLoading = false;
        });
        // Assumons que ta réponse API a un champ 'success' ou similaire
        if (response['success'] == true) { // Adapte ceci selon la structure de ta réponse API
          // Peut-être naviguer vers la page de connexion après inscription réussie
          Navigator.pop(context); // Revenir à la page de connexion
           ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Inscription réussie ! Vous pouvez vous connecter.')),
          );
        } else {
          // Afficher un message d'erreur reçu de l'API ou un message par défaut
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(response['message'] ?? 'Erreur d\'inscription.')), // Adapte ceci
          );
        }
      }).catchError((error) {
        // Gérer les erreurs réseau/exception
        setState(() {
          _isLoading = false;
        });
         ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Erreur: Impossible de s\'inscrire. Vérifiez votre connexion.')),
          );
      });
      
      // --- Simulation (à remplacer par ta logique API) ---
       /*Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isLoading = false;
        });
         // Simulation de succès
        Navigator.pop(context); // Revenir à la page de connexion
      });*/
      // ---------------------------------------------------
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Image de fond
          Positioned.fill(
            child: Image.asset(
              'assets/images/login_background.jpg', // <<--- Remplace par le chemin de ton image
              fit: BoxFit.cover,
            ),
          ),
          // Contenu du formulaire par-dessus l'image
           Container(
            // Optionnel: un léger overlay pour améliorer la lisibilité
             decoration: BoxDecoration(
               color: Colors.black.withOpacity(0.3), // Ajuste l'opacité
             ),
            child: SafeArea(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Logo et titre (ajustés pour le fond sombre)
                      const Text(
                        "🦜",
                        style: TextStyle(fontSize: 64, color: Colors.white70), // Couleur ajustée
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        "SAMWay",
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: Colors.white, // Couleur blanche pour le titre principal
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Créez votre compte",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70, // Couleur ajustée
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Formulaire d'inscription dans une carte transparente ou semi-transparente
                      Card(
                        elevation: 8,
                         color: Colors.white.withOpacity(0.8), // Carte semi-transparente
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(24.0),
                          child: Form(
                            key: _formKey,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                               mainAxisSize: MainAxisSize.min, // Pour que la carte ne prenne pas toute la hauteur
                              children: [
                                const Text(
                                  'S\'inscrire',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey, // Nouvelle couleur
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _nameController,
                                  decoration: InputDecoration(
                                    labelText: 'Nom complet',
                                    prefixIcon: const Icon(Icons.person_outline, color: Colors.blueGrey), // Nouvelle couleur
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none, // Pas de bordure visible par défaut
                                    ),
                                     filled: true,
                                    fillColor: Colors.blueGrey[50], // Couleur de fond légère
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre nom';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.blueGrey), // Nouvelle couleur
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                       borderSide: BorderSide.none,
                                    ),
                                     filled: true,
                                    fillColor: Colors.blueGrey[50],
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre email';
                                    }
                                    if (!value.contains('@')) {
                                      return 'Veuillez entrer un email valide';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _passwordController,
                                  decoration: InputDecoration(
                                    labelText: 'Mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueGrey), // Nouvelle couleur
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.blueGrey, // Nouvelle couleur
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                       borderSide: BorderSide.none,
                                    ),
                                     filled: true,
                                    fillColor: Colors.blueGrey[50],
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  obscureText: _obscurePassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer un mot de passe';
                                    }
                                    if (value.length < 6) {
                                      return 'Le mot de passe doit contenir au moins 6 caractères';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 16),
                                TextFormField(
                                  controller: _confirmPasswordController,
                                  decoration: InputDecoration(
                                    labelText: 'Confirmer le mot de passe',
                                    prefixIcon: const Icon(Icons.lock_outline, color: Colors.blueGrey), // Nouvelle couleur
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscureConfirmPassword
                                            ? Icons.visibility_off
                                            : Icons.visibility,
                                        color: Colors.blueGrey, // Nouvelle couleur
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscureConfirmPassword = !_obscureConfirmPassword;
                                        });
                                      },
                                    ),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                       borderSide: BorderSide.none,
                                    ),
                                     filled: true,
                                    fillColor: Colors.blueGrey[50],
                                    contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  obscureText: _obscureConfirmPassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez confirmer votre mot de passe';
                                    }
                                    if (value != _passwordController.text) {
                                      return 'Les mots de passe ne correspondent pas';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleRegister,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.blueGrey, // Nouvelle couleur du bouton
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 16),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                     elevation: 5, // Petite élévation
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                          ),
                                        )
                                      : const Text(
                                          'S\'inscrire',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    Navigator.pop(context); // Revenir à la page de connexion
                                  },
                                  child: Text(
                                    'Déjà un compte ? Se connecter',
                                    style: TextStyle(color: Colors.blueGrey[700]), // Nouvelle couleur du texte
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      // TODO: Tu peux ajouter ici d'autres éléments décoratifs par-dessus l'image de fond si tu le souhaites
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
} 