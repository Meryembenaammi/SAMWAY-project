import 'package:flutter/material.dart';
import '../services/api_service.dart';

enum ConversationState {
  idle,
  askingForDeparture,
  askingForDepartureDate,
  askingForArrivalDate,
}

class ChatPage extends StatefulWidget {
  const ChatPage({super.key});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  List<Map<String, dynamic>> messages = [
    {"role": "bot", "text": "Bonjour ! Je suis votre assistant de voyage. Comment puis-je vous aider ?"}
  ];
  List<String> availableCities = [];
  String detectedCity = '';
  bool isLoading = false;
  Map<String, dynamic>? bookingResult;
  ConversationState _conversationState = ConversationState.idle;
  String _departureLocation = '';
  String _arrivalLocation = '';
  String _departureDate = '';
  String _arrivalDate = '';
  final Map<String, String> cityImages = {
    'Paris': 'assets/images/paris.jpg',
    'Lyon': 'assets/images/lyon.jpg',
    'Marseille': 'assets/images/marseille.jpg',
    'Bordeaux': 'assets/images/bordeaux.jpg',
    'Nice': 'assets/images/nice.jpg',
    'Lille': 'assets/images/lille.jpg',
    'Toulouse': 'assets/images/toulouse.jpg',
    'Nantes': 'assets/images/nantes.jpg',
    'Strasbourg': 'assets/images/strasbourg.jpg',
    'Montpellier': 'assets/images/montpellier.jpg',
  };

  final List<Map<String, String>> cityCards = [
    {
      'name': 'Paris',
      'country': 'France',
      'image': 'assets/images/paris.jpeg',
      'description': 'Beyond such landmarks as the Eiffel Tower and the Gothic Notre-Dame...'
    },
    {
      'name': 'Madrid',
      'country': 'Spain',
      'image': 'assets/images/madrid.jpeg',
      'description': 'The vibrant capital of Spain, known for its art, culture, and lively plazas.'
    },
    {
      'name': 'New York City',
      'country': 'USA',
      'image': 'assets/images/newyork.jpeg',
      'description': 'The city that never sleeps, home to the Statue of Liberty and Central Park.'
    },
    {
      'name': 'Istanbul',
      'country': 'Turkey',
      'image': 'assets/images/istanbul.jpeg',
      'description': 'A city straddling Europe and Asia, famous for its historic sites and bazaars.'
    },
    {
      'name': 'Casablanca',
      'country': 'Morocco',
      'image': 'assets/images/casablanca.jpeg',
      'description': 'Morocco is the largest city, known for its modern business center and rich history.'
    },
    {
      'name': 'Rabat',
      'country': 'Morocco',
      'image': 'assets/images/rabat.jpeg',
      'description': 'The capital of Morocco, with beautiful beaches and historical landmarks.'
    },
  ];

  List<Map<String, dynamic>> conversationHistory = [];
  bool isLoadingHistory = false;
  String? _currentUserId;

  @override
  void initState() {
    super.initState();
    // Générer un nouvel userId au démarrage
    _currentUserId = DateTime.now().millisecondsSinceEpoch.toString();
    loadCities();
    loadConversationHistory();
  }

  Future<void> loadCities() async {
    try {
      final cities = await ApiService.fetchAvailableCities();
      setState(() {
        availableCities = cities;
      });
    } catch (e) {
      print("Erreur chargement des villes : $e");
    }
  }

  Future<void> loadConversationHistory() async {
    if (_currentUserId == null) return;

    setState(() {
      isLoadingHistory = true;
    });

    try {
      final history = await ApiService.getConversationHistory(_currentUserId!);
      setState(() {
        // Ensure conversationHistory is a new list to trigger UI update if needed
        // The backend already returns the full list sorted by lastMessageAt
        conversationHistory = List<Map<String, dynamic>>.from(history); 
      });
    } catch (e) {
      print('Erreur lors du chargement de l\'historique: $e');
       // Optionally clear history on error to reflect inability to load
       setState(() {
         conversationHistory = [];
       });
    } finally {
      setState(() {
        isLoadingHistory = false;
      });
    }
  }

