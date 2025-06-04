const express = require('express');
const { MongoClient } = require('mongodb');
const fetch = require('node-fetch');
const router = express.Router();
const { executeAction } = require('../services/actionExecutor');
const { sendConfirmationEmail } = require('../services/emailService');
const Conversation = require('../models/Conversation');
const mongoose = require('mongoose');

const url = 'mongodb://localhost:27017';
const dbName = 'TravelPlanner';

// Fonctions MongoDB
const getHotelsFromDB = async (query) => {
  console.log('🔎 [MongoDB] Recherche hôtels avec query:', query);
  const client = new MongoClient(url);
  try {
    await client.connect();
    const db = client.db(dbName);
    const hotelsCollection = db.collection('hotels');
    const hotels = await hotelsCollection.find(query).limit(5).toArray();
    console.log('🏨 Hôtels trouvés:', hotels.length);
    return hotels;
  } finally {
    await client.close();
  }
};

const getRestaurantsFromDB = async (query) => {
  console.log('🔎 [MongoDB] Recherche restaurants avec query:', query);
  const client = new MongoClient(url);
  try {
    await client.connect();
    const db = client.db(dbName);
    const restaurantsCollection = db.collection('Restaurants');
    const restaurants = await restaurantsCollection.find(query).limit(5).toArray();
    console.log('🍽️ Restaurants trouvés:', restaurants.length);
    return restaurants;
  } finally {
    await client.close();
  }
};

const getActivitiesFromDB = async (query) => {
  console.log('🔎 [MongoDB] Recherche activités avec query:', query);
  const client = new MongoClient(url);
  try {
    await client.connect();
    const db = client.db(dbName);
    const activitiesCollection = db.collection('activities');
    const activities = await activitiesCollection.find(query).limit(5).toArray();
    console.log('🎡 Activités trouvées:', activities.length);
    return activities;
  } finally {
    await client.close();
  }
};

// === FONCTIONS EXTERNES AVEC AVIATIONSTACK ===
const AVIATIONSTACK_KEY = 'ea74e13e668a4c3482becd7d53866017';

const getAirportsByCity = async (city) => {
  console.log('✈️ [Aviationstack] Recherche aéroports pour la ville:', city);
  const url = `http://api.aviationstack.com/v1/airports?access_key=${AVIATIONSTACK_KEY}&city_name=${encodeURIComponent(city)}`;
  const response = await fetch(url);
  const data = await response.json();
  console.log('✈️ [Aviationstack] Nombre d\'aéroports trouvés:', (data.data || []).length);
  return data.data || [];
};

const getFlightsByAirport = async (iata, date) => {
  console.log('🛬 [Aviationstack] Recherche vols pour IATA:', iata, 'à la date:', date);
  const url = `http://api.aviationstack.com/v1/flights?access_key=${AVIATIONSTACK_KEY}&arrival_iata=${iata}&flight_date=${date}`;
  const response = await fetch(url);
  const data = await response.json();
  console.log('🛬 [Aviationstack] Nombre de vols trouvés:', (data.data || []).length);
  return data.data || [];
};

const callGeminiAPI = async (userMessage) => {
  console.log('🤖 [Gemini] Préparation de l\'appel API');
  const body = {
    contents: [{ role: 'user', parts: [{ text: userMessage }] }]
  };
  const response = await fetch('https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash-latest:generateContent?key=AIzaSyCS_dwh4ulePklyplO82BR7ro-VhmeM4_g', {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(body)
  });
  if (!response.ok) {
    const error = await response.json();
    console.error('❌ [Gemini] Erreur API:', error);
    throw new Error(`Erreur Gemini: ${error.error.message}`);
  }
  const data = await response.json();
  console.log('✅ [Gemini] Réponse reçue');
  return data.candidates?.[0]?.content?.parts?.[0]?.text || 'Aucune réponse générée.';
};

// Extraction automatique de la date depuis le message
function extractDateFromMessage(message) {
  console.log('📅 [Date] Extraction de la date depuis le message');
  const regex = /([0-9]{4}-[0-9]{2}-[0-9]{2})|([0-9]{2}[\/-][0-9]{2}[\/-][0-9]{4})/;
  const match = message.match(regex);
  if (match) {
    let dateStr = match[0];
    if (/^[0-9]{2}[\/-][0-9]{2}[\/-][0-9]{4}$/.test(dateStr)) {
      const [day, month, year] = dateStr.split(/[\/-]/);
      dateStr = `${year}-${month}-${day}`;
    }
    console.log('📅 [Date] Date extraite:', dateStr);
    return dateStr;
  }
  console.log('📅 [Date] Aucune date trouvée dans le message');
  return null;
}

// Détection ville/quartier
function detectVilleEtQuartier(message) {
  console.log('🏙️ [Ville/Quartier] Détection dans le message');
  const msg = message.normalize("NFD").replace(/[\u0300-\u036f]/g, "").toLowerCase();
  
  const quartiersParVille = {
    Paris: [
      "batignolles", "8th Arr. - Élysée", "montparnasse", "champs", "louvre", "opéra", "belleville", "montmartre",
      "défense", "saint-germain", "charonne", "butte", "passy", "grenelle", "marais", "bastille", "la chapelle",
      "clichy", "villette", "auteuil", "trocadéro", "invalides", "quartier latin", "châtelet"
    ],
    Madrid: [
      "salamanca", "chamberí", "malasaña", "la latina", "retiro", "centro", "argüelles", "chamartín", "paseo del prado"
    ],
    "New York City": [
      "manhattan", "downtown", "midtown", "hudson yards", "theater district", "brooklyn", "queens", "staten island",
      "greenwich village"
    ],
    "San Francisco": [
      "tenderloin"
    ],
    Istanbul: [
      "beyoğlu", "sultanahmet", "taksim", "kadıköy", "beşiktaş"
    ],
    Casablanca: [
      "maarif", "ain diab", "anfa", "sidi maarouf", "hay hassani", "oulfa", "bouskoura", "sidi bernoussi", "casanearshore"
    ],
    Rabat: [
      "agdal", "hay riad", "souissi", "océan", "youssoufia", "akkari", "medina", "salmia", "takaddoum"
    ]
  };

  for (const [ville, quartiers] of Object.entries(quartiersParVille)) {
    for (const quartier of quartiers) {
      if (msg.includes(quartier.toLowerCase())) {
        console.log(`🏙️ [Ville/Quartier] Détecté: ${ville}, ${quartier}`);
        return { ville, quartier };
      }
    }
    if (msg.includes(ville.toLowerCase())) {
      console.log(`🏙️ [Ville/Quartier] Détecté: ${ville}, tous les quartiers`);
      return { ville, quartier: "tous les quartiers" };
    }
  }
  console.log('❌ [Ville/Quartier] Aucune ville ou quartier détecté');
  return null;
}

