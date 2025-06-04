import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const String baseUrl = "http://localhost:3000/api"; // ⚠️ Adapte si tu testes sur téléphone

  static Future<Map<String, dynamic>> sendMessage(String message, {String? userId}) async {
    final url = Uri.parse('$baseUrl/chat');
    print('DEBUG ApiService: Sending POST request to $url with userId: $userId');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'message': message,
          'userId': userId,
        }),
      );

      print('DEBUG ApiService: Received response with status code: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        // Vérification de la structure de la réponse
        if (data['response'] == null) {
          throw Exception('Réponse invalide : champ "response" manquant');
        }

        // Construction de la réponse structurée avec l'userId
        return {
          'response': data['response'],
          'userId': data['userId'], // Ajouter l'userId à la réponse
          'reasoning': data['reasoning'] ?? {
            'steps': [],
            'suggested_itinerary': {},
            'hotel_suggestions': {},
            'restaurant_suggestions': {}
          },
          'data': data['data'] ?? {
            'hotels': [],
            'restaurants': [],
            'activities': [],
            'airports': [],
            'flights': []
          }
        };
      } else {
        print('DEBUG ApiService Error: ${response.reasonPhrase}, Body: ${response.body}');
        throw Exception('Erreur : ${response.reasonPhrase}');
      }
    } catch (e) {
      print('DEBUG ApiService Error: Exception during POST request: $e');
      rethrow;
    }
  }

  static Future<List<String>> fetchAvailableCities() async {
    final url = Uri.parse('$baseUrl/available-cities');
    final response = await http.get(url);

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final List cities = data['cities'];
      return cities.map((c) => c.toString()).toList();
    } else {
      throw Exception('Erreur récupération des villes');
    }
  }

  // Nouvelle méthode pour gérer les actions (réservations)
  static Future<Map<String, dynamic>> executeAction(String action, Map<String, dynamic> params) async {
    final url = Uri.parse('$baseUrl/chat/action');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'action': action,
        'params': params,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['success'] == true) {
        return data['result'] ?? {};
      } else {
        throw Exception(data['error'] ?? 'Erreur lors de l\'exécution de l\'action');
      }
    } else {
      throw Exception('Erreur serveur: ${response.reasonPhrase}');
    }
  }

  static Future<Map<String, dynamic>> executeReservationAction(
    String action,
    Map<String, dynamic> params, {
    String? message,
    Map<String, dynamic>? modification,
  }) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/reservation-action'), 
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'action': action,
          'params': params,
          if (message != null) 'message': message,
          if (modification != null) 'modification': modification,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur lors de l\'exécution de l\'action: ${response.statusCode}');
      }
    } catch (e) {
      print('Erreur lors de l\'exécution de l\'action: $e');
      rethrow;
    }
  }

  // --- Nouvelles méthodes pour la connexion et l'inscription ---

  static Future<Map<String, dynamic>> login(String email, String password) async {
    final url = Uri.parse('$baseUrl/login'); // Adapte l'endpoint si nécessaire
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'email': email, 'password': password}),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
         // Gérer les réponses avec des codes d'erreur spécifiques de ton backend si besoin
        return {'success': false, 'message': 'Erreur de connexion: ${response.reasonPhrase}'}; 
      }
    } catch (e) {
      // Gérer les erreurs réseau
      print('Erreur connexion API: $e');
      return {'success': false, 'message': 'Impossible de se connecter. Vérifiez votre connexion.'}; 
    }
  }

  static Future<Map<String, dynamic>> register(String name, String email, String password) async {
     final url = Uri.parse('$baseUrl/register'); // Adapte l'endpoint si nécessaire
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'name': name, 'email': email, 'password': password}),
      );

      if (response.statusCode == 200 || response.statusCode == 201) { // 200 ou 201 pour succès
        return jsonDecode(response.body);
      } else {
         // Gérer les réponses avec des codes d'erreur spécifiques de ton backend si besoin
         // Ton backend devrait retourner un message d'erreur clair en cas d'échec
        final errorData = jsonDecode(response.body);
        return {'success': false, 'message': errorData['message'] ?? 'Erreur d\'inscription: ${response.reasonPhrase}'}; 
      }
    } catch (e) {
      // Gérer les erreurs réseau
      print('Erreur inscription API: $e');
      return {'success': false, 'message': 'Impossible de s\'inscrire. Vérifiez votre connexion.'}; 
    }
  }

  // Méthode utilitaire pour formater les données
  static Map<String, dynamic> _formatData(Map<String, dynamic> rawData) {
    return {
      'hotels': _formatHotels(rawData['hotels'] ?? []),
      'restaurants': _formatRestaurants(rawData['restaurants'] ?? []),
      'activities': _formatActivities(rawData['activities'] ?? []),
      'airports': rawData['airports'] ?? [],
      'flights': rawData['flights'] ?? []
    };
  }

  static List<Map<String, dynamic>> _formatHotels(List<dynamic> hotels) {
    return hotels.map((hotel) => {
      'name': hotel['name'] ?? 'Nom non disponible',
      'location': hotel['location'] ?? 'Localisation non disponible',
      'price': hotel['price'] ?? 'Prix non disponible',
      'description': hotel['description'] ?? 'Pas de description'
    }).toList();
  }

  static List<Map<String, dynamic>> _formatRestaurants(List<dynamic> restaurants) {
    return restaurants.map((restaurant) => {
      'name': restaurant['name'] ?? 'Nom non disponible',
      'rating': restaurant['rating'] ?? 'Non noté',
      'price': restaurant['price'] ?? 'Prix non disponible',
      'cuisine': restaurant['cuisine'] ?? 'Non spécifié',
      'status': restaurant['status'] ?? 'Statut inconnu'
    }).toList();
  }

  static List<Map<String, dynamic>> _formatActivities(List<dynamic> activities) {
    return activities.map((activity) => {
      'name': activity['name'] ?? 'Nom non disponible',
      'description': activity['description'] ?? 'Pas de description',
      'price': activity['price'] ?? 'Prix non disponible',
      'currency': activity['currency'] ?? ''
    }).toList();
  }

  // Méthode pour récupérer l'historique des conversations
  static Future<List<Map<String, dynamic>>> getConversationHistory(String userId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/history/$userId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        return List<Map<String, dynamic>>.from(data['conversations']);
      } else {
        throw Exception('Erreur lors de la récupération de l\'historique');
      }
    } catch (e) {
      print('Erreur lors de la récupération de l\'historique: $e');
      rethrow;
    }
  }

  // Méthode pour archiver une conversation
  static Future<bool> archiveConversation(String userId, String conversationId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/archive'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'conversationId': conversationId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors de l\'archivage de la conversation: $e');
      return false;
    }
  }

  // Méthode pour supprimer une conversation
  static Future<bool> deleteConversation(String userId, String conversationId) async {
    try {
      final response = await http.delete(
        Uri.parse('$baseUrl/chat/$conversationId'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors de la suppression de la conversation: $e');
      return false;
    }
  }

  // Méthode pour créer une nouvelle conversation
  static Future<Map<String, dynamic>> createNewConversation(String userId) async {
    try {
      final response = await http.post(
        Uri.parse('$baseUrl/chat/new'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
        }),
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur lors de la création de la conversation');
      }
    } catch (e) {
      print('Erreur lors de la création de la conversation: $e');
      rethrow;
    }
  }

  // Méthode pour mettre à jour le titre d'une conversation
  static Future<bool> updateConversationTitle(String userId, String conversationId, String newTitle) async {
    try {
      final response = await http.put(
        Uri.parse('$baseUrl/chat/$conversationId/title'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'title': newTitle,
        }),
      );

      return response.statusCode == 200;
    } catch (e) {
      print('Erreur lors de la mise à jour du titre: $e');
      return false;
    }
  }

  // Méthode pour récupérer une conversation spécifique
  static Future<Map<String, dynamic>> getConversation(String userId, String conversationId) async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/chat/$conversationId'),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Erreur lors de la récupération de la conversation');
      }
    } catch (e) {
      print('Erreur lors de la récupération de la conversation: $e');
      rethrow;
    }
  }
}