const { callGeminiAPI } = require('./geminiService');
const { detectVilleEtQuartier } = require('../utils/cityDetector');
const { extractDateFromMessage } = require('../utils/dateExtractor');

// Fonction principale pour traiter un message et générer une réponse
async function sendMessage(message) {
  try {
    // 1. Détection de la ville et du quartier
    const locationInfo = detectVilleEtQuartier(message);
    const detectedCity = locationInfo ? locationInfo.ville : '';
    const detectedQuartier = locationInfo ? locationInfo.quartier : '';

    // 2. Extraction des dates
    const dateInfo = extractDateFromMessage(message);
    const departureDate = dateInfo?.departureDate || '';
    const arrivalDate = dateInfo?.arrivalDate || '';

    // 3. Construction du contexte pour l'API Gemini
    const context = {
      detectedCity,
      detectedQuartier,
      departureDate,
      arrivalDate,
      message
    };

    // 4. Appel à l'API Gemini pour générer la réponse
    const response = await callGeminiAPI(context);

    // 5. Formatage de la réponse
    return {
      text: response.response,
      data: {
        detectedCity,
        detectedQuartier,
        departureDate,
        arrivalDate,
        ...response.data
      },
      reasoning: response.reasoning
    };

  } catch (error) {
    console.error('Erreur dans le service de chat:', error);
    throw new Error('Erreur lors du traitement du message');
  }
}

module.exports = {
  sendMessage
}; 