// Principaux aéroports en dur pour toutes les villes
const AIRPORTS_MANUAL = {
  paris: [
    { airport_name: 'Paris Charles de Gaulle', iata_code: 'CDG' },
    { airport_name: 'Paris Orly', iata_code: 'ORY' },
    { airport_name: 'Paris Beauvais', iata_code: 'BVA' }
  ],
  madrid: [
    { airport_name: 'Adolfo Suárez Madrid–Barajas', iata_code: 'MAD' }
  ],
  'new york city': [
    { airport_name: 'John F. Kennedy International', iata_code: 'JFK' },
    { airport_name: 'LaGuardia', iata_code: 'LGA' },
    { airport_name: 'Newark Liberty International', iata_code: 'EWR' }
  ],
  'san francisco': [
    { airport_name: 'San Francisco International', iata_code: 'SFO' },
    { airport_name: 'Oakland International', iata_code: 'OAK' }
  ],
  istanbul: [
    { airport_name: 'Istanbul Airport', iata_code: 'IST' },
    { airport_name: 'Sabiha Gokcen', iata_code: 'SAW' }
  ],
  casablanca: [
    { airport_name: 'Mohammed V International', iata_code: 'CMN' }
  ],
  rabat: [
    { airport_name: 'Rabat–Salé Airport', iata_code: 'RBA' }
  ]
};

// Fonction pour calculer la durée du séjour
const calculateStayDuration = (departureDate, arrivalDate) => {
  if (!departureDate || !arrivalDate) return 0; // Retourner 0 si pas de dates spécifiées
  
  const start = new Date(departureDate);
  const end = new Date(arrivalDate);
  
  // Vérifier que les dates sont valides
  if (isNaN(start.getTime()) || isNaN(end.getTime())) return 0;
  if (start > end) return 0; // Si la date de départ est après la date d'arrivée
  
  // Calculer la différence en jours
  const diffTime = end.getTime() - start.getTime();
  const diffDays = Math.ceil(diffTime / (1000 * 60 * 60 * 24));
  
  // Retourner la durée calculée
  return diffDays > 0 ? diffDays : 0;
};

// Fonction pour générer un itinéraire dynamique
const generateDynamicItinerary = (duration) => {
  if (duration <= 0) return {}; // Retourner un itinéraire vide si la durée est invalide
  
  const itinerary = {};
  for (let i = 1; i <= duration; i++) {
    itinerary[`day${i}`] = {
      morning: {
        activities: ["À planifier"],
        local_tips: "Journée à personnaliser selon vos préférences",
        hidden_gems: "Découvrez les quartiers moins touristiques"
      },
      afternoon: {
        activities: ["À planifier"],
        local_tips: "Journée à personnaliser selon vos préférences",
        hidden_gems: "Explorez les cafés et restaurants locaux"
      },
      evening: {
        activities: ["À planifier"],
        local_tips: "Journée à personnaliser selon vos préférences",
        hidden_gems: "Profitez de l\'ambiance nocturne parisienne"
      }
    };
  }
  return itinerary;
};

