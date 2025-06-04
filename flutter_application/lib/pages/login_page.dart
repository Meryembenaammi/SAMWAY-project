import 'package:flutter/material.dart';
import '../services/api_service.dart'; // Assure-toi que ce service API existe et est correct pour ta logique de connexion

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleLogin() {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      // --- Logique de connexion --- 
      // Ici, tu intégrerais l'appel à ton API de connexion (ApiService)
      
      ApiService.login(
        _emailController.text,
        _passwordController.text,
      ).then((response) {
        // Gérer la réponse (succès ou échec)
        setState(() {
          _isLoading = false;
        });
         // Assumons que ta réponse API a un champ 'success' ou similaire
        if (response != null && response['success'] == true) { // Ajout de la vérification response != null
          Navigator.pushReplacementNamed(context, '/chat'); // Navigation vers la page de chat en cas de succès
        } else {
          // Afficher un message d'erreur reçu de l'API ou un message par défaut
          // Utilise le message de l'API s'il existe, sinon un message par défaut
          final errorMessage = response != null && response.containsKey('message') 
              ? response['message']
              : 'Erreur de connexion inattendue.';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }).catchError((error) {
        // Gérer les erreurs réseau/exception
        setState(() {
          _isLoading = false;
        });
        
        // Tente d'extraire un message d'erreur de l'objet error si possible
        // Cela dépend du type d'erreur retourné par ApiService.handleResponse/le client http
        String errorMessage = 'Erreur: Impossible de se connecter. Vérifiez votre connexion.';
        if (error is String) {
           errorMessage = error; // Si l'erreur est une simple chaîne
        } else if (error is Map && error.containsKey('message')) {
           errorMessage = error['message']; // Si l'erreur est une Map avec un champ 'message'
        } else if (error.toString().contains('Failed host lookup')){
             errorMessage = 'Erreur réseau : Vérifiez que le serveur backend est lancé et accessible.';
        } else {
             errorMessage = error.toString(); // Afficher l'erreur brute si non gérée spécifiquement
        }

         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
      });
      
      // --- Simulation (à remplacer par ta logique API) ---
       /*Future.delayed(const Duration(seconds: 2), () {
        setState(() {
          _isLoading = false;
        });
         // Simulation de succès de connexion
        Navigator.pushReplacementNamed(context, '/chat');
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
                        "Votre Assistant de Voyage",
                        style: TextStyle(
                          fontSize: 18,
                          color: Colors.white70, // Couleur ajustée
                        ),
                      ),
                      const SizedBox(height: 48),

                      // Formulaire de connexion dans une carte transparente ou semi-transparente
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
                                  'Connectez-vous',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey, // Nouvelle couleur
                                  ),
                                ),
                                const SizedBox(height: 24),
                                TextFormField(
                                  controller: _emailController,
                                  decoration: InputDecoration(
                                    labelText: 'Email',
                                    prefixIcon: const Icon(Icons.email_outlined, color: Colors.blueGrey), // Nouvelle couleur
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none, // Pas de bordure visible par défaut
                                    ),
                                     filled: true,
                                    fillColor: Colors.blueGrey[50], // Couleur de fond légère
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
                                    fillColor: Colors.blueGrey[50], // Couleur de fond légère
                                     contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  ),
                                  obscureText: _obscurePassword,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return 'Veuillez entrer votre mot de passe';
                                    }
                                    if (value.length < 6) {
                                      return 'Le mot de passe doit contenir au moins 6 caractères';
                                    }
                                    return null;
                                  },
                                ),
                                const SizedBox(height: 24),
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
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
                                          'Se connecter',
                                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                        ),
                                ),
                                const SizedBox(height: 16),
                                TextButton(
                                  onPressed: () {
                                    // Navigation vers la page d'inscription
                                    Navigator.pushNamed(context, '/register'); // Assure-toi que cette route existe
                                  },
                                  child: Text(
                                    'Pas encore de compte ? S\'inscrire',
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