  Future<void> handleBooking(Map<String, dynamic> bookingData) async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiService.executeAction('book_hotel', bookingData);
      setState(() {
        bookingResult = result;
        messages.add({
          "role": "bot",
          "text": "Réservation effectuée avec succès !",
          "bookingResult": result
        });
      });
    } catch (e) {
      setState(() {
        messages.add({
          "role": "bot",
          "text": "Erreur lors de la réservation. Veuillez réessayer.",
        });
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> handleReservationAction(String action, Map<String, dynamic> params, {String? message, Map<String, dynamic>? modification}) async {
    setState(() {
      isLoading = true;
    });

    try {
      final result = await ApiService.executeReservationAction(action, params, message: message, modification: modification);

      // Affiche le message d'email envoyé si présent dans la réponse
      // Modified: Always show email sent message for 'modify' action
      if (action == 'modify') {
         messages.add({
           "role": "bot",
           "text": "📧 Email de modification envoyé",
         });
       } else if (result['emailSent'] == true) {
        messages.add({
          "role": "bot",
          "text": action == 'modify'
              ? "📧 Email de modification envoyé"
              : "📧 Email de confirmation envoyé",
        });
      }

      setState(() {
        messages.add({
          "role": "bot",
          "text": result['response'] ?? (action == 'modify' ? "Modification enregistrée avec succès !" : "Action effectuée avec succès !"), // Modified: Add specific success message for 'modify' if no response
          "reasoning": result['reasoning'] ?? {},
          "data": result['data'] ?? {},
          "bookingResult": result['result'] != null
              ? (result['result'] as Map).cast<String, dynamic>()
              : {},
        });
      });
    } catch (e) {
      setState(() {
        messages.add({
          "role": "bot",
          "text": "Erreur lors de l'action. Veuillez réessayer.",
        });
      });
    } finally {
      setState(() {
        isLoading = false;
      });
    }
  }

  // Nouvelle fonction pour calculer la durée du séjour
  int calculateStayDuration(String departureDate, String arrivalDate) {
    if (departureDate.isEmpty || arrivalDate.isEmpty) return 0; // Retourner 0 si les dates ne sont pas fournies
    
    final start = DateTime.parse(departureDate);
    final end = DateTime.parse(arrivalDate);
    
    // Vérifier que les dates sont valides
    if (start.isAfter(end)) return 0;
    
    // Calculer la différence en jours
    final diffDays = end.difference(start).inDays;
    
    // Retourner la durée calculée
    return diffDays > 0 ? diffDays : 0;
  }

  // Nouvelle fonction pour générer un itinéraire dynamique
  Map<String, dynamic> generateDynamicItinerary(int duration) {
    if (duration <= 0) return {}; // Retourner un itinéraire vide si la durée est invalide
    
    final itinerary = <String, dynamic>{};
    for (int i = 1; i <= duration; i++) {
      itinerary['day$i'] = {
        'morning': {
          'activities': [],
          'local_tips': "",
          'hidden_gems': ""
        },
        'afternoon': {
          'activities': [],
          'local_tips': "",
          'hidden_gems': ""
        },
        'evening': {
          'activities': [],
          'local_tips': "",
          'hidden_gems': ""
        }
      };
    }
    return itinerary;
  }

  void _startNewConversation() async {
    try {
      // Keep the existing userId for the current session
      // final newUserId = DateTime.now().millisecondsSinceEpoch.toString(); // Removed
      
      setState(() {
        // _currentUserId = newUserId; // Removed - keep existing
        messages = [
          {"role": "bot", "text": "Bonjour ! Je suis votre assistant de voyage. Comment puis-je vous aider ?"}
        ];
        _conversationState = ConversationState.idle;
        _departureLocation = '';
        _arrivalLocation = '';
        _departureDate = '';
        _arrivalDate = '';
        detectedCity = '';
      });
      
      // Appeler le nouvel endpoint pour créer une nouvelle conversation dans le backend
      if (_currentUserId != null) {
         await ApiService.createNewConversation(_currentUserId!); // Utiliser la méthode API existante pour appeler /chat/new
      } else {
         // If somehow _currentUserId is null (shouldn't happen after initState), handle gracefully
         print('Erreur: _currentUserId est null lors de la création d\'une nouvelle conversation');
         // Optionally generate a new one here as a fallback, but ideally it's set in initState
         // await ApiService.sendMessage("Bonjour !", userId: DateTime.now().millisecondsSinceEpoch.toString());
      }
      

      // Charger l'historique pour le nouvel utilisateur
      await loadConversationHistory();
      print('DEBUG: Started a new conversation for userId: $_currentUserId');
    } catch (e) {
      print('Erreur lors de la création d\'une nouvelle conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la création d\'une nouvelle conversation')),
      );
    }
  }

  Future<void> _archiveConversation(String conversationId) async {
    try {
      final success = await ApiService.archiveConversation(_currentUserId!, conversationId);
      if (success) {
        await loadConversationHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation archivée avec succès')),
        );
      }
    } catch (e) {
      print('Erreur lors de l\'archivage de la conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de l\'archivage de la conversation')),
      );
    }
  }

  Future<void> _deleteConversation(String conversationId) async {
    try {
      final success = await ApiService.deleteConversation(_currentUserId!, conversationId);
      if (success) {
        await loadConversationHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Conversation supprimée avec succès')),
        );
      }
    } catch (e) {
      print('Erreur lors de la suppression de la conversation: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la suppression de la conversation')),
      );
    }
  }

  Future<void> _updateConversationTitle(String conversationId, String newTitle) async {
    try {
      final success = await ApiService.updateConversationTitle(_currentUserId!, conversationId, newTitle);
      if (success) {
        await loadConversationHistory();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Titre mis à jour avec succès')),
        );
      }
    } catch (e) {
      print('Erreur lors de la mise à jour du titre: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Erreur lors de la mise à jour du titre')),
      );
    }
  }

  Future<void> sendMessage() async {
    String userInput = _controller.text.trim();
    if (userInput.isEmpty) return;

    print('DEBUG: sendMessage called with input: $userInput');
    print('DEBUG: Current conversation state: $_conversationState');
    print('DEBUG: Current userId: $_currentUserId');

    // Filtre anti-action illégale côté frontend
    final illegalKeywords = [
      'pirater', 'faux passeport', 'drogue', 'arnaque', 'hack', 'illégal', 'crime', 'terrorisme'
    ];
    final lowerMsg = userInput.toLowerCase();
    if (illegalKeywords.any((kw) => lowerMsg.contains(kw))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('❌ Demande non autorisée.')),
      );
      return;
    }

    // Handle responses based on the current state
    switch (_conversationState) {
      case ConversationState.askingForDeparture:
        _departureLocation = userInput;
        setState(() {
          _conversationState = ConversationState.askingForDepartureDate;
          messages.add({"role": "user", "text": userInput});
          messages.add({
            "role": "bot",
            "text": "Okay, départ de $_departureLocation. Quelle est la date de **départ** de votre voyage ? (AAAA-MM-JJ)",
          });
        });
        break;

      case ConversationState.askingForDepartureDate:
        _departureDate = userInput;
        setState(() {
          _conversationState = ConversationState.askingForArrivalDate;
          messages.add({"role": "user", "text": userInput});
          messages.add({
            "role": "bot",
            "text": "Entendu. Et quelle est la date de **retour** ? (AAAA-MM-JJ)",
          });
        });
        break;

      case ConversationState.askingForArrivalDate:
        _arrivalDate = userInput;
        setState(() {
          _conversationState = ConversationState.idle;
          messages.add({"role": "user", "text": userInput});
          _controller.clear();
        });

        // Add typing indicator before sending
        setState(() {
           messages.add({"role": "bot_typing"});
        });

        // Calculate the duration
        final duration = calculateStayDuration(_departureDate, _arrivalDate);

        try {
          // Construct a comprehensive message with all collected info
          final comprehensiveMessage = "Voyage de $_departureLocation à $_arrivalLocation du $_departureDate au $_arrivalDate";
          final response = await ApiService.sendMessage(comprehensiveMessage, userId: _currentUserId);

          // Mettre à jour l'userId si un nouveau est fourni dans la réponse
          if (response['userId'] != null) {
            setState(() {
              _currentUserId = response['userId'];
            });
          }

          // Vérifier et ajuster l'itinéraire si nécessaire
          Map<String, dynamic> finalItinerary = generateDynamicItinerary(duration);
          if (response['reasoning'] != null && 
              response['reasoning']['suggested_itinerary'] != null) {
            final suggestedItinerary = response['reasoning']['suggested_itinerary'] as Map<String, dynamic>;
            
            if (suggestedItinerary.length != duration) {
              print('⚠️ Ajustement de l\'itinéraire côté client: ${suggestedItinerary.length} jours trouvés, $duration jours requis');
              if (suggestedItinerary.length < duration) {
                 for (int i = suggestedItinerary.length + 1; i <= duration; i++) {
                   suggestedItinerary['day$i'] = {
                     'morning': {'activities': ['À planifier'], 'local_tips': '', 'hidden_gems': ''},
                     'afternoon': {'activities': ['À planifier'], 'local_tips': '', 'hidden_gems': ''},
                     'evening': {'activities': ['À planifier'], 'local_tips': '', 'hidden_gems': ''},
                   };
                 }
              } else if (suggestedItinerary.length > duration) {
                 suggestedItinerary.keys.toList().sublist(0, duration).forEach((key) => finalItinerary[key] = suggestedItinerary[key]);
              } else {
                 finalItinerary = suggestedItinerary;
              }
            } else {
              finalItinerary = suggestedItinerary;
            }
          }

          // Remove typing indicator and add bot response
          setState(() {
            messages.removeWhere((msg) => msg["role"] == "bot_typing");
            messages.add({
              "role": "bot",
              "text": response['response'] ?? "Voici votre plan de voyage !",
              "reasoning": response['reasoning'] ?? {},
              "data": response['data'] ?? {},
              "itinerary": finalItinerary,
              "duration": duration
            });
          });
        } catch (e) {
          print("DEBUG ERROR: Error sending message: $e");
          setState(() {
             messages.removeWhere((msg) => msg["role"] == "bot_typing");
            messages.add({
              "role": "bot",
              "text": "Désolé, une erreur s'est produite lors de la planification. Veuillez réessayer.",
            });
          });
        } finally {
          setState(() {
            isLoading = false;
            _departureLocation = '';
            _arrivalLocation = '';
            _departureDate = '';
            _arrivalDate = '';
            _conversationState = ConversationState.idle;
          });
          // Load history after message is processed and saved
          loadConversationHistory();
        }
        break;

      case ConversationState.idle:
      default:
        setState(() {
          messages.add({"role": "user", "text": userInput});
          _controller.clear();
        });

        String initialDetectedCity = '';
        for (String city in availableCities) {
          if (userInput.toLowerCase().contains(city.toLowerCase())) {
            initialDetectedCity = city;
            break;
          }
        }

        if (initialDetectedCity.isNotEmpty) {
          _arrivalLocation = initialDetectedCity;

          setState(() {
            _conversationState = ConversationState.askingForDeparture;
            messages.add({
              "role": "bot",
              "text": "Très bien pour $_arrivalLocation ! D'où souhaitez-vous partir ?",
            });
          });
          return;
        }

        setState(() {
           isLoading = true;
        });

        // Add typing indicator
        setState(() {
           messages.add({"role": "bot_typing"});
        });

        try {
          final response = await ApiService.sendMessage(userInput, userId: _currentUserId);

          // Mettre à jour l'userId si un nouveau est fourni dans la réponse
          if (response['userId'] != null) {
            setState(() {
              _currentUserId = response['userId'];
            });
          }

          // Remove typing indicator and add bot response
          setState(() {
            messages.removeWhere((msg) => msg["role"] == "bot_typing");
            messages.add({
              "role": "bot",
              "text": response['response'] ?? "Désolé, je n'ai pas pu traiter votre demande.",
              "reasoning": response['reasoning'] ?? {},
              "data": response['data'] ?? {}
            });
          });
        } catch (e) {
          print("DEBUG ERROR: Error sending message: $e");
          setState(() {
             messages.removeWhere((msg) => msg["role"] == "bot_typing");
            messages.add({
              "role": "bot",
              "text": "Désolé, une erreur s'est produite. Veuillez réessayer.",
            });
          });
        } finally {
          setState(() {
            isLoading = false;
          });
          // Load history after message is processed and saved
          loadConversationHistory();
        }
        break;
    }
  }

  Widget _buildCitiesGrid() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            "🌍 Villes disponibles",
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.deepPurple,
            ),
          ),
          const SizedBox(height: 16),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 1.5,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
            ),
            itemCount: availableCities.length,
            itemBuilder: (context, index) {
              final city = availableCities[index];
              return GestureDetector(
                onTap: () {
                  setState(() {
                    detectedCity = city;
                    _controller.text = "Je voudrais visiter $city";
                  });
                },
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Image.asset(
                          cityImages[city] ?? 'assets/images/default_city.jpg',
                          fit: BoxFit.cover,
                        ),
                        Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withOpacity(0.7),
                              ],
                            ),
                          ),
                        ),
                        Positioned(
                          bottom: 8,
                          left: 8,
                          right: 8,
                          child: Text(
                            city,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 16),
          const Text(
            "Cliquez sur une ville pour commencer à planifier votre voyage !",
            style: TextStyle(
              fontSize: 14,
              color: Colors.deepPurple,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessage(Map<String, dynamic> message) {
    final isUser = message["role"] == "user";
    final isTyping = message["role"] == "bot_typing";
    final emoji = isUser ? "😊" : isTyping ? "..." : "🤖";
    final alignment = isUser ? Alignment.centerRight : Alignment.centerLeft;
    final color = isUser ? Colors.pink[100] : isTyping ? Colors.grey[300] : Colors.amber[100];

    if (isTyping) {
      return Align(
        alignment: alignment,
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          padding: const EdgeInsets.all(14),
          constraints: const BoxConstraints(maxWidth: 150),
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("$emoji ", style: TextStyle(fontStyle: FontStyle.italic)),
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.black54),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Create a list to hold all content widgets
    List<Widget> contentWidgets = [];

    // Add the main message text
    contentWidgets.add(
      Text("$emoji ${message["text"]}", 
        style: const TextStyle(fontSize: 15)
      )
    );

    // Add spacing after the main text
    contentWidgets.add(const SizedBox(height: 16));

    // Add other sections if they exist
    if (message["showCities"] == true) {
      contentWidgets.add(_buildCitiesGrid());
    }
    
    if (message["reasoning"] != null && message["reasoning"] is Map) {
      contentWidgets.add(_buildReasoningSection(
        (message["reasoning"] as Map).cast<String, dynamic>(),
        (message["data"] as Map).cast<String, dynamic>()
      ));
    }
    
    if (message["data"] != null && message["data"] is Map) {
      contentWidgets.add(_buildDataSection((message["data"] as Map).cast<String, dynamic>()));
      contentWidgets.add(const SizedBox(height: 8));
      contentWidgets.add(_buildActionButtons((message["data"] as Map).cast<String, dynamic>()));
    }
    
    if (message["bookingResult"] != null && message["bookingResult"].isNotEmpty) {
      contentWidgets.add(_buildBookingResult((message["bookingResult"] as Map).cast<String, dynamic>()));
    }
    
    if (message["itinerary"] != null && message["itinerary"] is Map) {
      contentWidgets.add(_buildItinerarySection((message["itinerary"] as Map).cast<String, dynamic>()));
    }

    // Return the combined message bubble
    return Align(
      alignment: alignment,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(16),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isUser ? 16 : 4),
            topRight: Radius.circular(isUser ? 4 : 16),
            bottomLeft: const Radius.circular(16),
            bottomRight: const Radius.circular(16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.08),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: contentWidgets,
        ),
      ),
    );
  }

  Widget _buildBookingResult(Map<String, dynamic> result) {
    return Card(
      color: Colors.green[50],
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "✅ Réservation confirmée",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.green,
              ),
            ),
            const SizedBox(height: 8),
            Text("Hôtel: ${result['hotelName'] ?? 'Non spécifié'}"),
            Text("Date d'arrivée: ${result['checkIn'] ?? 'Non spécifiée'}"),
            Text("Date de départ: ${result['checkOut'] ?? 'Non spécifiée'}"),
            Text("Numéro de confirmation: ${result['confirmationNumber'] ?? 'Non spécifié'}"),
          ],
        ),
      ),
    );
  }

  Widget _buildReasoningSection(Map<String, dynamic> reasoning, Map<String, dynamic> data) {
    // Combine suggested hotels with available hotels
    final suggestedHotels = <Map<String, dynamic>>[];
    final otherHotels = <Map<String, dynamic>>[];
    
    // Process suggested hotels from Gemini
    ((reasoning['hotel_suggestions'] as Map<String, dynamic>?) ?? {}).forEach((category, value) {
      if (value is Map && value['options'] is List) {
        for (var hotel in value['options']) {
          if (hotel is Map) {
            suggestedHotels.add({
              'name': hotel['name'] ?? hotel['hotelName'] ?? 'Nom non spécifié',
              'location': hotel['location'] ?? '',
              'price': hotel['price'] ?? 'Prix non disponible',
              'category': category,
              'isSuggested': true
            });
          }
        }
      }
    });

    // Process other available hotels
    ((data['hotels'] as List?) ?? []).forEach((hotel) {
      if (!suggestedHotels.any((s) => s['name'] == hotel['name'])) {
        otherHotels.add({
          'name': hotel['name'] ?? 'Nom non spécifié',
          'location': hotel['location'] ?? '',
          'price': hotel['price'] ?? 'Prix non disponible',
          'isSuggested': false
        });
      }
    });

    // Combine suggested restaurants with available restaurants
    final suggestedRestaurants = <Map<String, dynamic>>[];
    final otherRestaurants = <Map<String, dynamic>>[];
    
    // Process suggested restaurants from Gemini
    ((reasoning['restaurant_suggestions'] as Map<String, dynamic>?) ?? {}).forEach((meal, value) {
      if (value is Map && value['options'] is List) {
        for (var restaurant in value['options']) {
          if (restaurant is Map) {
            suggestedRestaurants.add({
              'name': restaurant['name'] ?? 'Nom non spécifié',
              'meal': meal,
              'isSuggested': true
            });
          }
        }
      }
    });

    // Process other available restaurants
    ((data['restaurants'] as List?) ?? []).forEach((restaurant) {
      if (!suggestedRestaurants.any((s) => s['name'] == restaurant['name'])) {
        otherRestaurants.add({
          'name': restaurant['name'] ?? 'Nom non spécifié',
          'rating': restaurant['rating'] ?? 'Non noté',
          'price': restaurant['price'] ?? 'Prix non spécifié',
          'isSuggested': false
        });
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Plan d'action"),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ((reasoning['steps'] as List?) ?? []).map((step) {
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Étape ${step['priority'] ?? 'N/A'}",
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    Text(step['action'] ?? 'Action non spécifiée'),
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 16),
        _buildSectionTitle("Itinéraire suggéré"),
        ...((reasoning['suggested_itinerary'] as Map<String, dynamic>?) ?? {}).entries.map((entry) {
          final day = entry.key;
          final activities = entry.value as Map<String, dynamic>;
          return Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Jour ${day.replaceAll('day', '')}",
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Text("🌅 Matin: ${(activities['morning']?['activities'] as List?)?.join(', ') ?? 'Non spécifié'}"),
                  Text("🌞 Après-midi: ${(activities['afternoon']?['activities'] as List?)?.join(', ') ?? 'Non spécifié'}"),
                  Text("🌙 Soir: ${(activities['evening']?['activities'] as List?)?.join(', ') ?? 'Non spécifié'}"),
                ],
              ),
            ),
          );
        }).toList(),
        const SizedBox(height: 16),
        _buildSectionTitle("Suggestions d'hébergement"),
        // Afficher d'abord les suggestions Gemini
        if (suggestedHotels.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "✨ Suggestions de Gemini",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
          ...suggestedHotels.map((hotel) => Card(
            color: Colors.deepPurple[50],
            child: ListTile(
              title: Text("• ${hotel['name']}"),
              subtitle: Text(hotel['location']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(hotel['price']),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showBookingDialog({
                      'hotelName': hotel['name'],
                      'location': hotel['location'],
                      'price': hotel['price'],
                    }),
                    child: const Text("Confirmer"),
                  ),
                ],
              ),
            ),
          )),
        ],
        // Ensuite afficher les autres hôtels
        if (otherHotels.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "🏨 Autres hôtels disponibles",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          ...otherHotels.map((hotel) => Card(
            child: ListTile(
              title: Text("• ${hotel['name']}"),
              subtitle: Text(hotel['location']),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(hotel['price']),
                  const SizedBox(width: 8),
                  ElevatedButton(
                    onPressed: () => _showBookingDialog({
                      'hotelName': hotel['name'],
                      'location': hotel['location'],
                      'price': hotel['price'],
                    }),
                    child: const Text("Confirmer"),
                  ),
                ],
              ),
            ),
          )),
        ],
        const SizedBox(height: 16),
        _buildSectionTitle("Suggestions de restaurants"),
        // Afficher d'abord les suggestions Gemini
        if (suggestedRestaurants.isNotEmpty) ...[
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "✨ Suggestions de Gemini",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.deepPurple,
              ),
            ),
          ),
          ...suggestedRestaurants.map((restaurant) => Card(
            color: Colors.deepPurple[50],
            child: ListTile(
              title: Text("• ${restaurant['name']}"),
              subtitle: Text(restaurant['meal'] == 'breakfast' ? '🌅 Petit-déjeuner' :
                          restaurant['meal'] == 'lunch' ? '🌞 Déjeuner' : '🌙 Dîner'),
            ),
          )),
        ],
        // Ensuite afficher les autres restaurants
        if (otherRestaurants.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "🍽️ Autres restaurants disponibles",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.grey[700],
              ),
            ),
          ),
          ...otherRestaurants.map((restaurant) => Card(
            child: ListTile(
              title: Text("• ${restaurant['name']}"),
              subtitle: Text("Note: ${restaurant['rating']}"),
              trailing: Text(restaurant['price']),
            ),
          )),
        ],
      ],
    );
  }

  Widget _buildDataSection(Map<String, dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionTitle("Données disponibles"),
        _buildSectionTitle("🏨 Hôtels disponibles"),
        ...((data['hotels'] as List?) ?? []).map((hotel) => Card(
              child: ListTile(
                title: Text(hotel['name'] ?? 'Nom non spécifié'),
                subtitle: Text(hotel['location'] ?? 'Emplacement non spécifié'),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(hotel['price'] ?? 'Prix non spécifié'),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () => _showBookingDialog({
                        'hotelName': hotel['name'] ?? hotel['hotelName'] ?? 'Nom non spécifié',
                        'location': hotel['location'] ?? '',
                        'price': hotel['price'] ?? 'Prix non disponible',
                      }),
                      child: const Text("Confirmer"),
                    ),
                  ],
                ),
              ),
            )),
        const SizedBox(height: 16),
        _buildSectionTitle("🍽️ Restaurants disponibles"),
        ...((data['restaurants'] as List?) ?? []).map((restaurant) => Card(
              child: ListTile(
                title: Text(restaurant['name'] ?? 'Nom non spécifié'),
                subtitle: Text("Note: ${restaurant['rating'] ?? 'Non noté'}"),
                trailing: Text(restaurant['price'] ?? 'Prix non spécifié'),
              ),
            )),
        const SizedBox(height: 16),
        _buildSectionTitle("🎡 Activités disponibles"),
        ...((data['activities'] as List?) ?? []).map((activity) => Card(
              child: ListTile(
                title: Text(activity['name'] ?? 'Nom non spécifié'),
                subtitle: Text(activity['description'] ?? 'Description non spécifiée'),
                trailing: Text("${activity['price'] ?? 'Prix non spécifié'} ${activity['currency'] ?? ''}"),
              ),
            )),
      ],
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> data) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        ElevatedButton.icon(
          onPressed: () => _showBookingDialog({
            'hotelName': data['hotelName'] ?? data['name'] ?? 'Nom non spécifié',
            'location': data['location'] ?? '',
            'price': data['price'] ?? data['totalPrice'] ?? 'Prix non disponible',
          }),
          icon: const Icon(Icons.check_circle, color: Colors.green),
          label: const Text('Confirmer'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.green[50],
            foregroundColor: Colors.green,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showModificationDialog(data),
          icon: const Icon(Icons.edit, color: Colors.orange),
          label: const Text('Modifier'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.orange[50],
            foregroundColor: Colors.orange,
          ),
        ),
        ElevatedButton.icon(
          onPressed: () => _showRefusalDialog(data),
          icon: const Icon(Icons.cancel, color: Colors.red),
          label: const Text('Refuser'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red[50],
            foregroundColor: Colors.red,
          ),
        ),
      ],
    );
  }

  void _showBookingDialog(Map<String, dynamic> data) {
    print('DEBUG HOTEL DATA: $data');
    final TextEditingController emailController = TextEditingController();
    final TextEditingController nameController = TextEditingController();
    final TextEditingController checkInController = TextEditingController();
    final TextEditingController checkOutController = TextEditingController();
    final TextEditingController departureController = TextEditingController(text: _departureLocation);
    final TextEditingController arrivalController = TextEditingController(text: _arrivalLocation);

    // Utiliser uniquement les champs explicitement passés
    final String hotelName = data['hotelName'] ?? 'Nom non spécifié';
    final String price = data['price'] ?? 'Prix non disponible';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmer la réservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Votre nom complet'),
            ),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(labelText: 'Votre email'),
            ),
            TextField(
              controller: departureController,
              decoration: const InputDecoration(labelText: 'Ville de départ'),
            ),
            TextField(
              controller: arrivalController,
              decoration: const InputDecoration(labelText: 'Ville d\'arrivée'),
            ),
            TextField(
              controller: checkInController,
              decoration: const InputDecoration(labelText: 'Date d\'arrivée (YYYY-MM-DD)'),
            ),
            TextField(
              controller: checkOutController,
              decoration: const InputDecoration(labelText: 'Date de départ (YYYY-MM-DD)'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isEmpty ||
                  emailController.text.isEmpty ||
                  checkInController.text.isEmpty ||
                  checkOutController.text.isEmpty ||
                  departureController.text.isEmpty ||
                  arrivalController.text.isEmpty) {
                // Afficher une erreur à l'utilisateur
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez remplir tous les champs.')),
                );
                return;
              }
              handleReservationAction('confirm', {
                ...data,
                'userName': nameController.text,
                'userEmail': emailController.text,
                'checkIn': checkInController.text,
                'checkOut': checkOutController.text,
                'hotelName': hotelName,
                'price': price,
                'departureLocation': departureController.text,
                'arrivalLocation': arrivalController.text,
              });
              Navigator.pop(context);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

  void _showModificationDialog(Map<String, dynamic> data) {
    final TextEditingController messageController = TextEditingController();
    final TextEditingController dateController = TextEditingController();
    final TextEditingController emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier la réservation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: messageController,
              decoration: const InputDecoration(
                labelText: 'Raison de la modification',
                hintText: 'Expliquez les changements souhaités...',
              ),
              maxLines: 3,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: dateController,
              decoration: const InputDecoration(
                labelText: 'Nouvelle date (optionnel)',
                hintText: 'YYYY-MM-DD',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: emailController,
              decoration: const InputDecoration(
                labelText: 'Votre email (obligatoire)',
                hintText: 'exemple@email.com',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              if (emailController.text.isEmpty) {
                // Afficher une erreur si l'email est vide
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Veuillez saisir votre email.')),
                );
                return;
              }
              final modification = {
                if (dateController.text.isNotEmpty) 'newDates': dateController.text,
                'message': messageController.text,
                'userEmail': emailController.text,
              };
              handleReservationAction('modify', data, message: messageController.text, modification: modification);
              Navigator.pop(context);
            },
            child: const Text('Modifier'),
          ),
        ],
      ),
    );
  }

  void _showRefusalDialog(Map<String, dynamic> data) {
    final TextEditingController messageController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refuser la proposition'),
        content: TextField(
          controller: messageController,
          decoration: const InputDecoration(
            labelText: 'Raison du refus',
            hintText: 'Expliquez pourquoi vous refusez cette proposition...',
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          ElevatedButton(
            onPressed: () {
              handleReservationAction('refuse', data, message: messageController.text);
              Navigator.pop(context);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red[50],
              foregroundColor: Colors.red,
            ),
            child: const Text('Refuser'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Text(
        title,
        style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: Colors.deepPurple,
        ),
      ),
    );
  }

  Widget _buildCityCard(Map<String, String> city) {
    return GestureDetector(
      onTap: () {
        setState(() {
          detectedCity = city['name']!;
          _arrivalLocation = detectedCity;
          _conversationState = ConversationState.askingForDeparture;
          messages.add({"role": "user", "text": "Je voudrais visiter ${city['name']}"});
          messages.add({
            "role": "bot",
            "text": "Très bien pour $_arrivalLocation ! D'où souhaitez-vous partir ?",
          });
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
        width: 260,
        child: Stack(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(18),
              child: Image.asset(
                city['image']!,
                height: 170,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            ),
            Positioned(
              top: 10,
              right: 10,
              child: Icon(Icons.favorite_border, color: Colors.white.withOpacity(0.8)),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.92),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(18),
                    bottomRight: Radius.circular(18),
                  ),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${city['name']}, ${city['country']}',
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      city['description']!,
                      style: const TextStyle(
                        color: Colors.black54,
                        fontSize: 13,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildItinerarySection(Map<String, dynamic> itinerary) {
    // Vérifier si l'itinerary est vide
    if (itinerary.isEmpty) {
      return const SizedBox.shrink();
    }

    // Add default content for empty sections
    final defaultContent = {
      'activities': ['Activités suggérées par Chatbot'],
      'local_tips': 'Conseils locaux générés par Chatbot',
      'hidden_gems': 'Lieux secrets suggérés par Chatbot'
    };

    return Card(
      color: Colors.blue[50],
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Votre Itinéraire Personnalisé",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: Colors.blueAccent,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 20),
            ...itinerary.entries.map((entry) {
              final day = entry.key;
              final activities = entry.value as Map<String, dynamic>;
              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Jour ${day.replaceAll('day', '')}",
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.bold,
                          color: Colors.blueGrey,
                        ),
                      ),
                      const SizedBox(height: 12),
                      _buildTimeSlot(
                        "🌅 Matin",
                        _getTimeSlotContent(activities['morning'], defaultContent),
                        Colors.orange.shade100,
                        Icons.wb_sunny_outlined
                      ),
                      const SizedBox(height: 8),
                      _buildTimeSlot(
                        "🌞 Après-midi",
                        _getTimeSlotContent(activities['afternoon'], defaultContent),
                        Colors.yellow.shade100,
                        Icons.beach_access_outlined
                      ),
                      const SizedBox(height: 8),
                      _buildTimeSlot(
                        "🌙 Soir",
                        _getTimeSlotContent(activities['evening'], defaultContent),
                        Colors.purple.shade100,
                        Icons.mode_night_outlined
                      ),
                    ],
                  ),
                ),
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Map<String, dynamic> _getTimeSlotContent(Map<String, dynamic>? slot, Map<String, dynamic> defaultContent) {
    if (slot == null) return defaultContent;
    
    return {
      'activities': (slot['activities'] as List?)?.isNotEmpty == true 
          ? slot['activities'] 
          : defaultContent['activities'],
      'local_tips': slot['local_tips']?.isNotEmpty == true 
          ? slot['local_tips'] 
          : defaultContent['local_tips'],
      'hidden_gems': slot['hidden_gems']?.isNotEmpty == true 
          ? slot['hidden_gems'] 
          : defaultContent['hidden_gems'],
    };
  }

  Widget _buildTimeSlot(String title, Map<String, dynamic> slot, Color colorHint, IconData icon) {
    return Container( // Wrap in Container for background color
      padding: const EdgeInsets.all(10), // Added padding
      decoration: BoxDecoration(
        color: colorHint.withOpacity(0.4), // Use color hint for background
        borderRadius: BorderRadius.circular(8), // Rounded corners
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: Colors.blueGrey[700]), // Use passed icon
              const SizedBox(width: 8),
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: Colors.blueGrey[800], // Darker color
                  fontSize: 16,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8), // Increased spacing
          if (slot['activities'] != null && (slot['activities'] as List).isNotEmpty)
            ...(slot['activities'] as List).map((activity) => Padding(
                  padding: const EdgeInsets.only(left: 8.0, bottom: 4.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.circle, size: 6, color: Colors.blueGrey[400]), // Subtle bullet points
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          activity,
                          style: TextStyle(fontSize: 14, color: Colors.black87),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
          if (slot['local_tips']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6), // Increased spacing
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline, size: 18, color: Colors.green), // Tip icon
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    slot['local_tips'],
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.green,
                      fontSize: 13, // Slightly smaller font
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (slot['hidden_gems']?.isNotEmpty ?? false) ...[
            const SizedBox(height: 6), // Increased spacing
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.diamond_outlined, size: 18, color: Colors.purple), // Hidden gem icon
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    slot['hidden_gems'],
                    style: const TextStyle(
                      fontStyle: FontStyle.italic,
                      color: Colors.purple,
                      fontSize: 13, // Slightly smaller font
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildConversationHistory() {
    if (isLoadingHistory) {
      return const Center(child: CircularProgressIndicator());
    }

    if (conversationHistory.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.history, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              'Aucune conversation',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Commencez une nouvelle conversation',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: conversationHistory.length,
      itemBuilder: (context, index) {
        final conversation = conversationHistory[index];
        final lastMessage = conversation['messages']?.last;
        final date = DateTime.parse(conversation['updatedAt']).toLocal();
        
        return Dismissible(
          key: Key(conversation['_id']),
          background: Container(
            color: Colors.red,
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: 20),
            child: const Icon(Icons.delete, color: Colors.white),
          ),
          secondaryBackground: Container(
            color: Colors.orange,
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: 20),
            child: const Icon(Icons.archive, color: Colors.white),
          ),
          confirmDismiss: (direction) async {
            if (direction == DismissDirection.startToEnd) {
              // Archive
              await _archiveConversation(conversation['_id']);
              return false;
            } else {
              // Delete
              return await showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Supprimer la conversation'),
                  content: const Text('Êtes-vous sûr de vouloir supprimer cette conversation ?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('Annuler'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('Supprimer'),
                    ),
                  ],
                ),
              );
            }
          },
          onDismissed: (direction) {
            if (direction == DismissDirection.endToStart) {
              _deleteConversation(conversation['_id']);
            }
          },
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              leading: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.deepPurple[50],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Center(
                  child: Text(
                    conversation['detectedCity']?.substring(0, 1).toUpperCase() ?? '🌍',
                    style: TextStyle(
                      color: Colors.deepPurple[700],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              title: GestureDetector(
                onTap: () => _showEditTitleDialog(conversation['_id'], conversation['title']),
                child: Text(
                  conversation['title'] ?? 'Conversation sans titre',
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (lastMessage != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        lastMessage['text'] ?? '',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.grey[600],
                          fontSize: 13,
                        ),
                      ),
                    ),
                  Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      '${date.day}/${date.month}/${date.year}',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[500],
                      ),
                    ),
                  ),
                ],
              ),
              onTap: () {
                setState(() {
                  messages = List<Map<String, dynamic>>.from(conversation['messages']);
                  _currentUserId = conversation['userId']?.toString();
                });
              },
            ),
          ),
        );
      },
    );
  }

  void _showEditTitleDialog(String conversationId, String currentTitle) {
    final TextEditingController titleController = TextEditingController(text: currentTitle);
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Modifier le titre'),
        content: TextField(
          controller: titleController,
          decoration: const InputDecoration(
            labelText: 'Nouveau titre',
            hintText: 'Entrez un nouveau titre pour la conversation',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Annuler'),
          ),
          TextButton(
            onPressed: () {
              if (titleController.text.isNotEmpty) {
                _updateConversationTitle(conversationId, titleController.text);
                Navigator.pop(context);
              }
            },
            child: const Text('Enregistrer'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Row(
          children: [
            // Panneau latéral avec l'historique
            Container(
              width: 300,
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  right: BorderSide(
                    color: Colors.grey[200]!,
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: Colors.grey[200]!,
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.history, color: Colors.deepPurple),
                        const SizedBox(width: 8),
                        const Text(
                          'Historique',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.deepPurple,
                          ),
                        ),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.refresh, size: 20),
                          onPressed: loadConversationHistory,
                          tooltip: 'Actualiser',
                        ),
                        // New button to start a new conversation
                        IconButton(
                          icon: const Icon(Icons.add, size: 20),
                          onPressed: _startNewConversation,
                          tooltip: 'Nouvelle conversation',
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _buildConversationHistory(),
                  ),
                ],
              ),
            ),
            // Zone principale du chat
            Expanded(
              child: Column(
                children: [
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: const [
                      Text("🦜", style: TextStyle(fontSize: 32)),
                      SizedBox(width: 8),
                      Text("SAMWay", style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text("💬 Assistant de Voyage", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                  if (detectedCity.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.all(8.0),
                      child: Text("🌍 Ville détectée : $detectedCity",
                          style: const TextStyle(fontStyle: FontStyle.italic, color: Colors.deepPurple)),
                    ),
                  SizedBox(
                    height: 210,
                    child: ListView.builder(
                      scrollDirection: Axis.horizontal,
                      itemCount: cityCards.length,
                      itemBuilder: (context, index) {
                        return _buildCityCard(cityCards[index]);
                      },
                    ),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.builder(
                      itemCount: messages.length,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      itemBuilder: (context, index) => _buildMessage(messages[index]),
                    ),
                  ),
                  const Divider(height: 1),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _controller,
                            decoration: const InputDecoration(
                              hintText: "Décrivez votre voyage idéal...",
                              border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                            ),
                            onSubmitted: (_) => sendMessage(),
                          ),
                        ),
                        const SizedBox(width: 8),
                        isLoading
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator())
                            : IconButton(
                                icon: const Icon(Icons.send, color: Colors.deepPurple),
                                onPressed: sendMessage,
                              ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}