// Nouvelle fonction pour le Chain of Thought Reasoning
const chainOfThoughtReasoning = async (userMessage, context) => {
  console.log('🧠 [ChainOfThought] Début de la réflexion pour:', userMessage);
  
  // Calculer la durée du séjour
  const duration = calculateStayDuration(context.departureDate, context.arrivalDate);
  if (duration <= 0) {
    console.log('⚠️ Durée de séjour invalide:', duration);
    return {
      response: "Désolé, les dates fournies ne sont pas valides. Veuillez vérifier que la date de retour est après la date de départ.",
      reasoning: {
        steps: [],
        suggested_itinerary: {},
        hotel_suggestions: {},
        restaurant_suggestions: {},
        local_experiences: {}
      }
    };
  }

  const dynamicItinerary = generateDynamicItinerary(duration);
  
  const prompt = `En tant qu'expert voyage passionné et créatif, analysez la demande suivante et créez une expérience de voyage unique et mémorable :
  Message: "${userMessage}"
  Contexte: ${JSON.stringify(context)}
  Durée du séjour: ${duration} jours
  
  IMPORTANT: Vous DEVEZ générer un itinéraire pour EXACTEMENT ${duration} jours. Chaque jour doit avoir des activités pour le matin, l'après-midi et le soir.
  L'itinéraire doit être structuré comme suit:
  {
    "day1": { "morning": {...}, "afternoon": {...}, "evening": {...} },
    "day2": { "morning": {...}, "afternoon": {...}, "evening": {...} },
    ...
    "day${duration}": { "morning": {...}, "afternoon": {...}, "evening": {...} }
  }
  
  Répondez UNIQUEMENT avec un objet JSON valide, sans backticks ni marqueurs de code. Format attendu :
  {
    "response": "Une réponse captivante et personnalisée qui raconte une histoire de voyage, incluant des anecdotes locales, des conseils d'expert et des suggestions uniques",
    "reasoning": {
      "steps": [
        {
          "action": "recherche_hotels",
          "criteria": ["critère1", "critère2"],
          "priority": 1,
          "personalization": "Comment adapter les critères aux préférences du voyageur"
        },
        {
          "action": "recherche_activites",
          "criteria": ["critère1", "critère2"],
          "priority": 2,
          "personalization": "Comment créer une expérience authentique et locale"
        }
      ],
      "suggested_itinerary": ${JSON.stringify(dynamicItinerary)},
      "hotel_suggestions": {
        "budget": {
          "options": ["hôtel1", "hôtel2"],
          "local_insights": "Pourquoi ces hôtels sont uniques",
          "neighborhood_tips": "Conseils sur le quartier"
        },
        "mid_range": {
          "options": ["hôtel1", "hôtel2"],
          "local_insights": "Pourquoi ces hôtels sont uniques",
          "neighborhood_tips": "Conseils sur le quartier"
        },
        "luxury": {
          "options": ["hôtel1", "hôtel2"],
          "local_insights": "Pourquoi ces hôtels sont uniques",
          "neighborhood_tips": "Conseils sur le quartier"
        }
      },
      "restaurant_suggestions": {
        "breakfast": {
          "options": ["restaurant1", "restaurant2"],
          "specialties": "Plats typiques à ne pas manquer",
          "local_etiquette": "Conseils sur les usages locaux"
        },
        "lunch": {
          "options": ["restaurant1", "restaurant2"],
          "specialties": "Plats typiques à ne pas manquer",
          "local_etiquette": "Conseils sur les usages locaux"
        },
        "dinner": {
          "options": ["restaurant1", "restaurant2"],
          "specialties": "Plats typiques à ne pas manquer",
          "local_etiquette": "Conseils sur les usages locaux"
        }
      },
      "local_experiences": {
        "cultural_insights": ["Expérience culturelle 1", "Expérience culturelle 2"],
        "hidden_gems": ["Endroit secret 1", "Endroit secret 2"],
        "seasonal_events": ["Événement 1", "Événement 2"]
      }
    }
  }`;

  try {
    const response = await callGeminiAPI(prompt);
    // Nettoyer la réponse pour enlever les backticks et les marqueurs de code
    const cleanedResponse = response
      .replace(/```json\s*/g, '')  // Enlever ```json
      .replace(/```\s*/g, '')      // Enlever ```
      .replace(/^\s*{\s*/, '{')    // Nettoyer les espaces au début
      .replace(/\s*}\s*$/, '}');   // Nettoyer les espaces à la fin
    
    console.log('🧠 Réponse nettoyée:', cleanedResponse);
    const parsedResponse = JSON.parse(cleanedResponse);

    // Vérifier et ajuster l'itinéraire si nécessaire
    let suggestedItinerary = parsedResponse.reasoning?.suggested_itinerary || dynamicItinerary;
    
    // S'assurer que l'itinéraire a le bon nombre de jours
    if (Object.keys(suggestedItinerary).length !== duration) {
      console.log(`⚠️ Ajustement de l'itinéraire: ${Object.keys(suggestedItinerary).length} jours trouvés, ${duration} jours requis`);
      
      // Si l'itinéraire a moins de jours que requis, ajouter les jours manquants
      for (let i = Object.keys(suggestedItinerary).length + 1; i <= duration; i++) {
        suggestedItinerary[`day${i}`] = {
          morning: {
            activities: ["À planifier"],
            local_tips: "Journée à personnaliser selon vos préférences",
            hidden_gems: "Découvrez les quartiers moins touristiques"
          },
          afternoon: {
            activities: ["À planifier"],
            local_tips: "Journée à personnaliser selon vos préférences",
            hidden_gems: "Explorez les cafés et restaurants locaux"
          },
          evening: {
            activities: ["À planifier"],
            local_tips: "Journée à personnaliser selon vos préférences",
            hidden_gems: "Profitez de l'ambiance nocturne parisienne"
          }
        };
      }
    }

    // Si l'itinéraire a plus de jours que requis, supprimer les jours en trop
    if (Object.keys(suggestedItinerary).length > duration) {
      console.log(`⚠️ Suppression des jours en trop: ${Object.keys(suggestedItinerary).length} jours trouvés, ${duration} jours requis`);
      const daysToKeep = Object.keys(suggestedItinerary).slice(0, duration);
      const newItinerary = {};
      daysToKeep.forEach(day => {
        newItinerary[day] = suggestedItinerary[day];
      });
      suggestedItinerary = newItinerary;
    }

    // Vérifier et compléter la structure si nécessaire
    return {
      response: parsedResponse.response || "Je n'ai pas pu générer une réponse appropriée.",
      reasoning: {
        steps: parsedResponse.reasoning?.steps || [],
        suggested_itinerary: suggestedItinerary,
        hotel_suggestions: parsedResponse.reasoning?.hotel_suggestions || {
          budget: { options: [], local_insights: "", neighborhood_tips: "" },
          mid_range: { options: [], local_insights: "", neighborhood_tips: "" },
          luxury: { options: [], local_insights: "", neighborhood_tips: "" }
        },
        restaurant_suggestions: parsedResponse.reasoning?.restaurant_suggestions || {
          breakfast: { options: [], specialties: "", local_etiquette: "" },
          lunch: { options: [], specialties: "", local_etiquette: "" },
          dinner: { options: [], specialties: "", local_etiquette: "" }
        },
        local_experiences: parsedResponse.reasoning?.local_experiences || {
          cultural_insights: [],
          hidden_gems: [],
          seasonal_events: []
        }
      }
    };
  } catch (error) {
    console.error('❌ [ChainOfThought] Erreur lors de la réflexion:', error);
    // En cas d'erreur, retourner une structure par défaut avec l'itinéraire dynamique
    return {
      response: "Je suis désolé, je n'ai pas pu traiter votre demande correctement. Veuillez réessayer.",
      reasoning: {
        steps: [
          {
            action: "recherche_hotels",
            criteria: ["tous"],
            priority: 1,
            personalization: "Recherche d'hôtels adaptés à tous les budgets"
          },
          {
            action: "recherche_activites",
            criteria: ["tous"],
            priority: 2,
            personalization: "Recherche d'activités pour tous les goûts"
          }
        ],
        suggested_itinerary: dynamicItinerary,
        hotel_suggestions: {
          budget: {
            options: ["Hôtel Turenne Le Marais", "citizenM Paris Gare de Lyon"],
            local_insights: "Hôtels avec une excellente localisation",
            neighborhood_tips: "Quartiers animés et bien desservis"
          },
          mid_range: {
            options: ["Secret de Paris - Hotel & Spa", "B Montmartre Hotel"],
            local_insights: "Hôtels avec charme et confort",
            neighborhood_tips: "Quartiers authentiques et pittoresques"
          },
          luxury: {
            options: ["Le Bristol Paris", "Hôtel Plaza Athénée"],
            local_insights: "Hôtels de luxe avec service exceptionnel",
            neighborhood_tips: "Quartiers prestigieux et élégants"
          }
        },
        restaurant_suggestions: {
          breakfast: {
            options: ["Café de Flore", "Ladurée"],
            specialties: "Pâtisseries françaises traditionnelles",
            local_etiquette: "Le petit-déjeuner à la française"
          },
          lunch: {
            options: ["Le Petit Bistrot", "Chez Janou"],
            specialties: "Cuisine française authentique",
            local_etiquette: "Le déjeuner à la française"
          },
          dinner: {
            options: ["Le Grand Véfour", "L'Ami Louis"],
            specialties: "Gastronomie française raffinée",
            local_etiquette: "Le dîner à la française"
          }
        },
        local_experiences: {
          cultural_insights: ["Marchés locaux", "Visites guidées insolites"],
          hidden_gems: ["Passages couverts", "Jardins secrets"],
          seasonal_events: ["Festivals locaux", "Événements culturels"]
        }
      }
    };
  }
};

// Nouvelle fonction pour la gestion des actions
const handleUserAction = async (action, params) => {
  console.log('⚡ [ActionEngine] Exécution de l\'action:', action, params);
  
  try {
    switch (action) {
      case 'book_hotel':
        return await executeAction('bookHotel', params);
      case 'search_hotels':
        return await executeAction('searchHotels', params);
      case 'search_activities':
        return await executeAction('searchActivities', params);
      default:
        throw new Error(`Action non reconnue: ${action}`);
    }
  } catch (error) {
    console.error('❌ [ActionEngine] Erreur lors de l\'exécution:', error);
    throw error;
  }
};

// Function to parse structured travel messages
const parseTravelMessage = (message) => {
  console.log('🔍 [Parser] Analyzing message:', message);
  
  // Pattern: "Voyage de [departure] à [arrival] du [departure_date] au [arrival_date]"
  const pattern = /Voyage de (.*?) à (.*?) du (.*?) au (.*?)$/;
  const match = message.match(pattern);
  
  if (match) {
    const [_, departureLocation, arrivalLocation, departureDate, arrivalDate] = match;
    console.log('✅ [Parser] Travel details extracted:', {
      departureLocation,
      arrivalLocation,
      departureDate,
      arrivalDate
    });
    return {
      departureLocation: departureLocation.trim(),
      arrivalLocation: arrivalLocation.trim(),
      departureDate: departureDate.trim(),
      arrivalDate: arrivalDate.trim()
    };
  }
  
  console.log('❌ [Parser] No structured travel message pattern found');
  return null;
};

// Fonction de détection de requête illégale (insensible à la casse et aux accents)
function isIllegalRequest(message) {
  const illegalKeywords = [
    'pirater', 'faux passeport', 'drogue', 'arnaque', 'hack', 'illégal', 'illégale', 'terrorisme', 'crime'
  ];
  if (!message) return false;
  // Supprime les accents et met en minuscule
  const lowerMsg = message.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase();
  return illegalKeywords.some(keyword => lowerMsg.includes(keyword));
}

// Route principale pour le chat
router.post('/', async (req, res) => {
  let { message, dateVoyage, origin, userId } = req.body;
  console.log('📝 Message reçu:', message);
  console.log('👤 UserId reçu:', userId);
  
  // Log the full request body to see what is received from frontend
  console.log('🔍 Req body received:', req.body);

  if (!message) return res.status(400).json({ error: 'Message requis' });

  // Validation de l'userId
  if (!userId) {
    // Générer un nouvel userId si non fourni
    userId = new mongoose.Types.ObjectId();
    console.log('🆕 Nouvel userId généré:', userId);
  }

  // Filtre anti-action illégale (tout en haut)
  if (isIllegalRequest(message)) {
    return res.status(403).json({
      response: "Je suis désolé, je ne peux pas vous aider pour cette demande."
    });
  }

  // Convertir l'userId en ObjectId
  let userObjectId;
  try {
    userObjectId = new mongoose.Types.ObjectId(userId);
    console.log('✅ userId converti en ObjectId:', userObjectId);
  } catch (e) {
    console.error('❌ Erreur conversion userId en ObjectId:', e);
    // Si l'userId n'est pas un format valide, en générer un nouveau
    userObjectId = new mongoose.Types.ObjectId();
    console.log('🆕 Nouvel ObjectId généré:', userObjectId);
  }

  try {
    // 1. Extraction des informations de base
    let departureDate, arrivalDate;
    const travelDetails = parseTravelMessage(message);
    if (travelDetails) {
      departureDate = travelDetails.departureDate;
      arrivalDate = travelDetails.arrivalDate;
      console.log('📅 Dates extraites:', { departureDate, arrivalDate });
    } else if (!dateVoyage) {
      dateVoyage = extractDateFromMessage(message);
      if (dateVoyage) {
        console.log('📅 Date de voyage détectée automatiquement:', dateVoyage);
        departureDate = dateVoyage;
        // Par défaut, on considère un séjour de 3 jours si pas de date de retour spécifiée
        const endDate = new Date(dateVoyage);
        endDate.setDate(endDate.getDate() + 3);
        arrivalDate = endDate.toISOString().split('T')[0];
      }
    }

    const result = detectVilleEtQuartier(message);
    if (!result) {
      console.log('❌ Ville ou quartier non détecté dans le message');
      return res.status(200).json({
        response: `Je n'ai pas identifié de quartier ou de ville. Essayez par exemple : "Que faire à Montmartre", "Hôtels à Manhattan", ou "Activités à Taksim".`,
        userId: userObjectId.toString() // Retourner l'userId pour le frontend
      });
    }

    const { ville, quartier } = result;
    console.log(`✅ Ville détectée: ${ville}, Quartier détecté: ${quartier}`);

    // 2. Chain of Thought Reasoning
    const context = {
      ville,
      quartier,
      departureDate,
      arrivalDate,
      dateVoyage,
      origin,
      userId: userObjectId.toString() // Ajouter l'userId au contexte
    };
    
    const reasoning = await chainOfThoughtReasoning(message, context);
    console.log('🧠 Résultat de la réflexion:', reasoning);

    // Définir les requêtes pour MongoDB
    let hotelQuery = {};
    let restaurantQuery = {};
    let activityQuery = {};

    if (quartier === "tous les quartiers") {
      hotelQuery = {
        $or: [
          { 'data.data.title': new RegExp(ville, 'i') },
          { 'data.data.secondaryInfo': new RegExp(ville, 'i') }
        ]
      };
      restaurantQuery = {
        $or: [
          { 'data.restaurants.name': new RegExp(ville, 'i') }
        ]
      };
      activityQuery = {
        $or: [
          { 'data.products.name': new RegExp(ville, 'i') }
        ]
      };
      console.log('🔍 Recherche pour tous les quartiers à:', ville);
    } else {
      hotelQuery = {
        $or: [
          { 'data.data.title': new RegExp(quartier, 'i') },
          { 'data.data.secondaryInfo': new RegExp(quartier, 'i') }
        ]
      };
      restaurantQuery = {
        $or: [
          { 'data.restaurants.name': new RegExp(quartier, 'i') }
        ]
      };
      activityQuery = {
        $or: [
          { 'data.products.name': new RegExp(quartier, 'i') }
        ]
      };
      console.log(`🔍 Recherche pour le quartier ${quartier} à ${ville}`);
    }

    // 3. Exécution des actions en parallèle
    const [hotels, restaurants, activities, airports] = await Promise.all([
      getHotelsFromDB(hotelQuery),
      getRestaurantsFromDB(restaurantQuery),
      getActivitiesFromDB(activityQuery),
      getAirportsByCity(ville)
    ]);

    // 4. Formatage des données
    const formattedHotels = hotels.flatMap(hotel => {
      if (!hotel || !hotel.data) return [];
      const hotelData = Array.isArray(hotel.data) ? hotel.data : [hotel.data];
      return hotelData.flatMap(data => {
        if (!data || !data.data) return [];
        const items = Array.isArray(data.data) ? data.data : [data.data];
        return items.map(h => ({
          name: h.title?.trim() || '',
          location: h.secondaryInfo?.trim() || '',
          price: h.priceForDisplay || 'Prix non communiqué',
          description: h.priceSummary || 'Pas de description',
        }));
      });
    });

    const formattedRestaurants = restaurants.flatMap(r => {
      if (!r || !r.data) return [];
      const restaurantData = Array.isArray(r.data) ? r.data : [r.data];
      return restaurantData.flatMap(data => {
        if (!data || !data.restaurants) return [];
        const items = Array.isArray(data.restaurants) ? data.restaurants : [data.restaurants];
        return items.map(resto => ({
          name: resto.name || '',
          rating: resto.averageRating || 'Non noté',
          price: resto.priceTag || 'Prix non communiqué',
          cuisine: (resto.establishmentTypeAndCuisineTags || []).join(', ') || 'Non spécifié',
          url: resto.menuUrl || '',
          status: resto.currentOpenStatus || 'Statut inconnu'
        }));
      });
    });

    const formattedActivities = activities.flatMap(a => {
      if (!a || !a.data) return [];
      const activityData = Array.isArray(a.data) ? a.data : [a.data];
      return activityData.flatMap(data => {
        if (!data || !data.products) return [];
        const items = Array.isArray(data.products) ? data.products : [data.products];
        return items.map(act => ({
          name: act.name || '',
          description: act.shortDescription || 'Pas de description',
          price: act.representativePrice?.publicAmount || 'Prix non communiqué',
          currency: act.representativePrice?.currency || ''
        }));
      });
    });

    console.log('🏨 Hôtels formatés:', formattedHotels.length);
    console.log('🍽️ Restaurants formatés:', formattedRestaurants.length);
    console.log('🎡 Activités formatées:', formattedActivities.length);

    // Recherche aéroports destination
    let filteredAirports = airports.filter(a =>
      a.city_name && a.city_name.toLowerCase().includes(ville.toLowerCase())
    );

    if (!filteredAirports.length && airports.length) {
      filteredAirports = airports.filter(a =>
        (a.airport_name && a.airport_name.toLowerCase().includes(ville.toLowerCase())) ||
        (a.country_name && a.country_name.toLowerCase().includes(ville.toLowerCase()))
      );
    }

    let airportsWarning = '';
    if (!filteredAirports.length && airports.length) {
      airportsWarning = `⚠️ Aucun aéroport trouvé pour la ville "${ville}" dans les résultats. Voici la liste brute retournée par l'API :\n`;
      filteredAirports = airports;
    }
    if (!filteredAirports.length && AIRPORTS_MANUAL[ville.toLowerCase()]) {
      airportsWarning = `⚠️ Aucun aéroport trouvé pour "${ville}" dans l'API. Voici les principaux aéroports ajoutés manuellement :\n`;
      filteredAirports = AIRPORTS_MANUAL[ville.toLowerCase()];
    }
    console.log('✈️ Aéroports filtrés:', filteredAirports.length);

    // Recherche aéroports de départ si origin fourni
    let originAirports = [];
    let originAirportsWarning = '';
    if (origin) {
      let airportsOriginRaw = await getAirportsByCity(origin);
      console.log('🛫 Aéroports bruts trouvés pour origin:', airportsOriginRaw.length);
      
      originAirports = airportsOriginRaw.filter(a =>
        a.city_name && a.city_name.toLowerCase().includes(origin.toLowerCase())
      );

      if (!originAirports.length && airportsOriginRaw.length) {
        originAirports = airportsOriginRaw.filter(a =>
          (a.airport_name && a.airport_name.toLowerCase().includes(origin.toLowerCase())) ||
          (a.country_name && a.country_name.toLowerCase().includes(origin.toLowerCase()))
        );
      }

      if (!originAirports.length && airportsOriginRaw.length) {
        originAirportsWarning = `⚠️ Aucun aéroport trouvé pour la ville "${origin}" dans les résultats. Voici la liste brute retournée par l'API :\n`;
        originAirports = airportsOriginRaw;
      }

      if (!originAirports.length && AIRPORTS_MANUAL[origin.toLowerCase()]) {
        originAirportsWarning = `⚠️ Aucun aéroport trouvé pour "${origin}" dans l'API. Voici les principaux aéroports ajoutés manuellement :\n`;
        originAirports = AIRPORTS_MANUAL[origin.toLowerCase()];
      }
      console.log('🛫 Aéroports filtrés pour origin:', originAirports.length);
    }

    // Recherche vols si date et aéroports trouvés
    let flights = [];
    if (filteredAirports.length && dateVoyage) {
      const destIata = filteredAirports[0].iata_code;
      flights = await getFlightsByAirport(destIata, dateVoyage);
      console.log('🛬 Vols trouvés:', flights.length);
    }

    // 5. Construction du prompt final avec l'itinéraire suggéré
    const duration = calculateStayDuration(departureDate, arrivalDate);
    console.log(`📅 Durée du séjour calculée: ${duration} jours`);

    const prompt = `En tant qu'assistant de voyage SAMWay, créez un plan de voyage détaillé pour ${ville} dans le quartier ${quartier}. Structurez votre réponse comme un véritable plan de voyage avec des conseils pratiques.

PLAN DE VOYAGE - ${ville} (${quartier})
=====================================

IMPORTANT: Vous DEVEZ générer un itinéraire pour EXACTEMENT ${duration} jours. Chaque jour doit avoir des activités pour le matin, l'après-midi et le soir.

1. ARRIVÉE
----------
- Aéroport d'arrivée : [Sélectionner parmi les aéroports disponibles]
- Transport depuis l'aéroport : [Options de transport recommandées]
- Durée estimée du trajet : [Temps de trajet]

2. HÉBERGEMENT
-------------
- Hôtel recommandé : [Nom de l'hôtel] (catégorie)
- Localisation : [Quartier/Adresse]
- Points forts : [Pourquoi ce choix est idéal]
- Prix par nuit : [Montant]

3. ITINÉRAIRE JOUR PAR JOUR (${duration} jours)
--------------------------
${Array.from({length: duration}, (_, i) => `Jour ${i + 1} :
- Matin : [Activité 1] - [Conseils pratiques]
- Après-midi : [Activité 2] - [Conseils pratiques]
- Soirée : [Activité 3] - [Conseils pratiques]`).join('\n\n')}

4. RESTAURATION
--------------
- Petit-déjeuner : [Restaurant 1] - [Spécialité]
- Déjeuner : [Restaurant 2] - [Spécialité]
- Dîner : [Restaurant 3] - [Spécialité]

5. BUDGET ESTIMÉ
---------------
- Hébergement : [Montant] (${duration} nuits)
- Activités : [Montant]
- Restauration : [Montant]
- Transport : [Montant]
Total : [Montant total] € pour ${duration} jours

6. CONSEILS PRATIQUES
--------------------
- Meilleure période pour visiter : [Période]
- À ne pas oublier : [Liste d'objets essentiels]
- Conseils locaux : [Astuces pratiques]
- Transports locaux : [Options recommandées]

Voulez-vous que je procède à la réservation ? ✅/❌

Utilisez les données suivantes pour créer ce plan de voyage :

Aéroports disponibles :
${filteredAirports.length ? filteredAirports.map(a => `- ${a.airport_name} (${a.iata_code})`).join('\n') : 'Aucun aéroport trouvé'}

Hôtels disponibles :
${formattedHotels.length ? formattedHotels.map(h => `- ${h.name} (${h.location}) | ${h.price} | ${h.description}`).join('\n') : 'Aucun hôtel trouvé'}

Restaurants disponibles :
${formattedRestaurants.length ? formattedRestaurants.map(r => `- ${r.name} | ${r.cuisine} | ${r.price} | ${r.status}`).join('\n') : 'Aucun restaurant trouvé'}

Activités disponibles :
${formattedActivities.length ? formattedActivities.map(a => `- ${a.name} | ${a.description} | ${a.price} ${a.currency || ''}`).join('\n') : 'Aucune activité trouvée'}

${dateVoyage ? `Vols disponibles pour le ${dateVoyage} :
${flights.length ? flights.slice(0, 5).map(f => `- ${f.flight?.iata || ''} | ${f.departure?.airport || ''} → ${f.arrival?.airport || ''} | ${f.airline?.name || ''}`).join('\n') : 'Aucun vol trouvé'}` : ''}

Assurez-vous de :
1. Créer un plan de voyage clair et structuré
2. Inclure des conseils pratiques pour chaque activité
3. Fournir des informations détaillées sur les transports
4. Donner des conseils locaux utiles
5. Calculer un budget réaliste
6. Suivre EXACTEMENT le format demandé
7. Générer un itinéraire pour EXACTEMENT ${duration} jours`;

    // 6. Appel à l'API Gemini avec le nouveau prompt
    const responseText = await callGeminiAPI(prompt);
    console.log('🎉 Réponse de Gemini:', responseText);

    // 7. Envoi de la réponse avec les données nécessaires pour les actions
    const response = { 
      response: responseText,
      userId: userObjectId.toString(), // Ajouter l'userId à la réponse
      reasoning: {
        steps: reasoning.steps,
        suggested_itinerary: reasoning.suggested_itinerary,
        hotel_suggestions: reasoning.hotel_suggestions,
        restaurant_suggestions: reasoning.restaurant_suggestions,
        local_experiences: {
          cultural_insights: ["Marchés locaux", "Visites guidées insolites"],
          hidden_gems: ["Passages couverts", "Jardins secrets"],
          seasonal_events: ["Festivals locaux", "Événements culturels"]
        }
      },
      data: {
        hotels: Array.isArray(formattedHotels) ? formattedHotels : [],
        restaurants: Array.isArray(formattedRestaurants) ? formattedRestaurants : [],
        activities: Array.isArray(formattedActivities) ? formattedActivities : [],
        airports: Array.isArray(filteredAirports) ? filteredAirports : [],
        flights: Array.isArray(flights) ? flights.slice(0, 5) : []
      }
    };

    // Sauvegarder la conversation avec le nouvel userId
    try {
      console.log('Attempting to save conversation for userId ObjectId:', userObjectId);
      
      // Generate a simple title for the conversation
      const conversationTitle = ville ? `Voyage à ${ville}` : message.substring(0, Math.min(message.length, 50)) + '...';

      // Créer ou mettre à jour la conversation
      const conversation = await Conversation.findOneAndUpdate(
        { userId: userObjectId },
        {
          $push: {
            messages: {
              role: 'user',
              text: message,
              timestamp: new Date()
            }
          },
          $set: {
            detectedCity: ville || '',
            departureLocation: origin || '',
            arrivalLocation: ville || '',
            departureDate: departureDate || '',
            arrivalDate: arrivalDate || '',
            updatedAt: new Date(),
            title: conversationTitle
          }
        },
        { upsert: true, new: true }
      );
      console.log('User message saved. Conversation ID:', conversation?._id);

      // Ajouter la réponse du bot à la conversation
      await Conversation.findByIdAndUpdate(
        conversation._id,
        {
          $push: {
            messages: {
              role: 'bot',
              text: responseText,
              data: response.data,
              reasoning: response.reasoning,
              timestamp: new Date()
            }
          }
        }
      );
      console.log('Bot message added to conversation.');
    } catch (error) {
      console.error('❌ Erreur lors de la sauvegarde de la conversation:', error);
    }

    res.status(200).json(response);

  } catch (error) {
    console.error('❌ Erreur lors de la récupération des données:', error);
    res.status(500).json({ 
      error: 'Erreur serveur',
      userId: userObjectId.toString() // Inclure l'userId même en cas d'erreur
    });
  }
});

// Route pour exécuter une action utilisateur (ex: réservation d'hôtel)
router.post('/action', async (req, res) => {
  const { action, params } = req.body;
  if (!action) return res.status(400).json({ error: 'Action requise' });

  try {
    const result = await handleUserAction(action, params);
    res.status(200).json({ success: true, result });
  } catch (error) {
    console.error('❌ [ActionEngine] Erreur lors de l\'exécution de l\'action:', error);
    res.status(500).json({ error: 'Erreur lors de l\'exécution de l\'action' });
  }
});

// Nouvelle route pour gérer les actions de réservation
router.post('/reservation-action', async (req, res) => {
  const { action, params, message, modification } = req.body;
  console.log('📝 Action de réservation reçue:', action);

  // Filtre anti-action illégale
  if (isIllegalRequest(message)) {
    return res.status(403).json({
      response: "Je suis désolé, je ne peux pas vous aider pour cette demande."
    });
  }

  try {
    if (action === 'confirm') {
      // Situation 1: Confirmation de réservation
      console.log('✅ Confirmation de réservation demandée');
      
      // 1. Préparation des paramètres de réservation
      let bookingParams = { ...params };
      if (params.dateVoyage) {
        bookingParams.checkIn = params.dateVoyage;
        const inDate = new Date(params.dateVoyage);
        const outDate = new Date(inDate.getTime() + 3 * 24 * 60 * 60 * 1000); // +3 jours par défaut
        bookingParams.checkOut = outDate.toISOString().slice(0, 10);
      }

      // 2. Exécution de la réservation
      const bookingResult = await executeAction('bookHotel', bookingParams);
      console.log('🏨 Réservation effectuée:', bookingResult);

      // 3. Envoi de l'email de confirmation
      const tripSummary = `
        <h3>Détails de votre séjour</h3>
        <p>Hôtel: ${bookingParams.hotelName}</p>
        <p>Dates: ${bookingParams.checkIn} au ${bookingParams.checkOut}</p>
        <p>Prix total: ${bookingResult.totalPrice}</p>
      `;
      
      await sendConfirmationEmail(
        bookingParams.userEmail,
        tripSummary,
        bookingParams.departureLocation || bookingParams.departure || '',
        bookingParams.arrivalLocation || bookingParams.destination || '',
        bookingParams.userName || ''
      );
      console.log('📧 Email de confirmation envoyé');

      return res.status(200).json({
        success: true,
        result: bookingResult,
        emailSent: true,
        userEmail: bookingParams.userEmail
      });

    } else if (action === 'refuse') {
      console.log('Refus de la proposition');
      
      // 1. Récupérer les dates depuis params ou générer par défaut
      let departureDate = params?.departureDate;
      let arrivalDate = params?.arrivalDate;

      // Si aucune date, générer par défaut (aujourd'hui + 3 jours)
      if (!departureDate) {
        const today = new Date();
        departureDate = today.toISOString().slice(0, 10);
        const outDate = new Date(today.getTime() + 3 * 24 * 60 * 60 * 1000);
        arrivalDate = outDate.toISOString().slice(0, 10);
      } else if (!arrivalDate) {
        const inDate = new Date(departureDate);
        const outDate = new Date(inDate.getTime() + 3 * 24 * 60 * 60 * 1000);
        arrivalDate = outDate.toISOString().slice(0, 10);
      }

      // 2. Création du contexte pour le nouveau raisonnement
      const context = {
        ...params,
        previousRejection: true,
        rejectionReason: message,
        departureDate,
        arrivalDate
      };

      // 3. Relancement du raisonnement avec le nouveau contexte
      const reasoning = await chainOfThoughtReasoning(message, context);
      console.log('🧠 Nouveau raisonnement effectué');

      return res.status(200).json({
        response: reasoning.response || "D'accord, je vous propose d'autres options !",
        reasoning: reasoning.reasoning || {},
        data: {}
      });

    } else if (action === 'modify') {
      // Situation 3: Modification de la proposition
      console.log('🔄 Modification de la proposition');
      
      // 1. Récupérer les dates depuis modification OU params
      let departureDate = modification?.departureDate || params?.departureDate;
      let arrivalDate = modification?.arrivalDate || params?.arrivalDate;

      // Si l'utilisateur a mis une nouvelle date unique (ex: 'newDates'), on peut l'utiliser pour les deux
      if (modification?.newDates) {
        departureDate = modification.newDates;
        // Par défaut, +3 jours
        const inDate = new Date(modification.newDates);
        const outDate = new Date(inDate.getTime() + 3 * 24 * 60 * 60 * 1000);
        arrivalDate = outDate.toISOString().slice(0, 10);
      }

      const context = {
        ...params,
        ...modification,
        departureDate,
        arrivalDate,
        previousProposal: params,
        modificationReason: message
      };

      // 2. Relancement du raisonnement avec les nouveaux paramètres
      const reasoning = await chainOfThoughtReasoning(message, context);
      console.log('🧠 Nouveau raisonnement avec modifications');

      // 3. Envoi d'un email de modification si userEmail présent
      const userEmail = params.userEmail || modification?.userEmail;
      if (userEmail) {
        const modificationSummary = `
          <h3>Votre demande de modification a bien été prise en compte !</h3>
          <p>Message : ${message}</p>
          <p>Nouvelle proposition : ${reasoning.response}</p>
        `;
        await sendConfirmationEmail(
          userEmail,
          modificationSummary,
          params.departureLocation || params.departure || '',
          params.arrivalLocation || params.destination || '',
          params.userName || ''
        );
        console.log('📧 Email de modification envoyé');
      }

      return res.status(200).json({
        response: reasoning.response || "Voici un nouvel itinéraire adapté à vos modifications.",
        reasoning: reasoning.reasoning || {},
        data: {},
        emailSent: !!params.userEmail
      });

    } else {
      console.log('❌ Action inconnue:', action);
      return res.status(400).json({ error: 'Action inconnue' });
    }

  } catch (error) {
    console.error('❌ Erreur lors du traitement de la réservation:', error);
    res.status(500).json({ error: 'Erreur lors du traitement de la réservation' });
  }
});

// Route pour récupérer l'historique des conversations d'un utilisateur
router.get('/history/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    console.log('Attempting to fetch history for userId:', userId);
    
    // Utiliser la nouvelle méthode statique pour trouver les conversations
    const conversations = await Conversation.findByUserId(userId);
    
    console.log('Found', conversations.length, 'conversations for userId:', userId);
    res.status(200).json({ conversations });
  } catch (error) {
    console.error('❌ Erreur lors de la récupération de l\'historique:', error);
    res.status(500).json({ 
      error: 'Erreur lors de la récupération de l\'historique',
      details: error.message 
    });
  }
});

// Nouvelle route pour créer une nouvelle conversation
router.post('/new', async (req, res) => {
  const { userId } = req.body;
  console.log('🆕 Requête nouvelle conversation pour userId:', userId);

  if (!userId) {
    return res.status(400).json({ error: 'userId requis' });
  }

  try {
    const newConversation = new Conversation({
      userId: userId,
      title: 'Nouvelle conversation',
      messages: [{
        role: 'bot',
        text: 'Bonjour ! Je suis votre assistant de voyage. Comment puis-je vous aider ?',
        timestamp: new Date()
      }]
    });

    await newConversation.save();
    console.log('✅ Nouvelle conversation créée avec ID:', newConversation._id);

    res.status(200).json({ 
      success: true, 
      conversationId: newConversation._id, 
      userId: newConversation.userId 
    });

  } catch (error) {
    console.error('❌ Erreur lors de la création de la conversation:', error);
    res.status(500).json({ 
      error: 'Erreur lors de la création de la conversation',
      details: error.message 
    });
  }
});

module.exports = router;